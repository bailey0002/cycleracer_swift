import Foundation
import AVFoundation
import CoreVideo
import CoreGraphics
import Metal

/// Records finished post-pass frames into an H.264 `.mov` through AVAssetWriter.
///
/// The post pass calls `schedule` once per rendered frame: it blits the target texture into a
/// CPU-visible copy and, when the command buffer completes, hands the pixels to a serial queue
/// that appends them to the writer. Presentation times come from the game clock (`clock`,
/// written by the update loop before the frame renders), so a demo run with its fixed 1/60 s
/// step records exact 60 fps however slowly the readback makes the app render, and a hand-played
/// run records at wall-clock rate. Command buffers on one queue complete in order, so the
/// appends stay in order; a stamp that does not advance is nudged forward by one tick.
final class VideoRecorder {
    let url: URL
    let fps: Int32
    /// Timestamp resolution: 100 ticks per frame at the nominal rate.
    private var timescale: Int32 { fps * 100 }

    /// Game-clock seconds of the frame about to render. Written from the update loop.
    var clock: Double = 0
    private(set) var frames = 0

    private let queue = DispatchQueue(label: "speeder.video")
    private let lock = NSLock()
    private var inFlight = 0
    private var finished = false
    private var failed = false
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var size = (w: 0, h: 0)
    private var origin: Double? = nil
    private var lastTime: CMTime? = nil

    init(url: URL, fps: Int = 60) {
        self.url = url
        self.fps = Int32(fps)
    }

    /// Called from the post pass on the render thread: encode a blit of `texture` into a shared
    /// copy and append it once the command buffer has completed.
    func schedule(_ texture: MTLTexture, on commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        guard !finished, !failed else { return }
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat, width: texture.width, height: texture.height, mipmapped: false)
        d.usage = [.shaderRead]
        d.storageMode = .shared
        guard let copy = device.makeTexture(descriptor: d), let blit = commandBuffer.makeBlitCommandEncoder() else { return }
        blit.copy(from: texture, to: copy)
        blit.endEncoding()
        let seconds = clock
        lock.lock(); inFlight += 1; lock.unlock()
        commandBuffer.addCompletedHandler { [weak self] _ in
            guard let self else { return }
            self.queue.async { self.append(copy, seconds: seconds) }
        }
    }

    /// Stop taking frames, wait for the ones in flight, and close the file.
    /// `completion` runs on the writer's queue after the file is finalised.
    func finish(completion: (() -> Void)? = nil) {
        finished = true
        drain(completion)
    }

    private func drain(_ completion: (() -> Void)?) {
        queue.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            guard let self else { completion?(); return }
            self.lock.lock(); let n = self.inFlight; self.lock.unlock()
            if n > 0 { self.drain(completion); return }
            guard let writer = self.writer, let input = self.input else {
                print("video FAILED: no frames were recorded")
                completion?(); return
            }
            input.markAsFinished()
            let frames = self.frames, url = self.url
            let seconds = self.lastTime.map { CMTimeGetSeconds($0) } ?? 0
            writer.finishWriting {
                if writer.status == .completed {
                    print(String(format: "video saved: %@ (%ld frames, %.2f s, %ldx%ld)", url.path, frames, seconds, self.size.w, self.size.h))
                } else {
                    print("video FAILED: \(writer.error.map { "\($0)" } ?? "unknown error")")
                }
                completion?()
            }
        }
    }

    // MARK: - Writer queue

    private func append(_ tex: MTLTexture, seconds: Double) {
        defer { lock.lock(); inFlight -= 1; lock.unlock() }
        guard !failed else { return }
        if writer == nil {
            // H.264 wants even dimensions; drop an odd last row/column.
            guard start(width: tex.width & ~1, height: tex.height & ~1) else { failed = true; return }
        }
        guard let input, let adaptor, let pool = adaptor.pixelBufferPool else { return }
        if origin == nil { origin = seconds }
        var t = CMTime(value: Int64(((seconds - (origin ?? seconds)) * Double(timescale)).rounded()), timescale: timescale)
        if let last = lastTime, t <= last { t = CMTimeAdd(last, CMTime(value: 1, timescale: timescale)) }

        var maybeBuffer: CVPixelBuffer? = nil
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &maybeBuffer)
        guard let pb = maybeBuffer else { print("video: pixel buffer allocation failed"); return }
        CVPixelBufferLockBaseAddress(pb, [])
        if let base = CVPixelBufferGetBaseAddress(pb) {
            let rowBytes = CVPixelBufferGetBytesPerRow(pb)
            switch tex.pixelFormat {
            case .bgra8Unorm, .bgra8Unorm_srgb:
                // same layout as the buffer: straight copy
                tex.getBytes(base, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, size.w, size.h), mipmapLevel: 0)
            default:
                // HDR or RGBA targets: tone to 8-bit RGBA through FrameCapture, then draw into the BGRA buffer
                if let image = FrameCapture.image(from: tex),
                   let ctx = CGContext(data: base, width: size.w, height: size.h, bitsPerComponent: 8, bytesPerRow: rowBytes,
                                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                       bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) {
                    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size.w, height: size.h))
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pb, [])
        CVBufferSetAttachment(pb, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(pb, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(pb, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)

        // The encoder is not realtime-paced; wait for it rather than drop frames.
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
        if adaptor.append(pb, withPresentationTime: t) {
            frames += 1
            lastTime = t
        } else {
            print("video: append failed at frame \(frames): \(writer?.error.map { "\($0)" } ?? "unknown error")")
            failed = true
        }
    }

    private func start(width: Int, height: Int) -> Bool {
        size = (width, height)
        guard width > 0, height > 0 else { return false }
        try? FileManager.default.removeItem(at: url)
        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
            // ~15 Mbit/s at 1080p60, scaling with the frame area
            let bitrate = Int(Double(width * height) * Double(fps) * 0.12)
            let compression: [String: Any] = [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: Int(fps),
                AVVideoMaxKeyFrameIntervalKey: Int(fps),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ]
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: compression,
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = false
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ])
            guard writer.canAdd(input) else { print("video FAILED: writer refused the input"); return false }
            writer.add(input)
            guard writer.startWriting() else {
                print("video FAILED: \(writer.error.map { "\($0)" } ?? "startWriting")"); return false
            }
            writer.startSession(atSourceTime: .zero)
            self.writer = writer
            self.input = input
            self.adaptor = adaptor
            print("video recording \(url.lastPathComponent) at \(width)x\(height), \(fps) fps nominal")
            return true
        } catch {
            print("video FAILED: \(error)")
            return false
        }
    }
}
