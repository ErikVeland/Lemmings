#if os(macOS)
import AppKit
import Metal
import QuartzCore
import LemmingsGameArt

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
    var bytes = [UInt8](repeating: 0, count: warm.count * 2)
    for index in warm.indices {
      bytes[index * 2] = warm[index]
      bytes[index * 2 + 1] = green[index]
    }
    return bytes
  }

  static let shader = GameplayHDRShaders.source
}

/// Shared cinematic explosion and speed effects. The surface never intercepts input.
@MainActor final class ExplosionHDRView: NSView {
  private let gpu = MTLCreateSystemDefaultDevice()
  private var queue: MTLCommandQueue?
  private var pipeline: MTLRenderPipelineState?
  private var nuclearPipeline: MTLRenderPipelineState?
  private var speedPipeline: MTLRenderPipelineState?
  private var rescueRenderer: LemmingSelectionRenderer?
  private var rescueAuras: [LemmingSelectionEffect] = []
  private var surface: CAMetalLayer?
  private var texture: MTLTexture?
  private var flashes: [ExplosionFlash] = []
  private var worldFlashes: [ExplosionFlash] = []
  private var worldProjection: ((CGRect) -> CGRect?)?
  private var renderedFlashes: [ExplosionFlash] {
    flashes + worldFlashes.compactMap { flash in
      guard let rect = worldProjection?(flash.rect) else { return nil }
      return .init(rect: rect, strength: flash.strength, expiresAt: flash.expiresAt, tint: flash.tint)
    }
  }
  func explosionSamples(now: TimeInterval) -> [SIMD4<Float>] {
    timeline.samples(now: now) { centre in
      guard self.bounds.width > 0, self.bounds.height > 0,
            let rect = self.worldProjection?(CGRect(x: CGFloat(centre.x), y: CGFloat(centre.y), width: 0, height: 0)) else { return nil }
      return SIMD2(Float((rect.midX - self.bounds.minX) / self.bounds.width),
                   Float((rect.midY - self.bounds.minY) / self.bounds.height))
    }
  }
  private var expiration: Task<Void,Never>?
  private var timeline = NuclearExplosionTimeline()
  private var speed = SuperSpeedTimeline()
  private var speedMotionTime: TimeInterval = 0
  private var speedMotionLast: TimeInterval?
  private var speedField = CGRect.zero
  private var maskIsDirty = true
  var isSuperSpeedActive: Bool { speed.enabled }
  var hasAllocatedFlashMask: Bool { texture != nil }

  /// Each blast has a local fireball. A nuke shares the wider exposure bloom.
  func pulse(cores: [CGRect] = [], fullScreen: Bool, project: ((CGRect) -> CGRect?)? = nil) {
    let now = ProcessInfo.processInfo.systemUptime
    if let project { worldProjection = project }
    let visible = cores.filter { (project?($0) ?? (project == nil ? $0 : .null)).intersects(bounds) }
    if fullScreen, bounds.width > 0, bounds.height > 0 {
      let centres = visible.map { project == nil
        ? SIMD2(Float($0.midX/bounds.width),Float($0.midY/bounds.height))
        : SIMD2(Float($0.midX),Float($0.midY)) }
      timeline.trigger(centres: cores.isEmpty && project == nil ? [SIMD2(0.5,0.45)] : centres,
        now: now, worldAnchored: project != nil)
    } else {
      for core in visible {
        let flash = ExplosionFlash(rect: core, strength: 1, expiresAt: now + 0.10)
        if project == nil { flashes.append(flash) } else { worldFlashes.append(flash) }
      }
      maskIsDirty = true
    }
    render()
    scheduleExpiration()
  }

  func clearExplosions() {
    timeline.clear()
    flashes.removeAll(); worldFlashes.removeAll(); worldProjection = nil
    maskIsDirty = true
    render()
    scheduleExpiration()
  }

