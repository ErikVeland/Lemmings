import AppKit
import Metal
import QuartzCore

struct ExplosionFlash: Equatable {
  let rect: CGRect
  let strength: Float
  enum Tint { case warm, green }
  let expiresAt: TimeInterval
  let tint: Tint
  init(rect: CGRect, strength: Float, expiresAt: TimeInterval = .infinity, tint: Tint = .warm) {
    self.rect = rect; self.strength = strength; self.expiresAt = expiresAt; self.tint = tint
  }
}

/// Wall-clock animation continues while game logic is paused or runs faster.
struct NuclearExplosionTimeline {
  static let duration: TimeInterval = 1.8
  static let maximumBursts = 8
  struct Burst {
    let centre: SIMD2<Float>
    let bornAt: TimeInterval
    let exposure: Bool
  }
  private(set) var bursts: [Burst] = []
  private var lastExposure: TimeInterval = -.infinity

  mutating func trigger(centres: [SIMD2<Float>], now: TimeInterval) {
    expire(now: now)
    for centre in centres where centre.x.isFinite && centre.y.isFinite
      && (0...1).contains(centre.x) && (0...1).contains(centre.y) {
      let exposure = now - lastExposure >= 0.9
      if exposure { lastExposure = now }
      // Keep the main exposure alive when many lemmings detonate together.
      if bursts.count == Self.maximumBursts {
        bursts.remove(at: bursts.firstIndex(where: { !$0.exposure }) ?? 0)
      }
      bursts.append(Burst(centre: centre, bornAt: now, exposure: exposure))
    }
  }

  mutating func expire(now: TimeInterval) {
    bursts.removeAll { now - $0.bornAt >= Self.duration || now < $0.bornAt }
  }

  mutating func clear() { bursts.removeAll(); lastExposure = -.infinity }

  func samples(now: TimeInterval) -> [SIMD4<Float>] {
    bursts.filter { now >= $0.bornAt && now - $0.bornAt < Self.duration }.map {
      SIMD4($0.centre.x, $0.centre.y, Float(now - $0.bornAt), $0.exposure ? 1 : 0)
    }
  }
}

/// Matches the Metal uniform layout. Burst samples use a separate buffer.
struct NuclearExplosionUniforms {
  var size: SIMD2<Float>
  var headroom: Float
  var count: UInt32
}

/// Tier changes blend without restarting the engagement burst.
struct SuperSpeedTimeline {
  private(set) var enabled = false
  private var startedAt: TimeInterval = 0
  private var changedAt: TimeInterval = 0
  private var transitionFrom: Float = 0
  private(set) var multiplier: Double = 3
  private var targetStrength: Float = 0

  mutating func setEnabled(_ enabled: Bool, now: TimeInterval, immediate: Bool = false, multiplier: Double = 3) {
    if immediate && !enabled { self = Self(); return }
    guard enabled != self.enabled || multiplier != self.multiplier else { return }
    let engaging = enabled && !self.enabled
    let currentIntensity = intensity(now: now)
    self.multiplier = multiplier
    targetStrength = enabled ? Float(min(1.5, sqrt(max(0, multiplier - 1) / 2))) : 0
    transitionFrom = currentIntensity
    changedAt = now
    if engaging { startedAt = now }
    self.enabled = enabled
  }

  func intensity(now: TimeInterval) -> Float {
    let progress = Float(min(1,max(0,(now-changedAt)/0.2)))
    let eased = progress*progress*(3-2*progress)
    return transitionFrom + (targetStrength-transitionFrom)*eased
  }

  func isAnimating(now: TimeInterval) -> Bool { enabled || intensity(now: now) > 0 }

  func sample(now: TimeInterval, headroom: Float) -> SIMD4<Float> {
    let age = Float(max(0,now-startedAt))
    let engagement = enabled ? max(0,1-age/0.65) : 0
    return SIMD4(age,intensity(now: now),engagement,headroom)
  }
}

struct SuperSpeedUniforms {
  var field: SIMD4<Float>
  var animation: SIMD4<Float>
  var size: SIMD2<Float>
  var padding = SIMD2<Float>.zero
  var motion = SIMD4<Float>(0, 3, 0, 0)
}

