import Foundation
import RealityKit
import Metal
import CoreGraphics
import simd

/// Builds every shared material once. Materials are value types in RealityKit, so
/// copying one to tweak a colour is cheap; the expensive part is texture creation.
@MainActor
final class SceneMaterials {

    let road: PhysicallyBasedMaterial
    let barrier: PhysicallyBasedMaterial
    let concrete: PhysicallyBasedMaterial
    let tunnelWall: PhysicallyBasedMaterial
    let facades: [PhysicallyBasedMaterial]
    /// Near-black wet asphalt for the street aprons and cross streets; red-white chevron barricades;
    /// red arrow signal panels (left, ahead, right).
    let asphalt: PhysicallyBasedMaterial
    let chevron: UnlitMaterial
    let arrowSigns: [UnlitMaterial]
    let skyline: PhysicallyBasedMaterial
    let tubeWall: PhysicallyBasedMaterial
    private var holoCache: [String: UnlitMaterial] = [:]
    let signs: [UnlitMaterial]
    let glyphSigns: [UnlitMaterial]
    let hologramSigns: [any Material]
    let environment: EnvironmentResource
    /// Arena-only materials (nil for the corridor worlds).
    private(set) var gridFloor: PhysicallyBasedMaterial? = nil
    private(set) var gridWall: PhysicallyBasedMaterial? = nil
    /// Generated art (`Art`, `docs/art-brief.md`): empty / nil when the files are absent or `SPEEDER_ART=0`.
    private(set) var artShops: [UnlitMaterial] = []          // street-level storefront quads (2:1)
    private(set) var artSkyline: UnlitMaterial? = nil        // the far backdrop strip, alpha-faded top and bottom
    private(set) var artBowl: UnlitMaterial? = nil           // the arena bowl backdrop, black keyed out
    private(set) var artScreens: [UnlitMaterial] = []        // the hanging arena screens
    private(set) var artGridSkyline: UnlitMaterial? = nil    // the Grid's skyline strip with the spire (black sky keyed out)
    private(set) var gridSkylineAspect: Float = 1774 / 227
    /// The Grid's wall tile aspect (width / height) when the generated tile is in use; nil = procedural.
    private(set) var gridWallAspect: Float? = nil
    let library: MTLLibrary?

    private let glowTexture: TextureResource
    private let streakTexture: TextureResource
    private var neonCache: [String: PhysicallyBasedMaterial] = [:]

    let theme: Theme

