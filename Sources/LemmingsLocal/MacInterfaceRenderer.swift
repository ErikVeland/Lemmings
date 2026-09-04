import AppKit
import NxlvKit

/// Draws menus with the Macintosh release's own artwork.
///
/// The Macintosh version drew its front end at twice the resolution of the
/// other platforms and shipped a complete character set with it. Menus drawn
/// through this look like the game rather than like an application, and they
/// stay sharp because every glyph is placed at a whole-number scale.
@MainActor final class MacInterfaceRenderer {
  let interface: ClassicMacUserInterface
  private var cache: [String: NSImage] = [:]

  init(interface: ClassicMacUserInterface) {
    self.interface = interface
  }

  func font(_ face: ClassicMacUserInterface.Face) -> ClassicMacUserInterface.Font? {
    interface.font(face)
  }

  /// The scale that fits the face to a wanted height on screen.
  ///
  /// Whole numbers only. A fractional scale blurs the pixels, which is the one
  /// thing the original never did.
  func scale(for face: ClassicMacUserInterface.Face, targetHeight: CGFloat) -> Int {
    guard let font = interface.font(face), font.cellHeight > 0 else { return 1 }
    return max(1, Int((targetHeight / CGFloat(font.cellHeight)).rounded()))
  }

  func width(of text: String, face: ClassicMacUserInterface.Face, scale: Int) -> CGFloat {
    guard let font = interface.font(face) else { return 0 }
    return CGFloat(font.width(of: text, scale: scale))
  }

  func height(face: ClassicMacUserInterface.Face, scale: Int) -> CGFloat {
    guard let font = interface.font(face) else { return 0 }
    return CGFloat(font.height(scale: scale))
  }

  /// Draws a line with its top-left corner at the point. The view is flipped,
  /// so the text runs down and to the right from there.
  func draw(
    _ text: String, face: ClassicMacUserInterface.Face, at origin: CGPoint, scale: Int,
    alpha: CGFloat = 1
  ) {
    guard let font = interface.font(face) else { return }
    var pen = origin.x
    let step = CGFloat(font.cellWidth * scale)
    for character in text {
      defer { pen += step }
      guard let glyph = font.glyph(for: character),
        let image = image(for: glyph, key: "\(face.rawValue)-\(character)")
      else { continue }
      let rect = CGRect(
        x: pen + CGFloat(glyph.x * scale), y: origin.y + CGFloat(glyph.y * scale),
        width: CGFloat(glyph.width * scale), height: CGFloat(glyph.height * scale))
      image.draw(
        in: rect, from: .zero, operation: .sourceOver, fraction: alpha,
        respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
    }
  }

  /// Draws a line centered in a width, which is how every menu row is set.
  func drawCentered(
    _ text: String, face: ClassicMacUserInterface.Face, centerX: CGFloat, top: CGFloat,
    scale: Int, alpha: CGFloat = 1
  ) {
    let origin = CGPoint(x: centerX - width(of: text, face: face, scale: scale) / 2, y: top)
    draw(text, face: face, at: origin, scale: scale, alpha: alpha)
  }

  /// The title logo, fitted to a box. Whole-number scales are preferred, and
  /// a fraction is used only when the box is smaller than the artwork.
  func drawLogo(
    centerX: CGFloat, top: CGFloat, maximumWidth: CGFloat, maximumHeight: CGFloat
  ) -> CGFloat {
    guard let logo = interface.logo, let image = image(for: logo, key: "logo"),
      logo.width > 0, logo.height > 0
    else { return 0 }
    let fit = min(maximumWidth / CGFloat(logo.width), maximumHeight / CGFloat(logo.height))
    // Below one, the logo has to shrink, and a whole number is not available.
    let factor = fit >= 1 ? CGFloat(max(1, Int(fit))) : fit
    let size = CGSize(width: CGFloat(logo.width) * factor, height: CGFloat(logo.height) * factor)
    image.draw(
      in: CGRect(x: centerX - size.width / 2, y: top, width: size.width, height: size.height),
      from: .zero, operation: .sourceOver, fraction: 1,
      respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
    return size.height
  }

  var logoAspect: CGFloat? {
    guard let logo = interface.logo, logo.width > 0 else { return nil }
    return CGFloat(logo.height) / CGFloat(logo.width)
  }

  // MARK: - Images

  private func image(for frame: ClassicMacArtwork.Frame, key: String) -> NSImage? {
    if let cached = cache[key] { return cached }
    guard let provider = CGDataProvider(data: frame.rgba as CFData),
      let cg = CGImage(
        width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { return nil }
    let image = NSImage(cgImage: cg, size: NSSize(width: frame.width, height: frame.height))
    cache[key] = image
    return image
  }
}