enum ExplosionHDR {
  /// A hot centre and orange shoulders keep the burst vivid on SDR screens too.
  @MainActor static func drawCore(at point: CGPoint, pixel: CGSize, phase: Int) {
    guard (0..<2).contains(phase), pixel.width > 0, pixel.height > 0 else { return }
    let x = floor(point.x / pixel.width) * pixel.width
    let y = floor(point.y / pixel.height) * pixel.height
    NSColor(calibratedRed: 1, green: 0.32, blue: 0.04, alpha: 1).setFill()
    CGRect(x: x - 5 * pixel.width, y: y - 2 * pixel.height, width: 10 * pixel.width, height: 4 * pixel.height).fill()
    CGRect(x: x - 2 * pixel.width, y: y - 5 * pixel.height, width: 4 * pixel.width, height: 10 * pixel.height).fill()
    (phase == 0 ? NSColor.white : NSColor.yellow).setFill()
    CGRect(x: x - 3 * pixel.width, y: y - pixel.height, width: 6 * pixel.width, height: 2 * pixel.height).fill()
    CGRect(x: x - pixel.width, y: y - 3 * pixel.height, width: 2 * pixel.width, height: 6 * pixel.height).fill()
  }

  /// EDR is relative to SDR white. Never ask for more than the screen can show.
  static func headroom(_ available: CGFloat) -> Float {
    available.isFinite ? Float(min(8, max(1, available))) : 1
  }

