import AppKit
import Metal

struct Failure: Error { let message: String }
func require(_ value: Bool, _ message: String) throws {
  if !value { throw Failure(message:message) }
}

@MainActor func run() throws {
  guard let gpu = MTLCreateSystemDefaultDevice(), let queue = gpu.makeCommandQueue() else {
    throw Failure(message:"Metal is unavailable")
  }
  try require(ExplosionHDR.headroom(1) == 1 && ExplosionHDR.headroom(8) == 4 && ExplosionHDR.headroom(.nan) == 1,
    "display headroom is not bounded")
  let flashes = [ExplosionFlash(rect:CGRect(x:1,y:1,width:2,height:2),strength:1,expiresAt:20),
                 ExplosionFlash(rect:CGRect(x:5,y:5,width:1,height:1),strength:0.5,expiresAt:20)]
  let mask = ExplosionHDR.mask(width:8,height:8,flashes:flashes,now:10)
  try require(mask.filter {$0>0}.count == 5, "HDR mask escaped the explosion core")
  try require(ExplosionHDR.mask(width:8,height:8,flashes:flashes,now:20).allSatisfy {$0 == 0},
    "paused or stale flash did not expire")
  try require(ExplosionHDR.mask(width:8,height:8,flashes:[],now:10).allSatisfy {$0 == 0}, "empty mask contains a flash")
  let clipped = ExplosionHDR.mask(width:8,height:8,flashes:[.init(rect:CGRect(x:-2,y:-2,width:3,height:3),strength:1)])
  try require(clipped.filter {$0>0}.count == 1, "offscreen mask is not clipped")

  func texture(_ format: MTLPixelFormat, bytes: [UInt8], row: Int) -> MTLTexture {
    let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:format,width:8,height:8,mipmapped:false)
    d.usage = .shaderRead
    let t = gpu.makeTexture(descriptor:d)!
    bytes.withUnsafeBytes { t.replace(region:MTLRegionMake2D(0,0,8,8),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:row) }
    return t
  }
  let maskTexture = texture(.r8Unorm,bytes:mask,row:8)
  let source = texture(.rgba8Unorm,bytes:Array(repeating:[UInt8(64),64,64,255],count:64).flatMap {$0},row:32)
  let black = texture(.rgba16Float,bytes:[UInt8](repeating:0,count:8*8*8),row:64)

  func render<T>(code: String, vertex: String, fragment: String, textures: [MTLTexture], uniforms: T) throws -> [Float] {
    let library = try gpu.makeLibrary(source:code,options:nil)
    let p = MTLRenderPipelineDescriptor()
    p.vertexFunction = library.makeFunction(name:vertex)
    p.fragmentFunction = library.makeFunction(name:fragment)
    p.colorAttachments[0].pixelFormat = .rgba16Float
    let pipeline = try gpu.makeRenderPipelineState(descriptor:p)
    let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:8,height:8,mipmapped:false)
    d.usage = [.renderTarget,.shaderRead]; d.storageMode = .private
    let output = gpu.makeTexture(descriptor:d)!, command = queue.makeCommandBuffer()!
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = output
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let encoder = command.makeRenderCommandEncoder(descriptor:pass)!
    encoder.setRenderPipelineState(pipeline)
    for (i,t) in textures.enumerated() { encoder.setFragmentTexture(t,index:i) }
    var u = uniforms
    withUnsafeBytes(of:&u) { encoder.setFragmentBytes($0.baseAddress!,length:$0.count,index:0) }
    encoder.drawPrimitives(type:.triangleStrip,vertexStart:0,vertexCount:4)
    encoder.endEncoding()
    let buffer = gpu.makeBuffer(length:256*8,options:.storageModeShared)!
    let blit = command.makeBlitCommandEncoder()!
    blit.copy(from:output,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),
      sourceSize:MTLSize(width:8,height:8,depth:1),to:buffer,destinationOffset:0,destinationBytesPerRow:256,destinationBytesPerImage:256*8)
    blit.endEncoding(); command.commit(); command.waitUntilCompleted()
    try require(command.status == .completed, "GPU render failed: \(String(describing:command.error))")
    let words = buffer.contents().bindMemory(to:UInt16.self,capacity:1024)
    return (0..<8).flatMap { y in (0..<32).map { x in Float(Float16(bitPattern:words[y*128+x])) } }
  }
  let hdr = try render(code:ExplosionHDR.shader,vertex:"flash_vertex",fragment:"flash_fragment",textures:[maskTexture],uniforms:Float(4))
  let sdr = try render(code:ExplosionHDR.shader,vertex:"flash_vertex",fragment:"flash_fragment",textures:[maskTexture],uniforms:Float(1))
  try require(hdr[(1*8+1)*4] == 4 && hdr[0] == 0 && hdr[3] == 0, "overlay lost HDR values or changed its transparent background")
  try require(sdr.allSatisfy {$0 == 0}, "overlay altered the SDR fallback")
  try require(abs(hdr[(5*8+5)*4]-2.5)<0.02 && hdr[(5*8+5)*4+2] == 0, "second flash tick lost its warm, lower peak")

  var u = CRTUniforms()
  u.sourceSize = .init(8,8); u.outputSize = .init(8,8); u.hdrHeadroom = 4
  let crt = try render(code:CRTShaders.source,vertex:"crt_vertex",fragment:"crt_composite",textures:[source,black,maskTexture],uniforms:u)
  u.hdrHeadroom = 1
  let crtSDR = try render(code:CRTShaders.source,vertex:"crt_vertex",fragment:"crt_composite",textures:[source,black,maskTexture],uniforms:u)
  try require(crt[(1*8+1)*4] == 4, "CRT output clipped the HDR flash")
  try require(crtSDR.allSatisfy {$0 >= 0 && $0 <= 1}, "SDR CRT output exceeds SDR range")
  for i in 0..<64 where mask[i] == 0 {
    for c in 0..<4 { try require(crt[i*4+c] == crtSDR[i*4+c], "HDR changed the terrain or UI") }
  }
  for screen in NSScreen.screens {
    print("Display \(screen.localizedName): current EDR \(screen.maximumExtendedDynamicRangeColorComponentValue), potential \(screen.maximumPotentialExtendedDynamicRangeColorComponentValue)")
  }
  print("PASS actual FP16 GPU output: 4x HDR core, warm second tick, unchanged SDR/background, bounded headroom and expiry")
}
do { try run() } catch { print("FAIL: \(error)"); exit(1) }
