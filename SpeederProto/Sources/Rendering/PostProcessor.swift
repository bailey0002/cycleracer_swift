import Foundation
import Metal
import MetalPerformanceShaders
import RealityKit
import simd
import CoreGraphics

/// Layout mirrors `PostUniforms` in PostFX.metal.
struct PostUniforms {
    var vanishingTexel = SIMD4<Float>(0.5, 0.45, 0, 0)
    var bloom          = SIMD4<Float>(0.9, 0.4, 0.15, 0.0065)
    var fogColor       = SIMD4<Float>(0.075, 0.045, 0.150, 0.8)
    var proj           = SIMD4<Float>(0, 0, 1.15, 0.45)
    var misc           = SIMD4<Float>(0.002, 0, 1.15, 1.0)
    var flags          = SIMD4<Float>(1, 1, 1, 1)
    var section        = SIMD4<Float>(0, 0, 0, 0)   // x: enclosure (tunnel/conduit)  y: curtain  z: kick  w: boost level
    var haze           = SIMD4<Float>(0.5, 0.5, 0, 0.08)  // x,y: thruster (uv)  z: strength  w: radius
    var extra          = SIMD4<Float>(0, 1, 0, 0)         // x: lightning  y: dither  z: lens FX  w: motion blur (metres per frame x shutter)
    var vehicle        = SIMD4<Float>(0.8, 0.6, 6, 0.4)    // x,y: vehicle centre (uv)  z: its distance (m)  w: mask radius
    var weather        = SIMD4<Float>(0, 0, 0, 0)         // x: rain strength  y: rain speed  z,w: unused
}

/// Full-screen Metal post pass driven from ARView's render callback:
/// bright-pass -> Gaussian bloom (two radii via MPS) -> composite kernel that adds
/// depth fog, radial speed streaks, colour grade and vignette.
final class PostProcessor {

    // Written from the main thread, read on the render thread. They are plain
    // value copies so a torn read only affects a single frame.
    var settings = FXSettings()
    var vanishing = SIMD2<Float>(0.5, 0.45)
    var speedNorm: Float = 0
    /// Vehicle speed in m/s (the world's motion for the reprojection blur).
    var speed: Float = 0
    /// Lightning flash 0...1 (decays fast).
    var lightning: Float = 0
    /// Screen-space rain strength 0...1 (eased; off in enclosed sections).
    var rain: Float = 0
    var flash: Float = 0
    /// 0 in the open, 1 inside a tunnel or conduit: denser, darker fog and a tighter vignette.
    var enclosure: Float = 0
    /// 0 clear ... 1 black. Covers scene rebuilds and the launch.
    var curtain: Float = 0
    /// Boost kick envelope: extra streaks and aberration for a moment.
    var kick: Float = 0
    /// Held boost, eased (150 ms in, 400 ms out): one scalar that drives vignette, edge desaturation,
    /// streaks and the thruster haze together (Asphalt's nitro tunnel, Thumper's centre weighting).
    var boost: Float = 0
    /// Thruster position on screen (uv) and haze strength for the heat shimmer.
    var thrusterUV = SIMD2<Float>(0.5, 0.6)
    /// Vehicle centre on screen and its distance: the blur and the haze leave it alone.
    var vehicleUV = SIMD2<Float>(0.8, 0.6)
    var vehicleDistance: Float = 6
    var theme: Theme = .neonCity
    private(set) var sourceFormat: String = "-"
    /// Set to request a readback of the next finished frame.
    var captureRequest: ((CGImage?) -> Void)? = nil
    /// Like captureRequest but reads the un-processed scene render.
    var captureSourceRequest: ((CGImage?) -> Void)? = nil

    private var device: MTLDevice?
    private var brightPipeline: MTLComputePipelineState?
    private var compositePipeline: MTLComputePipelineState?
    private var blurNarrow: MPSImageGaussianBlur?
    private var blurWide: MPSImageGaussianBlur?
    private var scaler: MPSImageBilinearScale?
    private var texBright: MTLTexture?
    private var texBlurA: MTLTexture?
    private var texSmall: MTLTexture?
    private var texBlurB: MTLTexture?
    private var cachedSize = (w: 0, h: 0)
    private var loggedFormat = false
    private var probePipeline: MTLComputePipelineState?
    private var probeTexture: MTLTexture?
    private var frameIndex = 0
    /// nil = not yet probed, false = depth reads as zero (fog falls back to screen-space)
    private(set) var depthUsable: Bool? = nil
    private var isHDR = false
    private var texDirt: MTLTexture?

