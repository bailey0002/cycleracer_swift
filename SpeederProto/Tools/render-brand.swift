// Renders the brand assets into Resources/Assets.xcassets: the launch wordmark (LaunchLogo, @1x/@2x/@3x),
// the launch background colour, and the app icon (iOS single size + the macOS set).
// Run from SpeederProto/:  swift Tools/render-brand.swift [icon variant a|b]
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Resources/Assets.xcassets")
let variant = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "b"

// the HUD's colours (HUDStyle / Neon City roles)
let bg = (r: 0.01, g: 0.01, b: 0.02)
let cyan = (r: 0.35, g: 0.9, b: 1.0)
let magenta = (r: 1.0, g: 0.28, b: 0.82)
let amber = (r: 1.0, g: 0.75, b: 0.25)

func color(_ c: (r: Double, g: Double, b: Double), _ a: Double = 1) -> CGColor { CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: a) }

let fontURL = root.appendingPathComponent("Resources/Fonts/ChakraPetch-Bold.ttf")
guard CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil) || true else { fatalError() }

func context(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func write(_ image: CGImage, _ url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

func json(_ obj: Any, _ url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try! JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
    try! data.write(to: url)
}

/// A line of Chakra Petch Bold with tracking, as a CTLine.
func line(_ text: String, size: CGFloat, kern: CGFloat, color c: CGColor) -> CTLine {
    let font = CTFontCreateWithName("ChakraPetch-Bold" as CFString, size, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): c,
        NSAttributedString.Key(kCTKernAttributeName as String): kern,
    ]
    return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
}

// MARK: - Launch wordmark: the title's SPEEDER (56 pt, 10 pt tracking, cyan glow), centred on its canvas

func wordmark(scale: CGFloat) -> CGImage {
    let size: CGFloat = 44, kern: CGFloat = 6, pad: CGFloat = 30
    let l = line("KERB: GALACTIC", size: size * scale, kern: kern * scale, color: color((1, 1, 1)))
    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
    // the trailing kern is not part of the ink: centre the glyphs, not the advance
    let width = CGFloat(CTLineGetTypographicBounds(l, &ascent, &descent, &leading)) - kern * scale
    let capHeight = CTFontGetCapHeight(CTFontCreateWithName("ChakraPetch-Bold" as CFString, size * scale, nil))
    let w = Int(ceil(width + pad * 2 * scale)), h = Int(ceil(capHeight + pad * 2 * scale))
    let ctx = context(w, h)
    ctx.setShadow(offset: .zero, blur: 18 * scale, color: color(cyan, 0.85))
    ctx.textPosition = CGPoint(x: (CGFloat(w) - width) / 2, y: (CGFloat(h) - capHeight) / 2)
    CTLineDraw(l, ctx)
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.textPosition = CGPoint(x: (CGFloat(w) - width) / 2, y: (CGFloat(h) - capHeight) / 2)
    CTLineDraw(l, ctx)
    return ctx.makeImage()!
}

let logoSet = assets.appendingPathComponent("LaunchLogo.imageset")
var logoImages: [[String: String]] = []
for s in 1...3 {
    let name = "launch-logo@\(s)x.png"
    write(wordmark(scale: CGFloat(s)), logoSet.appendingPathComponent(name))
    logoImages.append(["idiom": "universal", "scale": "\(s)x", "filename": name])
}
json(["images": logoImages, "info": ["author": "xcode", "version": 1]], logoSet.appendingPathComponent("Contents.json"))

// MARK: - Launch background (matches the ARView's clear colour and the splash)

json(["colors": [["idiom": "universal", "color": ["color-space": "srgb", "components": ["red": "0.010", "green": "0.010", "blue": "0.020", "alpha": "1.000"]]]],
      "info": ["author": "xcode", "version": 1]], assets.appendingPathComponent("LaunchBackground.colorset/Contents.json"))

// MARK: - App icon: a neon road into a night skyline under a magenta horizon, the S of the wordmark above it

struct RNG { var s: UInt64; mutating func next() -> Double { s = s &* 6364136223846793005 &+ 1442695040888963407; return Double(s >> 33) / Double(1 << 31) } }

func icon(_ n: Int) -> CGImage {
    let W = CGFloat(n)
    let ctx = context(n, n)
    ctx.interpolationQuality = .high
    // CG origin is bottom-left; work in "from the top" terms with y(t) = W * (1 - t)
    func y(_ t: CGFloat) -> CGFloat { W * (1 - t) }
    let horizon: CGFloat = 0.54
    // sky
    let sky = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color((0.015, 0.02, 0.06)), color((0.07, 0.03, 0.14))] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: y(0)), end: CGPoint(x: 0, y: y(horizon)), options: [.drawsAfterEndLocation])
    // the horizon glow
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(magenta, 0.75), color(magenta, 0.0)] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.translateBy(x: W / 2, y: y(horizon))
    ctx.scaleBy(x: 1.9, y: 0.55)
    ctx.drawRadialGradient(glow, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: W * 0.42, options: [])
    ctx.restoreGState()
    // skyline: two rows of towers on the horizon, lit windows in the near row
    var rng = RNG(s: 77)
    for row in 0..<2 {
        var x: CGFloat = -W * 0.02
        while x < W {
            let bw = W * CGFloat(0.035 + rng.next() * 0.06)
            let centre = abs((x + bw / 2) / W - 0.5)
            // taller at the sides, a gap in the middle where the road meets the sky
            let hgt = W * CGFloat(row == 0 ? 0.10 + rng.next() * 0.16 : 0.05 + rng.next() * 0.10) * CGFloat(0.35 + min(1, centre * 2.4))
            let top = horizon - Double(hgt / W)
            ctx.setFillColor(row == 0 ? color((0.05, 0.05, 0.13)) : color((0.03, 0.03, 0.08)))
            ctx.fill(CGRect(x: x, y: y(horizon), width: bw - W * 0.004, height: hgt))
            if row == 1 {
                // windows
                var wy = CGFloat(top) + 0.012
                while wy < horizon - 0.01 {
                    var wx = x + W * 0.006
                    while wx < x + bw - W * 0.012 {
                        if rng.next() < 0.28 {
                            ctx.setFillColor(rng.next() < 0.7 ? color(amber, 0.85) : color(cyan, 0.9))
                            ctx.fill(CGRect(x: wx, y: y(wy) - W * 0.006, width: W * 0.006, height: W * 0.006))
                        }
                        wx += W * 0.011
                    }
                    wy += 0.014
                }
            }
            x += bw
        }
    }
    // ground below the horizon
    ctx.setFillColor(color((0.012, 0.012, 0.03)))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: y(horizon)))
    // the road: a trapezoid to the vanishing point, cyan edges with a glow, magenta centre dashes
    let vp = CGPoint(x: W / 2, y: y(horizon))
    let bl = CGPoint(x: -W * 0.08, y: 0), br = CGPoint(x: W * 1.08, y: 0)
    ctx.setFillColor(color((0.02, 0.03, 0.07)))
    ctx.beginPath(); ctx.move(to: vp); ctx.addLine(to: bl); ctx.addLine(to: br); ctx.closePath(); ctx.fillPath()
    // wet sheen: the horizon glow reflected down the road centre
    ctx.saveGState()
    ctx.beginPath(); ctx.move(to: vp); ctx.addLine(to: bl); ctx.addLine(to: br); ctx.closePath(); ctx.clip()
    let sheen = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(magenta, 0.35), color(magenta, 0.0)] as CFArray, locations: [0, 1])!
    ctx.translateBy(x: W / 2, y: y(horizon))
    ctx.scaleBy(x: 0.35, y: 1.0)
    ctx.drawRadialGradient(sheen, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: W * 0.5, options: [])
    ctx.restoreGState()
    func edge(_ from: CGPoint, _ width: CGFloat, _ c: CGColor, blur: CGFloat) {
        // a tapered stroke: wide at the bottom, a point at the horizon
        let dx = width / 2
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: blur, color: c)
        ctx.setFillColor(c)
        ctx.beginPath(); ctx.move(to: vp); ctx.addLine(to: CGPoint(x: from.x - dx, y: from.y)); ctx.addLine(to: CGPoint(x: from.x + dx, y: from.y)); ctx.closePath(); ctx.fillPath()
        ctx.restoreGState()
    }
    edge(CGPoint(x: W * 0.06, y: 0), W * 0.03, color(cyan), blur: W * 0.03)
    edge(CGPoint(x: W * 0.94, y: 0), W * 0.03, color(cyan), blur: W * 0.03)
    // centre dashes in perspective: z from near to far, projected to the vanishing point
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: W * 0.02, color: color(magenta))
    ctx.setFillColor(color(magenta))
    var z: CGFloat = 1.0
    for _ in 0..<9 {
        let z2 = z + 0.55
        let p1 = 1 / z, p2 = 1 / z2           // 1 at the bottom edge, towards 0 at the horizon
        let yb = y(horizon) * (1 - p1), yt = y(horizon) * (1 - p2)
        let hw1 = W * 0.018 * p1, hw2 = W * 0.018 * p2
        ctx.beginPath()
        ctx.move(to: CGPoint(x: W / 2 - hw1, y: yb)); ctx.addLine(to: CGPoint(x: W / 2 + hw1, y: yb))
        ctx.addLine(to: CGPoint(x: W / 2 + hw2, y: yt)); ctx.addLine(to: CGPoint(x: W / 2 - hw2, y: yt)); ctx.closePath(); ctx.fillPath()
        z = z2 + 0.55
    }
    ctx.restoreGState()
    // the S of the wordmark over the sky
    if variant == "b" {
        let l = line("S", size: W * 0.42, kern: 0, color: color((1, 1, 1)))
        var a: CGFloat = 0, d: CGFloat = 0, lead: CGFloat = 0
        let w = CGFloat(CTLineGetTypographicBounds(l, &a, &d, &lead))
        let cap = CTFontGetCapHeight(CTFontCreateWithName("ChakraPetch-Bold" as CFString, W * 0.42, nil))
        let pos = CGPoint(x: (W - w) / 2, y: y(0.10) - cap)
        ctx.setShadow(offset: .zero, blur: W * 0.05, color: color(cyan, 0.95))
        ctx.textPosition = pos; CTLineDraw(l, ctx)
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.textPosition = pos; CTLineDraw(l, ctx)
    }
    return ctx.makeImage()!
}