  static func mask(width: Int, height: Int, flashes: [ExplosionFlash], now: TimeInterval = ProcessInfo.processInfo.systemUptime, tint: ExplosionFlash.Tint = .warm) -> [UInt8] {
    guard width > 0, height > 0 else { return [] }
    var bytes = [UInt8](repeating: 0, count: width*height)
    for flash in flashes where flash.tint == tint && flash.expiresAt > now && flash.strength.isFinite && flash.strength > 0 && !flash.rect.isInfinite && !flash.rect.isNull {
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

  static func textureMask(width: Int, height: Int, flashes: [ExplosionFlash], now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> [UInt8] {
    let warm = mask(width: width, height: height, flashes: flashes, now: now)
    let green = mask(width: width, height: height, flashes: flashes, now: now, tint: .green)
    return zip(warm, green).flatMap { [$0, $1] }
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
    float2 pulse = mask.sample(s,v.uv).rg;
    float strength = pulse.r;
    if (pulse.g > 0 && headroom > 1) return float4(float3(.18,1,.18) * (1 + (headroom-1)*pulse.g),1);
    if (strength <= 0 || headroom <= 1) return float4(0);
    if (strength <= .25) {
      float alpha = strength;
      return float4(float3(1,.91,.65) * headroom * alpha, alpha);
    }
    float3 tint = strength > .75 ? float3(1) : float3(1,1,0);
    return float4(tint * (1 + (headroom-1)*strength),1);
  }

  struct NuclearUniforms { float2 size; float headroom; uint count; };
  float blast_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
  }
  float blast_noise(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f*f*(3-2*f);
    return mix(mix(blast_hash(i), blast_hash(i+float2(1,0)), f.x),
               mix(blast_hash(i+float2(0,1)), blast_hash(i+1), f.x), f.y);
  }
  float blast_fbm(float2 p) {
    float value = 0, weight = .55;
    for (int i=0; i<4; ++i) {
      value += weight * blast_noise(p);
      p = float2(p.x*.8-p.y*.6,p.x*.6+p.y*.8)*2.07+17.3;
      weight *= .48;
    }
    return value;
  }
  float4 blast_over(float4 front, float4 back) {
    return front + back * (1-front.a);
  }
  fragment float4 nuclear_fragment(Vertex v [[stage_in]],
    constant NuclearUniforms &u [[buffer(0)]], constant float4 *bursts [[buffer(1)]]) {
    float4 result = float4(0);
    float exposure = 0;
    float headroom = clamp(u.headroom, 1.0f, 8.0f);
    float2 aspect = u.size / max(1.0f, min(u.size.x,u.size.y));
    for (uint i=0; i<min(u.count,8u); ++i) {
      float4 burst = bursts[i];
      float t = burst.z;
      if (t < 0 || t >= 1.8) continue;
      float fade = 1-smoothstep(.95f,1.8f,t);
      float2 p = (v.uv-burst.xy)*aspect;
      float d = length(p);
      // The first flash collapses briefly before the fireball blooms again.
      float flash = .94*exp(-t*24) + .78*exp(-pow((t-.16)/.105,2.0f));
      exposure = max(exposure, burst.w*flash);
      float radius = .025 + .135*(1-exp(-t*5));
      float rise = .26*smoothstep(.16f,1.65f,t);
      float2 cloud = p + float2(0,rise);
      float n = .5, detail = .5;
      if (length(cloud) < radius*1.5 || (abs(p.x) < .07 && abs(p.y) < rise+.06)) {
        n = blast_fbm(cloud*38+float2(burst.x*23,-t*1.8));
        detail = blast_fbm(cloud*83+float2(t*1.4,burst.y*31));
      }
      float billow = smoothstep(.3f,1.3f,t);
      float capShape = length(cloud/float2(1+billow*.25,.82-billow*.26));
      float edge = radius*(.80+.37*n);
      float cap = 1-smoothstep(edge-.018,edge+.012,capShape);
      float column = (1-smoothstep(.014f,.048f,abs(p.x)+(n-.5)*.02))
        * smoothstep(-rise-.01f,-rise+.03f,p.y)
        * (1-smoothstep(.005f,.055f,p.y)) * smoothstep(.25f,.75f,t);
      float density = max(cap,column*.85);
      float heat = saturate(1-capShape/max(radius,.001f));
      heat = saturate(heat*.85+n*.65+detail*.18-t*.34);
      float3 fire = mix(float3(.18,.025,.009),float3(1,.16,.008),smoothstep(0.0f,.32f,heat));
      fire = mix(fire,float3(1,.72,.18),smoothstep(.25f,.65f,heat));
      fire = mix(fire,float3(1,.97,.84),smoothstep(.60f,.88f,heat));
      float smoke = smoothstep(.55f,1.5f,t)*(1-smoothstep(.12f,.55f,heat));
      fire = mix(fire,float3(.075,.06,.055)*( .7+n),smoke);
      float peak = 1+(headroom-1)*smoothstep(.4f,.9f,heat)*exp(-t*1.5);
      float alpha = density*fade*.94;
      float4 body = float4(fire*peak*alpha,alpha);

      // Broad scattered light, a thin pressure front and a ground-level dust ring.
      float halo = exp(-d*d/(radius*radius*3.8)) * exp(-t*2.7)*.5;
      float ringRadius = .015 + t*.53;
      float ring = exp(-pow((d-ringRadius)/(.005+t*.010),2.0f))*exp(-t*2.8)
        * smoothstep(.015f,.08f,t);
      float groundDistance = length(p/float2(1,.19));
      float dust = exp(-pow((groundDistance-t*.30)/(.012+t*.016),2.0f))
        * exp(-t*2)*smoothstep(.08f,.24f,t)*( .55+.45*n);
      float streak = exp(-abs(p.y)*350)*exp(-abs(p.x)*3.3)*exp(-t*9)*.65;
      float glowAlpha = saturate((halo+ring*.5+dust*.25+streak)*fade);
      float3 glow = (float3(1,.36,.06)*halo+float3(.8,.9,1)*ring*.5
        +float3(.56,.35,.16)*dust*.25+float3(1,.83,.53)*streak)*fade;
      float4 light = float4(glow*(1+(headroom-1)*exp(-t*6)),glowAlpha);
      result = blast_over(body,blast_over(light,result));
    }
    // Premultiplied output remains visible at SDR headroom, including the margins.
    float3 white = mix(float3(1,.97,.89),float3(1),saturate(exposure));
    result = blast_over(float4(white*headroom*exposure,exposure),result);
    result.a = saturate(result.a);
    result.rgb = clamp(result.rgb,float3(0),float3(headroom*result.a));
    return result;
  }
  struct SpeedUniforms { float4 field; float4 animation; float2 size; float2 padding; float4 motion; };
  fragment float4 speed_fragment(Vertex v [[stage_in]], constant SpeedUniforms &u [[buffer(0)]]) {
    if (u.animation.y <= 0 || any(u.field.zw <= 0)) return float4(0);
    float2 uv = (v.uv*u.size-u.field.xy)/u.field.zw;
    if (any(uv < 0) || any(uv > 1)) return float4(0);
    float2 p = (uv-.5)*u.field.zw/min(u.field.z,u.field.w);
    float r = length(p), t = u.motion.w > .5 ? u.motion.x : u.animation.x;
    float tier = clamp(u.motion.y,2.0f,10.0f);
    float edge = smoothstep(.28f,.92f,max(abs(uv.x-.5),abs(uv.y-.5))*2);
    float angle = atan2(p.y,p.x);
    float lane = (angle+M_PI_F)/(2*M_PI_F)*84;
    float id = floor(lane), seed = blast_hash(float2(id,4.7));
    float across = fract(lane)-(.25+.5*seed);
    float rayCore = exp(-pow(across/(.015+.016*seed),2.0f));
    float softThread = exp(-pow(across/.14,2.0f));
    float travel = fract(r*.8-t*(1.1+seed*.7)+seed*9);
    float dash = smoothstep(.1f,.5f,travel)*(1-smoothstep(.76f,.94f,travel));
    float streak = (rayCore*.66+softThread*.09)*dash*edge;
    float3 tint = seed > .72 ? float3(1,.58,.08) : mix(float3(.12,.68,1),float3(.65,.35,1),smoothstep(3.0f,10.0f,tier)*.6);
    float3 light = tint*streak;
    float alpha = streak;

    // Two irregular electrical filaments run along the outer frame.
    float jag = blast_noise(float2(uv.x*48,floor(t*8)))-.5;
    float cable = .06+.018*sin(uv.x*19-t*4)+jag*.008;
    float separation = min(abs(uv.y-cable),abs(1-uv.y-cable));
    float electric = exp(-pow(separation/.0016,2.0f));
    float electricGlow = exp(-pow(separation/.012,2.0f));
    float runner = pow(.5+.5*sin(uv.x*7-t*6),6.0f);
    float bolt = (electric*.28+electricGlow*.07)*runner;
    light += float3(.18,.8,1)*bolt;
    alpha += bolt;

    // A single expanding energy ring marks engagement, then clears the centre.
    float ignition = u.animation.z;
    float ring = exp(-pow((r-(.025+u.animation.x*1.9))/.016,2.0f))*ignition*.5;
    float glow = pow(edge,3.0f)*(.04+.008*sin(t*3));
    light += float3(.46,.9,1)*ring + float3(.04,.32,.65)*glow;
    alpha += ring+glow;
    float strength = u.animation.y;
    alpha = min(.62f,alpha)*strength;
    float peak = 1+(clamp(u.animation.w,1.0f,8.0f)-1)*.48;
    return float4(min(light*strength*peak,float3(alpha*peak)),alpha);
  }
  """
}

/// Shared cinematic explosion and speed effects. The surface never intercepts input.
@MainActor final class ExplosionHDRView: NSView {
  private let gpu = MTLCreateSystemDefaultDevice()
  private var queue: MTLCommandQueue?
  private var pipeline: MTLRenderPipelineState?
  private var nuclearPipeline: MTLRenderPipelineState?
  private var speedPipeline: MTLRenderPipelineState?
  private var surface: CAMetalLayer?
  private var texture: MTLTexture?
  private var flashes: [ExplosionFlash] = []
  private var expiration: Task<Void,Never>?
  private var timeline = NuclearExplosionTimeline()
  private var speed = SuperSpeedTimeline()
  private var speedMotionTime: TimeInterval = 0
  private var speedMotionLast: TimeInterval?
  private var speedField = CGRect.zero
  private var maskIsDirty = true
  var isSuperSpeedActive: Bool { speed.enabled }

  /// Each blast has a local fireball. A nuke shares the wider exposure bloom.
  func pulse(cores: [CGRect] = [], fullScreen: Bool) {
    let now = ProcessInfo.processInfo.systemUptime
    let visible = cores.filter { $0.intersects(bounds) }
    if fullScreen, bounds.width > 0, bounds.height > 0 {
      let centres = visible.map { SIMD2(Float($0.midX/bounds.width),Float($0.midY/bounds.height)) }
      timeline.trigger(centres: cores.isEmpty ? [SIMD2(0.5,0.45)] : centres, now: now)
    } else {
      for core in visible {
        flashes.append(.init(rect: core, strength: 1, expiresAt: now + 0.10))
      }
      maskIsDirty = true
    }
    render()
    scheduleExpiration()
  }

  func clearExplosions() {
    timeline.clear()
    flashes.removeAll()
    maskIsDirty = true
    render()
    scheduleExpiration()
  }

  func clear() {
    speed = SuperSpeedTimeline()
    speedMotionTime = 0; speedMotionLast = nil
    clearExplosions()
  }

  func setSuperSpeed(_ enabled: Bool, in field: CGRect, immediate: Bool = false, multiplier: Double = 3) {
    let now = ProcessInfo.processInfo.systemUptime
    let clipped = field.intersection(bounds)
    let wanted = enabled && !clipped.isNull && !clipped.isEmpty
    let changed = wanted != speed.enabled || clipped != speedField || (wanted && multiplier != speed.multiplier)
      || (immediate && !wanted && speed.isAnimating(now: now))
    guard changed else { return }
    speedField = clipped.isNull ? .zero : clipped
    advanceSpeedMotion(at: now)
    if wanted && !speed.enabled { speedMotionTime = 0; speedMotionLast = now }
    speed.setEnabled(wanted,now:now,immediate:immediate,multiplier:multiplier)
    render()
    scheduleExpiration()
  }

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
      descriptor.fragmentFunction = library.makeFunction(name:"nuclear_fragment")
      descriptor.colorAttachments[0].isBlendingEnabled = true
      descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
      descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
      descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
      descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
      nuclearPipeline = try gpu.makeRenderPipelineState(descriptor:descriptor)
      descriptor.fragmentFunction = library.makeFunction(name:"speed_fragment")
      speedPipeline = try gpu.makeRenderPipelineState(descriptor:descriptor)
    } catch {
      // AppKit still draws a visible blast if Metal compilation fails.
      self.layer = CALayer(); surface = nil; pipeline = nil
    }
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
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window == nil { clear() } else { render() }
  }
  override func layout() { super.layout(); texture = nil; maskIsDirty = true; render() }

  func update(_ flashes: [ExplosionFlash], force: Bool = false) {
    let changed = flashes != self.flashes
    self.flashes = flashes
    if changed {
      maskIsDirty = true
      scheduleExpiration()
    }
    if force || changed || !flashes.isEmpty || texture == nil { render() }
  }

  private func scheduleExpiration() {
    expiration?.cancel()
    let now = ProcessInfo.processInfo.systemUptime
    let end: TimeInterval
    if !timeline.bursts.isEmpty || speed.isAnimating(now: now) { end = now + 1.0/60 }
    else if let expiry = flashes.map(\.expiresAt).filter({$0.isFinite && $0 > now}).min() { end = expiry }
    else { return }
    expiration = Task { @MainActor [weak self] in
      // Nanoseconds keep this available on macOS 12.3. Duration-based sleep needs macOS 13.
      do { try await Task.sleep(nanoseconds: UInt64(max(0, end - now) * 1_000_000_000)) } catch { return }
      self?.render()
      self?.scheduleExpiration()
    }
  }

  private func advanceSpeedMotion(at now: TimeInterval) {
    if let last = speedMotionLast, speed.enabled {
      speedMotionTime += max(0, min(0.1, now-last)) * (0.5 + speed.multiplier / 6)
    }
    speedMotionLast = now
  }

  private func render() {
    let now = ProcessInfo.processInfo.systemUptime
    advanceSpeedMotion(at: now)
    timeline.expire(now: now)
    let previousCount = flashes.count
    flashes.removeAll { $0.expiresAt <= now }
    if flashes.count != previousCount { maskIsDirty = true }
    guard surface != nil else { needsDisplay = true; return }
    guard let gpu, let queue, let pipeline, let surface, let screen = window?.screen,
          bounds.width > 0, bounds.height > 0, !isHidden else { return }
    // Opt in while idle, so the display has headroom ready for the short pop.
    surface.wantsExtendedDynamicRangeContent = screen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1
    let scale = window?.backingScaleFactor ?? 1
    surface.contentsScale = scale
    surface.drawableSize = CGSize(width:bounds.width*scale,height:bounds.height*scale)
    let width = Int(ceil(bounds.width)), height = Int(ceil(bounds.height))
    // Reuse an unchanged mask. Submitted masks remain immutable on the GPU.
    if maskIsDirty || texture == nil {
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rg8Unorm,width:width,height:height,mipmapped:false)
      descriptor.usage = .shaderRead
      texture = gpu.makeTexture(descriptor:descriptor)
      if let texture {
        let mask = ExplosionHDR.textureMask(width:width,height:height,flashes:flashes,now:now)
        mask.withUnsafeBytes { bytes in
          texture.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,withBytes:bytes.baseAddress!,bytesPerRow:width*2)
        }
        maskIsDirty = false
      }
    }
    guard let texture, let drawable = surface.nextDrawable(), let command = queue.makeCommandBuffer() else { return }
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
    if let speedPipeline, speed.isAnimating(now: now) {
      var uniforms = SuperSpeedUniforms(
        field: SIMD4(Float(speedField.minX),Float(speedField.minY),Float(speedField.width),Float(speedField.height)),
        animation: speed.sample(now:now,headroom:headroom),size: SIMD2(Float(bounds.width),Float(bounds.height)),
        motion: SIMD4(Float(speedMotionTime),Float(speed.multiplier),0,1))
      encoder.setRenderPipelineState(speedPipeline)
      encoder.setFragmentBytes(&uniforms,length:MemoryLayout<SuperSpeedUniforms>.stride,index:0)
      encoder.drawPrimitives(type:.triangleStrip,vertexStart:0,vertexCount:4)
    }
    let samples = timeline.samples(now: now)
    if let nuclearPipeline, !samples.isEmpty {
      var uniforms = NuclearExplosionUniforms(size: SIMD2(Float(bounds.width),Float(bounds.height)),
        headroom: headroom, count: UInt32(samples.count))
      encoder.setRenderPipelineState(nuclearPipeline)
      encoder.setFragmentBytes(&uniforms,length:MemoryLayout<NuclearExplosionUniforms>.stride,index:0)
      samples.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!,length:$0.count,index:1) }
      encoder.drawPrimitives(type:.triangleStrip,vertexStart:0,vertexCount:4)
    }
    encoder.endEncoding()
    command.present(drawable)
    command.commit()
    #if PERFORMANCE_TESTS
    command.waitUntilCompleted()
    #endif
  }

  override func draw(_ dirtyRect: NSRect) {
    guard surface == nil else { return }
    let samples = timeline.samples(now: ProcessInfo.processInfo.systemUptime)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    bounds.clip()
    drawSpeedFallback()
    for sample in samples {
      let t = CGFloat(sample.z), fade = max(0,min(1,(1.8-t)/0.85))
      let point = CGPoint(x: CGFloat(sample.x)*bounds.width,y: CGFloat(sample.y)*bounds.height)
      let radius = min(bounds.width,bounds.height)*(0.025+0.135*(1-exp(-t*5)))
      let flash = CGFloat(sample.w)*(0.94*exp(-t*24)+0.78*exp(-pow((t-0.16)/0.105,2)))
      NSColor(calibratedWhite:1,alpha:flash).setFill(); bounds.fill()
      let fireball = NSBezierPath(ovalIn:CGRect(x:point.x-radius,y:point.y-radius,
        width:radius*2,height:radius*2))
      NSGradient(colors:[NSColor(calibratedWhite:1,alpha:fade),
        NSColor(calibratedRed:1,green:0.65,blue:0.08,alpha:fade),
        NSColor(calibratedRed:0.8,green:0.08,blue:0.01,alpha:0)])?
        .draw(in:fireball,relativeCenterPosition:.zero)
      let wave = min(bounds.width,bounds.height)*t*0.53
      NSColor(calibratedWhite:1,alpha:exp(-t*3)*fade*0.5).setStroke()
      let ring = NSBezierPath(ovalIn:CGRect(x:point.x-wave,y:point.y-wave,width:wave*2,height:wave*2))
      ring.lineWidth = 2; ring.stroke()
    }
  }

  private func drawSpeedFallback() {
    let now = ProcessInfo.processInfo.systemUptime
    guard speed.isAnimating(now: now), !speedField.isEmpty else { return }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    speedField.clip()
    let sample = speed.sample(now:now,headroom:1)
    let centre = CGPoint(x:speedField.midX,y:speedField.midY)
    let scale = max(speedField.width,speedField.height)
    for index in 0..<48 {
      let angle = CGFloat(index)*2 * .pi/48
      let distance = (CGFloat(speedMotionTime)*0.7+CGFloat(index)*0.371).truncatingRemainder(dividingBy:0.6)+0.25
      let path = NSBezierPath()
      path.move(to:CGPoint(x:centre.x+cos(angle)*distance*scale,y:centre.y+sin(angle)*distance*scale))
      path.line(to:CGPoint(x:centre.x+cos(angle)*(distance+0.10)*scale,y:centre.y+sin(angle)*(distance+0.10)*scale))
      NSColor(calibratedRed:0.2,green:0.8,blue:1,alpha:CGFloat(sample.y)*0.25).setStroke()
      path.lineWidth = 1.5; path.stroke()
    }
  }
}
