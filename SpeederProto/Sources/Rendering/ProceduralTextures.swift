import Foundation
import CoreGraphics
import CoreText
import simd

/// All environment art is generated at launch with Core Graphics so the prototype
/// has zero external dependencies beyond the speeder USDZ. Every generator is
/// deterministic (seeded) so the look is repeatable between runs.
enum ProceduralTextures {

    // MARK: - Image construction helpers

    static func makeImage(width: Int, height: Int, _ shade: (Int, Int) -> SIMD4<Float>) -> CGImage {
        var data = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let c = shade(x, y)
                let a = clamp01(c.w)
                let i = (y * width + x) * 4
                data[i]     = UInt8(clamp01(c.x * a) * 255)   // premultiplied
                data[i + 1] = UInt8(clamp01(c.y * a) * 255)
                data[i + 2] = UInt8(clamp01(c.z * a) * 255)
                data[i + 3] = UInt8(a * 255)
            }
        }
        let provider = CGDataProvider(data: Data(data) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }

    static func draw(width: Int, height: Int, _ body: (CGContext) -> Void) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        body(ctx)
        return ctx.makeImage()!
    }

    // MARK: - Noise

    @inline(__always) static func hash(_ x: Int, _ y: Int, _ seed: Int) -> Float {
        var h = UInt32(truncatingIfNeeded: x &* 374761393 &+ y &* 668265263 &+ seed &* 1442695041)
        h = (h ^ (h >> 13)) &* 1274126177
        h ^= h >> 16
        return Float(h & 0xFFFFFF) / Float(0xFFFFFF)
    }

    /// Tileable value noise. `wrap` is the lattice period.
    static func valueNoise(_ x: Float, _ y: Float, seed: Int, wrap: Int) -> Float {
        let xf = floor(x), yf = floor(y)
        let xi = Int(xf), yi = Int(yf)
        var fx = x - xf, fy = y - yf
        fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
        func h(_ a: Int, _ b: Int) -> Float { hash(((a % wrap) + wrap) % wrap, ((b % wrap) + wrap) % wrap, seed) }
        let a = h(xi, yi), b = h(xi + 1, yi), c = h(xi, yi + 1), d = h(xi + 1, yi + 1)
        return lerp(lerp(a, b, fx), lerp(c, d, fx), fy)
    }

    static func fbm(_ x: Float, _ y: Float, octaves: Int, seed: Int, wrap: Int) -> Float {
        var sum: Float = 0, amp: Float = 0.5, freq: Float = 1, norm: Float = 0
        for o in 0..<octaves {
            sum += valueNoise(x * freq, y * freq, seed: seed + o * 17, wrap: wrap * Int(freq)) * amp
            norm += amp; amp *= 0.5; freq *= 2
        }
        return sum / norm
    }

    // MARK: - Road

    /// Dark wet asphalt albedo: fine grain, faint tyre bands, occasional lighter aggregate.
    static func roadAlbedo(size: Int = 512) -> CGImage {
        makeImage(width: size, height: size) { x, y in
            let u = Float(x) / Float(size), v = Float(y) / Float(size)
            let grain = fbm(u * 24, v * 24, octaves: 4, seed: 11, wrap: 24)
            let patch = fbm(u * 3, v * 3, octaves: 3, seed: 5, wrap: 3)
            var base: Float = 0.030 + grain * 0.035 + patch * 0.02
            // tyre-polished bands are slightly darker and glossier
            for lane in [0.18, 0.32, 0.68, 0.82] as [Float] {
                let d = abs(u - lane)
                if d < 0.05 { base -= 0.012 * (1 - d / 0.05) }
            }
            let speck: Float = hash(x, y, 99) > 0.995 ? 0.06 : 0
            let c = base + speck
            return SIMD4<Float>(c * 0.92, c * 0.95, c * 1.08, 1)
        }
    }

    /// Height-derived normal map with flat puddles and rough asphalt in between.
    static func roadNormalAndRoughness(size: Int = 512) -> (normal: CGImage, roughness: CGImage) {
        var height = [Float](repeating: 0, count: size * size)
        var puddle = [Float](repeating: 0, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                let u = Float(x) / Float(size), v = Float(y) / Float(size)
                let low = fbm(u * 4, v * 4, octaves: 3, seed: 31, wrap: 4)
                let p = smooth(0.50, 0.60, low)               // 1 inside puddles
                let hi = fbm(u * 40, v * 40, octaves: 3, seed: 47, wrap: 40)
                height[y * size + x] = (1 - p) * hi
                puddle[y * size + x] = p
            }
        }
        let normal = makeImage(width: size, height: size) { x, y in
            func h(_ dx: Int, _ dy: Int) -> Float { height[((y + dy + size) % size) * size + ((x + dx + size) % size)] }
            let strength: Float = 1.3
            let dx = (h(1, 0) - h(-1, 0)) * strength
            let dy = (h(0, 1) - h(0, -1)) * strength
            let n = simd_normalize(SIMD3<Float>(-dx, -dy, 1))
            return SIMD4<Float>(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1)
        }
        let rough = makeImage(width: size, height: size) { x, y in
            let p = puddle[y * size + x]
            let hi = height[y * size + x]
            let r = lerp(0.42 + hi * 0.25, 0.06, p)
            return SIMD4<Float>(r, r, r, 1)
        }
        return (normal, rough)
    }

    @inline(__always) static func smooth(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
        let t = clamp01((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t)
    }

    // MARK: - Buildings

    /// A facade tile covering roughly 24 m x 36 m: 8 x 12 windows.
    /// Returns a dark base-color image and an emissive image containing only lit windows.
    static func facade(seed: Int, size: Int = 1024) -> (base: CGImage, emissive: CGImage) {
        let cols = 16, rows = 24
        let cw = size / cols, rh = size / rows
        // Per-window decisions
        var lit = [SIMD3<Float>](repeating: .zero, count: cols * rows)
        var rng = SeededRNG(seed: UInt64(seed))
        let warm  = SIMD3<Float>(1.0, 0.80, 0.55)
        let cool  = SIMD3<Float>(0.60, 0.82, 1.0)
        let white = SIMD3<Float>(0.85, 0.88, 1.0)
        for i in 0..<(cols * rows) {
            if rng.chance(seed % 2 == 0 ? 0.30 : 0.22) {
                let roll = rng.float()
                let col: SIMD3<Float> = roll < 0.55 ? warm : roll < 0.82 ? cool : roll < 0.93 ? white : (rng.chance(0.5) ? Neon.magenta : Neon.cyan)
                lit[i] = col * rng.float(0.35, 0.9)
            }
        }
        let frame: Float = 0.16   // fraction of cell that is wall
        // grime is low frequency: evaluate on a coarse grid instead of per pixel
        let g = 128
        var grimeGrid = [Float](repeating: 0, count: g * g)
        for gy in 0..<g { for gx in 0..<g {
            grimeGrid[gy * g + gx] = fbm(Float(gx) / Float(g) * 6, Float(gy) / Float(g) * 6, octaves: 3, seed: seed, wrap: 6)
        } }
        let base = makeImage(width: size, height: size) { x, y in
            let cx = min(x / cw, cols - 1), cy = min(y / rh, rows - 1)
            let fx = Float(x % cw) / Float(cw), fy = Float(y % rh) / Float(rh)
            let inWindow = fx > frame && fx < 1 - frame && fy > frame * 1.6 && fy < 1 - frame * 1.6
            let grime = grimeGrid[(y * g / size) * g + (x * g / size)]
            if inWindow {
                let l = lit[cy * cols + cx]
                let glass = SIMD3<Float>(0.02, 0.025, 0.04) + l * 0.15
                return SIMD4<Float>(glass.x, glass.y, glass.z, 1)
            }
            let wall: Float = 0.045 + grime * 0.04
            return SIMD4<Float>(wall * 0.9, wall * 0.95, wall * 1.1, 1)
        }
        let emissive = makeImage(width: size, height: size) { x, y in
            let cx = min(x / cw, cols - 1), cy = min(y / rh, rows - 1)
            let fx = Float(x % cw) / Float(cw), fy = Float(y % rh) / Float(rh)
            let inWindow = fx > frame && fx < 1 - frame && fy > frame * 1.6 && fy < 1 - frame * 1.6
            guard inWindow else { return SIMD4<Float>(0, 0, 0, 1) }
            var l = lit[cy * cols + cx]
            // blinds: darken the lower part of some windows
            if hash(cx, cy, seed + 3) > 0.7 && fy > 0.55 { l *= 0.25 }
            return SIMD4<Float>(l.x, l.y, l.z, 1)
        }
        return (base, emissive)
    }

    /// Distant skyline towers: sparse tiny windows, mostly dark.
    static func skylineFacade(size: Int = 256) -> (base: CGImage, emissive: CGImage) {
        let base = makeImage(width: size, height: size) { _, _ in SIMD4<Float>(0.02, 0.022, 0.035, 1) }
        let emissive = makeImage(width: size, height: size) { x, y in
            let cell = 8
            let cx = x / cell, cy = y / cell
            let on = hash(cx, cy, 77) > 0.72
            let fx = x % cell, fy = y % cell
            let inside = fx >= 2 && fx <= 5 && fy >= 2 && fy <= 4
            if on && inside {
                let warmish = hash(cx, cy, 78) > 0.5
                let c: SIMD3<Float> = warmish ? SIMD3(1.0, 0.75, 0.45) : SIMD3(0.5, 0.8, 1.0)
                let b = 0.4 + hash(cx, cy, 79) * 0.6
                return SIMD4<Float>(c.x * b, c.y * b, c.z * b, 1)
            }
            return SIMD4<Float>(0, 0, 0, 1)
        }
        return (base, emissive)
    }

    // MARK: - Signs

    static let signTexts = ["NEXUS", "KAZE", "VOLT", "SYNTH", "HALO CORP", "ORBITAL", "ZERO-G", "AXIOM",
                            "DRIFT", "PULSE", "NOVA LINE", "SECTOR 7", "ION", "VEGA", "HYPERWAY", "MERIDIAN"]

    private static func font(_ size: CGFloat) -> CTFont {
        let f = CTFontCreateWithName("AvenirNext-Heavy" as CFString, size, nil)
        return f
    }

    private static func cg(_ c: SIMD3<Float>, _ a: Float = 1) -> CGColor {
        CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [CGFloat(c.x), CGFloat(c.y), CGFloat(c.z), CGFloat(a)])!
    }

    private static func drawText(_ text: String, in ctx: CGContext, rect: CGRect, color: SIMD3<Float>, maxSize: CGFloat) {
        var size = maxSize
        var line: CTLine
        var width: CGFloat
        repeat {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font(size),
                .foregroundColor: cg(color)
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            line = CTLineCreateWithAttributedString(str)
            width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            size *= 0.9
        } while width > rect.width * 0.86 && size > 8
        var ascent: CGFloat = 0, descent: CGFloat = 0
        _ = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        let x = rect.midX - width / 2
        let y = rect.midY - (ascent - descent) / 2
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: rect.height * 0.12, color: cg(color, 0.9))
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
        ctx.textPosition = CGPoint(x: x, y: y)   // CTLineDraw advances the position
        CTLineDraw(line, ctx)   // second pass thickens the glow
        ctx.restoreGState()
    }

    private static func scanlines(_ ctx: CGContext, width: Int, height: Int) {
        ctx.setFillColor(CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0, 0, 0, 0.18])!)
        var y = 0
        while y < height { ctx.fill(CGRect(x: 0, y: y, width: width, height: 2)); y += 6 }
    }

    /// Landscape billboard 2:1 with a neon border and bold text.
    static func billboard(text: String, color: SIMD3<Float>, accent: SIMD3<Float>, seed: Int, width: Int = 1024, height: Int = 512) -> CGImage {
        draw(width: width, height: height) { ctx in
            let w = CGFloat(width), h = CGFloat(height)
            ctx.setFillColor(cg(SIMD3(0.015, 0.012, 0.03)))
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            // soft gradient wash
            let cs = CGColorSpaceCreateDeviceRGB()
            let grad = CGGradient(colorsSpace: cs, colors: [cg(accent, 0.35), cg(color, 0.0)] as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])
            // border
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 18, color: cg(color, 1))
            ctx.setStrokeColor(cg(color)); ctx.setLineWidth(10)
            ctx.stroke(CGRect(x: 16, y: 16, width: w - 32, height: h - 32))
            ctx.setStrokeColor(cg(accent)); ctx.setLineWidth(4)
            ctx.stroke(CGRect(x: 40, y: 40, width: w - 80, height: h - 80))
            ctx.restoreGState()
            // decorative bar + small caption
            var rng = SeededRNG(seed: UInt64(seed))
            let barY = rng.chance(0.5) ? h * 0.18 : h * 0.78
            ctx.setFillColor(cg(accent, 0.9))
            ctx.fill(CGRect(x: w * 0.12, y: barY, width: w * 0.76, height: 8))
            drawText(text, in: ctx, rect: CGRect(x: 0, y: h * 0.22, width: w, height: h * 0.56), color: color, maxSize: h * 0.42)
            let captions = ["DRIVE FURTHER", "A CLEANER TOMORROW", "NIGHT SHIFT", "FEEL THE VOLTAGE", "LEVEL 9 ACCESS", "NO LIMITS"]
            drawText(rng.pick(captions), in: ctx, rect: CGRect(x: 0, y: barY < h / 2 ? h * 0.05 : h * 0.83, width: w, height: h * 0.12), color: accent, maxSize: h * 0.09)
            scanlines(ctx, width: width, height: height)
        }
    }

    /// Tall vertical sign with abstract glyph blocks (reads like distant foreign lettering).
    static func glyphStrip(color: SIMD3<Float>, seed: Int, width: Int = 256, height: Int = 1024) -> CGImage {
        draw(width: width, height: height) { ctx in
            let w = CGFloat(width), h = CGFloat(height)
            ctx.setFillColor(cg(SIMD3(0.01, 0.01, 0.02)))
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 14, color: cg(color, 1))
            ctx.setStrokeColor(cg(color)); ctx.setLineWidth(6)
            ctx.stroke(CGRect(x: 12, y: 12, width: w - 24, height: h - 24))
            var rng = SeededRNG(seed: UInt64(seed))
            let cells = 6
            let cellH = (h - 60) / CGFloat(cells)
            for i in 0..<cells {
                let oy = 30 + CGFloat(i) * cellH + cellH * 0.15
                let box = CGRect(x: w * 0.2, y: oy, width: w * 0.6, height: cellH * 0.7)
                ctx.setLineWidth(9)
                ctx.setLineCap(.round)
                let strokes = Int(rng.float(3, 7))
                for _ in 0..<strokes {
                    let p1 = CGPoint(x: box.minX + CGFloat(rng.float()) * box.width, y: box.minY + CGFloat(rng.float()) * box.height)
                    let horizontal = rng.chance(0.5)
                    let p2 = horizontal ? CGPoint(x: box.minX + CGFloat(rng.float()) * box.width, y: p1.y)
                                        : CGPoint(x: p1.x, y: box.minY + CGFloat(rng.float()) * box.height)
                    ctx.move(to: p1); ctx.addLine(to: p2); ctx.strokePath()
                }
            }
            ctx.restoreGState()
            scanlines(ctx, width: width, height: height)
        }
    }

    /// Dark metal panels with dim emissive seams and a few lit tiles, for the conduit tube.
    static func tubePanel(size: Int = 512) -> (base: CGImage, emissive: CGImage) {
        let cell = size / 4
        let base = makeImage(width: size, height: size) { x, y in
            let fx = x % cell, fy = y % cell
            let seam = fx < 3 || fy < 3
            let v: Float = seam ? 0.02 : 0.045 + hash(x / 16, y / 16, 5) * 0.02
            return SIMD4<Float>(v * 0.9, v, v * 1.15, 1)
        }
        let emissive = makeImage(width: size, height: size) { x, y in
            let fx = x % cell, fy = y % cell
            let cx = x / cell, cy = y / cell
            if fx < 3 || fy < 3 { return SIMD4<Float>(0.08, 0.16, 0.35, 1) }
            let r = hash(cx, cy, 9)
            if r > 0.965 && fx > 40 && fx < cell - 40 && fy > 40 && fy < cell - 40 {
                let c = r > 0.985 ? Neon.magenta : Neon.cyan
                return SIMD4<Float>(c.x * 0.28, c.y * 0.28, c.z * 0.28, 1)
            }
            return SIMD4<Float>(0, 0, 0, 1)
        }
        return (base, emissive)
    }

    // MARK: - Sprites

    /// Soft radial glow, white premultiplied, for engine halos.
    static func glowSprite(size: Int = 128) -> CGImage {
        makeImage(width: size, height: size) { x, y in
            let dx = (Float(x) + 0.5) / Float(size) * 2 - 1
            let dy = (Float(y) + 0.5) / Float(size) * 2 - 1
            let r = sqrt(dx * dx + dy * dy)
            let a = pow(clamp01(1 - r), 2.2)
            return SIMD4<Float>(1, 1, 1, a)
        }
    }

    /// Elongated soft ellipse used as a fake wet-road reflection under each light.
    static func reflectionStreak(width: Int = 64, height: Int = 256) -> CGImage {
        makeImage(width: width, height: height) { x, y in
            let dx = (Float(x) + 0.5) / Float(width) * 2 - 1
            let dy = (Float(y) + 0.5) / Float(height) * 2 - 1
            let a = pow(clamp01(1 - abs(dx)), 1.8) * pow(clamp01(1 - abs(dy)), 1.2)
            let ripple = 0.85 + 0.15 * sin(dy * 40)
            return SIMD4<Float>(1, 1, 1, a * ripple * 0.9)
        }
    }

    // MARK: - Canyon theme

    /// Sandstone strata: horizontal bands of red-brown with noise, no emissive.
    static func rockFacade(seed: Int, size: Int = 512) -> CGImage {
        makeImage(width: size, height: size) { x, y in
            let u = Float(x) / Float(size), v = Float(y) / Float(size)
            let band = fbm(u * 2, v * 14, octaves: 3, seed: seed, wrap: 2)
            let grain = fbm(u * 18, v * 18, octaves: 3, seed: seed + 5, wrap: 18)
            let strata = 0.5 + 0.5 * sin(v * 60 + band * 6)
            let base = SIMD3<Float>(0.62, 0.36, 0.22)
            let dark = SIMD3<Float>(0.30, 0.15, 0.10)
            let sand = SIMD3<Float>(0.80, 0.62, 0.42)
            let toDark: SIMD3<Float> = (dark - base) * (strata * 0.85)
            let toSand: SIMD3<Float> = (sand - base) * (band * 0.35)
            var c: SIMD3<Float> = base + toDark + toSand
            let gainF: Float = 0.85 + grain * 0.3
            c *= gainF
            return SIMD4<Float>(c.x, c.y, c.z, 1)
        }
    }

    /// Dry two-lane asphalt with sandy shoulders (lane paint is geometry, as in the city).
    static func roadAlbedoDay(size: Int = 512) -> CGImage {
        makeImage(width: size, height: size) { x, y in
            let u = Float(x) / Float(size), v = Float(y) / Float(size)
            let grain = fbm(u * 24, v * 24, octaves: 4, seed: 11, wrap: 24)
            let patch = fbm(u * 3, v * 3, octaves: 3, seed: 5, wrap: 3)
            var g: Float = 0.16 + grain * 0.08 + patch * 0.05
            for lane in [0.18, 0.32, 0.68, 0.82] as [Float] {
                let d = abs(u - lane)
                if d < 0.05 { g -= 0.03 * (1 - d / 0.05) }
            }
            let asphalt = SIMD3<Float>(g, g * 0.98, g * 0.94)
            let edge: Float = smooth(0.04, 0.09, min(u, 1 - u))
            let sandGain: Float = 0.8 + grain * 0.3
            let sand: SIMD3<Float> = SIMD3<Float>(0.72, 0.56, 0.36) * sandGain
            let c: SIMD3<Float> = sand + (asphalt - sand) * edge
            return SIMD4<Float>(c.x, c.y, c.z, 1)
        }
    }

    /// Uniform dry roughness.
    static func flatRoughness(_ r: Float, size: Int = 8) -> CGImage {
        makeImage(width: size, height: size) { _, _ in SIMD4<Float>(r, r, r, 1) }
    }

    /// Low sun on the horizon ahead, orange to violet sky, warm sandy ground.
    static func environmentSunset(width: Int = 1024, height: Int = 512) -> CGImage {
        makeImage(width: width, height: height) { x, y in
            let u = Float(x) / Float(width)
            let v = Float(y) / Float(height)
            let elev = (0.5 - v) * Float.pi
            var c: SIMD3<Float>
            if elev >= 0 {
                let t = pow(clamp01(1 - elev / (Float.pi / 2)), 2.2)
                let zenith = SIMD3<Float>(0.16, 0.13, 0.36)
                let horizon = SIMD3<Float>(1.0, 0.55, 0.30)
                c = zenith + (horizon - zenith) * t
                let cl = fbm(u * 10, v * 6, octaves: 4, seed: 21, wrap: 10)
                c += SIMD3<Float>(0.35, 0.18, 0.12) * pow(cl, 2) * t
            } else {
                let g = fbm(u * 6, v * 6, octaves: 3, seed: 31, wrap: 6)
                c = SIMD3<Float>(0.55, 0.40, 0.26) * (0.8 + g * 0.35)
            }
            // sun disc + halo straight ahead (u = 0.5 maps to -Z)
            var du = abs(u - 0.5); du = min(du, 1 - du)
            let de = elev - 0.11
            let d = sqrt(du * du * 4 + de * de)
            let disc: Float = exp(-pow(d / 0.03, 2)) * 1.5
            let halo: Float = exp(-pow(d / 0.25, 2)) * 0.6
            c += SIMD3<Float>(1.0, 0.85, 0.6) * (disc + halo)
            return SIMD4<Float>(c.x, c.y, c.z, 1)
        }
    }

    // MARK: - Environment (equirectangular)

    /// Night sky with a coloured haze band at the horizon and neon "city light" spikes.
    /// Used both as the skybox and as the image-based light that the wet road reflects.
    static func environment(width: Int = 1024, height: Int = 512) -> CGImage {
        var rng = SeededRNG(seed: 2024)
        struct Spike { var az: Float; var w: Float; var h: Float; var col: SIMD3<Float>; var i: Float }
        var spikes: [Spike] = []
        for _ in 0..<70 {
            spikes.append(Spike(az: rng.float(), w: rng.float(0.002, 0.008), h: rng.float(0.02, 0.12),
                                col: rng.pick(Neon.all), i: rng.float(0.5, 1.0)))
        }
        return makeImage(width: width, height: height) { x, y in
            let u = Float(x) / Float(width)
            let v = Float(y) / Float(height)
            let elev = (0.5 - v) * Float.pi          // +pi/2 zenith ... -pi/2 nadir
            let top = SIMD3<Float>(0.004, 0.004, 0.012)
            let horizon = SIMD3<Float>(0.06, 0.025, 0.11)
            var c: SIMD3<Float>
            if elev >= 0 {
                let t = pow(clamp01(1 - elev / (Float.pi / 2)), 3.0)
                c = top + (horizon - top) * t
                // clouds
                let cl = fbm(u * 8, v * 8, octaves: 4, seed: 12, wrap: 8)
                c += SIMD3<Float>(0.02, 0.012, 0.03) * cl * t
            } else {
                c = SIMD3<Float>(0.008, 0.008, 0.014)
            }
            // haze band hue cycles around azimuth
            let hue = 0.5 + 0.5 * sin(u * Float.pi * 2 * 3 + 0.7)
            let hue2 = 0.5 + 0.5 * sin(u * Float.pi * 2 * 5 + 2.1)
            let bandCol = Neon.cyan * hue + Neon.magenta * (1 - hue) * 0.9 + Neon.orange * hue2 * 0.35
            let band = exp(-pow((elev - 0.015) / 0.045, 2)) * 0.55 + exp(-pow((elev - 0.03) / 0.16, 2)) * 0.12
            c += bandCol * band
            // spikes just above the horizon
            for s in spikes {
                var d = abs(u - s.az); d = min(d, 1 - d)
                if d < s.w * 2 && elev > -0.005 && elev < s.h {
                    let fall = (1 - d / (s.w * 2)) * (1 - elev / s.h)
                    c += s.col * fall * fall * s.i * 1.4
                }
            }
            // mirror a faint reflection of the band below the horizon so nothing is pure black
            if elev < 0 { c += bandCol * exp(-pow((elev + 0.02) / 0.05, 2)) * 0.12 }
            return SIMD4<Float>(c.x, c.y, c.z, 1)
        }
    }

    // MARK: - The Grid (arena)

    /// Arena floor tile: near-black base with a cyan grid in the emissive map. One tile covers
    /// 4 x 4 cells; the material repeats it, so the major line lands every tile edge.
    static func gridFloor(size: Int = 512) -> (base: CGImage, emissive: CGImage) {
        let cells = 4
        let base = makeImage(width: size, height: size) { x, y in
            let u = Float(x) / Float(size), v = Float(y) / Float(size)
            let n = fbm(u * 6, v * 6, octaves: 3, seed: 71, wrap: 6)
            let c: Float = 0.012 + n * 0.014
            return SIMD4<Float>(c * 0.8, c * 0.95, c * 1.25, 1)
        }
        let emissive = makeImage(width: size, height: size) { x, y in
            let fx = Float(x) + 0.5, fy = Float(y) + 0.5
            let cell = Float(size) / Float(cells)
            func lineMask(_ p: Float, width: Float) -> Float {
                let d = abs(p - (p / cell).rounded() * cell)
                return clamp01(1 - d / width)
            }
            let minor = max(lineMask(fx, width: 1.6), lineMask(fy, width: 1.6))
            // tile edge is the major line (thicker, brighter)
            let dxEdge = min(fx, Float(size) - fx), dyEdge = min(fy, Float(size) - fy)
            let major = clamp01(1 - min(dxEdge, dyEdge) / 3.2)
            let l = max(minor * 0.55, major)
            let col = SIMD3<Float>(0.18, 0.85, 1.0) * l
            return SIMD4<Float>(col.x, col.y, col.z, 1)
        }
        return (base, emissive)
    }

    /// Tall luminous wall panel: dark slab with a bright vertical panel and a top rail in the emissive map.
    static func gridWall(width: Int = 256, height: Int = 512) -> (base: CGImage, emissive: CGImage) {
        let base = makeImage(width: width, height: height) { x, y in
            let u = Float(x) / Float(width)
            let panel = abs(u - 0.5) < 0.36 ? Float(0.035) : Float(0.018)
            return SIMD4<Float>(panel * 0.8, panel * 1.0, panel * 1.3, 1)
        }
        let emissive = makeImage(width: width, height: height) { x, y in
            let u = Float(x) / Float(width), v = Float(y) / Float(height)
            let inner = abs(u - 0.5) < 0.36
            let frame = abs(abs(u - 0.5) - 0.36) < 0.012
            var l: Float = 0
            if inner {
                // panel glows from the bottom, fading upward, with faint horizontal data bands
                let bands = 0.85 + 0.15 * sin(v * 90)
                l = (0.20 + 0.55 * pow(1 - v, 1.8)) * bands
            }
            if frame { l = 1.0 }
            if v < 0.03 { l = 1.0 }       // top rail (v = 0 is the top of the image)
            let col = SIMD3<Float>(0.22, 0.80, 1.0) * l
            return SIMD4<Float>(col.x, col.y, col.z, 1)
        }
        return (base, emissive)
    }

    /// Environment for the arena: black zenith, a cold blue horizon band and a faint
    /// reflected grid glow below it, so the floor picks up a cyan reflection.
    static func environmentGrid(width: Int = 1024, height: Int = 512) -> CGImage {
        makeImage(width: width, height: height) { x, y in
            let u = Float(x) / Float(width)
            let v = Float(y) / Float(height)
            let elev = (0.5 - v) * Float.pi
            var c = SIMD3<Float>(0.002, 0.003, 0.006)
            if elev >= 0 {
                let t = pow(clamp01(1 - elev / (Float.pi / 2)), 4.0)
                c += SIMD3<Float>(0.02, 0.05, 0.10) * t
            } else {
                c = SIMD3<Float>(0.004, 0.008, 0.014)
            }
            let band = exp(-pow((elev - 0.01) / 0.03, 2)) * 0.7 + exp(-pow((elev - 0.02) / 0.12, 2)) * 0.18
            let pulse = 0.85 + 0.15 * sin(u * Float.pi * 2 * 6)
            c += SIMD3<Float>(0.15, 0.75, 1.0) * band * pulse
            if elev < 0 { c += SIMD3<Float>(0.12, 0.6, 0.9) * exp(-pow((elev + 0.03) / 0.06, 2)) * 0.15 }
            return SIMD4<Float>(c.x, c.y, c.z, 1)
        }
    }
}
