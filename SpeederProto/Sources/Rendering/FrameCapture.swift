import Foundation
import Metal
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Reads a finished frame back from the GPU and encodes it as PNG.
/// Used for the "P" screenshot key and for automated visual checks.
enum FrameCapture {

    /// Blit `texture` into a CPU-visible copy and hand back a CGImage once the command buffer completes.
    static func schedule(_ texture: MTLTexture, on commandBuffer: MTLCommandBuffer, device: MTLDevice, completion: @escaping (CGImage?) -> Void) {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat, width: texture.width, height: texture.height, mipmapped: false)
        d.usage = [.shaderRead]
        d.storageMode = .shared
        guard let readback = device.makeTexture(descriptor: d), let blit = commandBuffer.makeBlitCommandEncoder() else {
            completion(nil); return
        }
        blit.copy(from: texture, to: readback)
        blit.endEncoding()
        commandBuffer.addCompletedHandler { _ in
            completion(image(from: readback))
        }
    }

    static func image(from tex: MTLTexture) -> CGImage? {
        let w = tex.width, h = tex.height
        var rgba = [UInt8](repeating: 255, count: w * h * 4)
        let region = MTLRegionMake2D(0, 0, w, h)
        switch tex.pixelFormat {
        case .bgra8Unorm, .bgra8Unorm_srgb:
            var raw = [UInt8](repeating: 0, count: w * h * 4)
            tex.getBytes(&raw, bytesPerRow: w * 4, from: region, mipmapLevel: 0)
            for i in stride(from: 0, to: raw.count, by: 4) {
                rgba[i] = raw[i + 2]; rgba[i + 1] = raw[i + 1]; rgba[i + 2] = raw[i]
            }
        case .rgba8Unorm, .rgba8Unorm_srgb:
            tex.getBytes(&rgba, bytesPerRow: w * 4, from: region, mipmapLevel: 0)
            for i in stride(from: 3, to: rgba.count, by: 4) { rgba[i] = 255 }
        case .rgba16Float:
            var raw = [UInt16](repeating: 0, count: w * h * 4)
            tex.getBytes(&raw, bytesPerRow: w * 8, from: region, mipmapLevel: 0)
            for i in 0..<(w * h * 4) {
                if i % 4 == 3 { rgba[i] = 255; continue }
                let v = Float(Float16(bitPattern: raw[i]))
                let enc = pow(max(0, min(1, v)), 1 / 2.2)
                rgba[i] = UInt8(enc * 255)
            }
        default:
            print("FrameCapture: unsupported format \(tex.pixelFormat.rawValue)")
            return nil
        }
        let provider = CGDataProvider(data: Data(rgba) as CFData)!
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    @discardableResult
    static func writePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest)
    }

    static func defaultURL(ext: String = "png") -> URL {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"
        let name = "Speeder-\(f.string(from: Date())).\(ext)"
        #if os(macOS)
        let dir = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        #else
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        #endif
        return dir.appendingPathComponent(name)
    }
}
