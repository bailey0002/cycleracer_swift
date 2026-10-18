// Tiles PNGs into one contact sheet with each file's name under its tile.
// usage: swift Tools/contact-sheet.swift <out.png> <columns> <tileWidth> <in.png> [in.png ...]
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CoreText

let args = CommandLine.arguments
guard args.count >= 5, let cols = Int(args[2]), let tileW = Int(args[3]) else {
    print("usage: contact-sheet.swift <out.png> <columns> <tileWidth> <in.png> ..."); exit(1)
}
let inputs = Array(args[4...])
func load(_ p: String) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}
let images = inputs.compactMap { p in load(p).map { (p, $0) } }
guard let first = images.first?.1 else { print("no images"); exit(1) }
let tileH = Int(Double(tileW) * Double(first.height) / Double(first.width))
let label = 34, gap = 12
let rows = (images.count + cols - 1) / cols
let W = cols * tileW + (cols + 1) * gap, H = rows * (tileH + label) + (rows + 1) * gap
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(CGColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
let font = CTFontCreateWithName("Menlo-Bold" as CFString, 20, nil)
for (i, (path, img)) in images.enumerated() {
    let c = i % cols, r = i / cols
    let x = gap + c * (tileW + gap)
    let yTop = gap + r * (tileH + label + gap)
    let y = H - yTop - tileH                       // CG origin is bottom-left
    ctx.draw(img, in: CGRect(x: x, y: y, width: tileW, height: tileH))
    let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".png", with: "")
    let attr = NSAttributedString(string: name, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font,
                                                             NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0.6, green: 0.9, blue: 1, alpha: 1)])
    ctx.textPosition = CGPoint(x: x + 4, y: y - 26)
    CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
}
let out = URL(fileURLWithPath: args[1])
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
print(CGImageDestinationFinalize(dest) ? "wrote \(out.path) (\(W)x\(H), \(images.count) tiles)" : "write failed")
