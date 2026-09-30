import AppKit
import Metal

/// Sprite coordinates are in the playfield after precision zoom, before CRT projection.
struct LemmingSelectionEffect {
    var sprite: CGImage
    var rect: CGRect
    var clipRect: CGRect
    var mirrored = false
    var animated = true
    var extendedBrightness = true
    var bloom = true
}

/// Matches the Metal layout. Output dimensions are physical display pixels.
struct LemmingSelectionUniforms {
    var rect: SIMD4<Float>
    var clip: SIMD4<Float>
    var dimensions: SIMD4<Float>
    var shape: SIMD4<Float>
    var animation: SIMD4<Float>
    var glass = SIMD4<Float>.zero

    init(_ effect: LemmingSelectionEffect, sourceSize: CGSize, outputSize: CGSize,
         headroom: Float, now: TimeInterval) {
        rect = SIMD4(Float(effect.rect.minX), Float(effect.rect.minY), Float(effect.rect.width), Float(effect.rect.height))
        clip = SIMD4(Float(effect.clipRect.minX), Float(effect.clipRect.minY), Float(effect.clipRect.maxX), Float(effect.clipRect.maxY))
        dimensions = SIMD4(Float(sourceSize.width), Float(sourceSize.height), Float(outputSize.width), Float(outputSize.height))
        shape = SIMD4(Float(effect.sprite.width), Float(effect.sprite.height), Float(LemmingSelectionRenderer.padding), effect.mirrored ? 1 : 0)
        animation = SIMD4(Float(now.truncatingRemainder(dividingBy: 8)),
            effect.extendedBrightness ? max(1, min(8, headroom)) : 1,
            effect.animated ? 1 : 0, effect.bloom ? 1 : 0)
    }
}

/// Shared by flat and CRT output. The sprite mask stays native; its outline is
/// sampled two output pixels away, after every zoom and projection.
@MainActor final class LemmingSelectionRenderer {
    nonisolated static let padding = 10
    nonisolated static let outlineWidth = 2
    private let device: MTLDevice
    private let pipeline: MTLRenderPipelineState
    private var cachedSprite: CGImage?
    private var texture: MTLTexture?

    init(device: MTLDevice) throws {
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

    /// R is the silhouette. G is its Gaussian convolution, used as emitted light
    /// in the linear HDR shader. Padding lets bloom extend beyond the sprite bank.
    static func mask(_ sprite: CGImage) -> (bytes: [UInt8], width: Int, height: Int)? {
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
        let alpha = (0..<(width * height)).map { rgba[$0 * 4 + 3] >= 128 ? Float(1) : 0 }
        let weights = (-padding...padding).map { exp(-Float($0 * $0) / (2 * 2.5 * 2.5)) }
        let total = weights.reduce(0, +)
        var horizontal = [Float](repeating: 0, count: alpha.count)
        for y in 0..<height { for x in 0..<width {
            for offset in -padding...padding where (0..<width).contains(x + offset) {
                horizontal[y * width + x] += alpha[y * width + x + offset] * weights[offset + padding] / total
            }
        } }
        var bytes = [UInt8](repeating: 0, count: alpha.count * 2)
        for y in 0..<height { for x in 0..<width {
            var blurred: Float = 0
            for offset in -padding...padding where (0..<height).contains(y + offset) {
                blurred += horizontal[(y + offset) * width + x] * weights[offset + padding] / total
            }
            bytes[(y * width + x) * 2] = alpha[y * width + x] > 0 ? 255 : 0
            bytes[(y * width + x) * 2 + 1] = UInt8((min(1, blurred) * 255).rounded())
        } }
        return (bytes, width, height)
    }

    func encode(_ effect: LemmingSelectionEffect, sourceSize: CGSize, outputSize: CGSize,
                headroom: Float, now: TimeInterval, glass: SIMD4<Float> = .zero,
                into encoder: MTLRenderCommandEncoder) {
        guard effect.rect.width > 0, effect.rect.height > 0,
              sourceSize.width > 0, sourceSize.height > 0 else { return }
        if cachedSprite !== effect.sprite || texture == nil {
            guard let mask = Self.mask(effect.sprite) else { return }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg8Unorm,
                width: mask.width, height: mask.height, mipmapped: false)
            descriptor.usage = .shaderRead
            guard let fresh = device.makeTexture(descriptor: descriptor) else { return }
            mask.bytes.withUnsafeBytes {
                fresh.replace(region: MTLRegionMake2D(0, 0, mask.width, mask.height), mipmapLevel: 0,
                    withBytes: $0.baseAddress!, bytesPerRow: mask.width * 2)
            }
            texture = fresh
            cachedSprite = effect.sprite
        }
        var uniforms = LemmingSelectionUniforms(effect, sourceSize: sourceSize, outputSize: outputSize,
            headroom: headroom, now: now)
        uniforms.glass = glass
        if glass == .zero {
            let scaleX = outputSize.width / sourceSize.width, scaleY = outputSize.height / sourceSize.height
            let field = effect.rect.insetBy(
                dx: -CGFloat(Self.padding) * effect.rect.width / CGFloat(effect.sprite.width) - CGFloat(Self.outlineWidth) / scaleX,
                dy: -CGFloat(Self.padding) * effect.rect.height / CGFloat(effect.sprite.height) - CGFloat(Self.outlineWidth) / scaleY)
                .intersection(effect.clipRect).intersection(CGRect(origin: .zero, size: sourceSize))
            guard !field.isNull, !field.isEmpty else { return }
            let x = max(0, Int(floor(field.minX * scaleX))), y = max(0, Int(floor(field.minY * scaleY)))
            let right = min(Int(outputSize.width), Int(ceil(field.maxX * scaleX)))
            let bottom = min(Int(outputSize.height), Int(ceil(field.maxY * scaleY)))
            guard right > x, bottom > y else { return }
            encoder.setScissorRect(MTLScissorRect(x: x, y: y, width: right - x, height: bottom - y))
        }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LemmingSelectionUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.setScissorRect(MTLScissorRect(x: 0, y: 0, width: Int(outputSize.width), height: Int(outputSize.height)))
    }

