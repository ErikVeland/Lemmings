#if os(iOS)
import LemmingsGameArt
import LemmingsMobileCore
import MetalKit
import NxlvKit
import UIKit

/// Uses the Mac's tube shader and keeps UIKit responsible for input.
@MainActor final class MobileCRTView: MTKView {
    private let commands: MTLCommandQueue
    private let pipelines: [MTLRenderPipelineState]
    private var source: MTLTexture?
    private var scratch: [MTLTexture] = []
    private var flash: MTLTexture?
    private var uniform = CRTUniforms()
    var selection: LemmingSelectionEffect?
    private var selectionRenderer: LemmingSelectionRenderer?
    private(set) var tubeSettings = CRTSettings.amiga1084

    init?(tubeDevice: Bool) {
        guard let device = MTLCreateSystemDefaultDevice(), let commands = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: CRTShaders.source, options: nil),
              let vertex = library.makeFunction(name: "crt_vertex") else { return nil }
        var pipelines: [MTLRenderPipelineState] = []
        for name in ["crt_bright", "crt_blur_h", "crt_blur_v", "crt_composite"] {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = library.makeFunction(name: name)
            descriptor.colorAttachments[0].pixelFormat = .rgba16Float
            guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
            pipelines.append(pipeline)
        }
        selectionRenderer = try? LemmingSelectionRenderer(device: device)
        self.commands = commands
        self.pipelines = pipelines
        super.init(frame: .zero, device: device)
        colorPixelFormat = .rgba16Float
        framebufferOnly = false
        isPaused = true
        enableSetNeedsDisplay = true
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .black
        (layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func update(image: CGImage, settings: ClassicSettings, flashMask: [UInt8]) {
        guard let device else { return }
        tubeSettings = settings.display == .television ? .television : .amiga1084
        let intensity = Float(settings.displayIntensity)
        tubeSettings.scanlineDepth *= intensity
        tubeSettings.maskStrength *= intensity
        tubeSettings.bloomAmount *= intensity
        tubeSettings.vignette *= intensity
        tubeSettings.convergence *= intensity
        tubeSettings.convergenceY *= intensity
        tubeSettings.colorLevels = settings.colorDepth == .amigaOCS ? 16 : 0
        tubeSettings.pixelAspect = Float(settings.pixelAspect)
        let width = image.width, height = image.height
        if source?.width != width || source?.height != height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                width: width, height: height, mipmapped: false)
            descriptor.usage = .shaderRead
            source = device.makeTexture(descriptor: descriptor)
            descriptor.pixelFormat = .rgba16Float
            descriptor.usage = [.shaderRead, .renderTarget]
            scratch = [device.makeTexture(descriptor: descriptor), device.makeTexture(descriptor: descriptor)].compactMap { $0 }
            descriptor.pixelFormat = .rg8Unorm
            descriptor.usage = .shaderRead
            flash = device.makeTexture(descriptor: descriptor)
            let black = [UInt8](repeating: 0, count: width * height * 2)
            black.withUnsafeBytes { bytes in
                flash?.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                    withBytes: bytes.baseAddress!, bytesPerRow: width * 2)
            }
        }
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        rgba.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            source?.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                withBytes: bytes.baseAddress!, bytesPerRow: width * 4)
        }
        if flashMask.count == width * height * 2 {
            flashMask.withUnsafeBytes { bytes in
                flash?.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: width * 2)
            }
        }
        updateUniforms(settings: settings)
        setNeedsDisplay()
    }

    /// Uses the same bend as the shader, so touch selects the visible pixel.
    func sourceViewPoint(_ point: CGPoint) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else { return point }
        var x = point.x / bounds.width * 2 - 1
        var y = point.y / bounds.height * 2 - 1
        let previousX = x, previousY = y
        if tubeSettings.curvature > 0 { x += previousX * pow(abs(previousY) / CGFloat(tubeSettings.curvature), 2) }
        if tubeSettings.curvatureY > 0 { y += previousY * pow(abs(previousX) / CGFloat(tubeSettings.curvatureY), 2) }
        return CGPoint(x: (x + 1) / 2 * bounds.width, y: (y + 1) / 2 * bounds.height)
    }

    private func updateUniforms(settings: ClassicSettings) {
        uniform.sourceSize = SIMD2(Float(source?.width ?? 1), Float(source?.height ?? 1))
        uniform.curvature = tubeSettings.curvature
        uniform.curvatureY = tubeSettings.curvatureY
        uniform.cornerRadius = tubeSettings.cornerRadius
        uniform.cornerSoftness = tubeSettings.cornerSoftness
        uniform.scanlineDepth = tubeSettings.scanlineDepth
        uniform.beamWidth = tubeSettings.beamWidth
        uniform.beamBloom = tubeSettings.beamBloom
        uniform.maskStrength = tubeSettings.maskStrength
        uniform.maskType = tubeSettings.maskType
        uniform.maskSize = tubeSettings.maskSize
        uniform.maskDark = tubeSettings.maskDark
        uniform.maskLight = tubeSettings.maskLight
        uniform.bloomAmount = tubeSettings.bloomAmount
        uniform.gamma = tubeSettings.gamma
        uniform.brightness = tubeSettings.brightness
        uniform.brightBoostDark = tubeSettings.brightBoostDark
        uniform.brightBoostBright = tubeSettings.brightBoostBright
        uniform.saturation = tubeSettings.saturation
        uniform.convergence = tubeSettings.convergence
        uniform.convergenceY = tubeSettings.convergenceY
        uniform.vignette = tubeSettings.vignette
        uniform.pixelAspect = tubeSettings.pixelAspect
        uniform.colorLevels = tubeSettings.colorLevels
        uniform.hdrHeadroom = settings.hdEffectsEnabled ? Float(max(1, min(8, window?.screen.currentEDRHeadroom ?? 1))) : 1
        (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = settings.hdEffectsEnabled && uniform.hdrHeadroom > 1
    }

    override func draw(_ rect: CGRect) {
        guard let source, scratch.count == 2, let flash, let drawable = currentDrawable,
              let buffer = commands.makeCommandBuffer() else { return }
        uniform.outputSize = SIMD2(Float(drawableSize.width), Float(drawableSize.height))
        let destinations = [scratch[0], scratch[1], scratch[0], drawable.texture]
        let sources = [[source], [scratch[0]], [scratch[1]], [source, scratch[0], flash]]
        for index in pipelines.indices {
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = destinations[index]
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].storeAction = .store
            descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
            guard let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { continue }
            encoder.setRenderPipelineState(pipelines[index])
            for (slot, texture) in sources[index].enumerated() { encoder.setFragmentTexture(texture, index: slot) }
            encoder.setFragmentBytes(&uniform, length: MemoryLayout<CRTUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }
        if let selection, let selectionRenderer {
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = drawable.texture
            pass.colorAttachments[0].loadAction = .load
            pass.colorAttachments[0].storeAction = .store
            if let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) {
                selectionRenderer.encode(selection,
                    sourceSize: CGSize(width: source.width, height: source.height), outputSize: drawableSize,
                    glass: SIMD4(tubeSettings.curvature, tubeSettings.curvatureY, tubeSettings.cornerRadius, tubeSettings.cornerSoftness), into: encoder)
                encoder.endEncoding()
            }
        }
        buffer.present(drawable)
        buffer.commit()
    }
}
#endif
