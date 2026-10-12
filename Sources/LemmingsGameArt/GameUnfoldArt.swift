import CoreGraphics
import Foundation
import NxlvKit

/// The shipped walker takes a few steps along the menu's stone border on unfold.
public final class GameUnfoldArt {
    public let frames: [CGImage]

    public init?(directory: URL) {
        guard let artwork = try? ClassicMacArtwork(directory: directory) else { return nil }
        frames = (0..<8).compactMap { tick in
            guard let frame = artwork.lemming(pose: .walking, left: false, tick: tick),
                  let provider = CGDataProvider(data: frame.rgba as CFData) else { return nil }
            return CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
                           bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                           provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        }
        guard frames.count == 8 else { return nil }
    }

    public func frame(in region: CGRect, progress: CGFloat) -> CGRect {
        let image = frames[0]
        let width = CGFloat(image.width) * 2, height = CGFloat(image.height) * 2
        let distance = min(96, max(0, region.width - width - 32))
        return CGRect(x: floor(region.midX - distance / 2 + distance * min(1, max(0, progress)) - width / 2),
                      y: floor(region.maxY - height - 16), width: width, height: height)
    }

    public func draw(in context: CGContext, region: CGRect, progress: CGFloat) {
        let tick = min(15, max(0, Int(progress * 16)))
        context.saveGState()
        context.interpolationQuality = .none
        GameStoneArt.drawImage(frames[tick % frames.count], in: frame(in: region, progress: progress), context: context)
        context.restoreGState()
    }
}
