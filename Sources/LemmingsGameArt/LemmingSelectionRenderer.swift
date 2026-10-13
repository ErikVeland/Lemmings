import Foundation
import CoreGraphics
import Metal

/// Sprite coordinates are in the playfield after precision zoom, before CRT projection.
public struct LemmingSelectionEffect {
    public init(sprite: CGImage, rect: CGRect, clipRect: CGRect, mirrored: Bool = false, bloom: Bool = true, time: TimeInterval? = nil) {
        self.sprite = sprite; self.rect = rect; self.clipRect = clipRect
        self.mirrored = mirrored; self.bloom = bloom; self.time = time
    }
    public var sprite: CGImage
    public var rect: CGRect
    public var clipRect: CGRect
    public var mirrored = false
    public var bloom = true
    public var opacity: CGFloat = 1
    /// Golden rescue light uses the same sprite mask without a selection outline.
    public var rescueAmount: CGFloat = 0
    /// Simulation time keeps the pulse in the game frame and holds it on pause.
    /// Nil holds the midpoint for reduced motion and reduced flashes.
    public var time: TimeInterval? = nil

    public var glowGain: CGFloat {
        guard let time else { return 0.87 }
        return 0.87 - 0.13 * cos(time * 2 * .pi / 2.8)
    }
}

/// Matches the Metal layout. Output dimensions are physical display pixels.
struct LemmingSelectionUniforms {
    var rect: SIMD4<Float>
    var clip: SIMD4<Float>
    var dimensions: SIMD4<Float>
    var shape: SIMD4<Float>
    var style: SIMD4<Float>
    var glass = SIMD4<Float>.zero
    var fade = SIMD4<Float>(1, 0, 0, 0)

    init(_ effect: LemmingSelectionEffect, sourceSize: CGSize, outputSize: CGSize) {
        rect = SIMD4(Float(effect.rect.minX), Float(effect.rect.minY), Float(effect.rect.width), Float(effect.rect.height))
        clip = SIMD4(Float(effect.clipRect.minX), Float(effect.clipRect.minY), Float(effect.clipRect.maxX), Float(effect.clipRect.maxY))
        dimensions = SIMD4(Float(sourceSize.width), Float(sourceSize.height), Float(outputSize.width), Float(outputSize.height))
        shape = SIMD4(Float(effect.sprite.width), Float(effect.sprite.height), Float(LemmingSelectionRenderer.padding), effect.mirrored ? 1 : 0)
        fade.x = Float(min(1, max(0, effect.opacity)))
        style = effect.rescueAmount > 0
            ? SIMD4(Float(effect.rescueAmount) * 2.4, 1, 1, 0)
            : SIMD4(effect.bloom ? Float(effect.glowGain) : 0, 0, 0, 0)
    }
}

/// Shared by flat and CRT output. The sprite mask stays native; its outline is
/// sampled two output pixels away, after every zoom and projection.
@MainActor public final class LemmingSelectionRenderer {
    nonisolated public static let padding = 16
    nonisolated public static let outlineWidth = 2
    private let device: MTLDevice
    private let pipeline: MTLRenderPipelineState
    private struct Frame {
        let sprite: CGImage
        let bytes: [UInt8]
        let width: Int
        let height: Int
        let cells: [CGRect]
        let glow: CGImage
        let goldGlow: CGImage
    }
    // Retain the source image with its entry, so object identities cannot be reused.
    // Animation cycles reuse their masks instead of rebuilding every pose change.
    private static var frames: [ObjectIdentifier: Frame] = [:]
    private static var frameOrder: [ObjectIdentifier] = []
    public static let cacheLimit = 128
    public static var cachedFrameCount: Int { frames.count }
    private var textures: [ObjectIdentifier: (sprite: CGImage, texture: MTLTexture)] = [:]
    private var textureOrder: [ObjectIdentifier] = []