// MARK: - KERB: GALACTIC icon (1 Oct 2026): the hoverboard rider mid-360 (a game frame shot with
// SPEEDER_ICON_SHOT=1 against black, Tools/brand/icon-rider.png) over a block KERB wordmark with a cyan
// drop shadow and a GALACTIC line: the same composition as KERB's icon (rider over the red-shadowed
// wordmark on cream), in this game's dark neon palette.

let riderFrame: CGImage? = {
    let url = root.appendingPathComponent("Tools/brand/icon-rider.png")
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}()

func iconGalactic(_ n: Int) -> CGImage {
    let W = CGFloat(n)
    let ctx = context(n, n)
    ctx.interpolationQuality = .high
    func y(_ t: CGFloat) -> CGFloat { W * (1 - t) }
    // ground: near black with a cool gradient and a magenta glow low behind the wordmark
    let ground = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color((0.02, 0.02, 0.06)), color((0.05, 0.02, 0.10))] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(ground, start: CGPoint(x: 0, y: W), end: CGPoint(x: 0, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(magenta, 0.45), color(magenta, 0.0)] as CFArray, locations: [0, 1])!
    ctx.saveGState(); ctx.translateBy(x: W * 0.5, y: y(0.86)); ctx.scaleBy(x: 1.6, y: 0.5)
    ctx.drawRadialGradient(glow, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: W * 0.5, options: []); ctx.restoreGState()
    // a cyan halo behind the rider
    let halo = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(cyan, 0.30), color(cyan, 0.0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(halo, startCenter: CGPoint(x: W * 0.5, y: y(0.40)), startRadius: 0, endCenter: CGPoint(x: W * 0.5, y: y(0.40)), endRadius: W * 0.42, options: [])

    // KERB: block letters, solid cyan shadow offset down-right (KERB's icon uses red on cream)
    let size = W * 0.30
    let l = line("KERB", size: size, kern: W * 0.01, color: color((1, 1, 1)))
    let ls = line("KERB", size: size, kern: W * 0.01, color: color(cyan))
    var a: CGFloat = 0, d: CGFloat = 0, lead: CGFloat = 0
    let w = CGFloat(CTLineGetTypographicBounds(l, &a, &d, &lead)) - W * 0.01
    let base = CGPoint(x: (W - w) / 2, y: y(0.80))
    ctx.setShadow(offset: .zero, blur: W * 0.03, color: color(cyan, 0.6))
    ctx.textPosition = CGPoint(x: base.x + W * 0.014, y: base.y - W * 0.014); CTLineDraw(ls, ctx)
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.textPosition = base; CTLineDraw(l, ctx)
    // GALACTIC under it in magenta
    let g = line("GALACTIC", size: W * 0.095, kern: W * 0.022, color: color(magenta))
    let gw = CGFloat(CTLineGetTypographicBounds(g, &a, &d, &lead)) - W * 0.022
    ctx.setShadow(offset: .zero, blur: W * 0.025, color: color(magenta, 0.8))
    ctx.textPosition = CGPoint(x: (W - gw) / 2, y: y(0.905)); CTLineDraw(g, ctx)
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // the rider over the letters (the board crosses the top of the K-E-R-B like KERB's deck does)
    if let frame = riderFrame {
        // crop a square around the rider in the 1920 x 1144 frame
        let fw = CGFloat(frame.width), scale = fw / 1920
        let crop = CGRect(x: 540 * scale, y: 110 * scale, width: 840 * scale, height: 840 * scale)
        if let cut = frame.cropping(to: crop) {
            let side = W * 0.84
            let rect = CGRect(x: (W - side) / 2, y: y(0.78), width: side, height: side)   // bottom of the crop at 78 %
            // black ground of the frame blends into the dark icon: multiply-free screen blend keeps the neon
            ctx.saveGState(); ctx.setBlendMode(.screen)
            ctx.draw(cut, in: rect)
            ctx.restoreGState()
        }
    }
    return ctx.makeImage()!
}

// `--logo-only` re-renders the wordmark alone (the icon is Tools/brand + this script since 1 Oct 2026; Mark's
// GRDRNNR: QUANTIS art of 29 Sep is kept at Captures/polish/p14/icon-grdrnnr-quantis-1024.png).
if CommandLine.arguments.contains("--logo-only") { exit(0) }
let iconSet = assets.appendingPathComponent("AppIcon.appiconset")
var iconImages: [[String: String]] = [["idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "icon-1024.png"]]
write(iconGalactic(1024), iconSet.appendingPathComponent("icon-1024.png"))
for pt in [16, 32, 128, 256, 512] {
    for s in 1...2 {
        let name = "mac-\(pt)@\(s)x.png"
        write(iconGalactic(pt * s), iconSet.appendingPathComponent(name))
        iconImages.append(["idiom": "mac", "size": "\(pt)x\(pt)", "scale": "\(s)x", "filename": name])
    }
}
json(["images": iconImages, "info": ["author": "xcode", "version": 1]], iconSet.appendingPathComponent("Contents.json"))
json(["info": ["author": "xcode", "version": 1]], assets.appendingPathComponent("Contents.json"))
print("brand assets written to \(assets.path) (icon variant \(variant))")