    func prepare(device: MTLDevice) {
        self.device = device
        guard let lib = device.makeDefaultLibrary() else {
            print("PostProcessor: default Metal library missing; post FX disabled")
            return
        }
        do {
            if let f = lib.makeFunction(name: "brightPass") { brightPipeline = try device.makeComputePipelineState(function: f) }
            if let f = lib.makeFunction(name: "compositePass") { compositePipeline = try device.makeComputePipelineState(function: f) }
            if let f = lib.makeFunction(name: "depthProbe") { probePipeline = try device.makeComputePipelineState(function: f) }
        } catch {
            print("PostProcessor: pipeline creation failed: \(error)")
        }
        blurNarrow = MPSImageGaussianBlur(device: device, sigma: 4.5)
        blurWide = MPSImageGaussianBlur(device: device, sigma: 7.0)
        scaler = MPSImageBilinearScale(device: device)
        blurNarrow?.edgeMode = .clamp
        blurWide?.edgeMode = .clamp
        texDirt = Self.texture(from: ProceduralTextures.lensDirt(), device: device)
    }

    /// RGBA8 texture from a CGImage (the lens dirt mask).
    private static func texture(from image: CGImage, device: MTLDevice) -> MTLTexture? {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
        d.usage = [.shaderRead]
        guard let tex = device.makeTexture(descriptor: d) else { return nil }
        tex.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: data, bytesPerRow: w * 4)
        return tex
    }

    func process(_ ctx: ARView.PostProcessContext) {
        if device == nil { prepare(device: ctx.device) }
        let src = ctx.sourceColorTexture
        let dst = ctx.targetColorTexture
        if !loggedFormat {
            loggedFormat = true
            isHDR = [.rgba16Float, .rgba32Float, .bgr10_xr, .bgr10_xr_srgb, .rgb10a2Unorm].contains(src.pixelFormat)
            sourceFormat = "\(src.pixelFormat.rawValue)/\(src.width)x\(src.height)\(isHDR ? " HDR" : "")"
            let p = ctx.projection
            print("PostProcessor: source \(src.pixelFormat.rawValue) \(src.width)x\(src.height) depth \(ctx.sourceDepthTexture.pixelFormat.rawValue) \(ctx.sourceDepthTexture.width)x\(ctx.sourceDepthTexture.height) usage \(ctx.sourceDepthTexture.usage.rawValue) target \(dst.pixelFormat.rawValue) P22=\(p.columns.2.z) P32=\(p.columns.3.z)")
            NSLog("PostProcessor: depth fmt %d P22=%f P32=%f", ctx.sourceDepthTexture.pixelFormat.rawValue, p.columns.2.z, p.columns.3.z)
        }
        guard let composite = compositePipeline, let bright = brightPipeline,
              let blurNarrow, let blurWide, let scaler else {
            blit(ctx); return
        }
        let s = settings
        ensureTextures(width: src.width, height: src.height, device: ctx.device)
        guard let texBright, let texBlurA, let texSmall, let texBlurB else { blit(ctx); return }

        var u = PostUniforms()
        let th = theme
        u.fogColor = th.fogColor
        let p = ctx.projection
        u.proj.x = p.columns.2.z
        u.proj.y = p.columns.3.z
        let sp = speedNorm
        let lvl = max(0, min(2, s.bloomLevel))
        let bloomMul: Float = [0.5, 1.0, 2.0][lvl]
        let threshold: Float = [0.84, 0.74, 0.56][lvl]
        let enc = enclosure, kk = kick
        let fogDensity: Float = [0.0020, 0.0060, 0.0140][max(0, min(2, s.fogLevel))] * th.fogDensityScale * (1 + 1.5 * enc)
        u.vanishingTexel = SIMD4<Float>(vanishing.x, vanishing.y, flash, threshold)
        u.bloom = SIMD4<Float>((isHDR ? 0.6 : 0.72) * bloomMul,
                               s.streaks ? (0.12 + sp * 0.5 + kk * 0.35 + boost * 0.18) * th.streakScale : 0,
                               0.07 + sp * 0.22 + kk * 0.06 + boost * 0.05,
                               fogDensity)
        u.misc = SIMD4<Float>(0.0007 + sp * 0.0025 + kk * 0.0015 + boost * 0.0012, Float(ctx.time), th.saturation, th.gradeStrength)
        u.section = SIMD4<Float>(enc, curtain, kk, boost)
        u.haze = SIMD4<Float>(thrusterUV.x, thrusterUV.y, (0.35 + sp * 0.4 + boost * 0.9) * (s.particles ? 1 : 0), 0.06 + boost * 0.05)
        u.extra = SIMD4<Float>(lightning, 1, s.lensFX ? th.lensScale : 0, s.motionBlur ? speed / 60 * (0.22 + boost * 0.4) : 0)
        u.vehicle = SIMD4<Float>(vehicleUV.x, vehicleUV.y, vehicleDistance, 0.42)
        u.weather = SIMD4<Float>(rain, 14 + sp * 10, 0, 0)
        u.proj.z = (isHDR ? 1.2 : 1.0) * th.exposure
        u.proj.w = th.vignette
        let fogMode: Float = s.fog ? (depthUsable == false ? 2 : 1) : 0
        u.flags = s.postFX ? SIMD4<Float>(fogMode, s.bloom ? 1 : 0, s.streaks ? 1 : 0, s.colorGrade ? 1 : 0)
                           : SIMD4<Float>(-1, 0, 0, 0)

        let cb = ctx.commandBuffer
        frameIndex += 1
        // probe every half second until the scene has geometry in view (sky alone reads ~0)
        if frameIndex % 30 == 8, depthUsable == nil, let probe = probePipeline {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: 2, height: 2, mipmapped: false)
            d.usage = [.shaderWrite, .shaderRead]
            d.storageMode = .shared
            if let tex = ctx.device.makeTexture(descriptor: d), let enc = cb.makeComputeCommandEncoder() {
                probeTexture = tex
                enc.setComputePipelineState(probe)
                enc.setTexture(ctx.sourceDepthTexture, index: 0)
                enc.setTexture(tex, index: 1)
                enc.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 2, height: 2, depth: 1))
                enc.endEncoding()
                cb.addCompletedHandler { [weak self] _ in
                    var vals = [Float](repeating: 0, count: 16)
                    tex.getBytes(&vals, bytesPerRow: 32, from: MTLRegionMake2D(0, 0, 2, 2), mipmapLevel: 0)
                    let depths = [vals[0], vals[4], vals[8], vals[12]]
                    if depths.contains(where: { !$0.isFinite }) {
                        self?.depthUsable = false
                        print("PostProcessor: depth probe \(depths) -> unreadable, using screen-space fog fallback")
                    } else if depths.contains(where: { $0 > 1e-6 && $0 < 1 }) {
                        self?.depthUsable = true
                        print("PostProcessor: depth probe \(depths) -> depth fog")
                    }
                }
            }
        }
        if s.postFX && (s.bloom || s.streaks) {
            if let enc = cb.makeComputeCommandEncoder() {
                enc.label = "brightPass"
                enc.setComputePipelineState(bright)
                enc.setTexture(src, index: 0)
                enc.setTexture(texBright, index: 1)
                enc.setBytes(&u, length: MemoryLayout<PostUniforms>.stride, index: 0)
                dispatch(enc, bright, width: texBright.width, height: texBright.height)
                enc.endEncoding()
            }
            blurNarrow.encode(commandBuffer: cb, sourceTexture: texBright, destinationTexture: texBlurA)
            scaler.encode(commandBuffer: cb, sourceTexture: texBlurA, destinationTexture: texSmall)
            blurWide.encode(commandBuffer: cb, sourceTexture: texSmall, destinationTexture: texBlurB)
        }
        if let enc = cb.makeComputeCommandEncoder() {
            enc.label = "composite"
            enc.setComputePipelineState(composite)
            enc.setTexture(src, index: 0)
            enc.setTexture(texBlurA, index: 1)
            enc.setTexture(texBlurB, index: 2)
            enc.setTexture(ctx.sourceDepthTexture, index: 3)
            enc.setTexture(dst, index: 4)
            if let texDirt { enc.setTexture(texDirt, index: 5) }
            enc.setBytes(&u, length: MemoryLayout<PostUniforms>.stride, index: 0)
            dispatch(enc, composite, width: dst.width, height: dst.height)
            enc.endEncoding()
        }
        if let capture = captureSourceRequest {
            captureSourceRequest = nil
            FrameCapture.schedule(src, on: cb, device: ctx.device, completion: capture)
        }
        if let capture = captureRequest {
            captureRequest = nil
            FrameCapture.schedule(dst, on: cb, device: ctx.device, completion: capture)
        }
    }

    private func dispatch(_ enc: MTLComputeCommandEncoder, _ pso: MTLComputePipelineState, width: Int, height: Int) {
        let w = pso.threadExecutionWidth
        let h = max(1, pso.maxTotalThreadsPerThreadgroup / w)
        let tg = MTLSize(width: w, height: h, depth: 1)
        let groups = MTLSize(width: (width + w - 1) / w, height: (height + h - 1) / h, depth: 1)
        enc.dispatchThreadgroups(groups, threadsPerThreadgroup: tg)
    }

    private func blit(_ ctx: ARView.PostProcessContext) {
        guard let b = ctx.commandBuffer.makeBlitCommandEncoder() else { return }
        b.copy(from: ctx.sourceColorTexture, to: ctx.targetColorTexture)
        b.endEncoding()
    }

    private func ensureTextures(width: Int, height: Int, device: MTLDevice) {
        guard cachedSize.w != width || cachedSize.h != height else { return }
        cachedSize = (width, height)
        func make(_ w: Int, _ h: Int) -> MTLTexture? {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: max(1, w), height: max(1, h), mipmapped: false)
            d.usage = [.shaderRead, .shaderWrite]
            d.storageMode = .private
            return device.makeTexture(descriptor: d)
        }
        texBright = make(width / 4, height / 4)
        texBlurA  = make(width / 4, height / 4)
        texSmall  = make(width / 8, height / 8)
        texBlurB  = make(width / 8, height / 8)
    }
}