  func clear() {
    rescueAuras.removeAll()
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
    rescueRenderer = try? LemmingSelectionRenderer(device: gpu)
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

  func setRescueAuras(_ effects: [LemmingSelectionEffect]) {
    guard !effects.isEmpty || !rescueAuras.isEmpty else { return }
    rescueAuras = effects
    render()
  }

  private func scheduleExpiration() {
    expiration?.cancel()
    let now = ProcessInfo.processInfo.systemUptime
    let end: TimeInterval
    if !timeline.bursts.isEmpty || !worldFlashes.isEmpty || speed.isAnimating(now: now) { end = now + 1.0/MacFXPerformance.shared.quality.effectHz }
    else if let expiry = (flashes + worldFlashes).map(\.expiresAt).filter({$0.isFinite && $0 > now}).min() { end = expiry }
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
    let hadWorldFlashes = !worldFlashes.isEmpty
    worldFlashes.removeAll { $0.expiresAt <= now }
    if hadWorldFlashes { maskIsDirty = true }
    let previousCount = flashes.count
    flashes.removeAll { $0.expiresAt <= now }
    if flashes.count != previousCount { maskIsDirty = true }
    // An idle overlay has no pixels to present. Hide the previous frame without
    // allocating a full-window mask or waiting for a Metal drawable.
    let currentFlashes = renderedFlashes
    let active = !rescueAuras.isEmpty || !currentFlashes.isEmpty || !timeline.bursts.isEmpty || speed.isAnimating(now: now)
    // AppKit can restore a backing layer's visibility during display. Hide the
    // view too, so idle effects stay out of window composition.
    isHidden = !active
    surface?.isHidden = !active
    guard active else {
      texture = nil
      if surface == nil { needsDisplay = true }
      return
    }
    guard surface != nil else { needsDisplay = true; return }
    guard let gpu, let queue, let pipeline, let surface, let screen = window?.screen,
          bounds.width > 0, bounds.height > 0, !isHidden else { return }
    // Opt in while idle, so the display has headroom ready for the short pop.
    surface.wantsExtendedDynamicRangeContent = screen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1
    let quality = MacFXPerformance.shared.quality
    let scale = (window?.backingScaleFactor ?? 1) * quality.overlayScale
    surface.contentsScale = scale
    surface.drawableSize = CGSize(width:bounds.width*scale,height:bounds.height*scale)
    let width = Int(ceil(bounds.width)), height = Int(ceil(bounds.height))
    // Reuse an unchanged mask. Submitted masks remain immutable on the GPU.
    if !currentFlashes.isEmpty && (maskIsDirty || texture == nil) {
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rg8Unorm,width:width,height:height,mipmapped:false)
      descriptor.usage = .shaderRead
      texture = gpu.makeTexture(descriptor:descriptor)
      if let texture {
        let mask = ExplosionHDR.textureMask(width:width,height:height,flashes:currentFlashes,now:now)
        mask.withUnsafeBytes { bytes in
          texture.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,withBytes:bytes.baseAddress!,bytesPerRow:width*2)
        }
        maskIsDirty = false
      }
    }
    if currentFlashes.isEmpty { texture = nil }
    guard let drawable = surface.nextDrawable(), let command = queue.makeCommandBuffer() else { return }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = drawable.texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,0)
    guard let encoder = command.makeRenderCommandEncoder(descriptor:pass) else { return }
    var headroom = ExplosionHDR.headroom(screen.maximumExtendedDynamicRangeColorComponentValue)
    if let texture {
      encoder.setRenderPipelineState(pipeline)
      encoder.setFragmentTexture(texture,index:0)
      encoder.setFragmentBytes(&headroom,length:MemoryLayout<Float>.size,index:0)
      encoder.drawPrimitives(type:.triangleStrip,vertexStart:0,vertexCount:4)
    }
    if let speedPipeline, speed.isAnimating(now: now) {
      var uniforms = SuperSpeedUniforms(
        field: SIMD4(Float(speedField.minX),Float(speedField.minY),Float(speedField.width),Float(speedField.height)),
        animation: speed.sample(now:now,headroom:headroom),size: SIMD2(Float(bounds.width),Float(bounds.height)),
        motion: SIMD4(Float(speedMotionTime),Float(speed.multiplier),0,1))
      encoder.setRenderPipelineState(speedPipeline)
      encoder.setFragmentBytes(&uniforms,length:MemoryLayout<SuperSpeedUniforms>.stride,index:0)
      encoder.drawPrimitives(type:.triangleStrip,vertexStart:0,vertexCount:4)
    }
    let allSamples = explosionSamples(now: now)
    // Retain the exposure burst, then the most recent decorative bursts.
    var samples = Array(allSamples.suffix(quality.explosionLimit))
    if let exposure = allSamples.first(where: { $0.w > 0 }), !samples.contains(exposure) {
      if samples.count == quality.explosionLimit { samples.removeFirst() }
      samples.insert(exposure, at: 0)
    }
    if let nuclearPipeline, !samples.isEmpty {
      var uniforms = NuclearExplosionUniforms(size: SIMD2(Float(bounds.width),Float(bounds.height)),
        headroom: headroom, count: UInt32(samples.count))
      encoder.setRenderPipelineState(nuclearPipeline)
      encoder.setFragmentBytes(&uniforms,length:MemoryLayout<NuclearExplosionUniforms>.stride,index:0)
      samples.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!,length:$0.count,index:1) }
      encoder.drawPrimitives(type:.triangleStrip,vertexStart:0,vertexCount:4)
    }
    if let rescueRenderer {
      for effect in rescueAuras {
        rescueRenderer.encode(effect, sourceSize: bounds.size, outputSize: surface.drawableSize, headroom: headroom, additive: true, into: encoder)
      }
    }
    encoder.endEncoding()
    command.addCompletedHandler { completed in
      let seconds = max(0, completed.gpuEndTime - completed.gpuStartTime)
      Task { @MainActor in MacFXPerformance.shared.recordGPU(seconds, source: "effects") }
    }
    command.present(drawable)
    command.commit()
    #if PERFORMANCE_TESTS
    command.waitUntilCompleted()
    #endif
  }

  override func draw(_ dirtyRect: NSRect) {
    guard surface == nil else { return }
    let samples = explosionSamples(now: ProcessInfo.processInfo.systemUptime).suffix(MacFXPerformance.shared.quality.explosionLimit)
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
#endif
