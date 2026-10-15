#if os(iOS) || os(tvOS)
import LemmingsGameArt
import LemmingsMobileCore
import MetalKit
import NxlvKit
import UIKit

/// Uses the Mac's tube shader and keeps UIKit responsible for input.
@MainActor final class MobileCRTView: MTKView {
    private let commands: MTLCommandQueue
    private let pipelines: [MTLRenderPipelineState]
    @MainActor private final class SourceSlot {
        let source: MTLTexture
        let flash: MTLTexture
        var submissions = 0
        var hasFlash = false
        init(source: MTLTexture, flash: MTLTexture) {
            self.source = source; self.flash = flash
        }
    }
    private var slots: [SourceSlot] = []
    private var currentSlot: SourceSlot?
    private var outstandingSubmissions = 0
    private var submissionDeferred = false
    private var pendingSource: (context: CGContext, settings: ClassicSettings, flashes: [ExplosionGlow.Flash])?
    private var source: MTLTexture? { currentSlot?.source }
    private var blackMask = [UInt8]()
    private var scratch: [MTLTexture] = []
    private var uniform = CRTUniforms()
    private var bloomDirty = true
    private var bloomGamma: Float = .nan
    var selection: LemmingSelectionEffect?
    var failureAmount: CGFloat = 0 { didSet { if oldValue != failureAmount { setNeedsDisplay() } } }
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
        framebufferOnly = true
        autoResizeDrawable = false
        isPaused = true
        enableSetNeedsDisplay = true
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .black
        (layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func releaseEffectResources() {
        scratch.removeAll(); bloomDirty = true
        releaseDrawables()
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateDrawableBudget()
    }
    private func updateDrawableBudget() {
        var scale = MobileDevicePerformance.constrained ? CGFloat(1) : (window?.screen.scale ?? contentScaleFactor)
        if !MobileDevicePerformance.presentation.enhancedEffectsAllowed { scale = min(1, scale) }
        #if os(tvOS)
        scale = MobileDevicePerformance.presentation.televisionPlayfieldScale(nativeScale: Double(scale))
        #endif
        let size = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
        if drawableSize != size { drawableSize = size }
    }

    func update(context: CGContext, settings: ClassicSettings, flashes: [ExplosionGlow.Flash]) {
        guard let device, let pixels = context.data else { return }
        pendingSource = nil
        let width = context.width, height = context.height
        if source?.width != width || source?.height != height {
            slots.removeAll(); currentSlot = nil
            blackMask = [UInt8](repeating: 0, count: width * height * 2)
        }
        // Never overwrite pixels that an outstanding GPU command can still read.
        let slot: SourceSlot
        if let available = slots.first(where: { $0.submissions == 0 }) {
            slot = available
        } else if slots.count < 3 {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                width: width, height: height, mipmapped: false)
            descriptor.usage = .shaderRead
            guard let texture = device.makeTexture(descriptor: descriptor) else { return }
            descriptor.pixelFormat = .rg8Unorm
            guard let flash = device.makeTexture(descriptor: descriptor) else { return }
            slot = SourceSlot(source: texture, flash: flash)
            blackMask.withUnsafeBytes { bytes in
                flash.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                    withBytes: bytes.baseAddress!, bytesPerRow: width * 2)
            }
            slots.append(slot)
        } else {
            // Keep input and simulation moving rather than waiting for a texture.
            pendingSource = (context, settings, flashes)
            return
        }
        currentSlot = slot
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
        bloomDirty = true
        slot.source.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
            withBytes: pixels, bytesPerRow: context.bytesPerRow)
        if !flashes.isEmpty {
            let mask = ExplosionGlow.textureMask(width: width, height: height, flashes: flashes)
            mask.withUnsafeBytes { bytes in
                slot.flash.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                    withBytes: bytes.baseAddress!, bytesPerRow: width * 2)
            }
            slot.hasFlash = true
        } else if slot.hasFlash {
            blackMask.withUnsafeBytes { bytes in
                slot.flash.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                    withBytes: bytes.baseAddress!, bytesPerRow: width * 2)
            }
            slot.hasFlash = false
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

    /// Invert the input projection to anchor light on the curved output.
    func outputViewPoint(_ point: CGPoint) -> CGPoint {
        var output = point
        for _ in 0..<6 {
            let source = sourceViewPoint(output)
            output.x += (point.x - source.x) * 0.5
            output.y += (point.y - source.y) * 0.5
        }
        return output
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
        uniform.hdrHeadroom = settings.hdEffectsEnabled && !MobileDevicePerformance.constrained
            ? Float(max(1, min(8, window?.screen.currentEDRHeadroom ?? 1))) : 1
#if os(iOS)
        (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = settings.hdEffectsEnabled && uniform.hdrHeadroom > 1
#endif
    }

    override func draw(_ rect: CGRect) {
        let drawStarted = ProcessInfo.processInfo.systemUptime
        defer { MobileDevicePerformance.recordCPU(ProcessInfo.processInfo.systemUptime - drawStarted, source: "crt") }
        guard outstandingSubmissions < 3 else { submissionDeferred = true; return }
        updateDrawableBudget()
        guard let device, let slot = currentSlot, let drawable = currentDrawable,
              let buffer = commands.makeCommandBuffer() else { return }
        submissionDeferred = false
        let source = slot.source, flash = slot.flash
        let budget = MobileDevicePerformance.presentation
        uniform.saturation = tubeSettings.saturation * FailureMoodArt.saturation(failureAmount)
        uniform.brightness = tubeSettings.brightness * FailureMoodArt.brightness(failureAmount)
        uniform.bloomAmount = budget.bloomAllowed ? tubeSettings.bloomAmount : 0
        #if os(tvOS)
        uniform.bloomAmount = budget.televisionBloomAllowed ? tubeSettings.bloomAmount : 0
        #endif
        if uniform.bloomAmount == 0 { scratch.removeAll(); bloomDirty = true }
        if !budget.enhancedEffectsAllowed {
            uniform.hdrHeadroom = 1
            #if os(iOS)
            (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = false
            #endif
        }
        if uniform.bloomAmount > 0 {
            let scale = min(budget.bloomScale, sqrt(Double(budget.maximumOverlayPixels) / Double(source.width) / Double(source.height)))
            let width = max(1, Int(Double(source.width) * scale))
            let height = max(1, Int(Double(source.height) * scale))
            if scratch.count != 2 || scratch[0].width != width || scratch[0].height != height {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
                    width: width, height: height, mipmapped: false)
                descriptor.usage = [.shaderRead, .renderTarget]
                scratch = [device.makeTexture(descriptor: descriptor), device.makeTexture(descriptor: descriptor)].compactMap { $0 }
                bloomDirty = true
            }
            guard scratch.count == 2 else { return }
        }
        uniform.outputSize = SIMD2(Float(drawableSize.width), Float(drawableSize.height))
        let glow = uniform.bloomAmount > 0 ? scratch[0] : source
        let temporary = uniform.bloomAmount > 0 ? scratch[1] : source
        let destinations = [glow, temporary, glow, drawable.texture]
        let sources = [[source], [glow], [temporary], [source, glow, flash]]
        let rebuildBloom = uniform.bloomAmount > 0 && (bloomDirty || bloomGamma != uniform.gamma)
        for index in pipelines.indices {
            if index < 3 && !rebuildBloom { continue }
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = destinations[index]
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].storeAction = .store
            descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
            guard let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
            encoder.setRenderPipelineState(pipelines[index])
            for (slot, texture) in sources[index].enumerated() { encoder.setFragmentTexture(texture, index: slot) }
            encoder.setFragmentBytes(&uniform, length: MemoryLayout<CRTUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }
        if rebuildBloom { bloomDirty = false; bloomGamma = uniform.gamma }
        if let selectionRenderer, let selection {
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = drawable.texture
            pass.colorAttachments[0].loadAction = .load
            pass.colorAttachments[0].storeAction = .store
            if let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) {
                let glass = SIMD4(tubeSettings.curvature, tubeSettings.curvatureY, tubeSettings.cornerRadius, tubeSettings.cornerSoftness)
                let sourceSize = CGSize(width: source.width, height: source.height)
                selectionRenderer.encode(selection,
                    sourceSize: sourceSize, outputSize: drawableSize, glass: glass, into: encoder)
                encoder.endEncoding()
            }
        }
        slot.submissions += 1
        outstandingSubmissions += 1
        buffer.addCompletedHandler { [weak self, slot] completed in
            let seconds = max(0, completed.gpuEndTime - completed.gpuStartTime)
            let succeeded = completed.status == .completed
            Task { @MainActor [weak self, slot] in
                slot.submissions -= 1
                self?.outstandingSubmissions -= 1
                if succeeded { MobileDevicePerformance.recordGPU(seconds, source: "crt") }
                else { self?.bloomDirty = true }
                if let pending = self?.pendingSource {
                    self?.update(context: pending.context, settings: pending.settings, flashes: pending.flashes)
                } else if self?.submissionDeferred == true {
                    self?.setNeedsDisplay()
                }
            }
        }
        buffer.present(drawable)
        buffer.commit()
    }
}
#endif
