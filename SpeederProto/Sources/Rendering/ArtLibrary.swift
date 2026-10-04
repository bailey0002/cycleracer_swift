import Foundation
import CoreGraphics
import ImageIO

/// Generated art (`docs/art-brief.md`) in `Resources/Art`, loaded by name. A missing file means the
/// procedural look stays; `SPEEDER_ART=0` keeps every image out (the A/B baseline).
enum Art {
    static var enabled: Bool { ProcessInfo.processInfo.environment["SPEEDER_ART"] != "0" }

    static func image(_ name: String) -> CGImage? {
        guard enabled else { return nil }
        let url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Art")
        guard let url, let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        print("art: \(name) \(img.width)x\(img.height)")
        return img
    }

    /// `prefix-01.png`, `prefix-02.png`, ... up to the first missing one.
    static func images(_ prefix: String, upTo count: Int = 16) -> [CGImage] {
        var out: [CGImage] = []
        for i in 1...count {
            guard let img = image(String(format: "%@-%02d", prefix, i)) else { break }
            out.append(img)
        }
        return out
    }

    /// A copy with a vertical alpha ramp: clear above `top`, opaque between `top + fade` and
    /// `bottom - fade`, clear below `bottom` (all fractions of the height from the top). For backdrop
    /// strips that were generated with a sky and a ground haze the scene wants to draw itself.
    static func faded(_ img: CGImage, top: CGFloat, bottom: CGFloat, fade: CGFloat = 0.12) -> CGImage {
        let w = img.width, h = img.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return img }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setBlendMode(.destinationIn)
        // CoreGraphics y runs up, so the picture's top is y = h: the gradient starts there
        let stops: [CGFloat] = [0, top, min(1, top + fade), max(0, bottom - fade), bottom, 1]
        let alphas: [CGFloat] = [0, 0, 1, 1, 0, 0]
        let colors = alphas.map { CGColor(srgbRed: 1, green: 1, blue: 1, alpha: $0) } as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors, locations: stops) else { return img }
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: [])
        return ctx.makeImage() ?? img
    }

    /// Pixels of a decoded copy (RGBA8, premultiplied, w * 4 stride) with a writable context.
    private static func pixels(_ img: CGImage) -> (CGContext, UnsafeMutablePointer<UInt8>)? {
        let w = img.width, h = img.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let base = ctx.data else { return nil }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (ctx, base.bindMemory(to: UInt8.self, capacity: w * 4 * h))
    }

    /// White where the image is saturated in the accent's hue (the tile's own cyan light channels), black
    /// elsewhere: the emissive mask when the generator did not deliver one.
    static func emissiveMask(_ img: CGImage, minValue: Float = 0.45, minChroma: Float = 0.18) -> CGImage {
        guard let (ctx, d) = pixels(img) else { return img }
        let n = img.width * img.height
        for i in 0..<n {
            let r = Float(d[i * 4]) / 255, g = Float(d[i * 4 + 1]) / 255, b = Float(d[i * 4 + 2]) / 255
            let v = max(r, g, b), chroma = (g + b) * 0.5 - r
            let m: Float = (v > minValue && chroma > minChroma) ? min(1, (v - minValue) / 0.35) : 0
            let o = UInt8(m * 255)
            d[i * 4] = o; d[i * 4 + 1] = o; d[i * 4 + 2] = o; d[i * 4 + 3] = 255
        }
        return ctx.makeImage() ?? img
    }

    /// A greyscale mask multiplied by a colour (the Grid's wall emissive follows the palette).
    static func tinted(_ img: CGImage, _ c: SIMD3<Float>) -> CGImage {
        guard let (ctx, d) = pixels(img) else { return img }
        let n = img.width * img.height
        for i in 0..<n {
            let l = Float(d[i * 4]) * 0.299 + Float(d[i * 4 + 1]) * 0.587 + Float(d[i * 4 + 2]) * 0.114
            d[i * 4] = UInt8(min(255, l * c.x)); d[i * 4 + 1] = UInt8(min(255, l * c.y)); d[i * 4 + 2] = UInt8(min(255, l * c.z)); d[i * 4 + 3] = 255
        }
        return ctx.makeImage() ?? img
    }

    /// A tangent-space normal map from the image's luminance as a height field (Sobel), wrapping at the
    /// edges so a tiling albedo gives a tiling normal. `strength` scales the slope.
    static func normalMap(_ img: CGImage, strength: Float = 2.0) -> CGImage {
        guard let (src, d) = pixels(img) else { return img }
        let w = img.width, h = img.height
        func lum(_ x: Int, _ y: Int) -> Float {
            let xx = (x + w) % w, yy = (y + h) % h, i = (yy * w + xx) * 4
            return (Float(d[i]) * 0.299 + Float(d[i + 1]) * 0.587 + Float(d[i + 2]) * 0.114) / 255
        }
        guard let out = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let ob = out.data else { return img }
        let o = ob.bindMemory(to: UInt8.self, capacity: w * 4 * h)
        for y in 0..<h {
            for x in 0..<w {
                let gx = (lum(x + 1, y - 1) + 2 * lum(x + 1, y) + lum(x + 1, y + 1)) - (lum(x - 1, y - 1) + 2 * lum(x - 1, y) + lum(x - 1, y + 1))
                let gy = (lum(x - 1, y + 1) + 2 * lum(x, y + 1) + lum(x + 1, y + 1)) - (lum(x - 1, y - 1) + 2 * lum(x, y - 1) + lum(x + 1, y - 1))
                var n = SIMD3<Float>(-gx * strength, gy * strength, 1)
                n /= max(1e-5, (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot())
                let i = (y * w + x) * 4
                o[i] = UInt8((n.x * 0.5 + 0.5) * 255); o[i + 1] = UInt8((n.y * 0.5 + 0.5) * 255); o[i + 2] = UInt8((n.z * 0.5 + 0.5) * 255); o[i + 3] = 255
            }
        }
        _ = src
        return out.makeImage() ?? img
    }

    /// A copy with black keyed to transparent by luminance (backdrops generated on a black ground).
    /// `lift` is a soft tone curve (1 - exp(-lift * v)) that raises the darks without clipping the lights:
    /// a dark backdrop must survive the depth fog and the grade.
    static func keyedBlack(_ img: CGImage, floor: Float = 0.012, ramp: Float = 0.05, lift: Float = 0) -> CGImage {
        let w = img.width, h = img.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let base = ctx.data else { return img }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        let data = base.bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * h)
        for y in 0..<h {
            let row = y * ctx.bytesPerRow
            for x in 0..<w {
                let i = row + x * 4
                let r = Float(data[i]) / 255, g = Float(data[i + 1]) / 255, b = Float(data[i + 2]) / 255
                let lum = 0.30 * r + 0.55 * g + 0.15 * b
                let a = max(0, min(1, (lum - floor) / ramp))
                func tone(_ v: Float) -> Float { lift > 0 ? (1 - exp(-lift * v)) / (1 - exp(-lift)) : v }
                let r2 = tone(r), g2 = tone(g), b2 = tone(b)
                data[i] = UInt8(r2 * a * 255); data[i + 1] = UInt8(g2 * a * 255); data[i + 2] = UInt8(b2 * a * 255)
                data[i + 3] = UInt8(a * 255)
            }
        }
        return ctx.makeImage() ?? img
    }
}

