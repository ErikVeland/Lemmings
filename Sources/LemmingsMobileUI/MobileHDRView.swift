#if os(iOS) || os(tvOS)
import LemmingsGameArt
import LemmingsMobileCore
import MetalKit
import NxlvKit
import UIKit

/// Speed and pop light share the desktop shaders. The game display link drives
/// this surface only while an effect is visible.
@MainActor final class MobileHDRView: MTKView {
    private let commands: MTLCommandQueue
    private let speedPipeline: MTLRenderPipelineState
    private let popPipeline: MTLRenderPipelineState
    private let flashPipeline: MTLRenderPipelineState
    private let glintPipeline: MTLRenderPipelineState
    private var glints: ClassicMacScene.ArrowGlints?
    private var glintRect = CGRect.null
    private var glintClip = CGRect.null
    private var glintTexture: MTLTexture?
    private var paintedGlintRect = CGRect.null
    /// The last frame held only glints, at this headroom. It stays valid until something changes.
    private var paintedGlintHeadroom: Float?
    private var speed = SuperSpeedTimeline()
    private var pops = NuclearExplosionTimeline()
    private var cores: [(rect: CGRect, expires: Double)] = []
    private var flashTexture: MTLTexture?
    private var motionTime = 0.0
    private var lastTime: Double?
    private var lastPaint: Double?
    private var now = 0.0
    private var field = CGRect.zero
    private var project: ((SIMD2<Float>) -> CGPoint)?
    private var outstandingSubmissions = 0

