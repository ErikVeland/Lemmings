import Metal
import Foundation

// Builds the CRT shaders the way CRTView does, and reports what happens.
// The view swallows a failure into `isAvailable == false`, which shows up as
// the television and monitor settings quietly doing nothing.

guard let device = MTLCreateSystemDefaultDevice() else {
    print("no Metal device"); exit(1)
}
print("device: \(device.name)")

do {
    let library = try device.makeLibrary(source: CRTShaders.source, options: nil)
    print("library built. functions: \(library.functionNames.sorted())")
    func pipeline(_ fragment: String, format: MTLPixelFormat) throws {
        let d = MTLRenderPipelineDescriptor()
        d.vertexFunction = library.makeFunction(name: "crt_vertex")
        d.fragmentFunction = library.makeFunction(name: fragment)
        guard d.vertexFunction != nil else { print("MISSING crt_vertex"); return }
        guard d.fragmentFunction != nil else { print("MISSING \(fragment)"); return }
        d.colorAttachments[0].pixelFormat = format
        _ = try device.makeRenderPipelineState(descriptor: d)
        print("pipeline ok: \(fragment)")
    }
    try pipeline("crt_bright", format: .rgba16Float)
    try pipeline("crt_blur_h", format: .rgba16Float)
    try pipeline("crt_blur_v", format: .rgba16Float)
    try pipeline("crt_composite", format: .bgra8Unorm)
} catch {
    print("FAILED: \(error)")
    exit(1)
}
