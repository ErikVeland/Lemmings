#if os(macOS)
import AppKit
#if canImport(NxlvKit)
import NxlvKit
#endif
import LemmingsGameArt
import Metal
import QuartzCore
import simd

#if PERFORMANCE_TESTS
final class CRTPerformanceMetrics: @unchecked Sendable {
  struct Frame: Sendable { let gpuMS: Double; let completionMS: Double }
  private let lock = NSLock()
  private var submitted = 0
  private var completed: [Frame] = []
  private var failures = 0
  func submit() { lock.lock(); submitted += 1; lock.unlock() }
  func complete(gpuMS: Double, completionMS: Double, failed: Bool) {
    lock.lock(); defer { lock.unlock() }
    completed.append(Frame(gpuMS: gpuMS, completionMS: completionMS))
    if failed { failures += 1 }
  }
  var snapshot: (submitted: Int, frames: [Frame], failures: Int) {
    lock.lock(); defer { lock.unlock() }
    return (submitted, completed, failures)
  }
}
#endif

/// Draws a game frame through a simulated picture tube.
///
/// The Command Line Tools have no offline Metal compiler, so the shaders are
/// built at launch from source. If anything fails the view reports it and the
/// app falls back to drawing without the tube.
@MainActor final class CRTView: NSView {
  #if PERFORMANCE_TESTS
  var performanceMetrics = CRTPerformanceMetrics()
  #endif
  private var device: MTLDevice?
  private var queue: MTLCommandQueue?
  private var metalLayer: CAMetalLayer?

  private var brightPipeline: MTLRenderPipelineState?
  private var blurHPipeline: MTLRenderPipelineState?
  private var blurVPipeline: MTLRenderPipelineState?
  private var compositePipeline: MTLRenderPipelineState?

  @MainActor private final class FrameSlot {
    var source: MTLTexture?
    var flash: MTLTexture?
    var pixels: CGContext?
    var sourceRevision = UInt64.max
    var flashRevision = UInt64.max
    var busy = false
  }
  private let slots = (0..<3).map { _ in FrameSlot() }
  private var nextSlot = 0
  private var sourceImage: CGImage?
  private var sourceRevision: UInt64 = 0
  private var flashes: [ExplosionFlash] = []
  private var flashRevision: UInt64 = 0
  private var pendingRender = false
  private var bloomRevision = UInt64.max
  private var bloomGamma: Float = 0
  private var bloomScale: Double = 0
  #if PERFORMANCE_TESTS
  private(set) var sourceUploads = 0
  private(set) var flashUploads = 0
  private(set) var textureAllocations = 0
  private(set) var bloomPasses = 0
  #endif
  private var scratchA: MTLTexture?
  private var scratchB: MTLTexture?
  private var sourceSize = CGSize.zero
  private var selectionRenderer: LemmingSelectionRenderer?
  private var selection: LemmingSelectionEffect?
  private var rescueAuras: [LemmingSelectionEffect] = []

  var settings = CRTSettings.amiga1084

