import CoreGraphics
import Foundation
import NxlvKit

/// The same shipped poses used by the Mac player portraits.
public final class GamePortraitArt {
    private let images: [CGImage?]
    public init?(directory: URL) {
        guard let artwork = try? ClassicMacArtwork(directory: directory) else { return nil }
        let poses: [ClassicLemmingPose] = [.walking, .climbing, .floating, .building, .bashing, .mining, .digging, .blocking]
        images = poses.map { pose in
            guard let frame = artwork.lemming(pose: pose, left: false, tick: 3),
                  let provider = CGDataProvider(data: frame.rgba as CFData) else { return nil }
            return CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
                           bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                           provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        }
    }
    public func image(_ portrait: Int) -> CGImage? {
        images.indices.contains(portrait) ? images[portrait] : nil
    }
    public func draw(_ portrait: Int, in box: CGRect, context: CGContext) {
        guard let image = image(portrait) else { return }
        let scale = max(1, floor(min(box.width / CGFloat(image.width), box.height / CGFloat(image.height))))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        GameStoneArt.drawImage(image, in: CGRect(x: floor(box.midX - size.width / 2),
            y: floor(box.midY - size.height / 2), width: size.width, height: size.height), context: context)
    }
}