    init(device: MTLDevice?, theme: Theme = .neonCity) throws {
        self.theme = theme
        let day = theme == .sunsetCanyon
        let lib = device?.makeDefaultLibrary()
        library = lib
        // --- textures
        let roadAlbedo = try Self.texture(day ? ProceduralTextures.roadAlbedoDay() : ProceduralTextures.roadAlbedo(), .color)
        let (nImg, rImg) = ProceduralTextures.roadNormalAndRoughness()
        let roadNormal = try Self.texture(nImg, .normal)
        let roadRough = try Self.texture(day ? ProceduralTextures.flatRoughness(0.78) : rImg, .raw)
        glowTexture = try Self.texture(ProceduralTextures.glowSprite(), .color)
        streakTexture = try Self.texture(ProceduralTextures.reflectionStreak(), .color)
        switch theme {
        case .sunsetCanyon: environment = try EnvironmentResource(equirectangular: ProceduralTextures.environmentSunset(), withName: "sunset")
        case .neonCity: environment = try EnvironmentResource(equirectangular: ProceduralTextures.environment(), withName: "night")
        case .theGrid: environment = try EnvironmentResource(equirectangular: ProceduralTextures.environmentGrid(accent: Theme.gridAccent), withName: "grid-\(Theme.gridPalette)")
        }
        if theme == .theGrid {
            // floor: dark, glossy (IBL reflection sells it), grid lines in the emissive map
            let accent = Theme.gridAccent
            let (fb, fe) = ProceduralTextures.gridFloor(accent: accent)
            var gm = PhysicallyBasedMaterial()
            if let plate = Art.image("grid-floor-01") {
                // the generated floor plate (3 Oct 2026): albedo + roughness map + a normal derived from the
                // albedo, like the city road; the grid stays the procedural emissive layer on top
                gm.baseColor = .init(tint: .init(red: 0.95, green: 0.93, blue: 0.86, alpha: 1), texture: Self.repeating(try Self.texture(plate, .color)))   // pull the tile's blue toward charcoal
                gm.normal = .init(texture: Self.repeating(try Self.texture(Art.normalMap(plate, strength: 1.6), .normal)))
                if let rough = Art.image("grid-floor-01-rough") {
                    gm.roughness = .init(scale: 0.9, texture: Self.repeating(try Self.texture(rough, .raw)))
                } else {
                    gm.roughness = .init(floatLiteral: 0.42)
                }
                gm.specular = .init(floatLiteral: 1.0)
            } else {
                gm.baseColor = .init(tint: .white, texture: Self.repeating(try Self.texture(fb, .color)))
                gm.roughness = .init(floatLiteral: 0.42)
                gm.specular = .init(floatLiteral: 0.6)
            }
            gm.emissiveColor = .init(color: .black, texture: Self.repeating(try Self.texture(fe, .color)))
            gm.emissiveIntensity = 1.9
            gm.metallic = .init(floatLiteral: 0.06)
            gridFloor = gm
            let (wb, we) = ProceduralTextures.gridWall(accent: accent)
            var wm = PhysicallyBasedMaterial()
            if let tile = Art.image("grid-wall-01") {
                // the generated wall module: the tile is the base colour (its own cyan dimmed, the mask relit
                // in the palette's accent), a normal map from its luminance for the panel recesses
                wm.baseColor = .init(tint: .init(red: 1.25, green: 1.25, blue: 1.2, alpha: 1), texture: Self.repeating(try Self.texture(tile, .color)))   // the slab body must read, not just its channels
                wm.normal = .init(texture: Self.repeating(try Self.texture(Art.normalMap(tile, strength: 1.2), .normal)))
                let mask = Art.image("grid-wall-01-mask") ?? Art.emissiveMask(tile)
                wm.emissiveColor = .init(color: .black, texture: Self.repeating(try Self.texture(Art.tinted(mask, accent), .color)))
                wm.emissiveIntensity = 2.6
                wm.roughness = .init(floatLiteral: 0.5)
                wm.metallic = .init(floatLiteral: 0.2)
                gridWallAspect = Float(tile.width) / Float(tile.height)
            } else {
                wm.baseColor = .init(tint: .white, texture: Self.repeating(try Self.texture(wb, .color)))
                wm.emissiveColor = .init(color: .black, texture: Self.repeating(try Self.texture(we, .color)))
                wm.emissiveIntensity = 2.2
                wm.roughness = .init(floatLiteral: 0.45)
                wm.metallic = .init(floatLiteral: 0.25)
            }
            gridWall = wm
            if let sky = Art.image("grid-skyline") {
                // the strip is on a black sky: key it out and lift the darks so the towers survive the haze
                let tex = try Self.texture(Art.keyedBlack(sky, floor: 0.03, ramp: 0.08, lift: 2.5), .color)
                gridSkylineAspect = Float(sky.width) / Float(sky.height)
                var m = UnlitMaterial()
                m.color = .init(tint: .rgb(SIMD3(0.7, 0.78, 0.84)), texture: .init(tex))
                m.blending = .transparent(opacity: .init(scale: 1, texture: .init(tex)))
                artGridSkyline = m
            }
            if let img = Art.image("grid-bowl") {
                let tex = try Self.texture(Art.keyedBlack(img, lift: 4.0), .color)
                var m = UnlitMaterial()
                m.color = .init(tint: .rgb(SIMD3(0.55, 0.55, 0.55) + accent * 0.45), texture: .init(tex))   // the lift whitens the lights; pull them back to the accent
                m.blending = .transparent(opacity: .init(scale: 1, texture: .init(tex)))
                artBowl = m
            }
            for img in Art.images("grid-screen") {
                let tex = try Self.texture(Art.keyedBlack(img, lift: 2.0), .color)
                var m = UnlitMaterial()
                m.color = .init(tint: .white, texture: .init(tex))
                m.blending = .transparent(opacity: .init(scale: 1, texture: .init(tex)))
                artScreens.append(m)
            }
        }

        // --- road: dark, low roughness in puddles, normal map for ripple highlights
        var rm = PhysicallyBasedMaterial()
        rm.baseColor = .init(tint: .white, texture: Self.repeating(roadAlbedo))
        rm.normal = .init(texture: Self.repeating(roadNormal))
        rm.roughness = .init(scale: 1.0, texture: Self.repeating(roadRough))
        rm.metallic = .init(floatLiteral: 0.0)
        rm.specular = .init(floatLiteral: 1.0)
        rm.textureCoordinateTransform = .init(offset: .zero, scale: SIMD2<Float>(2, 4.5), rotation: 0)
        road = rm

        var bm = PhysicallyBasedMaterial()
        bm.baseColor = .init(tint: day ? .rgb(0.55, 0.52, 0.48) : .rgb(0.06, 0.065, 0.08))
        bm.roughness = .init(floatLiteral: day ? 0.8 : 0.55)
        bm.metallic = .init(floatLiteral: day ? 0.0 : 0.3)
        barrier = bm

        var cm = PhysicallyBasedMaterial()
        cm.baseColor = .init(tint: day ? .rgb(0.50, 0.44, 0.38) : .rgb(0.04, 0.042, 0.055))
        cm.roughness = .init(floatLiteral: 0.85)
        concrete = cm
        var am = PhysicallyBasedMaterial()
        am.baseColor = .init(tint: .rgb(0.010, 0.011, 0.016))
        am.roughness = .init(floatLiteral: 0.55)
        am.metallic = .init(floatLiteral: 0.0)
        am.specular = .init(floatLiteral: 0.6)
        asphalt = am
        var chev = UnlitMaterial()
        chev.color = .init(tint: .white, texture: Self.repeating(try Self.texture(ProceduralTextures.chevronStripes(), .color)))
        chev.textureCoordinateTransform = .init(offset: .zero, scale: SIMD2(6, 1), rotation: 0)
        chevron = chev
        var arrows: [UnlitMaterial] = []
        for dir in [-1, 0, 1] {
            var m = UnlitMaterial()
            m.color = .init(tint: .white, texture: .init(try Self.texture(ProceduralTextures.arrowSign(direction: dir), .color)))
            arrows.append(m)
        }
        arrowSigns = arrows

        // tunnel interiors: dark rock by day (IBL ignores occlusion, so fake the shade), barrier panels by night
        var tm = PhysicallyBasedMaterial()
        if day {
            tm.baseColor = .init(tint: .rgb(0.28, 0.17, 0.12), texture: Self.repeating(try Self.texture(ProceduralTextures.rockFacade(seed: 411), .color)))
            tm.roughness = .init(floatLiteral: 1.0)
        } else {
            tm = bm
        }
        tunnelWall = tm

        // --- building facades (3 curated variants); the arena needs none of the city art
        var fs: [PhysicallyBasedMaterial] = []
        if theme == .theGrid {
            facades = [bm, bm, bm]
            skyline = bm
        } else if day {
            for seed in [401, 402, 403] {
                var m = PhysicallyBasedMaterial()
                m.baseColor = .init(tint: .white, texture: Self.repeating(try Self.texture(ProceduralTextures.rockFacade(seed: seed), .color)))
                m.roughness = .init(floatLiteral: 0.95)
                m.metallic = .init(floatLiteral: 0.0)
                fs.append(m)
            }
            facades = fs
            var sk = PhysicallyBasedMaterial()
            sk.baseColor = .init(tint: .rgb(0.45, 0.30, 0.28), texture: Self.repeating(try Self.texture(ProceduralTextures.rockFacade(seed: 409), .color)))
            sk.roughness = .init(floatLiteral: 1.0)
            skyline = sk
        } else {
            for seed in [101, 202, 303] {
                let (b, e) = ProceduralTextures.facade(seed: seed)
                var m = PhysicallyBasedMaterial()
                m.baseColor = .init(tint: .white, texture: Self.repeating(try Self.texture(b, .color)))
                // NOTE: RealityKit adds the emissive colour on top of the texture (it is not a tint), so it must stay black here.
                m.emissiveColor = .init(color: .black, texture: Self.repeating(try Self.texture(e, .color)))
                m.emissiveIntensity = 1.0
                m.roughness = .init(floatLiteral: 0.55)
                m.metallic = .init(floatLiteral: 0.15)
                fs.append(m)
            }
            // generated facades: the picture is both the albedo (dimmed) and the emissive, so the lit windows glow
            for img in Art.images("neon-facade") {
                let tex = Self.repeating(try Self.texture(img, .color))
                var m = PhysicallyBasedMaterial()
                m.baseColor = .init(tint: .rgb(0.38, 0.38, 0.46), texture: tex)
                m.emissiveColor = .init(color: .black, texture: tex)
                m.emissiveIntensity = 1.25
                m.roughness = .init(floatLiteral: 0.6)
                m.metallic = .init(floatLiteral: 0.1)
                fs.append(m)
            }
            facades = fs
            for img in Art.images("neon-shop") {
                var m = UnlitMaterial()
                m.color = .init(tint: .white, texture: .init(try Self.texture(img, .color)))
                artShops.append(m)
            }
            if let img = Art.image("neon-skyline") {
                let tex = try Self.texture(Art.faded(img, top: 0.10, bottom: 0.92, fade: 0.22), .color)
                var m = UnlitMaterial()
                m.color = .init(tint: .rgb(0.85, 0.85, 0.95), texture: .init(tex))
                m.blending = .transparent(opacity: .init(scale: 1, texture: .init(tex)))
                artSkyline = m
            }
            let (sb, se) = ProceduralTextures.skylineFacade()
            var sk = PhysicallyBasedMaterial()
            sk.baseColor = .init(tint: .white, texture: Self.repeating(try Self.texture(sb, .color)))
            sk.emissiveColor = .init(color: .black, texture: Self.repeating(try Self.texture(se, .color)))
            sk.emissiveIntensity = 1.4
            sk.roughness = .init(floatLiteral: 0.9)
            skyline = sk
        }

        let (tb, te) = ProceduralTextures.tubePanel()
        var tw = PhysicallyBasedMaterial()
        tw.baseColor = .init(tint: day ? .rgb(0.55, 0.32, 0.20) : .white, texture: Self.repeating(try Self.texture(tb, .color)))
        tw.emissiveColor = .init(color: .black, texture: Self.repeating(try Self.texture(te, .color)))
        tw.emissiveIntensity = day ? 0.9 : 1.6
        tw.roughness = .init(floatLiteral: day ? 0.7 : 0.4)
        tw.metallic = .init(floatLiteral: 0.6)
        tw.faceCulling = .none
        tubeWall = tw

        // --- signs
        var signMats: [UnlitMaterial] = []
        var holo: [any Material] = []
        let library = lib
        for (i, text) in (theme == .theGrid ? [] : ProceduralTextures.signTexts).enumerated() {
            let color = Neon.all[i % Neon.all.count]
            let accent = Neon.all[(i * 5 + 2) % Neon.all.count]
            let tex = try Self.texture(ProceduralTextures.billboard(text: text, color: color, accent: accent, seed: i), .color)
            var m = UnlitMaterial()
            m.color = .init(tint: .white, texture: .init(tex))
            signMats.append(m)
            if let library, let h = Self.hologram(texture: tex, library: library) { holo.append(h) } else { holo.append(m) }
        }
        // generated billboards join the sign pool (the mega-signs and the building billboards pick from it)
        if theme == .neonCity {
            for img in Art.images("neon-sign") {
                var m = UnlitMaterial()
                m.color = .init(tint: .white, texture: .init(try Self.texture(img, .color)))
                signMats.append(m); holo.append(m)
            }
        }
        signs = signMats
        hologramSigns = holo

        var glyphs: [UnlitMaterial] = []
        for i in 0..<(theme == .theGrid ? 0 : 6) {
            let tex = try Self.texture(ProceduralTextures.glyphStrip(color: Neon.all[(i * 7) % Neon.all.count], seed: 900 + i), .color)
            var m = UnlitMaterial()
            m.color = .init(tint: .white, texture: .init(tex))
            glyphs.append(m)
        }
        glyphSigns = glyphs
    }

