import AppKit
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

/// Display settings for the picture tube stage.
struct CRTSettings {
  var curvature: Float
  var curvatureY: Float
  var cornerRadius: Float
  var cornerSoftness: Float
  var scanlineDepth: Float
  var beamWidth: Float
  var beamBloom: Float
  var maskStrength: Float
  /// 0 is an aperture grille, 1 is a shadow mask.
  var maskType: Float
  var maskSize: Float
  var maskDark: Float
  var maskLight: Float
  var bloomAmount: Float
  var gamma: Float
  var brightness: Float
  var brightBoostDark: Float
  var brightBoostBright: Float
  var saturation: Float
  var convergence: Float
  var convergenceY: Float
  var vignette: Float
  var pixelAspect: Float
  /// 0 keeps full depth. 16 matches the Amiga OCS and ECS palette, which
  /// held four bits per channel.
  var colorLevels: Float

  /// A Commodore 1084 style monitor, which is how most people saw an A500.
  ///
  /// A fine shadow mask, mild curvature, and aligned colour channels.
  static let amiga1084 = CRTSettings(
    curvature: 24.0,
    curvatureY: 24.0,
    cornerRadius: 0.012,
    cornerSoftness: 0.006,
    scanlineDepth: 0.16,
    beamWidth: 0.30,
    beamBloom: 0.10,
    maskStrength: 0.10,
    maskType: 1,
    maskSize: 1.0,
    maskDark: 0.76,
    maskLight: 1.12,
    bloomAmount: 0.025,
    gamma: 2.2,
    brightness: 1.02,
    brightBoostDark: 1.08,
    brightBoostBright: 1.03,
    saturation: 1.02,
    convergence: 0,
    convergenceY: 0,
    vignette: 0.025,
    pixelAspect: 1.0,
    colorLevels: 16)

  /// A softer television with restrained glow and a fine aperture grille.
  static let television = CRTSettings(
    curvature: 18.0,
    curvatureY: 24.0,
    cornerRadius: 0.022,
    cornerSoftness: 0.009,
    scanlineDepth: 0.22,
    beamWidth: 0.34,
    beamBloom: 0.16,
    maskStrength: 0.13,
    maskType: 0,
    maskSize: 1.0,
    maskDark: 0.70,
    maskLight: 1.18,
    bloomAmount: 0.045,
    gamma: 2.2,
    brightness: 1.03,
    brightBoostDark: 1.10,
    brightBoostBright: 1.05,
    saturation: 1.04,
    convergence: 0.10,
    convergenceY: 0.03,
    vignette: 0.04,
    pixelAspect: 1.15,
    colorLevels: 16)
}

