#if os(iOS)
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
              let flash = pipeline("flash_fragment") else { return nil }
        self.commands = commands; speedPipeline = speed; popPipeline = pop; flashPipeline = flash
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

    func advance(at now: Double, multiplier: Double, enabled: Bool, field: CGRect,
                 project: @escaping (SIMD2<Float>) -> CGPoint) {
        self.now = now; self.field = field; self.project = project
        speed.setEnabled(enabled && multiplier > 1.01, now: now, multiplier: multiplier)
        if let lastTime, speed.enabled { motionTime += min(0.1, max(0, now - lastTime)) * (0.5 + multiplier / 6) }
        self.lastTime = now
        pops.expire(now: now); cores.removeAll { $0.expires <= now }
        let active = speed.isAnimating(now: now) || !pops.bursts.isEmpty || !cores.isEmpty
        isHidden = !active
        if !active {
            flashTexture = nil
            (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = false
            return
        }
        if let lastPaint, now - lastPaint < 1.0 / 30 { return }
        lastPaint = now
        let scale = min(2, window?.screen.scale ?? 1)
        drawableSize = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
        (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = (window?.screen.potentialEDRHeadroom ?? 1) > 1
        setNeedsDisplay()
    }

    func clear() {
        speed = SuperSpeedTimeline(); pops.clear(); cores.removeAll()
        flashTexture = nil; lastTime = nil; lastPaint = nil; motionTime = 0
        isHidden = true
        (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = false
    }

    override func draw(_ rect: CGRect) {
        guard !isHidden, bounds.width > 0, bounds.height > 0, let project,
              let drawable = currentDrawable, let buffer = commands.makeCommandBuffer() else { return }
        let headroom = Float(min(8, max(1, window?.screen.currentEDRHeadroom ?? 1)))
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
        let samples = pops.samples(now: now) { centre in
            let point = project(centre)
            return SIMD2(Float(point.x / self.bounds.width), Float(point.y / self.bounds.height))
        }
        if !samples.isEmpty {
            var uniforms = NuclearExplosionUniforms(size: SIMD2(Float(bounds.width), Float(bounds.height)), headroom: headroom, count: UInt32(samples.count))
            encoder.setRenderPipelineState(popPipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<NuclearExplosionUniforms>.stride, index: 0)
            samples.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 1) }
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        if !cores.isEmpty, headroom > 1, let device {
            let width = max(1, min(512, Int(ceil(bounds.width))))
            let scale = CGFloat(width) / bounds.width
            let height = max(1, Int(ceil(bounds.height * scale)))
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = .shaderRead
            flashTexture = device.makeTexture(descriptor: descriptor)
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
        encoder.endEncoding(); buffer.present(drawable); buffer.commit()
    }
}
#endif
