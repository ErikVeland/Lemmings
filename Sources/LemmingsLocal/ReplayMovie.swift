#if os(macOS)
import AppKit
import LemmingsAppCore

@MainActor enum ReplayFrameCapture {
  /// Draw a game surface at a fixed movie resolution without resizing the live view.
  static func image(size: CGSize, draw: () -> Void) -> CGImage? {
    let width = Int(size.width) / 2 * 2, height = Int(size.height) / 2 * 2
    guard width > 0, height > 0, let context = CGContext(data: nil, width: width, height: height,
      bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
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
