import Foundation
import CoreGraphics
import ImageIO
import Metal

@main struct MobileFailureMoodTests {
    static let width = 64, height = 32
    static func context() -> CGContext {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }
    static func patches(_ context: CGContext) {
        for (index, color) in [CGColor(gray: 0, alpha: 1), CGColor(gray: 0.5, alpha: 1),
            CGColor(srgbRed: 0, green: 0.8, blue: 0, alpha: 1), CGColor(srgbRed: 0.8, green: 0, blue: 0, alpha: 1)].enumerated() {
            context.setFillColor(color)
            context.fill(CGRect(x: index * 16, y: 0, width: 16, height: height))
        }
    }
    static func pixels(_ context: CGContext) -> [UInt8] {
        Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: width * height * 4))
    }
    static func pixel(_ data: [UInt8], _ column: Int) -> [UInt8] {
        let offset = (height / 2 * width + column * 16 + 8) * 4
        return Array(data[offset..<offset + 3])
    }
    static func main() throws {
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let normal = context(); patches(normal)
        let original = pixels(normal)
        FailureMoodArt.draw(in: bounds, amount: 0, context: normal)
        precondition(pixels(normal) == original, "Recovery must preserve every source pixel")
        var frames: [[UInt8]] = []
        for amount: CGFloat in [0, 0.5, 1] {
            let canvas = context(); patches(canvas)
            FailureMoodArt.draw(in: bounds, amount: amount, context: canvas)
            let data = pixels(canvas)
            precondition(pixel(data, 0) == [0, 0, 0], "Funeral mood must not put a grey veil over black")
            if let previous = frames.last {
                let color = pixel(data, 2), before = pixel(previous, 2)
                precondition(color.max()! - color.min()! < before.max()! - before.min()!, "Green must desaturate")
                precondition(pixel(data, 1)[0] < pixel(previous, 1)[0], "Grey must darken rather than brighten")
            }
            frames.append(data)
        }
        precondition(FailureMoodArt.saturation(0) == 1 && FailureMoodArt.brightness(0) == 1)
        precondition(FailureMoodArt.saturation(1) < 0.3 && FailureMoodArt.brightness(1) < 0.75)
        let metalChecked = try checkMetal(original)
        if CommandLine.arguments.count > 1 {
            let root = URL(fileURLWithPath: CommandLine.arguments[1])
            let source = root.appendingPathComponent(".build/graphics-refresh-renders/dos.png")
            if let input = CGImageSourceCreateWithURL(source as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(input, 0, nil) {
                let output = root.appendingPathComponent(".build/failure-mood-render-tests")
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                for (name, amount): (String, CGFloat) in [("normal", 0), ("funeral", 1), ("recovered", 0)] {
                    let canvas = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                        bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
                    canvas.setFillColor(CGColor(gray: 0, alpha: 1))
                    canvas.fill(rect)
                    canvas.draw(image, in: rect)
                    FailureMoodArt.draw(in: rect, amount: amount, context: canvas)
                    let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name + ".png") as CFURL, "public.png" as CFString, 1, nil)!
                    CGImageDestinationAddImage(destination, canvas.makeImage()!, nil)
                    precondition(CGImageDestinationFinalize(destination))
                }
            }
        }
        print("PASS flat funeral desaturation, preserved black, darkening and exact recovery")
        if metalChecked { print("PASS Metal funeral desaturation, preserved black, darkening and exact recovery") }
    }

    static func checkMetal(_ source: [UInt8]) throws -> Bool {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            print("SKIP Metal funeral check: no headless Metal device available")
            return false
        }
        let library = try device.makeLibrary(source: CRTShaders.source, options: nil)
        let pipeline = MTLRenderPipelineDescriptor()
        pipeline.vertexFunction = library.makeFunction(name: "crt_vertex")
        pipeline.fragmentFunction = library.makeFunction(name: "crt_composite")
        pipeline.colorAttachments[0].pixelFormat = .rgba16Float
        let state = try device.makeRenderPipelineState(descriptor: pipeline)
        let inputDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        inputDescriptor.usage = .shaderRead
        let input = device.makeTexture(descriptor: inputDescriptor)!
        source.withUnsafeBytes { input.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
        let mask = device.makeTexture(descriptor: inputDescriptor)!
        [UInt8](repeating: 0, count: source.count).withUnsafeBytes {
            mask.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4)
        }
        let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        targetDescriptor.usage = [.renderTarget, .shaderRead]
        targetDescriptor.storageMode = .shared
        let target = device.makeTexture(descriptor: targetDescriptor)!
        var previous: [Float]?
        var recovered: [Float]?
        for amount: CGFloat in [0, 0.5, 1, 0] {
            var uniforms = CRTUniforms()
            uniforms.sourceSize = SIMD2(Float(width), Float(height))
            uniforms.outputSize = uniforms.sourceSize
            uniforms.saturation = FailureMoodArt.saturation(amount)
            uniforms.brightness = FailureMoodArt.brightness(amount)
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            let buffer = queue.makeCommandBuffer()!, encoder = buffer.makeRenderCommandEncoder(descriptor: pass)!
            encoder.setRenderPipelineState(state)
            encoder.setFragmentTexture(input, index: 0)
            encoder.setFragmentTexture(input, index: 1)
            encoder.setFragmentTexture(mask, index: 2)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CRTUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding(); buffer.commit(); buffer.waitUntilCompleted()
            precondition(buffer.status == .completed)
            var bytes = [UInt16](repeating: 0, count: width * height * 4)
            bytes.withUnsafeMutableBytes { target.getBytes($0.baseAddress!, bytesPerRow: width * 8, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0) }
            let data = bytes.map { Float(Float16(bitPattern: $0)) }
            let black = (height / 2 * width + 8) * 4
            precondition(data[black..<black + 3].allSatisfy { abs($0) < 0.0001 })
            if amount == 0 {
                if let recovered { precondition(data == recovered, "CRT recovery accumulated the previous mood") }
                else { recovered = data }
            } else if let previous {
                let green = (height / 2 * width + 40) * 4
                precondition(data[green + 1] - data[green] < previous[green + 1] - previous[green], "CRT green must lose saturation")
                let grey = (height / 2 * width + 24) * 4
                precondition(data[grey] < previous[grey], "CRT grey must darken")
            }
            previous = data
        }
        return true
    }
}