    /// A crisp SDR outline remains available if Metal cannot create its surface.
    static func drawFallback(_ effect: LemmingSelectionEffect) {
        guard let context = NSGraphicsContext.current?.cgContext, let mask = mask(effect.sprite),
              effect.rect.width > 0, effect.rect.height > 0 else { return }
        let deviceScale = abs(context.convertToDeviceSpace(CGSize(width: 1, height: 0)).width)
        let stroke = CGFloat(outlineWidth) / max(1, deviceScale)
        let dx = effect.rect.width / CGFloat(effect.sprite.width)
        let dy = effect.rect.height / CGFloat(effect.sprite.height)
        func opaque(_ x: Int, _ y: Int) -> Bool {
            mask.bytes[((y + padding) * mask.width + x + padding) * 2] > 0
        }
        context.saveGState()
        context.clip(to: effect.clipRect)
        context.setShouldAntialias(false)
        context.setFillColor(NSColor.white.cgColor)
        var cells: [CGRect] = []
        for y in 0..<effect.sprite.height { for x in 0..<effect.sprite.width where opaque(x, y) {
            let px = effect.rect.minX + CGFloat(effect.mirrored ? effect.sprite.width - 1 - x : x) * dx
            let py = effect.rect.minY + CGFloat(y) * dy
            cells.append(CGRect(x: px, y: py, width: dx, height: dy))
        } }
        // Subtract the sprite before expanding, so concave corners stay clear.
        context.addRect(effect.clipRect)
        context.addRects(cells)
        context.clip(using: .evenOdd)
        context.fill(cells.map { $0.insetBy(dx: -stroke, dy: -stroke) })
        context.restoreGState()
    }

    static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct SelectionVertex { float4 position [[position]]; };
    struct SelectionUniforms {
        float4 rect, clip, dimensions, shape, animation, glass;
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
        if (edge > .5) {
            // White-only marching highlights. The dim segments never turn black.
            float phase = (v.position.x + v.position.y) / 8 - u.animation.x * 1.5;
            float shimmer = u.animation.z > 0 ? .5 + .5 * sin(phase * 2 * M_PI_F) : .7;
            float white = mix(.68f, 1.0f, shimmer) * u.animation.y;
            return float4(float3(white) * glass, glass);
        }
        constexpr sampler linear(filter::linear, address::clamp_to_zero);
        // Give the halo a visible SDR floor. HDR headroom adds light to that
        // same broad silhouette instead of being required to see the effect.
        // A two-second breath changes brightness only. Its low point stays
        // visible, and reduced motion or flashes hold the midpoint steady.
        float breath = u.animation.z > 0 ? .5 - .5 * cos(u.animation.x * M_PI_F) : .5;
        float haloGain = mix(.21f, .39f, breath);
        float light = mask.sample(linear, uv).g * haloGain * u.animation.w * glass;
        return float4(float3(.72, 1, .80) * light * u.animation.y, light);
    }
    """
}
