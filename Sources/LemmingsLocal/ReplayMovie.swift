#if os(macOS)
import AppKit
import LemmingsAppCore

@MainActor enum ReplayFrameCapture {
  private static var contexts: [String: CGContext] = [:]
  private static var contextOrder: [String] = []
  #if PERFORMANCE_TESTS
  static var contextAllocations = 0
  #endif
  /// Draw a game surface at a fixed movie resolution without resizing the live view.
  static func image(size: CGSize, draw: () -> Void) -> CGImage? {
    let width = Int(size.width) / 2 * 2, height = Int(size.height) / 2 * 2
    guard width > 0, height > 0 else { return nil }
    let key = "\(width)x\(height)"
    let context: CGContext
    if let cached = contexts[key] { context = cached }
    else {
      guard let made = CGContext(data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
      made.translateBy(x: 0, y: CGFloat(height)); made.scaleBy(x: 1, y: -1)
      context = made
      // At most two normal movie surfaces remain resident. Large exports are transient.
      if width * height <= 2_097_152 {
        if contextOrder.count == 2 { contexts.removeValue(forKey: contextOrder.removeFirst()) }
        contexts[key] = made; contextOrder.append(key)
      }
      #if PERFORMANCE_TESTS
      contextAllocations += 1
      #endif
    }
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.saveGState()
    defer { context.restoreGState() }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()
  }
  static func draw(_ view: NSView, in rect: CGRect) {
    guard view.bounds.width > 0, view.bounds.height > 0 else { return }
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: rect.minX, yBy: rect.minY)
    transform.scaleX(by: rect.width / view.bounds.width, yBy: rect.height / view.bounds.height)
    transform.concat()
    view.draw(view.bounds)
    NSGraphicsContext.restoreGraphicsState()
  }
}
#endif
