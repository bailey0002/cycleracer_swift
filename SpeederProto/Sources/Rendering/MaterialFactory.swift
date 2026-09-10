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
        case .theGrid: environment = try EnvironmentResource(equirectangular: ProceduralTextures.environmentGrid(), withName: "grid")
        }
        if theme == .theGrid {
            // floor: dark, glossy (IBL reflection sells it), grid lines in the emissive map
            let (fb, fe) = ProceduralTextures.gridFloor()
            var gm = PhysicallyBasedMaterial()
            gm.baseColor = .init(tint: .white, texture: Self.repeating(try Self.texture(fb, .color)))
            gm.emissiveColor = .init(color: .black, texture: Self.repeating(try Self.texture(fe, .color)))
            gm.emissiveIntensity = 2.2
            gm.roughness = .init(floatLiteral: 0.2)
            gm.metallic = .init(floatLiteral: 0.0)
            gm.specular = .init(floatLiteral: 1.0)
            gridFloor = gm
            let (wb, we) = ProceduralTextures.gridWall()
            var wm = PhysicallyBasedMaterial()
            wm.baseColor = .init(tint: .white, texture: Self.repeating(try Self.texture(wb, .color)))
            wm.emissiveColor = .init(color: .black, texture: Self.repeating(try Self.texture(we, .color)))
            wm.emissiveIntensity = 2.6
            wm.roughness = .init(floatLiteral: 0.35)
            wm.metallic = .init(floatLiteral: 0.2)
            gridWall = wm
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
            facades = fs
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
