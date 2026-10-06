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
  try require(ExplosionHDR.headroom(1) == 1 && ExplosionHDR.headroom(12) == 8 && ExplosionHDR.headroom(.nan) == 1,
    "display headroom is not bounded")
  let host = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1600, height: 1000),
    styleMask: [.titled], backing: .buffered, defer: false)
  let idle = ExplosionHDRView(frame: host.contentView!.bounds)
  host.contentView?.addSubview(idle)
  idle.layout()
  idle.update([], force: true)
  try require(!idle.hasAllocatedFlashMask, "An idle full-screen overlay allocated an HDR mask")
  idle.update([.init(rect: CGRect(x: 10, y: 10, width: 4, height: 4), strength: 1)])
  try require(idle.hasAllocatedFlashMask, "An active flash did not allocate its mask")
  idle.clear()
  try require(!idle.hasAllocatedFlashMask && idle.layer?.isHidden == true,
    "Clearing the last flash left an idle mask or visible frame")
  print("PASS idle HDR overlay skips masks and clears the last effect")
  var camera = CGPoint(x: 100, y: 20)
  var zoom: CGFloat = 2
  let world = CGRect(x: 397, y: 97, width: 6, height: 6)
  idle.pulse(cores: [world], fullScreen: true) { rect in
    CGRect(x: (rect.minX - camera.x) * zoom, y: (rect.minY - camera.y) * zoom,
           width: rect.width * zoom, height: rect.height * zoom)
  }
  let sampleTime = ProcessInfo.processInfo.systemUptime
  let first = idle.explosionSamples(now: sampleTime)[0]
  camera = CGPoint(x: 180, y: 30)
  let moved = idle.explosionSamples(now: sampleTime)[0]
  try require(abs(first.x - moved.x - Float(80 * zoom / idle.bounds.width)) < 0.0001
    && abs(first.y - moved.y - Float(10 * zoom / idle.bounds.height)) < 0.0001,
    "A world blast followed the camera instead of its detonation point")
  zoom = 3
  let magnified = idle.explosionSamples(now: sampleTime)[0]
  try require(abs(magnified.x - Float((400 - camera.x) * zoom / idle.bounds.width)) < 0.0001
    && magnified.z == first.z && magnified.w == first.w,
    "Zoom moved the blast origin or restarted its age/exposure")
  camera.x = 2000
  try require(idle.explosionSamples(now: sampleTime)[0].x < 0,
    "An offscreen blast was clamped to the viewport")
  camera.x = 100
  idle.frame.size = CGSize(width: 800, height: 600)
  try require(abs(idle.explosionSamples(now: sampleTime)[0].x - Float(300 * zoom / 800)) < 0.0001,
    "Resize retained the old normalized screen position")
  idle.clear()
  try require(idle.explosionSamples(now: sampleTime).isEmpty, "Clearing retained world anchors")
  print("PASS world-anchored explosions across camera pan, zoom, resize and offscreen travel")
  let flashes = [ExplosionFlash(rect:CGRect(x:1,y:1,width:2,height:2),strength:1,expiresAt:20),
                 ExplosionFlash(rect:CGRect(x:5,y:5,width:1,height:1),strength:0.5,expiresAt:20)]
  let combined = ExplosionHDR.textureMask(width: 8, height: 8, flashes: flashes, now: 10)
  let expected = zip(ExplosionHDR.mask(width: 8, height: 8, flashes: flashes, now: 10),
    ExplosionHDR.mask(width: 8, height: 8, flashes: flashes, now: 10, tint: .green)).flatMap { [$0, $1] }
  try require(combined == expected, "Interleaved HDR mask changed its channels")
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

  func render<T>(code: String, vertex: String, fragment: String, textures: [MTLTexture], uniforms: T,
                 width: Int = 8, height: Int = 8, bursts: [SIMD4<Float>] = [],
                 encode: ((MTLRenderCommandEncoder) -> Void)? = nil) throws -> [Float] {
    let library = try gpu.makeLibrary(source:code,options:nil)
    let p = MTLRenderPipelineDescriptor()
    p.vertexFunction = library.makeFunction(name:vertex)
    p.fragmentFunction = library.makeFunction(name:fragment)
    p.colorAttachments[0].pixelFormat = .rgba16Float
    let pipeline = try gpu.makeRenderPipelineState(descriptor:p)
    let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:width,height:height,mipmapped:false)
    d.usage = [.renderTarget,.shaderRead]; d.storageMode = .private
    let output = gpu.makeTexture(descriptor:d)!, command = queue.makeCommandBuffer()!
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = output
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
    let encoder = command.makeRenderCommandEncoder(descriptor:pass)!
    encoder.setRenderPipelineState(pipeline)
    for (i,t) in textures.enumerated() { encoder.setFragmentTexture(t,index:i) }
    var u = uniforms
    withUnsafeBytes(of:&u) { encoder.setFragmentBytes($0.baseAddress!,length:$0.count,index:0) }
    if !bursts.isEmpty {
      bursts.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!,length:$0.count,index:1) }
    }
    if let encode { encode(encoder) }
    else { encoder.drawPrimitives(type:.triangleStrip,vertexStart:0,vertexCount:4) }
    encoder.endEncoding()
    let rowBytes = ((width*8+255)/256)*256
    let buffer = gpu.makeBuffer(length:rowBytes*height,options:.storageModeShared)!
    let blit = command.makeBlitCommandEncoder()!
    blit.copy(from:output,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),
      sourceSize:MTLSize(width:width,height:height,depth:1),to:buffer,destinationOffset:0,destinationBytesPerRow:rowBytes,destinationBytesPerImage:rowBytes*height)
    blit.endEncoding(); command.commit(); command.waitUntilCompleted()
    try require(command.status == .completed, "GPU render failed: \(String(describing:command.error))")
    let words = buffer.contents().bindMemory(to:UInt16.self,capacity:rowBytes*height/2)
    return (0..<height).flatMap { y in (0..<width*4).map { x in Float(Float16(bitPattern:words[y*rowBytes/2+x])) } }
  }
  // An asymmetric sprite catches inverted rows and mirrored-mask regressions.
  let silhouette: [UInt8] = [1,1,1, 1,0,0, 1,0,0, 1,1,0]
  let spriteBytes = silhouette.flatMap { [UInt8(0), UInt8(255), UInt8(0), $0 * 255] }
  let sprite = CGImage(width: 3, height: 4, bitsPerComponent: 8, bitsPerPixel: 32,
    bytesPerRow: 12, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
    provider: CGDataProvider(data: Data(spriteBytes) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
  let selectionMask = LemmingSelectionRenderer.mask(sprite)!
  let selectionDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg8Unorm,
    width: selectionMask.width, height: selectionMask.height, mipmapped: false)
  let selectionTexture = gpu.makeTexture(descriptor: selectionDescriptor)!
  selectionMask.bytes.withUnsafeBytes {
    selectionTexture.replace(region: MTLRegionMake2D(0, 0, selectionMask.width, selectionMask.height),
      mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: selectionMask.width * 2)
  }
  func selection(_ effect: LemmingSelectionEffect, backing: Int = 1, curved: Bool = false) throws -> [Float] {
    var u = LemmingSelectionUniforms(effect, sourceSize: CGSize(width: 64, height: 64),
      outputSize: CGSize(width: 64 * backing, height: 64 * backing))
    if curved { u.glass = SIMD4(3, 4, 0, 0) }
    return try render(code: LemmingSelectionRenderer.shader, vertex: "selection_vertex", fragment: "selection_fragment",
      textures: [selectionTexture], uniforms: u, width: 64 * backing, height: 64 * backing)
  }
  var effect = LemmingSelectionEffect(sprite: sprite, rect: CGRect(x: 16, y: 16, width: 12, height: 16),
    clipRect: CGRect(x: 0, y: 0, width: 64, height: 64), bloom: false)
  for backing in [1, 2] { for zoom: CGFloat in [1, 2, 4, 6.5] { for mirrored in [false, true] { for curved in [false, true] {
    effect.rect = CGRect(x: 16, y: 16, width: 3 * zoom, height: 4 * zoom * 1.2)
    effect.mirrored = mirrored
    let pixels = try selection(effect, backing: backing, curved: curved)
    let size = 64 * backing
    func occupied(_ x: Int, _ y: Int) -> Bool {
      var sx = CGFloat(x) + 0.5, sy = CGFloat(y) + 0.5
      if curved {
        let cx = sx / CGFloat(size) * 2 - 1, cy = sy / CGFloat(size) * 2 - 1
        sx = ((cx + cx * pow(abs(cy) / 3, 2)) * 0.5 + 0.5) * CGFloat(size)
        sy = ((cy + cy * pow(abs(cx) / 4, 2)) * 0.5 + 0.5) * CGFloat(size)
      }
      var localX = (sx / CGFloat(backing) - effect.rect.minX) / effect.rect.width
      if mirrored { localX = 1 - localX }
      let ix = Int(floor(localX * 3))
      let iy = Int(floor((sy / CGFloat(backing) - effect.rect.minY) / effect.rect.height * 4))
      return (0..<3).contains(ix) && (0..<4).contains(iy) && silhouette[iy * 3 + ix] == 1
    }
    for y in 0..<size { for x in 0..<size {
      let outlined = !occupied(x, y) && (-2...2).contains { dy in (-2...2).contains { dx in occupied(x + dx, y + dy) } }
      let index = (y * size + x) * 4
      try require((pixels[index + 3] > 0.5) == outlined,
        "Selection outline escaped two physical pixels at zoom \(zoom), backing \(backing), mirror \(mirrored), CRT \(curved), pixel \(x),\(y)")
      if outlined {
        try require(pixels[index] == 1 && pixels[index] == pixels[index + 1] && pixels[index] == pixels[index + 2],
          "Selection border lost neutral SDR white")
      }
    } }
  } } } }
  effect.rect = CGRect(x: 16, y: 16, width: 12, height: 16)
  effect.mirrored = false
  try require(try selection(effect).allSatisfy { $0 <= 1 }, "Selection exceeded SDR white")
  effect.bloom = true
  let selectionBloom = try selection(effect)
  let near = (24 * 64 + 13) * 4
  try require(selectionBloom[near + 1] > selectionBloom[near] && selectionBloom[near + 1] > selectionBloom[near + 2]
    && selectionBloom[near + 1] >= 0.20 && selectionBloom[near + 3] < 0.65,
    "Selection bloom must remain visible in SDR outside the two-pixel border")
  try require(selectionBloom[(24 * 64 + 17) * 4 + 3] == 0 && selectionBloom[(63 * 64 + 63) * 4 + 3] == 0,
    "Selection bloom changed the sprite interior or distant terrain")

  // Use the production encoder as well as the full-screen reference shader.
  // A bad curved scissor would pass shader-only tests but cut off the highlight.
  let renderer = try LemmingSelectionRenderer(device: gpu)
  for x: CGFloat in [-4, 0, 16, 44, 60] { for y: CGFloat in [0, 20, 52] {
    effect.rect = CGRect(x: x, y: y, width: 12, height: 16)
    let size = CGSize(width: 128, height: 128)
    let encoded = try render(code: LemmingSelectionRenderer.shader, vertex: "selection_vertex", fragment: "selection_fragment",
      textures: [], uniforms: Float(0), width: 128, height: 128, encode: { encoder in
        renderer.encode(effect, sourceSize: CGSize(width: 64, height: 64), outputSize: size,
          glass: SIMD4(3, 4, 0, 0), into: encoder)
      })
    let reference = try selection(effect, backing: 2, curved: true)
    try require(encoded == reference, "Curved selection scissor cut off the outline or glow at \(x),\(y), index \(zip(encoded, reference).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset ?? -1)")
  } }
  // Exercise the flat-mode renderer used on screen, including sprite holes,
  // fractional zoom, mirroring, Retina, clipping and animation-frame reuse.
  func raster(_ effect: LemmingSelectionEffect, backing: Int = 1) -> [UInt8] {
    let size = 64 * backing
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
      bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: CGFloat(backing), y: -CGFloat(backing))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    LemmingSelectionRenderer.draw(effect)
    NSGraphicsContext.restoreGraphicsState()
    return Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: size * size * 4))
  }
  effect.bloom = false
  for backing in [1, 2] { for zoom: CGFloat in [1, 2, 4, 6.5] { for mirrored in [false, true] {
    effect.rect = CGRect(x: 16, y: 16, width: 3 * zoom, height: 4 * zoom * 1.2)
    effect.mirrored = mirrored
    let flat = raster(effect, backing: backing)
    let metal = try selection(effect, backing: backing)
    for index in stride(from: 0, to: flat.count, by: 4) {
      try require((flat[index + 3] > 127) == (metal[index + 3] > 0.5),
        "Flat and CRT outlines differ at zoom \(zoom), backing \(backing), mirror \(mirrored), pixel \(index / 4)")
    }
  } } }
  effect.rect = CGRect(x: 16, y: 16, width: 12, height: 16)
  effect.mirrored = false; effect.bloom = true
  let flatBloom = raster(effect)
  try require(flatBloom[near + 1] > flatBloom[near] && flatBloom[near + 1] >= 50,
    "Flat selection lost its green bloom")
  try require(flatBloom[(24 * 64 + 17) * 4 + 3] == 0, "Flat selection tinted the sprite interior")
  effect.time = 0
  let low = raster(effect), lowCRT = try selection(effect)
  effect.time = 1.4
  let peak = raster(effect), peakCRT = try selection(effect)
  try require(low[near + 1] >= 40 && peak[near + 1] > low[near + 1] + 12,
    "The halo must stay visible at its low point and breathe in flat output")
  try require(lowCRT[near + 1] >= 0.16 && peakCRT[near + 1] > lowCRT[near + 1] * 1.3,
    "The halo must stay visible at its low point and breathe in CRT output")
  let rim = (24 * 64 + 15) * 4
  try require(low[rim] == 255 && peak[rim] == 255, "The pulse dimmed the targeting outline")
  effect.time = 2.8
  try require(raster(effect) == low, "Halo animation did not repeat after 2.8 seconds")
  effect.time = nil
  let steady = raster(effect)
  try require(steady == raster(effect) && steady[near + 1] > low[near + 1] && steady[near + 1] < peak[near + 1],
    "Reduced effects must hold a visible midpoint")
  effect.clipRect = CGRect(x: 20, y: 20, width: 10, height: 10)
  let cropped = raster(effect)
  for y in 0..<64 { for x in 0..<64 where !effect.clipRect.contains(CGPoint(x: x, y: y)) {
    try require(cropped[(y * 64 + x) * 4 + 3] == 0, "Selection escaped its playfield clip")
  } }
  let cached = LemmingSelectionRenderer.mask(sprite)!
  try require(cached.bytes.withUnsafeBufferPointer { $0.baseAddress } == selectionMask.bytes.withUnsafeBufferPointer { $0.baseAddress },
    "A repeated animation frame rebuilt its selection mask")
  effect.clipRect = CGRect(x: 0, y: 0, width: 64, height: 64)
  let start = ProcessInfo.processInfo.systemUptime
  for _ in 0..<240 { _ = raster(effect, backing: 2) }
  print(String(format: "Selection raster benchmark: %.3f ms/frame (includes bitmap allocation and readback)",
    (ProcessInfo.processInfo.systemUptime - start) * 1000 / 240))
  for _ in 0..<140 {
    let copy = CGImage(width: 3, height: 4, bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: 12, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: CGDataProvider(data: Data(spriteBytes) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    _ = LemmingSelectionRenderer.mask(copy)
  }
  try require(LemmingSelectionRenderer.cachedFrameCount == LemmingSelectionRenderer.cacheLimit, "Selection cache is unbounded")
  try require(!idle.hasAllocatedFlashMask && idle.layer?.isHidden == true,
    "Drawing selection woke the full-window HDR surface")
  try require(idle.hitTest(CGPoint(x: 20, y: 20)) == nil, "Effects overlay intercepted gameplay input")
  print("PASS cached flat/CRT outlines, visible breathing halo, Retina, fractional zoom, mirror, clipping and idle HDR")

  let hdr = try render(code:ExplosionHDR.shader,vertex:"flash_vertex",fragment:"flash_fragment",textures:[maskTexture],uniforms:Float(8))
  let sdr = try render(code:ExplosionHDR.shader,vertex:"flash_vertex",fragment:"flash_fragment",textures:[maskTexture],uniforms:Float(1))
  try require(hdr[(1*8+1)*4] == 8 && hdr[0] == 0 && hdr[3] == 0, "overlay lost HDR values or changed its transparent background")
  try require(sdr.allSatisfy {$0 == 0}, "overlay altered the SDR fallback")
  try require(abs(hdr[(5*8+5)*4]-4.5)<0.02 && hdr[(5*8+5)*4+2] == 0, "second flash tick lost its warm, lower peak")

  let wideMask = ExplosionHDR.mask(width:8,height:8,flashes:[.init(rect:CGRect(x:0,y:0,width:8,height:8),strength:0.22,expiresAt:20)],now:10)
  let wide = try render(code:ExplosionHDR.shader,vertex:"flash_vertex",fragment:"flash_fragment",
    textures:[texture(.r8Unorm,bytes:wideMask,row:8)],uniforms:Float(8))
  try require(wide[0] > 1 && wide[3] > 0.20 && wide[3] < 0.25, "Whole-screen pulse lost its HDR light or transparency")
  try require(wide[(7*8+7)*4] == wide[0], "Whole-screen flash did not reach the margins")
  var u = CRTUniforms()
  u.sourceSize = .init(8,8); u.outputSize = .init(8,8); u.hdrHeadroom = 8
  let crt = try render(code:CRTShaders.source,vertex:"crt_vertex",fragment:"crt_composite",textures:[source,black,maskTexture],uniforms:u)
  u.hdrHeadroom = 1
  let crtSDR = try render(code:CRTShaders.source,vertex:"crt_vertex",fragment:"crt_composite",textures:[source,black,maskTexture],uniforms:u)
  try require(crt[(1*8+1)*4] == 8, "CRT output clipped the HDR flash")
  try require(crtSDR.allSatisfy {$0 >= 0 && $0 <= 1}, "SDR CRT output exceeds SDR range")
  for i in 0..<64 where mask[i] == 0 {
    for c in 0..<4 { try require(crt[i*4+c] == crtSDR[i*4+c], "HDR changed the terrain or UI") }
  }

  let greenMask = ExplosionHDR.textureMask(width: 8, height: 8, flashes: [
    .init(rect: CGRect(x: 1, y: 1, width: 2, height: 2), strength: 1, expiresAt: 20, tint: .green)], now: 10)
  let greenTexture = texture(.rg8Unorm, bytes: greenMask, row: 16)
  let greenHDR = try render(code: ExplosionHDR.shader, vertex: "flash_vertex", fragment: "flash_fragment", textures: [greenTexture], uniforms: Float(8))
  u.hdrHeadroom = 8
  let greenCRT = try render(code: CRTShaders.source, vertex: "crt_vertex", fragment: "crt_composite", textures: [source, black, greenTexture], uniforms: u)
  let greenIndex = (1 * 8 + 1) * 4
  for image in [greenHDR, greenCRT] {
    try require(image[greenIndex + 1] == 8 && image[greenIndex] < 2 && image[greenIndex + 2] < 2,
      "Assignment pulse lost green HDR colour in flat or CRT output")
  }
  try require(greenHDR[3] == 0, "Assignment pulse changed pixels outside the reticle")

  // Regressions for the enabled effect doing nothing on an SDR display.
  func nuclear(age: Float, headroom: Float = 1, centre: SIMD2<Float> = .init(0.5,0.55),
               exposure: Float = 1, width: Int = 256, height: Int = 144) throws -> [Float] {
    try render(code:ExplosionHDR.shader,vertex:"flash_vertex",fragment:"nuclear_fragment",textures:[],
      uniforms:NuclearExplosionUniforms(size:.init(Float(width),Float(height)),headroom:headroom,count:1),
      width:width,height:height,bursts:[SIMD4(centre.x,centre.y,age,exposure)])
  }
  let initial = try nuclear(age:0)
  try require(initial[0] > 0.9 && initial[3] > 0.9, "SDR nuclear flash is invisible at the screen margins")
  let bloom = try nuclear(age:0.16)
  try require(bloom[3] > 0.7, "the fireball exposure did not bloom after the initial flash")
  let fireball = try nuclear(age:0.45)
  let glow = try nuclear(age:0.95)
  let hdrBlast = try nuclear(age:0.16,headroom:8)
  try require(hdrBlast.max()! > 5, "nuclear flash did not use available HDR brightness")
  try require(fireball[3] < 0.02 && glow[3] < 0.01, "the screen wash hides the game after the flash")
  try require(fireball != glow, "fireball and smoke are static")
  try require(try nuclear(age:1.8).allSatisfy { $0 == 0 }, "finished blast left pixels lit")
  let local = try nuclear(age:0.45,centre:.init(0.25,0.3),exposure:0)
  func alphaNear(_ pixels: [Float], x: Int, y: Int) -> Float {
    pixels[(y*256+x)*4+3]
  }
  try require(alphaNear(local,x:64,y:38) > 0.5 && alphaNear(local,x:192,y:100) < 0.01,
    "fireball did not follow its explosion origin")
  // The expanding pressure front must be visible outside the fireball.
  let wave = try nuclear(age:0.3,exposure:0)
  try require(alphaNear(wave,x:153,y:79) > alphaNear(wave,x:166,y:79)+0.08,
    "pressure ring did not expand beyond the fireball")
  for pixels in [initial,bloom,fireball,glow,local,wave] {
    for i in stride(from:0,to:pixels.count,by:4) {
      try require(pixels[i+3].isFinite && (0...1).contains(pixels[i+3]), "invalid blast opacity")
      for c in 0..<3 {
        try require(pixels[i+c].isFinite && pixels[i+c] >= 0 && pixels[i+c] <= pixels[i+3]+0.002,
          "SDR blast has invalid premultiplied colour")
      }
    }
  }
  var timeline = NuclearExplosionTimeline()
  timeline.trigger(centres:Array(repeating:SIMD2(0.5,0.5),count:100),now:10)
  try require(timeline.bursts.count <= 8 && timeline.bursts.filter(\.exposure).count == 1,
    "simultaneous nuke bursts repeated the screen exposure or exceeded the GPU limit")
  timeline.trigger(centres:[SIMD2(0.3,0.4)],now:10.3)
  try require(timeline.bursts.filter(\.exposure).count == 1, "nuke restarted the screen flash too quickly")
  timeline.expire(now:12.2)
  try require(timeline.samples(now:12.2).isEmpty, "paused or fast-forwarded blast did not expire by wall clock")
  timeline.clear()
  timeline.trigger(centres:[SIMD2(0.5,0.5)],now:12.3)
  try require(timeline.bursts.first?.exposure == true, "new level retained the old exposure cooldown")
  timeline.clear()
  try require(timeline.samples(now:12.3).isEmpty, "turning off explosions retained an active blast")

  let tube = CRTView(frame:CGRect(x:0,y:0,width:1024,height:576))
  let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:320,pixelsHigh:200,bitsPerSample:8,
    samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:1280,bitsPerPixel:32)!
  tube.setSource(bitmap.cgImage!)
  for sourcePoint in [CGPoint(x:160,y:80),CGPoint(x:25,y:30),CGPoint(x:295,y:155)] {
    let screenPoint = tube.viewPoint(fromSource:sourcePoint)!
    let roundTrip = tube.sourcePoint(from:screenPoint)!
    try require(abs(roundTrip.x-sourcePoint.x)<0.01 && abs(roundTrip.y-sourcePoint.y)<0.01,
      "CRT curvature misplaced the explosion")
  }
  tube.settings.curvature = 3
  for x in [CGFloat(0), tube.bounds.maxX] {
    let point = CGPoint(x: x, y: tube.bounds.height * 0.6)
    try require(tube.sourcePoint(from: point) == nil, "The curved border should not accept clicks")
    let edge = tube.sourcePoint(from: point, clampingToImage: true)!
    try require(edge.x >= 0 && edge.x < 320 && edge.y >= 0 && edge.y < 160,
      "CRT border lost the edge-scrolling sample")
  }
  func superSpeed(age: Float, headroom: Float = 1, intensity: Float = 1, multiplier: Float = 3, motionTime: Float? = nil,
                  width: Int = 256, height: Int = 144) throws -> [Float] {
    try render(code:ExplosionHDR.shader,vertex:"flash_vertex",fragment:"speed_fragment",textures:[],
      uniforms:SuperSpeedUniforms(field:.init(0,0,Float(width),Float(height)*0.8),
        animation:.init(age,intensity,max(0,1-age/0.65),headroom),size:.init(Float(width),Float(height)),
        motion:.init(motionTime ?? age,multiplier,0,motionTime == nil ? 0 : 1)),
      width:width,height:height)
  }
  let boost = try superSpeed(age:0.25)
  let cruising = try superSpeed(age:2)
  let cruisingNext = try superSpeed(age:2.1)
  let speedHDR = try superSpeed(age:2,headroom:8)
  try require(cruising.max()! > 0.2 && cruising != cruisingNext, "3x speed has no visible, moving streaks")
  try require(boost != cruising, "3x engagement did not produce an energy burst")
  try require(speedHDR.max()! > 1, "speed highlights did not use HDR brightness")
  for pixels in [boost,cruising,cruisingNext] {
    for y in 0..<144 { for x in 0..<256 {
      let index = (y*256+x)*4
      try require(pixels[index+3] <= 0.621, "speed effects obscure the game")
      if y >= 116 { try require(pixels[index+3] == 0, "speed effects cover the controls") }
      for c in 0..<3 {
        try require(pixels[index+c].isFinite && pixels[index+c] >= 0 && pixels[index+c] <= pixels[index+3]+0.002,
          "speed effects produced invalid SDR colour")
      }
    } }
  }
  try require(cruising[(57*256+128)*4+3] < 0.01, "speed streaks obscured the centre of the playfield")
  try require(try superSpeed(age:2,intensity:0).allSatisfy { $0 == 0 }, "normal speed still draws energy")
  var previousAlpha: Float = 0
  for multiplier: Float in [2, 3, 5, 10] {
    let pixels = try superSpeed(age: 2, intensity: min(1.5, sqrt((multiplier-1)/2)), multiplier: multiplier, motionTime: 2)
    let alpha = stride(from: 3, to: pixels.count, by: 4).reduce(Float(0)) { $0 + pixels[$1] }
    try require(alpha > previousAlpha, "The GPU did not increase the effect across speed tiers")
    try require(pixels[(57*256+128)*4+3] < 0.01, "A faster tier obscured the centre")
    previousAlpha = alpha
  }
  var speedClock = SuperSpeedTimeline()
  var tiers = SuperSpeedTimeline()
  tiers.setEnabled(true, now: 0, multiplier: 2)
  var lastIntensity = tiers.intensity(now: 1)
  for (time, multiplier) in [(1.0, 3.0), (2, 5), (3, 10)] {
    tiers.setEnabled(true, now: time, multiplier: multiplier)
    try require(abs(tiers.intensity(now: time) - lastIntensity) < 0.0001, "A tier change jumped in brightness")
    try require(tiers.sample(now: time, headroom: 1).z == 0, "A tier change restarted the engagement burst")
    let settled = tiers.intensity(now: time + 0.25)
    try require(settled > lastIntensity, "A faster tier did not strengthen the effect")
    lastIntensity = settled
  }
  tiers.setEnabled(true, now: 4, multiplier: 2)
  try require(abs(tiers.intensity(now: 4) - lastIntensity) < 0.0001, "Slowing down jumped in brightness")
  try require(tiers.intensity(now: 4.25) < lastIntensity, "Slowing down did not soften the effect")
  speedClock.setEnabled(true,now:20)
  try require(speedClock.sample(now:20.25,headroom:1).y == 1, "super speed did not reach full strength")
  speedClock.setEnabled(true,now:22)
  try require(speedClock.sample(now:22,headroom:1).x == 2 && speedClock.sample(now:22,headroom:1).z == 0,
    "a repeated speed update restarted the engagement burst")
  speedClock.setEnabled(false,now:22,immediate:true)
  try require(!speedClock.isAnimating(now:22), "pausing retained speed animation")
  speedClock.setEnabled(true,now:23)
  try require(speedClock.sample(now:23.1,headroom:1).z > 0, "resuming speed did not re-engage")

  func savePreview(_ pixels: [Float], to url: URL) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:960,pixelsHigh:540,bitsPerSample:8,
      samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,
      bitmapFormat:.alphaNonpremultiplied,bytesPerRow:960*4,bitsPerPixel:32)!
    for i in stride(from:0,to:pixels.count,by:4) {
      let alpha = pixels[i+3]
      for c in 0..<3 {
        let linear = alpha > 0 ? pixels[i+c]/alpha : 0
        let srgb = linear <= 0.0031308 ? linear*12.92 : 1.055*pow(linear,1/2.4)-0.055
        bitmap.bitmapData![i+c] = UInt8((min(1,max(0,srgb))*255).rounded())
      }
      bitmap.bitmapData![i+3] = UInt8((alpha*255).rounded())
    }
    try bitmap.representation(using:.png,properties:[:])!.write(to:url)
  }
  if let option = CommandLine.arguments.firstIndex(of:"--speed-preview"), option+1 < CommandLine.arguments.count {
    let directory = URL(fileURLWithPath:CommandLine.arguments[option+1])
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    for (index,age) in [Float(0.12),0.25,0.4,1.1,2,2.1].enumerated() {
      try savePreview(superSpeed(age:age,width:960,height:540),to:directory.appendingPathComponent("speed-\(index).png"))
    }
  }
  if let option = CommandLine.arguments.firstIndex(of:"--preview"), option+1 < CommandLine.arguments.count {
    let directory = URL(fileURLWithPath:CommandLine.arguments[option+1])
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    for (index,age) in [Float(0),0.08,0.16,0.3,0.45,0.7,1,1.4,1.79].enumerated() {
      let pixels = try nuclear(age:age,width:960,height:540)
      try savePreview(pixels,to:directory.appendingPathComponent("blast-\(index).png"))
    }
  }
  for screen in NSScreen.screens {
    print("Display \(screen.localizedName): current EDR \(screen.maximumExtendedDynamicRangeColorComponentValue), potential \(screen.maximumPotentialExtendedDynamicRangeColorComponentValue)")
  }
  print("PASS actual FP16 GPU output: 8x HDR core, warm second tick, unchanged SDR/background, bounded headroom and expiry")
  print("PASS cinematic nuclear blast: visible SDR exposure, HDR peak, animated fireball, pressure ring, origin, expiry and nuke limits")
  print("PASS superheroic speed: animated SDR/HDR streaks, engagement, clear centre and controls, pause and resume")
}
do { try run() } catch { print("FAIL: \(error)"); exit(1) }
