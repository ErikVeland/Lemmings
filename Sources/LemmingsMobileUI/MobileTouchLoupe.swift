#if os(iOS) || os(tvOS)
import LemmingsMobileCore
import UIKit

/// A view of the existing bitmap, above the finger and outside the input tree.
@MainActor final class MobileTouchLoupe: UIView {
    private let imageView = UIImageView()
    private let countdownView = MobileBombCountdownView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        isHidden = true
        backgroundColor = .black
        layer.borderWidth = 2
        layer.borderColor = CGColor(srgbRed: 0.45, green: 1, blue: 0.10, alpha: 1)
        imageView.layer.magnificationFilter = .nearest
        imageView.layer.minificationFilter = .nearest
        imageView.contentMode = .scaleToFill
        addSubview(imageView)
        addSubview(countdownView)
    }

    required init?(coder: NSCoder) { nil }

    func update(bitmap: MobilePixelFrame, target: MobilePoint, finger: CGPoint, bounds safe: CGRect,
        pixelAspect: Double, countdowns: [MobileBombCountdown] = [], renderScale: Double = 1) {
        guard safe.width > 4, safe.height > 4,
              let crop = try? bitmap.cropped(around: target, width: 64, height: 40),
              let provider = CGDataProvider(data: crop.rgba as CFData),
              let image = CGImage(width: crop.width, height: crop.height,
                                  bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: crop.width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { isHidden = true; return }
        let width = min(192, safe.width)
        let height = min(width * CGFloat(crop.height) / CGFloat(crop.width) * CGFloat(pixelAspect), safe.height)
        let x = min(max(safe.minX, finger.x - width / 2), safe.maxX - width)
        var y = finger.y - height - 44
        if y < safe.minY { y = finger.y + 44 }
        y = min(max(safe.minY, y), safe.maxY - height)
        frame = CGRect(x: x, y: y, width: width, height: height)
        imageView.frame = self.bounds.insetBy(dx: 2, dy: 2)
        imageView.image = UIImage(cgImage: image)
        let sourceScale = max(1, renderScale)
        let cropX = min(Double(bitmap.width - crop.width), max(0, target.x - Double(crop.width) / 2))
        let cropY = min(Double(bitmap.height - crop.height), max(0, target.y - Double(crop.height) / 2))
        let scaleY = imageView.bounds.height / Double(crop.height)
        let scaleX = imageView.bounds.width / Double(crop.width)
        let viewport = MobileViewport(
            levelSize: .init(width: Double(bitmap.width) / sourceScale, height: Double(bitmap.height) / sourceScale),
            viewSize: .init(width: imageView.bounds.width, height: imageView.bounds.height),
            origin: .init(x: floor(cropX) / sourceScale, y: floor(cropY) / sourceScale),
            zoom: scaleY * sourceScale, pixelAspect: scaleX / scaleY,
            maximumZoom: max(12, scaleY * sourceScale))
        countdownView.frame = imageView.frame
        let localCountdowns: [MobileBombCountdown]
        if let region = bitmap.renderedRect {
            localCountdowns = countdowns.map {
                MobileBombCountdown(id: $0.id, seconds: $0.seconds,
                    anchor: .init(x: $0.anchor.x - region.x, y: $0.anchor.y - region.y))
            }
        } else { localCountdowns = countdowns }
        countdownView.update(localCountdowns, viewport: viewport, project: nil)
        isHidden = false
    }
}
#endif
