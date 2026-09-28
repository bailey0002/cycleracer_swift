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

