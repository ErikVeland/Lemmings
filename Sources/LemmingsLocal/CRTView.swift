import AppKit
import Metal
import QuartzCore
import simd

/// Display settings for the picture tube stage.
struct CRTSettings {
  var curvature: Float
  var scanlineDepth: Float
  var beamWidth: Float
  var beamBloom: Float
  var maskStrength: Float
  /// 0 is an aperture grille, 1 is a shadow mask.
  var maskType: Float
  var bloomAmount: Float
  var gamma: Float
  var brightness: Float
  var convergence: Float
  var vignette: Float
  var pixelAspect: Float
  /// 0 keeps full depth. 16 matches the Amiga OCS and ECS palette, which
  /// held four bits per channel.
  var colorLevels: Float

  /// A Commodore 1084 style monitor, which is how most people saw an A500.
  ///
  /// A shadow mask tube, mild curvature, and only slight convergence error.
  /// It is sharper than a television, so the smear stays low.
  static let amiga1084 = CRTSettings(
    curvature: 14.0,
    scanlineDepth: 0.38,
    beamWidth: 0.42,
    beamBloom: 0.34,
    maskStrength: 0.30,
    maskType: 1,
    bloomAmount: 0.14,
    gamma: 2.2,
    brightness: 1.16,
    convergence: 0.25,
    vignette: 0.12,
    pixelAspect: 1.0,
    colorLevels: 16)

  /// A television fed over composite, which is blurrier and bloomier.
  static let television = CRTSettings(
    curvature: 10.0,
    scanlineDepth: 0.34,
    beamWidth: 0.52,
    beamBloom: 0.50,
    maskStrength: 0.22,
    maskType: 0,
    bloomAmount: 0.22,
    gamma: 2.2,
    brightness: 1.14,
    convergence: 0.55,
    vignette: 0.18,
    pixelAspect: 1.15,
    colorLevels: 16)
}

struct CRTUniforms {
  var sourceSize: SIMD2<Float> = .zero
  var outputSize: SIMD2<Float> = .zero
  var curvature: Float = 0
  var scanlineDepth: Float = 0
  var beamWidth: Float = 0.4
  var beamBloom: Float = 0
  var maskStrength: Float = 0
  var maskType: Float = 0
  var bloomAmount: Float = 0
  var gamma: Float = 2.4
  var brightness: Float = 1
  var convergence: Float = 0
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
  var onMouseDown: ((CGPoint) -> Void)?
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
      options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
      owner: self)
    addTrackingArea(area)
    trackingArea = area
  }

  override var acceptsFirstResponder: Bool { true }

  /// Matches the shader's display-to-source sampling coordinates.
  private func sourceUV(_ uv: CGPoint) -> CGPoint {
    let amount = CGFloat(settings.curvature)
    guard amount > 0 else { return uv }

    func bend(_ point: CGPoint) -> CGPoint {
      var x = point.x * 2 - 1
      var y = point.y * 2 - 1
      let offsetX = abs(y) / amount
      let offsetY = abs(x) / amount
      x += x * offsetX * offsetX
      y += y * offsetY * offsetY
      return CGPoint(x: x * 0.5 + 0.5, y: y * 0.5 + 0.5)
    }

    return bend(uv)
  }

  /// Converts a point in this view to a pixel in the game image.
  func sourcePoint(from viewPoint: CGPoint) -> CGPoint? {
    guard sourceSize.width > 0, bounds.width > 0, bounds.height > 0 else { return nil }
    // The view uses a bottom left origin while the image runs top down.
    let uv = CGPoint(
      x: viewPoint.x / bounds.width,
      y: 1 - viewPoint.y / bounds.height)
    let straightened = sourceUV(uv)
    guard straightened.x >= 0, straightened.x <= 1,
      straightened.y >= 0, straightened.y <= 1
    else { return nil }
    return CGPoint(
      x: straightened.x * sourceSize.width,
      y: straightened.y * sourceSize.height)
  }

  override func mouseDown(with event: NSEvent) {
    guard let point = sourcePoint(from: convert(event.locationInWindow, from: nil))
    else { return }
    onMouseDown?(point)
  }

  override func mouseMoved(with event: NSEvent) {
    guard let point = sourcePoint(from: convert(event.locationInWindow, from: nil))
    else { onMouseExited?(); return }
    onMouseMoved?(point)
  }

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
    let mask = ExplosionHDR.mask(width:width,height:height,flashes:flashes)
    let flash = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.r8Unorm,width:width,height:height,mipmapped:false)
    flash.usage = .shaderRead
    flashTexture = device.makeTexture(descriptor:flash)
    mask.withUnsafeBytes { bytes in
      flashTexture?.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,
        withBytes:bytes.baseAddress!,bytesPerRow:width)
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
    uniforms.scanlineDepth = settings.scanlineDepth
    uniforms.beamWidth = settings.beamWidth
    uniforms.beamBloom = settings.beamBloom
    uniforms.maskStrength = settings.maskStrength
    uniforms.maskType = settings.maskType
    uniforms.bloomAmount = settings.bloomAmount
    uniforms.gamma = settings.gamma
    uniforms.brightness = settings.brightness
    uniforms.convergence = settings.convergence
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

    buffer.present(drawable)
    buffer.commit()
  }
}