    public init(device: MTLDevice) throws {
        self.device = device
        let library = try device.makeLibrary(source: Self.shader, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "selection_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "selection_fragment")
        let attachment = descriptor.colorAttachments[0]!
        attachment.pixelFormat = .rgba16Float
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .one
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    /// R is the silhouette. G is a soft distance falloff shared by the bitmap
    /// and CRT paths. Thin limbs emit the same light as solid parts of the sprite.
    public static func mask(_ sprite: CGImage) -> (bytes: [UInt8], width: Int, height: Int)? {
        guard let frame = frame(sprite) else { return nil }
        return (frame.bytes, frame.width, frame.height)
    }

    private static func frame(_ sprite: CGImage) -> Frame? {
        let key = ObjectIdentifier(sprite)
        if let cached = frames[key] { return cached }
        let width = sprite.width + 2 * padding, height = sprite.height + 2 * padding
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.interpolationQuality = .none
            context.draw(sprite, in: CGRect(x: padding, y: padding, width: sprite.width, height: sprite.height))
            return true
        }
        guard drawn else { return nil }
        let opaque = (0..<(width * height)).map { rgba[$0 * 4 + 3] >= 128 }
        // Two short distance passes replace convolution. Each animation pose is
        // built once, with a bright inner glow and a soft, wider falloff.
        var distance = opaque.map { $0 ? Float(0) : Float(width + height) }
        let diagonal: Float = 1.41421356
        for y in 0..<height { for x in 0..<width {
            let index = y * width + x
            if x > 0 { distance[index] = min(distance[index], distance[index - 1] + 1) }
            if y > 0 {
                distance[index] = min(distance[index], distance[index - width] + 1)
                if x > 0 { distance[index] = min(distance[index], distance[index - width - 1] + diagonal) }
                if x + 1 < width { distance[index] = min(distance[index], distance[index - width + 1] + diagonal) }
            }
        } }
        for y in (0..<height).reversed() { for x in (0..<width).reversed() {
            let index = y * width + x
            if x + 1 < width { distance[index] = min(distance[index], distance[index + 1] + 1) }
            if y + 1 < height {
                distance[index] = min(distance[index], distance[index + width] + 1)
                if x > 0 { distance[index] = min(distance[index], distance[index + width - 1] + diagonal) }
                if x + 1 < width { distance[index] = min(distance[index], distance[index + width + 1] + diagonal) }
            }
        } }
        let artworkScale = max(0.75, min(1.5, Float(sprite.height) / 16))
        var bytes = [UInt8](repeating: 0, count: opaque.count * 2)
        for index in opaque.indices {
            let d = distance[index] / artworkScale
            let glow = 0.38 * exp(-d * d / (2 * 1.1 * 1.1)) + 0.24 * exp(-d * d / (2 * 3.2 * 3.2))
            bytes[index * 2] = opaque[index] ? 255 : 0
            bytes[index * 2 + 1] = UInt8((glow * 255).rounded())
        }
        var cells: [CGRect] = []
        for y in 0..<sprite.height {
            var x = 0
            while x < sprite.width {
                if bytes[((y + padding) * width + x + padding) * 2] == 0 { x += 1; continue }
                let start = x
                while x < sprite.width && bytes[((y + padding) * width + x + padding) * 2] > 0 { x += 1 }
                cells.append(CGRect(x: start, y: y, width: x - start, height: 1))
            }
        }
        let glowBytes = stride(from: 1, to: bytes.count, by: 2).flatMap { index -> [UInt8] in
            let light = Float(bytes[index])
            return [UInt8(light * 0.32), UInt8(light), UInt8(light * 0.56), UInt8(light)]
        }
        guard let provider = CGDataProvider(data: Data(glowBytes) as CFData),
              let glow = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        let goldBytes = stride(from: 1, to: bytes.count, by: 2).flatMap { index -> [UInt8] in
            let light = min(255, Float(bytes[index]) * 2.4)
            return [UInt8(light), UInt8(light * 0.72), UInt8(light * 0.18), UInt8(light)]
        }
        guard let goldProvider = CGDataProvider(data: Data(goldBytes) as CFData),
              let goldGlow = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: goldProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        let result = Frame(sprite: sprite, bytes: bytes, width: width, height: height, cells: cells, glow: glow, goldGlow: goldGlow)
        if frameOrder.count == cacheLimit { frames.removeValue(forKey: frameOrder.removeFirst()) }
        frameOrder.append(key); frames[key] = result
        return result
    }

    public func encode(_ effect: LemmingSelectionEffect, sourceSize: CGSize, outputSize: CGSize,
                glass: SIMD4<Float> = .zero,
                headroom: Float = 1,
                additive: Bool = false,
                into encoder: MTLRenderCommandEncoder) {
        guard effect.rect.width > 0, effect.rect.height > 0,
              sourceSize.width > 0, sourceSize.height > 0 else { return }
        let key = ObjectIdentifier(effect.sprite)
        if textures[key] == nil {
            guard let mask = Self.mask(effect.sprite) else { return }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg8Unorm,
                width: mask.width, height: mask.height, mipmapped: false)
            descriptor.usage = .shaderRead
            guard let fresh = device.makeTexture(descriptor: descriptor) else { return }
            mask.bytes.withUnsafeBytes {
                fresh.replace(region: MTLRegionMake2D(0, 0, mask.width, mask.height), mipmapLevel: 0,
                    withBytes: $0.baseAddress!, bytesPerRow: mask.width * 2)
            }
            if textureOrder.count == Self.cacheLimit { textures.removeValue(forKey: textureOrder.removeFirst()) }
            textureOrder.append(key); textures[key] = (effect.sprite, fresh)
        }
        var uniforms = LemmingSelectionUniforms(effect, sourceSize: sourceSize, outputSize: outputSize)
        uniforms.style.z = min(3, max(1, headroom))
        uniforms.style.w = additive ? 1 : 0
        uniforms.glass = glass
        do {
            let scaleX = outputSize.width / sourceSize.width, scaleY = outputSize.height / sourceSize.height
            let field = effect.rect.insetBy(
                dx: -CGFloat(Self.padding) * effect.rect.width / CGFloat(effect.sprite.width) - CGFloat(Self.outlineWidth) / scaleX,
                dy: -CGFloat(Self.padding) * effect.rect.height / CGFloat(effect.sprite.height) - CGFloat(Self.outlineWidth) / scaleY)
                .intersection(effect.clipRect).intersection(CGRect(origin: .zero, size: sourceSize))
            guard !field.isNull, !field.isEmpty else { return }
            // Curvature pulls source coordinates towards the display centre.
            // Bound that contraction on each axis using the other source axis.
            func projected(_ low: CGFloat, _ high: CGFloat, other: CGFloat, curvature: Float) -> (CGFloat, CGFloat) {
                guard curvature > 0 else { return (low, high) }
                let divisor = 1 + pow(other / CGFloat(curvature), 2)
                return (min(low, low / divisor), max(high, high / divisor))
            }
            let left = field.minX / sourceSize.width * 2 - 1, rightEdge = field.maxX / sourceSize.width * 2 - 1
            let top = field.minY / sourceSize.height * 2 - 1, bottomEdge = field.maxY / sourceSize.height * 2 - 1
            let px = projected(left, rightEdge, other: max(abs(top), abs(bottomEdge)), curvature: glass.x)
            let py = projected(top, bottomEdge, other: max(abs(left), abs(rightEdge)), curvature: glass.y)
            let projectedField = CGRect(x: (px.0 + 1) * sourceSize.width / 2, y: (py.0 + 1) * sourceSize.height / 2,
                width: (px.1 - px.0) * sourceSize.width / 2, height: (py.1 - py.0) * sourceSize.height / 2)
            let x = max(0, Int(floor(projectedField.minX * scaleX))), y = max(0, Int(floor(projectedField.minY * scaleY)))
            let right = min(Int(outputSize.width), Int(ceil(projectedField.maxX * scaleX)))
            let bottom = min(Int(outputSize.height), Int(ceil(projectedField.maxY * scaleY)))
            guard right > x, bottom > y else { return }
            encoder.setScissorRect(MTLScissorRect(x: x, y: y, width: right - x, height: bottom - y))
        }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(textures[key]?.texture, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LemmingSelectionUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.setScissorRect(MTLScissorRect(x: 0, y: 0, width: Int(outputSize.width), height: Int(outputSize.height)))
    }

    /// Paint with the game frame. Selection never owns a surface or a timer.
    public static func drawObvious(at point: CGPoint, scale: CGFloat, animated: Bool, context: CGContext) {
        let pixel = max(1, floor(scale))
        let radius = max(8 * pixel, 7 * scale * 1.3)
        let alpha = CGFloat(0.62 + (animated ? 0.06 * sin(ProcessInfo.processInfo.systemUptime * .pi) : 0))
        let tint = CGColor(srgbRed: 0.3, green: 0.85, blue: 0.2, alpha: 1)
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(true)
        for (colour, opacity, haloRadius) in [(CGColor(gray: 0, alpha: 1), CGFloat(0.34), radius * 1.25), (tint, alpha, radius)] {
            if let start = colour.copy(alpha: opacity), let end = colour.copy(alpha: 0),
               let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [start, end] as CFArray, locations: [0, 1]) {
                context.drawRadialGradient(gradient, startCenter: point, startRadius: 0, endCenter: point, endRadius: haloRadius, options: [])
            }
        }
        context.setShouldAntialias(false)
        let x = floor(point.x / pixel) * pixel, y = floor(point.y / pixel) * pixel - 15 * pixel
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        for (dx, dy, width, height) in [(-4.0, 0.0, 8.0, 3.0), (-3, 3, 6, 1), (-2, 4, 4, 1), (-1, 5, 2, 1)] {
            context.fill(CGRect(x: x + dx * pixel, y: y + dy * pixel, width: width * pixel, height: height * pixel))
        }
        context.setFillColor(tint)
        for (dx, dy, width, height) in [(-3.0, 1.0, 6.0, 2.0), (-2, 3, 4, 1), (-1, 4, 2, 1)] {
            context.fill(CGRect(x: x + dx * pixel, y: y + dy * pixel, width: width * pixel, height: height * pixel))
        }
    }