  /// Input, reported in source image pixels rather than view points.
  ///
  /// The picture is curved and letterboxed on its way to the screen, so a
  /// click has to travel back through both before it means anything to the
  /// game.
  var onMouseDown: ((CGPoint, TimeInterval, Int) -> Void)?
  var onMouseUp: (() -> Void)?
  var onMouseDragged: ((CGPoint) -> Void)?
  var onMouseExited: (() -> Void)?
  var onMouseMoved: ((CGPoint) -> Void)?
  var onScroll: ((NSEvent, CGPoint?) -> Void)?
  /// Source-space area that draws its own pointer. Controls outside it keep the system arrow.
  var gameplayCursorRect: CGRect? {
    didSet {
      if oldValue != gameplayCursorRect { window?.invalidateCursorRects(for: self) }
    }
  }
  private var trackingArea: NSTrackingArea?
  private(set) var failureReason: String?
  var isAvailable: Bool { compositePipeline != nil }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setUp()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setUp()
  }


  private func setUp() {
    wantsLayer = true
    guard let device = MTLCreateSystemDefaultDevice() else {
      failureReason = L10n.text("no Metal device")
      return
    }
    self.device = device
    queue = device.makeCommandQueue()

    let layer = CAMetalLayer()
    layer.device = device
    layer.pixelFormat = .rgba16Float
    layer.colorspace = CGColorSpace(name:CGColorSpace.extendedLinearSRGB)
    layer.wantsExtendedDynamicRangeContent = true
    layer.framebufferOnly = true
    layer.isOpaque = true
    self.layer = layer
    metalLayer = layer

    do {
      let library = try device.makeLibrary(source: CRTShaders.source, options: nil)
      func pipeline(_ fragment: String) throws -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "crt_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: fragment)
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        return try device.makeRenderPipelineState(descriptor: descriptor)
      }
      brightPipeline = try pipeline("crt_bright")
      blurHPipeline = try pipeline("crt_blur_h")
      blurVPipeline = try pipeline("crt_blur_v")

      let final = MTLRenderPipelineDescriptor()
      final.vertexFunction = library.makeFunction(name: "crt_vertex")
      final.fragmentFunction = library.makeFunction(name: "crt_composite")
      final.colorAttachments[0].pixelFormat = .rgba16Float
      compositePipeline = try device.makeRenderPipelineState(descriptor: final)
      selectionRenderer = try? LemmingSelectionRenderer(device: device)
    } catch {
      failureReason = "\(error)"
    }
  }

  // MARK: - Input

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingArea { removeTrackingArea(trackingArea) }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
      owner: self)
    addTrackingArea(area)
    trackingArea = area
  }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: NSCursor.arrow)
  }

  override func cursorUpdate(with event: NSEvent) {
    updateSystemCursor(at: convert(event.locationInWindow, from: nil))
  }

  /**
   * Applies the cursor policy after mouse events and pointer-capture warps.
   */
  func updateSystemCursor(at viewPoint: CGPoint) {
    GameCursor.update(
      at: sourcePoint(from: viewPoint),
      hidingInside: gameplayCursorRect)
  }

  override var acceptsFirstResponder: Bool { true }

  /// Matches the shader's display-to-source sampling coordinates.
  private func sourceUV(_ uv: CGPoint) -> CGPoint {
    let amountX = CGFloat(settings.curvature)
    let amountY = CGFloat(settings.curvatureY)
    guard amountX > 0 || amountY > 0 else { return uv }

    func bend(_ point: CGPoint) -> CGPoint {
      var x = point.x * 2 - 1
      var y = point.y * 2 - 1
      let originalX = x
      let originalY = y
      let offsetX = abs(originalY) / max(amountX, 0.0001)
      let offsetY = abs(originalX) / max(amountY, 0.0001)
      x += x * offsetX * offsetX
      y += y * offsetY * offsetY
      return CGPoint(x: x * 0.5 + 0.5, y: y * 0.5 + 0.5)
    }

    return bend(uv)
  }

  /// Returns false for the rounded glass corners that the shader leaves dark.
  private func isInsideGlass(_ uv: CGPoint) -> Bool {
    let radius = CGFloat(settings.cornerRadius)
    guard radius > 0 else { return true }
    let edgeX = min(uv.x, 1 - uv.x)
    let edgeY = min(uv.y, 1 - uv.y)
    let outsideX = max(radius - edgeX, 0)
    let outsideY = max(radius - edgeY, 0)
    return hypot(outsideX, outsideY) < radius
  }

  /// Converts a point in this view to a pixel in the game image.
  func sourcePoint(from viewPoint: CGPoint, clampingToImage: Bool = false) -> CGPoint? {
    guard sourceSize.width > 0, bounds.width > 0, bounds.height > 0 else { return nil }
    // The view uses a bottom left origin while the image runs top down.
    let uv = CGPoint(
      x: viewPoint.x / bounds.width,
      y: 1 - viewPoint.y / bounds.height)
    var straightened = sourceUV(uv)
    // Keep edge scrolling active over the black border of the curved image.
    if clampingToImage {
      straightened.x = min(1 - 0.001 / sourceSize.width, max(0, straightened.x))
      straightened.y = min(1 - 0.001 / sourceSize.height, max(0, straightened.y))
    }
    guard straightened.x >= 0, straightened.x <= 1,
      straightened.y >= 0, straightened.y <= 1,
      clampingToImage || isInsideGlass(straightened)
    else { return nil }
    return CGPoint(
      x: straightened.x * sourceSize.width,
      y: straightened.y * sourceSize.height)
  }

  /// Places screen effects at the same curved position as their source sprite.
  func viewPoint(fromSource point: CGPoint) -> CGPoint? {
    guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
    let target = CGPoint(x:point.x/sourceSize.width,y:point.y/sourceSize.height)
    guard (0...1).contains(target.x), (0...1).contains(target.y) else { return nil }
    var uv = target
    for _ in 0..<12 {
      let projected = sourceUV(uv)
      uv.x += (target.x-projected.x)*0.75
      uv.y += (target.y-projected.y)*0.75
    }
    guard isInsideGlass(target) else { return nil }
    return CGPoint(x:uv.x*bounds.width,y:(1-uv.y)*bounds.height)
  }

  override func mouseDown(with event: NSEvent) {
    guard let point = sourcePoint(from: convert(event.locationInWindow, from: nil))
    else { return }
    onMouseDown?(point, event.timestamp, event.clickCount)
  }

  override func mouseMoved(with event: NSEvent) {
    let viewPoint = convert(event.locationInWindow, from: nil)
    updateSystemCursor(at: viewPoint)
    guard let point = sourcePoint(from: viewPoint)
    else { onMouseExited?(); return }
    onMouseMoved?(point)
  }

  var accessibleContent: (() -> [Any])?
  override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityChildren() -> [Any]? { accessibleContent?() ?? super.accessibilityChildren() }
  override func mouseUp(with event: NSEvent) { onMouseUp?() }

  override func mouseDragged(with event: NSEvent) {
    guard let point = sourcePoint(from: convert(event.locationInWindow, from: nil)) else { return }
    onMouseDragged?(point)
  }

  override func mouseExited(with event: NSEvent) {
    NSCursor.arrow.set()
    onMouseExited?()
  }

  override func scrollWheel(with event: NSEvent) {
    let point = sourcePoint(from: convert(event.locationInWindow, from: nil))
    onScroll?(event, point)
  }

  // MARK: - Source

  /// Uploads the composed game frame.
  func setSource(_ image: CGImage, flashes: [ExplosionFlash] = [], selection: LemmingSelectionEffect? = nil,
                 rescueAuras: [LemmingSelectionEffect] = []) {
    if sourceImage !== image { sourceImage = image; sourceRevision &+= 1 }
    updateEffects(flashes: flashes, selection: selection, rescueAuras: rescueAuras)
  }

  /// Effect-only redraws reuse the scene pixels and cached halation.
  func updateEffects(flashes: [ExplosionFlash], selection: LemmingSelectionEffect?,
                     rescueAuras: [LemmingSelectionEffect] = []) {
    self.selection = selection; self.rescueAuras = rescueAuras
    let active = flashes.filter { $0.expiresAt > ProcessInfo.processInfo.systemUptime }
    if self.flashes != active { self.flashes = active; flashRevision &+= 1 }
    render()
  }

  private func prepare(_ slot: FrameSlot) -> Bool {
    guard let device, let image = sourceImage else { return false }
    let width = image.width, height = image.height
    if slot.source?.width != width || slot.source?.height != height {
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
        width: width, height: height, mipmapped: false)
      descriptor.usage = .shaderRead
      slot.source = device.makeTexture(descriptor: descriptor)
      descriptor.pixelFormat = .rg8Unorm
      slot.flash = device.makeTexture(descriptor: descriptor)
      slot.pixels = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      slot.sourceRevision = .max; slot.flashRevision = .max
      #if PERFORMANCE_TESTS
      textureAllocations += 2
      #endif
    }
    guard let source = slot.source, let flash = slot.flash, let pixels = slot.pixels else { return false }
    if slot.sourceRevision != sourceRevision {
      pixels.interpolationQuality = .none
      pixels.setBlendMode(.copy)
      pixels.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      source.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
        withBytes: pixels.data!, bytesPerRow: width * 4)
      slot.sourceRevision = sourceRevision
      #if PERFORMANCE_TESTS
      sourceUploads += 1
      #endif
    }
    if slot.flashRevision != flashRevision {
      let mask = ExplosionHDR.textureMask(width: width, height: height, flashes: flashes)
      mask.withUnsafeBytes { bytes in
        flash.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
          withBytes: bytes.baseAddress!, bytesPerRow: width * 2)
      }
      slot.flashRevision = flashRevision
      #if PERFORMANCE_TESTS
      flashUploads += 1
      #endif
    }
    sourceSize = CGSize(width: width, height: height)
    return true
  }

  // MARK: - Drawing

  override func layout() {
    super.layout()
    let scale = window?.backingScaleFactor ?? 2
    metalLayer?.contentsScale = scale
    metalLayer?.drawableSize = CGSize(
      width: bounds.width * scale, height: bounds.height * scale)
    // A resize changes the drawable, so what was on screen no longer fits it.
    render()
  }

  override func draw(_ dirtyRect: NSRect) {
    render()
  }

  func render() {
    guard let queue, let layer = metalLayer else { return }
    guard let offset = (0..<slots.count).first(where: { !slots[(nextSlot + $0) % slots.count].busy }) else {
      pendingRender = true; return
    }
    let slot = slots[(nextSlot + offset) % slots.count]
    guard prepare(slot), window != nil, let drawable = layer.nextDrawable(), let buffer = queue.makeCommandBuffer() else { return }
    nextSlot = (nextSlot + offset + 1) % slots.count
    slot.busy = true; pendingRender = false
    encode(slot, target: drawable.texture, buffer: buffer)
    #if PERFORMANCE_TESTS
    let metrics = performanceMetrics
    let submittedAt = ProcessInfo.processInfo.systemUptime
    metrics.submit()
    #endif
    buffer.addCompletedHandler { [weak self] completed in
      let gpuSeconds = max(0, completed.gpuEndTime - completed.gpuStartTime)
      let failed = completed.status != .completed
      #if PERFORMANCE_TESTS
      metrics.complete(gpuMS: gpuSeconds * 1000,
        completionMS: (ProcessInfo.processInfo.systemUptime - submittedAt) * 1000,
        failed: completed.status != .completed)
      #endif
      Task { @MainActor in
        slot.busy = false
        if failed { self?.bloomRevision = .max; slot.sourceRevision = .max; slot.flashRevision = .max }
        MacFXPerformance.shared.recordGPU(gpuSeconds, source: "crt")
        if self?.pendingRender == true { self?.render() }
      }
    }
    buffer.present(drawable)
    buffer.commit()
  }

  private func encode(_ slot: FrameSlot, target: MTLTexture, buffer: MTLCommandBuffer, headroom: Float? = nil) {
    if let screen = window?.screen { MacFXPerformance.shared.configureDisplay(screen) }
    guard let device, let sourceTexture = slot.source, let flashTexture = slot.flash,
      let bright = brightPipeline, let blurH = blurHPipeline, let blurV = blurVPipeline,
      let composite = compositePipeline else { return }
    let scale = MacFXPerformance.shared.presentation.bloomScale
    let width = max(1, Int(sourceSize.width * scale)), height = max(1, Int(sourceSize.height * scale))
    if settings.bloomAmount > 0, scratchA?.width != width || scratchA?.height != height {
      let scratch = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
        width: width, height: height, mipmapped: false)
      scratch.usage = [.shaderRead, .renderTarget]
      scratchA = device.makeTexture(descriptor: scratch); scratchB = device.makeTexture(descriptor: scratch)
      bloomRevision = .max
      #if PERFORMANCE_TESTS
      textureAllocations += 2
      #endif
    }
    guard settings.bloomAmount <= 0 || (scratchA != nil && scratchB != nil) else { return }
    let scratchA = scratchA ?? sourceTexture, scratchB = scratchB ?? sourceTexture
    var uniforms = CRTUniforms()
    uniforms.sourceSize = SIMD2(Float(sourceSize.width), Float(sourceSize.height))
    uniforms.outputSize = SIMD2(
      Float(target.width), Float(target.height))
    uniforms.curvature = settings.curvature
    uniforms.curvatureY = settings.curvatureY
    uniforms.cornerRadius = settings.cornerRadius
    uniforms.cornerSoftness = settings.cornerSoftness
    uniforms.scanlineDepth = settings.scanlineDepth
    uniforms.beamWidth = settings.beamWidth
    uniforms.beamBloom = settings.beamBloom
    uniforms.maskStrength = settings.maskStrength
    uniforms.maskType = settings.maskType
    uniforms.maskSize = settings.maskSize
    uniforms.maskDark = settings.maskDark
    uniforms.maskLight = settings.maskLight
    uniforms.bloomAmount = settings.bloomAmount
    uniforms.gamma = settings.gamma
    uniforms.brightness = settings.brightness
    uniforms.brightBoostDark = settings.brightBoostDark
    uniforms.brightBoostBright = settings.brightBoostBright
    uniforms.saturation = settings.saturation
    uniforms.convergence = settings.convergence
    uniforms.convergenceY = settings.convergenceY
    uniforms.vignette = settings.vignette
    uniforms.pixelAspect = settings.pixelAspect
    uniforms.colorLevels = settings.colorLevels
    uniforms.hdrHeadroom = headroom ?? ExplosionHDR.headroom(window?.screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1)
    metalLayer?.wantsExtendedDynamicRangeContent = (window?.screen?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1) > 1

    func pass(
      _ pipeline: MTLRenderPipelineState,
      target: MTLTexture,
      textures: [MTLTexture]
    ) {
      let descriptor = MTLRenderPassDescriptor()
      descriptor.colorAttachments[0].texture = target
      descriptor.colorAttachments[0].loadAction = .clear
      descriptor.colorAttachments[0].storeAction = .store
      descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
      guard let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
      encoder.setRenderPipelineState(pipeline)
      for (index, texture) in textures.enumerated() {
        encoder.setFragmentTexture(texture, index: index)
      }
      encoder.setFragmentBytes(
        &uniforms, length: MemoryLayout<CRTUniforms>.stride, index: 0)
      encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
      encoder.endEncoding()
    }

    // Halation: pull out the bright parts, then spread them.
    if settings.bloomAmount > 0,
       bloomRevision != sourceRevision || bloomGamma != settings.gamma || bloomScale != scale {
      pass(bright, target: scratchA, textures: [sourceTexture])
      pass(blurH, target: scratchB, textures: [scratchA])
      pass(blurV, target: scratchA, textures: [scratchB])
      bloomRevision = sourceRevision; bloomGamma = settings.gamma; bloomScale = scale
      #if PERFORMANCE_TESTS
      bloomPasses += 3
      #endif
    }
    pass(composite, target: target, textures: [sourceTexture, settings.bloomAmount > 0 ? scratchA : sourceTexture, flashTexture])
    // Selection is composited after the tube. Its neighbour samples are always
    // two physical output pixels apart, even on a Retina display or curved edge.
    if (!rescueAuras.isEmpty || (!GameCursor.gameplaySuppressed && selection != nil)), let selectionRenderer {
      let descriptor = MTLRenderPassDescriptor()
      descriptor.colorAttachments[0].texture = target
      descriptor.colorAttachments[0].loadAction = .load
      descriptor.colorAttachments[0].storeAction = .store
      if let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) {
        let glass = SIMD4(settings.curvature, settings.curvatureY, settings.cornerRadius, settings.cornerSoftness)
        for effect in rescueAuras {
          selectionRenderer.encode(effect, sourceSize: sourceSize, outputSize: CGSize(width: target.width, height: target.height),
            glass: glass, headroom: Float(window?.screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1),
            additive: true, into: encoder)
        }
        if !GameCursor.gameplaySuppressed, let selection {
          selectionRenderer.encode(selection, sourceSize: sourceSize, outputSize: CGSize(width: target.width, height: target.height), glass: glass, into: encoder)
        }
        encoder.endEncoding()
      }
    }

  }

  #if PERFORMANCE_TESTS
  /// Exercise the shipping passes without a visible window or drawable.
  func renderForTesting(size: CGSize, headroom: Float = 1, slotIndex: Int = 0) -> MTLTexture? {
    guard let device, let queue, slots.indices.contains(slotIndex) else { return nil }
    let slot = slots[slotIndex]
    guard !slot.busy, prepare(slot), let command = queue.makeCommandBuffer() else { return nil }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
      width: Int(size.width), height: Int(size.height), mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    guard let target = device.makeTexture(descriptor: descriptor) else { return nil }
    encode(slot, target: target, buffer: command, headroom: headroom)
    command.commit(); command.waitUntilCompleted()
    return command.status == .completed ? target : nil
  }
  #endif
}
#endif