    // MARK: - Factories

    /// Emissive neon surface. Intensity > 1 pushes it well over the bloom threshold.
    func neon(_ color: SIMD3<Float>, intensity rawIntensity: Float = 3.0) -> PhysicallyBasedMaterial {
        let intensity = rawIntensity * theme.neonScale
        let key = "\(color.x),\(color.y),\(color.z),\(intensity)"
        if let m = neonCache[key] { return m }
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .rgb(color * (theme == .neonCity ? 0.6 : 0.9)))
        m.emissiveColor = .init(color: .rgb(color))
        m.emissiveIntensity = intensity
        m.roughness = .init(floatLiteral: 0.3)
        m.metallic = .init(floatLiteral: 0.0)
        neonCache[key] = m
        return m
    }

    /// Translucent hologram panel used by the obstacle skin.
    func holoPanel(_ color: SIMD3<Float>) -> UnlitMaterial {
        let key = "\(color.x),\(color.y),\(color.z)"
        if let m = holoCache[key] { return m }
        var hp = UnlitMaterial()
        hp.color = .init(tint: .rgb(color * 0.9))
        hp.blending = .transparent(opacity: .init(floatLiteral: 0.42))
        holoCache[key] = hp
        return hp
    }

    /// Soft additive-looking halo quad (alpha blended; bloom finishes the job).
    func glow(_ color: SIMD3<Float>, opacity: Float) -> UnlitMaterial {
        var m = UnlitMaterial()
        m.color = .init(tint: .rgb(color), texture: .init(glowTexture))
        m.blending = .transparent(opacity: .init(scale: opacity, texture: .init(glowTexture)))
        return m
    }

    /// Fake wet-road reflection pool for a light source.
    func reflection(_ color: SIMD3<Float>, opacity: Float) -> UnlitMaterial {
        var m = UnlitMaterial()
        m.color = .init(tint: .rgb(color), texture: .init(streakTexture))
        m.blending = .transparent(opacity: .init(scale: opacity, texture: .init(streakTexture)))
        return m
    }

    // MARK: - Helpers

    static func texture(_ image: CGImage, _ semantic: TextureResource.Semantic) throws -> TextureResource {
        try TextureResource(image: image, options: .init(semantic: semantic))
    }

    static func repeating(_ tex: TextureResource) -> MaterialParameters.Texture {
        let d = MTLSamplerDescriptor()
        d.sAddressMode = .repeat
        d.tAddressMode = .repeat
        d.minFilter = .linear
        d.magFilter = .linear
        d.mipFilter = .linear
        d.maxAnisotropy = 8
        return MaterialParameters.Texture(tex, sampler: .init(d))
    }

    private static func hologram(texture: TextureResource, library: MTLLibrary) -> (any Material)? {
        do {
            let shader = CustomMaterial.SurfaceShader(named: "hologramSurface", in: library)
            var m = try CustomMaterial(surfaceShader: shader, lightingModel: .unlit)
            m.baseColor = .init(tint: .white, texture: .init(texture))
            return m
        } catch {
            print("CustomMaterial unavailable: \(error)")
            return nil
        }
    }
}