    public static func draw(_ effect: LemmingSelectionEffect, in context: CGContext) {
        guard let frame = frame(effect.sprite),
              effect.rect.width > 0, effect.rect.height > 0 else { return }
        let deviceScale = abs(context.convertToDeviceSpace(CGSize(width: 1, height: 0)).width)
        let stroke = CGFloat(outlineWidth) / max(1, deviceScale)
        let dx = effect.rect.width / CGFloat(effect.sprite.width)
        let dy = effect.rect.height / CGFloat(effect.sprite.height)
        let field = effect.rect.insetBy(dx: -CGFloat(padding) * dx - stroke, dy: -CGFloat(padding) * dy - stroke)
        guard field.intersects(effect.clipRect) else { return }
        let cells = frame.cells.map { cell in
            let rect = CGRect(x: effect.rect.minX + (effect.mirrored ? CGFloat(effect.sprite.width) - cell.maxX : cell.minX) * dx,
                y: effect.rect.minY + cell.minY * dy, width: cell.width * dx, height: cell.height * dy)
            // Match nearest-neighbour sampling before expanding the outline.
            func snapX(_ x: CGFloat) -> CGFloat {
                (effect.mirrored ? floor(x * deviceScale + 0.5) : ceil(x * deviceScale - 0.5)) / deviceScale
            }
            let x = snapX(rect.minX)
            let y = ceil(rect.minY * deviceScale - 0.5) / deviceScale
            return CGRect(x: x, y: y, width: snapX(rect.maxX) - x,
                height: ceil(rect.maxY * deviceScale - 0.5) / deviceScale - y)
        }.filter { !$0.isEmpty }
        context.saveGState()
        defer { context.restoreGState() }
        // Keep the clip mask local to this sprite, even on a large display.
        let opacity = min(1, max(0, effect.opacity))
        context.setAlpha(opacity)
        context.clip(to: field.intersection(effect.clipRect))
        // Fade the composited halo and border once, including overlapping cells.
        if opacity < 1 { context.beginTransparencyLayer(auxiliaryInfo: nil) }
        defer { if opacity < 1 { context.endTransparencyLayer() } }
        context.setShouldAntialias(false)
        context.addRect(field)
        context.addRects(cells)
        context.clip(using: .evenOdd)
        if effect.bloom {
            context.saveGState()
            let glowRect = effect.rect.insetBy(dx: -CGFloat(padding) * dx, dy: -CGFloat(padding) * dy)
            context.interpolationQuality = .low
            context.setAlpha(effect.rescueAmount > 0 ? effect.rescueAmount * 0.3 : effect.glowGain)
            context.translateBy(x: effect.mirrored ? glowRect.maxX : glowRect.minX, y: glowRect.maxY)
            context.scaleBy(x: effect.mirrored ? -1 : 1, y: -1)
            context.draw(effect.rescueAmount > 0 ? frame.goldGlow : frame.glow, in: CGRect(origin: .zero, size: glowRect.size))
            context.restoreGState()
        }
        guard effect.rescueAmount == 0 else { return }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.addRects(cells.map { $0.insetBy(dx: -stroke, dy: -stroke) })
        context.fillPath()
    }

