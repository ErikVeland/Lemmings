#if os(iOS)
import LemmingsMobileCore
import MetalKit
import UIKit

@MainActor final class MobileMetalView: MTKView, MTKViewDelegate, UIGestureRecognizerDelegate {
    var onTouchEffects: (([MobileTouchEffect]) -> Void)?
    var onViewportChanged: ((MobileViewport) -> Void)?

    var gameViewport: MobileViewport {
        didSet {
            renderer?.viewport = gameViewport
            setNeedsDisplay()
        }
    }

    private var router = MobileTouchRouter()
    private var activeTouchID: Int?
    private var automaticallyFitsViewport: Bool
    private var renderer: MobileMetalRenderer?

    init(viewport: MobileViewport, automaticallyFitsViewport: Bool = true) {
        gameViewport = viewport
        self.automaticallyFitsViewport = automaticallyFitsViewport
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        framebufferOnly = true
        enableSetNeedsDisplay = true
        isPaused = true
        preferredFramesPerSecond = 60
        isMultipleTouchEnabled = true
        delegate = self
        renderer = device.flatMap { try? MobileMetalRenderer(device: $0, pixelFormat: colorPixelFormat) }
        renderer?.viewport = viewport

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        isAccessibilityElement = true
        accessibilityLabel = "Game playfield"
        accessibilityHint = "Tap a lemming to assign the selected skill. Drag to pan. Pinch to zoom."
        accessibilityTraits = .allowsDirectInteraction
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func update(frame: MobilePixelFrame) {
        renderer?.update(frame: frame)
        setNeedsDisplay()
    }

    func purgeTexture() {
        renderer?.purgeTexture()
    }

    func stopAutomaticFitting() {
        automaticallyFitsViewport = false
    }

    func draw(in view: MTKView) {
        renderer?.draw(in: view)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = MobileSize(width: bounds.width, height: bounds.height)
        if automaticallyFitsViewport {
            gameViewport.fitGameplay(in: size)
        } else {
            gameViewport.resize(size)
        }
        renderer?.viewport = gameViewport
        onViewportChanged?(gameViewport)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouchID == nil, let touch = touches.first else { return }
        let id = ObjectIdentifier(touch).hashValue
        activeTouchID = id
        let point = touch.location(in: self)
        onTouchEffects?(router.began(
            id: id,
            at: MobilePoint(x: point.x, y: point.y),
            time: touch.timestamp
        ))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let id = activeTouchID,
              let touch = touches.first(where: { ObjectIdentifier($0).hashValue == id }) else { return }
        let point = touch.location(in: self)
        onTouchEffects?(router.moved(id: id, to: MobilePoint(x: point.x, y: point.y)))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let id = activeTouchID,
              let touch = touches.first(where: { ObjectIdentifier($0).hashValue == id }) else { return }
        activeTouchID = nil
        let point = touch.location(in: self)
        onTouchEffects?(router.ended(
            id: id,
            at: MobilePoint(x: point.x, y: point.y),
            time: touch.timestamp
        ))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouchID = nil
        onTouchEffects?(router.cancel())
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .began {
            automaticallyFitsViewport = false
            activeTouchID = nil
            onTouchEffects?(router.cancel())
        }
        guard recognizer.state == .began || recognizer.state == .changed else { return }
        let anchor = recognizer.location(in: self)
        gameViewport.magnify(
            by: recognizer.scale,
            around: MobilePoint(x: anchor.x, y: anchor.y)
        )
        recognizer.scale = 1
        renderer?.viewport = gameViewport
        onViewportChanged?(gameViewport)
        setNeedsDisplay()
    }
}

@MainActor private final class MobileMetalRenderer {
    private struct Uniforms {
        var textureRect: SIMD4<Float>
    }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var texture: MTLTexture?
    var viewport = MobileViewport(
        levelSize: MobileSize(width: 1, height: 1),
        viewSize: MobileSize(width: 1, height: 1)
    )

    init(device: MTLDevice, pixelFormat: MTLPixelFormat) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else { throw MobileSessionError.frameUnavailable }
        self.queue = queue
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 uv;
        };

        struct Uniforms {
            float4 textureRect;
        };

        vertex VertexOut mobile_vertex(
            uint id [[vertex_id]],
            constant Uniforms& uniforms [[buffer(0)]]) {
            const float2 positions[4] = {
                float2(-1.0, -1.0), float2(1.0, -1.0),
                float2(-1.0, 1.0), float2(1.0, 1.0)
            };
            const float2 corners[4] = {
                float2(0.0, 1.0), float2(1.0, 1.0),
                float2(0.0, 0.0), float2(1.0, 0.0)
            };
            VertexOut out;
            out.position = float4(positions[id], 0.0, 1.0);
            out.uv = mix(uniforms.textureRect.xy, uniforms.textureRect.zw, corners[id]);
            return out;
        }

        fragment float4 mobile_fragment(
            VertexOut in [[stage_in]],
            texture2d<float> image [[texture(0)]]) {
            constexpr sampler nearestSampler(coord::normalized, address::clamp_to_edge,
                                              filter::nearest, mip_filter::none);
            return image.sample(nearestSampler, in.uv);
        }
        """
        let library = try device.makeLibrary(source: source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "mobile_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "mobile_fragment")
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func update(frame: MobilePixelFrame) {
        if texture?.width != frame.width || texture?.height != frame.height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: frame.width,
                height: frame.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead]
            texture = device.makeTexture(descriptor: descriptor)
        }
        frame.rgba.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            texture?.replace(
                region: MTLRegionMake2D(0, 0, frame.width, frame.height),
                mipmapLevel: 0,
                withBytes: base,
                bytesPerRow: frame.width * 4
            )
        }
    }

    func purgeTexture() {
        texture = nil
    }

    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let buffer = queue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        defer {
            encoder.endEncoding()
            buffer.present(drawable)
            buffer.commit()
        }
        guard let texture else { return }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)

        let visible = viewport.visibleLevelRect
        var uniforms = Uniforms(textureRect: SIMD4<Float>(
            Float(visible.minX / viewport.levelSize.width),
            Float(visible.minY / viewport.levelSize.height),
            Float(visible.maxX / viewport.levelSize.width),
            Float(visible.maxY / viewport.levelSize.height)
        ))
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

        let content = viewport.contentFrame
        let scaleX = Double(view.drawableSize.width) / max(1, view.bounds.width)
        let scaleY = Double(view.drawableSize.height) / max(1, view.bounds.height)
        encoder.setViewport(MTLViewport(
            originX: content.x * scaleX,
            originY: content.y * scaleY,
            width: content.width * scaleX,
            height: content.height * scaleY,
            znear: 0,
            zfar: 1
        ))
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
}
#endif