    init?(effects: Bool) {
        guard let device = MTLCreateSystemDefaultDevice(), let commands = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: GameplayHDRShaders.source, options: nil),
              let vertex = library.makeFunction(name: "flash_vertex") else { return nil }
        func pipeline(_ name: String) -> MTLRenderPipelineState? {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = library.makeFunction(name: name)
            let colour = descriptor.colorAttachments[0]!
            colour.pixelFormat = .rgba16Float
            colour.isBlendingEnabled = true
            colour.sourceRGBBlendFactor = .one
            colour.destinationRGBBlendFactor = .oneMinusSourceAlpha
            colour.sourceAlphaBlendFactor = .one
            colour.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try? device.makeRenderPipelineState(descriptor: descriptor)
        }
        guard let speed = pipeline("speed_fragment"), let pop = pipeline("nuclear_fragment"),
              let flash = pipeline("flash_fragment"), let glint = pipeline("glint_fragment") else { return nil }
        self.commands = commands; speedPipeline = speed; popPipeline = pop; flashPipeline = flash
        glintPipeline = glint
        super.init(frame: .zero, device: device)
        colorPixelFormat = .rgba16Float
        framebufferOnly = true; autoResizeDrawable = false
        isPaused = true; enableSetNeedsDisplay = true
        isOpaque = false; backgroundColor = .clear
        isHidden = true; isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        (layer as? CAMetalLayer)?.isOpaque = false
        (layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func trigger(rects: [CGRect], cinematic: Bool, at now: Double) {
        if cinematic {
            pops.trigger(centres: rects.map { SIMD2(Float($0.midX), Float($0.midY)) }, now: now, worldAnchored: true)
        } else {
            cores += rects.map { ($0, now + 0.14) }
            if cores.count > NuclearExplosionTimeline.maximumBursts { cores.removeFirst(cores.count - NuclearExplosionTimeline.maximumBursts) }
        }
    }

    /// HDR light on lit arrow edges. `rect` is the view area of the mask; `clip` is the visible playfield.
    /// SDR screens draw nothing, because the frame already holds the glint up to white.
    func setArrowGlints(_ glints: ClassicMacScene.ArrowGlints?, in rect: CGRect, clip: CGRect) {
        if glints != self.glints { glintTexture = nil }
        self.glints = glints
        glintRect = glints == nil ? .null : rect; glintClip = glints == nil ? .null : clip
    }

    private var currentHeadroom: Float { Float(min(8, max(1, window?.screen.currentEDRHeadroom ?? 1))) }

    private var showsGlints: Bool {
#if os(iOS)
        glints != nil && glintRect.intersects(glintClip) && (window?.screen.potentialEDRHeadroom ?? 1) > 1
#else
        false
#endif
    }

    func advance(at now: Double, multiplier: Double, enabled: Bool, field: CGRect,
                 project: @escaping (SIMD2<Float>) -> CGPoint) {
        self.now = now; self.field = field; self.project = project
        speed.setEnabled(enabled && multiplier > 1.01, now: now, multiplier: multiplier)
        if let lastTime, speed.enabled { motionTime += min(0.1, max(0, now - lastTime)) * (0.5 + multiplier / 6) }
        self.lastTime = now
        pops.expire(now: now); cores.removeAll { $0.expires <= now }
        let active = speed.isAnimating(now: now) || !pops.bursts.isEmpty || !cores.isEmpty || showsGlints
        isHidden = !active
        if !active {
            flashTexture = nil; paintedGlintRect = .null; paintedGlintHeadroom = nil
            releaseDrawables()
            drawableSize = CGSize(width: 1, height: 1)
#if os(iOS)
            (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = false
#endif
            return
        }
        let budget = MobileDevicePerformance.presentation
        let effectHz = MobileDevicePerformance.constrained ? min(20, budget.effectHz) : budget.effectHz
        // A moved glint skips the frame limit so it stays on the panned terrain.
        let glintMoved = showsGlints && glintRect != paintedGlintRect
        if !glintMoved, let lastPaint, now - lastPaint < 1.0 / effectHz { return }
        let onlyGlints = !speed.isAnimating(now: now) && pops.bursts.isEmpty && cores.isEmpty
        if onlyGlints, !glintMoved, glintTexture != nil, paintedGlintHeadroom == currentHeadroom { return }
        lastPaint = now
        let scale = CGFloat(budget.overlayRenderScale(width: Double(bounds.width), height: Double(bounds.height),
                                                     nativeScale: Double(min(2, window?.screen.scale ?? 1))))
        let pixelLimit: CGFloat = MobileDevicePerformance.constrained ? 180_000 : 720_000
        let renderScale = min(scale, sqrt(pixelLimit / max(1, bounds.width * bounds.height)))
        let size = CGSize(width: max(1, floor(bounds.width * renderScale)), height: max(1, floor(bounds.height * renderScale)))
        if drawableSize != size { drawableSize = size }
#if os(iOS)
        (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = (window?.screen.potentialEDRHeadroom ?? 1) > 1
#endif
        setNeedsDisplay()
    }

    func clear() {
        speed = SuperSpeedTimeline(); pops.clear(); cores.removeAll()
        glints = nil; glintRect = .null; glintClip = .null; glintTexture = nil
        paintedGlintRect = .null; paintedGlintHeadroom = nil
        flashTexture = nil; lastTime = nil; lastPaint = nil; motionTime = 0
        releaseDrawables(); drawableSize = CGSize(width: 1, height: 1)
        isHidden = true
#if os(iOS)
        (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = false
#endif
    }

    override func draw(_ rect: CGRect) {
        guard outstandingSubmissions == 0, MobileDevicePerformance.enhancedEffectsAllowed,
              !isHidden, bounds.width > 0, bounds.height > 0, let project,
              let drawable = currentDrawable, let buffer = commands.makeCommandBuffer() else { return }
        let headroom = currentHeadroom
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        if speed.isAnimating(now: now) {
            var uniforms = SuperSpeedUniforms(field: SIMD4(Float(field.minX), Float(field.minY), Float(field.width), Float(field.height)),
                animation: speed.sample(now: now, headroom: headroom), size: SIMD2(Float(bounds.width), Float(bounds.height)),
                motion: SIMD4(Float(motionTime), Float(speed.multiplier), 0, 1))
            encoder.setRenderPipelineState(speedPipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SuperSpeedUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        let allSamples = pops.samples(now: now) { centre in
            let point = project(centre)
            return SIMD2(Float(point.x / self.bounds.width), Float(point.y / self.bounds.height))
        }
        let limit = MobileDevicePerformance.presentation.explosionLimit
        var samples = Array(allSamples.suffix(limit))
        if let exposure = allSamples.first(where: { $0.w > 0 }), !samples.contains(exposure) {
            if samples.count == limit { samples.removeFirst() }
            samples.insert(exposure, at: 0)
        }
        if !samples.isEmpty {
            var uniforms = NuclearExplosionUniforms(size: SIMD2(Float(bounds.width), Float(bounds.height)), headroom: headroom, count: UInt32(samples.count))
            encoder.setRenderPipelineState(popPipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<NuclearExplosionUniforms>.stride, index: 0)
            samples.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 1) }
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        if !cores.isEmpty, headroom > 1, let device {
            let pixelBudget = CGFloat(MobileDevicePerformance.presentation.maximumOverlayPixels)
            let scale = min(1, 512 / bounds.width, sqrt(pixelBudget / bounds.width / bounds.height))
            let width = max(1, Int(floor(bounds.width * scale)))
            let height = max(1, Int(floor(bounds.height * scale)))
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = .shaderRead
            if flashTexture?.width != width || flashTexture?.height != height {
                flashTexture = device.makeTexture(descriptor: descriptor)
            }
            let flashes = cores.map { core -> ExplosionGlow.Flash in
                let centre = project(SIMD2(Float(core.rect.midX), Float(core.rect.midY)))
                let corner = project(SIMD2(Float(core.rect.maxX), Float(core.rect.maxY)))
                let sx = max(2, abs(corner.x - centre.x)), sy = max(2, abs(corner.y - centre.y))
                return .init(rect: CGRect(x: (centre.x - sx) * scale, y: (centre.y - sy) * scale,
                    width: sx * 2 * scale, height: sy * 2 * scale), strength: 1)
            }
            let mask = ExplosionGlow.textureMask(width: width, height: height, flashes: flashes)
            mask.withUnsafeBytes { bytes in flashTexture?.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                withBytes: bytes.baseAddress!, bytesPerRow: width * 2) }
            if let flashTexture {
                var gain = headroom
                encoder.setRenderPipelineState(flashPipeline)
                encoder.setFragmentTexture(flashTexture, index: 0)
                encoder.setFragmentBytes(&gain, length: MemoryLayout<Float>.stride, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
        }
        // The flash pass replaces every pixel, so light is added after it.
        if showsGlints, headroom > 1, let glints, let device {
            if glintTexture == nil {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm,
                    width: glints.width, height: glints.height, mipmapped: false)
                descriptor.usage = .shaderRead
                // A new texture each change keeps submitted frames immutable.
                glintTexture = device.makeTexture(descriptor: descriptor)
                glints.strength.withUnsafeBytes { bytes in
                    glintTexture?.replace(region: MTLRegionMake2D(0, 0, glints.width, glints.height), mipmapLevel: 0,
                        withBytes: bytes.baseAddress!, bytesPerRow: glints.width)
                }
            }
            if let glintTexture {
                func fraction(_ rect: CGRect) -> SIMD4<Float> {
                    SIMD4(Float(rect.minX / bounds.width), Float(rect.minY / bounds.height),
                          Float(rect.width / bounds.width), Float(rect.height / bounds.height))
                }
                var uniforms = ArrowGlintUniforms(scene: fraction(glintRect), clip: fraction(glintClip), headroom: headroom)
                encoder.setRenderPipelineState(glintPipeline)
                encoder.setFragmentTexture(glintTexture, index: 0)
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ArrowGlintUniforms>.stride, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
        }
        paintedGlintRect = showsGlints ? glintRect : .null
        paintedGlintHeadroom = showsGlints && !speed.isAnimating(now: now) && samples.isEmpty && cores.isEmpty
            ? headroom : nil
        encoder.endEncoding()
        outstandingSubmissions += 1
        buffer.addCompletedHandler { [weak self] completed in
            let seconds = max(0, completed.gpuEndTime - completed.gpuStartTime)
            let succeeded = completed.status == .completed
            Task { @MainActor in
                self?.outstandingSubmissions = 0
                if succeeded { MobileDevicePerformance.recordGPU(seconds, source: "effects") }
            }
        }
        buffer.present(drawable); buffer.commit()
    }
}
#endif