    public static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct SelectionVertex { float4 position [[position]]; };
    struct SelectionUniforms {
        float4 rect, clip, dimensions, shape, style, glass, fade;
    };
    vertex SelectionVertex selection_vertex(uint id [[vertex_id]]) {
        float2 p[4] = {float2(-1,-1),float2(1,-1),float2(-1,1),float2(1,1)};
        return {float4(p[id],0,1)};
    }
    float2 selection_source(float2 pixel, constant SelectionUniforms &u) {
        float2 uv = pixel / u.dimensions.zw;
        if (u.glass.x > 0 || u.glass.y > 0) {
            float2 c = uv * 2 - 1;
            c += c * pow(abs(c.yx) / max(u.glass.xy, float2(.0001)), 2.0f);
            uv = c * .5 + .5;
        }
        return uv * u.dimensions.xy;
    }
    float2 selection_uv(float2 source, constant SelectionUniforms &u) {
        float2 local = (source - u.rect.xy) / u.rect.zw;
        if (u.shape.w > 0) local.x = 1 - local.x;
        return (local * u.shape.xy + u.shape.z) / (u.shape.xy + 2 * u.shape.z);
    }
    float selection_alpha(float2 pixel, texture2d<float> mask, constant SelectionUniforms &u) {
        constexpr sampler nearest(filter::nearest, address::clamp_to_zero);
        return mask.sample(nearest, selection_uv(selection_source(pixel, u), u)).r;
    }
    fragment float4 selection_fragment(SelectionVertex v [[stage_in]],
        texture2d<float> mask [[texture(0)]], constant SelectionUniforms &u [[buffer(0)]]) {
        float2 source = selection_source(v.position.xy, u);
        if (any(source < u.clip.xy) || any(source >= u.clip.zw)) return float4(0);
        float2 uv = selection_uv(source, u);
        if (any(uv < 0) || any(uv > 1)) return float4(0);
        float glass = 1;
        if (u.glass.z > 0) {
            float2 norm = source / u.dimensions.xy;
            float2 outside = max(u.glass.z - min(norm, 1 - norm), 0.0f);
            glass = 1 - smoothstep(u.glass.z - max(u.glass.w, .0001f), u.glass.z, length(outside));
        }
        // Do not bleach the sprite, including transparent holes and mirrored art.
        if (selection_alpha(v.position.xy, mask, u) > .5) return float4(0);
        float edge = 0;
        for (int y = -\(outlineWidth); y <= \(outlineWidth); ++y) for (int x = -\(outlineWidth); x <= \(outlineWidth); ++x) {
            edge = max(edge, selection_alpha(v.position.xy + float2(x, y), mask, u));
        }
        if (edge > .5 && u.style.y < .5) {
            return float4(float3(glass), glass) * u.fade.x;
        }
        constexpr sampler linear(filter::linear, address::clamp_to_zero);
        float light = mask.sample(linear, uv).g * u.style.x * glass;
        if (u.style.y > .5) {
            float alpha = min(.88f, light) * .3f;
            float peak = 1 + (u.style.z - 1) * .65;
            if (u.style.w > .5) return float4(float3(1,.72,.18) * alpha * (peak - 1), 0) * u.fade.x;
            return float4(float3(1,.72,.18) * alpha * peak, alpha) * u.fade.x;
        }
        return float4(float3(.32, 1, .56) * light, light) * u.fade.x;
    }
    """
}
