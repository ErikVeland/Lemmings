import CoreGraphics
import Foundation
import ImageIO
import NxlvKit

/// Places the Ultimate badge across the original logo's upper-left L.
public enum GameMenuLogo {
    /// Centres the original mark while allowing the badge to extend left.
    public static func frame(canvasSize: CGSize, originalWidth: CGFloat, in box: CGRect,
                             topAligned: Bool = false, wholeNumberScale: Bool = true) -> CGRect {
        let overhang = max(0, canvasSize.width - originalWidth)
        let fit = min(box.width / (canvasSize.width + overhang), box.height / canvasSize.height)
        let scale = wholeNumberScale && fit >= 1 ? floor(fit) : fit
        return CGRect(x: floor(box.midX - (overhang + originalWidth / 2) * scale),
            y: topAligned ? box.minY : floor(box.midY - canvasSize.height * scale / 2),
            width: canvasSize.width * scale, height: canvasSize.height * scale)
    }

    public static func image(for logo: ClassicMacArtwork.Frame, letteringURL: URL? = nil) -> CGImage? {
        guard let provider = CGDataProvider(data: logo.rgba as CFData),
              let original = CGImage(width: logo.width, height: logo.height,
                bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: logo.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        let url = letteringURL ?? Bundle.main.resourceURL?.appendingPathComponent("MenuArtwork/ultimate.png")
        guard let url, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let lettering = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return original }
        let scale = CGFloat(logo.width) / 629
        let width = (242 * scale).rounded()
        let wordHeight = (width * CGFloat(lettering.height) / CGFloat(lettering.width)).rounded()
        let angle = 8 * CGFloat.pi / 180
        let anchor = CGPoint(x: (55 * scale).rounded(), y: CGFloat(logo.height) - (50 * scale).rounded())
        // The visual centre of “ima” crosses the L stalk, independent of badge size.
        let wordRect = CGRect(x: -width * 0.59, y: -wordHeight / 2, width: width, height: wordHeight)
        let badgeBounds = wordRect.applying(CGAffineTransform(rotationAngle: angle))
            .offsetBy(dx: anchor.x, dy: anchor.y)
        let leftPadding = Int(ceil(max(0, -badgeBounds.minX)))
        let topPadding = Int(ceil(max(0, badgeBounds.maxY - CGFloat(logo.height))))
        let canvasWidth = logo.width + leftPadding
        let height = logo.height + topPadding
        guard let context = CGContext(data: nil, width: canvasWidth, height: height,
            bitsPerComponent: 8, bytesPerRow: canvasWidth * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return original }
        // Draw original pixels at their native size. Only the new lettering is sampled.
        context.interpolationQuality = .none
        context.draw(original, in: CGRect(x: leftPadding, y: 0, width: logo.width, height: logo.height))
        context.interpolationQuality = .high
        context.translateBy(x: CGFloat(leftPadding) + anchor.x, y: anchor.y)
        context.rotate(by: angle)
        context.draw(lettering, in: wordRect)
        return context.makeImage()
    }
}