struct CRTUniforms {
  var sourceSize: SIMD2<Float> = .zero
  var outputSize: SIMD2<Float> = .zero
  var curvature: Float = 0
  var curvatureY: Float = 0
  var cornerRadius: Float = 0
  var cornerSoftness: Float = 0
  var scanlineDepth: Float = 0
  var beamWidth: Float = 0.4
  var beamBloom: Float = 0
  var maskStrength: Float = 0
  var maskType: Float = 0
  var maskSize: Float = 1
  var maskDark: Float = 0.76
  var maskLight: Float = 1.12
  var bloomAmount: Float = 0
  var gamma: Float = 2.4
  var brightness: Float = 1
  var brightBoostDark: Float = 1
  var brightBoostBright: Float = 1
  var saturation: Float = 1
  var convergence: Float = 0
  var convergenceY: Float = 0
  var vignette: Float = 0
  var pixelAspect: Float = 1
  var colorLevels: Float = 0
  var hdrHeadroom: Float = 1
}

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

  private var sourceTexture: MTLTexture?
  private var flashTexture: MTLTexture?
  private var scratchA: MTLTexture?
  private var scratchB: MTLTexture?
  private var sourceSize = CGSize.zero

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
  var onScroll: ((CGFloat, CGFloat) -> Void)?
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
      failureReason = "no Metal device"
      return
    }
    self.device = device
    queue = device.makeCommandQueue()

    let layer = CAMetalLayer()
    layer.device = device
    layer.pixelFormat = .rgba16Float
    layer.colorspace = CGColorSpace(name:CGColorSpace.extendedLinearSRGB)
    layer.wantsExtendedDynamicRangeContent = true
    layer.framebufferOnly = false
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
    addCursorRect(bounds, cursor: GameCursor.invisible)
  }

  override func cursorUpdate(with event: NSEvent) {
    GameCursor.invisible.set()
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
    guard let point = sourcePoint(from: convert(event.locationInWindow, from: nil))
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

  override func mouseExited(with event: NSEvent) { onMouseExited?() }

  override func scrollWheel(with event: NSEvent) {
    onScroll?(event.scrollingDeltaX, event.scrollingDeltaY)
  }

  // MARK: - Source

  /// Uploads the composed game frame.
  func setSource(_ image: CGImage, flashes: [ExplosionFlash] = []) {
    guard let device else { return }
    let width = image.width
    let height = image.height

    if sourceTexture == nil || Int(sourceSize.width) != width
      || Int(sourceSize.height) != height {
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
      descriptor.usage = [.shaderRead]
      sourceTexture = device.makeTexture(descriptor: descriptor)

      let scratch = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
      scratch.usage = [.shaderRead, .renderTarget]
      scratchA = device.makeTexture(descriptor: scratch)
      scratchB = device.makeTexture(descriptor: scratch)
      sourceSize = CGSize(width: width, height: height)
    }
    guard let sourceTexture else { return }

    // Draw the image into a tight RGBA buffer, then upload it.
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    bytes.withUnsafeMutableBytes { raw in
      guard let context = CGContext(
        data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return }
      context.interpolationQuality = .none
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    sourceTexture.replace(
      region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
      withBytes: bytes, bytesPerRow: width * 4)
    let mask = ExplosionHDR.textureMask(width:width,height:height,flashes:flashes)
    let flash = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rg8Unorm,width:width,height:height,mipmapped:false)
    flash.usage = .shaderRead
    flashTexture = device.makeTexture(descriptor:flash)
    mask.withUnsafeBytes { bytes in
      flashTexture?.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,
        withBytes:bytes.baseAddress!,bytesPerRow:width*2)
    }
    // Draw straight away rather than asking for a redraw. Assigning a
    // CAMetalLayer to `layer` makes this view layer-hosting, and a
    // layer-hosting view never receives `draw(_:)`, so `needsDisplay` here
    // would mark a redraw that never arrives and the tube would stay black.
    render()
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
    guard let queue, let layer = metalLayer, let sourceTexture, let flashTexture,
      let bright = brightPipeline, let blurH = blurHPipeline, let blurV = blurVPipeline,
      let composite = compositePipeline, let scratchA, let scratchB,
      let drawable = layer.nextDrawable(), let buffer = queue.makeCommandBuffer()
    else { return }

    var uniforms = CRTUniforms()
    uniforms.sourceSize = SIMD2(Float(sourceSize.width), Float(sourceSize.height))
    uniforms.outputSize = SIMD2(
      Float(layer.drawableSize.width), Float(layer.drawableSize.height))
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
    uniforms.hdrHeadroom = ExplosionHDR.headroom(window?.screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1)
    layer.wantsExtendedDynamicRangeContent = (window?.screen?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1) > 1

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
    pass(bright, target: scratchA, textures: [sourceTexture])
    pass(blurH, target: scratchB, textures: [scratchA])
    pass(blurV, target: scratchA, textures: [scratchB])
    pass(composite, target: drawable.texture, textures: [sourceTexture, scratchA, flashTexture])

    #if PERFORMANCE_TESTS
    let metrics = performanceMetrics
    let submittedAt = ProcessInfo.processInfo.systemUptime
    metrics.submit()
    buffer.addCompletedHandler { completed in
      metrics.complete(gpuMS: max(0, completed.gpuEndTime - completed.gpuStartTime) * 1000,
        completionMS: (ProcessInfo.processInfo.systemUptime - submittedAt) * 1000,
        failed: completed.status != .completed)
    }
    #endif
    buffer.present(drawable)
    buffer.commit()
  }
}
