import AppKit
import Metal
import QuartzCore

struct ExplosionFlash: Equatable {
  let rect: CGRect
  let strength: Float
  let expiresAt: TimeInterval
  init(rect: CGRect, strength: Float, expiresAt: TimeInterval = .infinity) {
    self.rect = rect; self.strength = strength; self.expiresAt = expiresAt
  }
}

enum ExplosionHDR {
  /// EDR is relative to SDR white. Never ask for more than the screen can show.
  static func headroom(_ available: CGFloat) -> Float {
    available.isFinite ? Float(min(4, max(1, available))) : 1
  }

  static func mask(width: Int, height: Int, flashes: [ExplosionFlash], now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> [UInt8] {
    guard width > 0, height > 0 else { return [] }
    var bytes = [UInt8](repeating: 0, count: width*height)
    for flash in flashes where flash.expiresAt > now && flash.strength.isFinite && flash.strength > 0 && !flash.rect.isInfinite && !flash.rect.isNull {
      guard flash.rect.minX.isFinite, flash.rect.minY.isFinite, flash.rect.maxX.isFinite, flash.rect.maxY.isFinite else { continue }
      let rect = flash.rect.intersection(CGRect(x:0,y:0,width:width,height:height))
      guard !rect.isEmpty else { continue }
      let x0 = max(0,Int(floor(rect.minX))), x1 = min(width,Int(ceil(rect.maxX)))
      let y0 = max(0,Int(floor(rect.minY))), y1 = min(height,Int(ceil(rect.maxY)))
      let value = UInt8((min(1,flash.strength)*255).rounded())
      for y in y0..<y1 { for x in x0..<x1 { bytes[y*width+x] = max(bytes[y*width+x],value) } }
    }
    return bytes
  }

  static let shader = """
  #include <metal_stdlib>
  using namespace metal;
  struct Vertex { float4 position [[position]]; float2 uv; };
  vertex Vertex flash_vertex(uint id [[vertex_id]]) {
    float2 p[4] = {float2(-1,-1),float2(1,-1),float2(-1,1),float2(1,1)};
    return {float4(p[id],0,1),float2(p[id].x*.5+.5,.5-p[id].y*.5)};
  }
  fragment float4 flash_fragment(Vertex v [[stage_in]], texture2d<float> mask [[texture(0)]],
                                  constant float &headroom [[buffer(0)]]) {
    constexpr sampler s(filter::nearest,address::clamp_to_zero);
    float strength = mask.sample(s,v.uv).r;
    if (strength <= 0 || headroom <= 1) return float4(0);
    float3 tint = strength > .75 ? float3(1) : float3(1,1,0);
    return float4(tint * (1 + (headroom-1)*strength),1);
  }
  """
}

/// A transparent EDR surface over the SDR playfield. It never intercepts input.
@MainActor final class ExplosionHDRView: NSView {
  private let gpu = MTLCreateSystemDefaultDevice()
  private var queue: MTLCommandQueue?
  private var pipeline: MTLRenderPipelineState?
  private var surface: CAMetalLayer?
  private var texture: MTLTexture?
  private var flashes: [ExplosionFlash] = []
  private var expiration: Task<Void,Never>?

  override init(frame: NSRect) {
    super.init(frame: frame)
    guard let gpu else { return }
    queue = gpu.makeCommandQueue()
    let layer = CAMetalLayer()
    layer.device = gpu
    layer.pixelFormat = .rgba16Float
    layer.colorspace = CGColorSpace(name:CGColorSpace.extendedLinearSRGB)
    layer.wantsExtendedDynamicRangeContent = true
    layer.isOpaque = false
    layer.backgroundColor = NSColor.clear.cgColor
    self.layer = layer
    wantsLayer = true
    surface = layer
    do {
      let library = try gpu.makeLibrary(source:ExplosionHDR.shader,options:nil)
      let descriptor = MTLRenderPipelineDescriptor()
      descriptor.vertexFunction = library.makeFunction(name:"flash_vertex")
      descriptor.fragmentFunction = library.makeFunction(name:"flash_fragment")
      descriptor.colorAttachments[0].pixelFormat = .rgba16Float
      pipeline = try gpu.makeRenderPipelineState(descriptor:descriptor)
    } catch { surface?.wantsExtendedDynamicRangeContent = false }
    NotificationCenter.default.addObserver(self,selector:#selector(displayChanged),name:NSWindow.didChangeScreenNotification,object:nil)
    NotificationCenter.default.addObserver(self,selector:#selector(displayChanged),name:NSApplication.didChangeScreenParametersNotification,object:nil)
    NotificationCenter.default.addObserver(self,selector:#selector(displayChanged),name:NSWindow.didDeminiaturizeNotification,object:nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  deinit {
    expiration?.cancel()
    NotificationCenter.default.removeObserver(self)
  }
  @objc private func displayChanged() { render() }
  override var isFlipped: Bool { true }
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); render() }
  override func layout() { super.layout(); texture = nil; render() }

  func update(_ flashes: [ExplosionFlash], force: Bool = false) {
    let changed = flashes != self.flashes
    self.flashes = flashes
    if changed {
      scheduleExpiration()
    }
    if force || changed || !flashes.isEmpty || texture == nil { render() }
  }

  private func scheduleExpiration() {
    expiration?.cancel()
    let now = ProcessInfo.processInfo.systemUptime
    guard let end = flashes.map(\.expiresAt).filter({$0.isFinite && $0 > now}).min() else { return }
    expiration = Task { @MainActor [weak self] in
      do { try await Task.sleep(for:.seconds(end-now)) } catch { return }
      self?.render()
      self?.scheduleExpiration()
    }
  }

  private func render() {
    guard let gpu, let queue, let pipeline, let surface, let screen = window?.screen,
          bounds.width > 0, bounds.height > 0, !isHidden else { return }
    // Opt in while idle, so the display has headroom ready for the short pop.
    surface.wantsExtendedDynamicRangeContent = screen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1
    let scale = window?.backingScaleFactor ?? 1
    surface.contentsScale = scale
    surface.drawableSize = CGSize(width:bounds.width*scale,height:bounds.height*scale)
    let width = Int(ceil(bounds.width)), height = Int(ceil(bounds.height))
    // Keep each submitted mask immutable while the GPU is reading it.
    do {
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.r8Unorm,width:width,height:height,mipmapped:false)
      descriptor.usage = .shaderRead
      texture = gpu.makeTexture(descriptor:descriptor)
    }
    guard let texture, let drawable = surface.nextDrawable(), let command = queue.makeCommandBuffer() else { return }
    let mask = ExplosionHDR.mask(width:width,height:height,flashes:flashes)
    mask.withUnsafeBytes { bytes in
      texture.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,withBytes:bytes.baseAddress!,bytesPerRow:width)
    }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = drawable.texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,0)
    guard let encoder = command.makeRenderCommandEncoder(descriptor:pass) else { return }
    var headroom = ExplosionHDR.headroom(screen.maximumExtendedDynamicRangeColorComponentValue)
    encoder.setRenderPipelineState(pipeline)
    encoder.setFragmentTexture(texture,index:0)
    encoder.setFragmentBytes(&headroom,length:MemoryLayout<Float>.size,index:0)
    encoder.drawPrimitives(type:.triangleStrip,vertexStart:0,vertexCount:4)
    encoder.endEncoding()
    command.present(drawable)
    command.commit()
  }
}
