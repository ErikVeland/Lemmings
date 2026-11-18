import CoreGraphics
import Foundation
import NxlvKit

/// The same shipped poses used by the Mac player portraits.
public final class GamePortraitArt {
    private let images: [CGImage?]
    public init?(directory: URL) {
        let artwork = try? ClassicMacArtwork(directory: directory)
        let poses: [ClassicLemmingPose] = [.walking, .climbing, .floating, .building, .bashing, .mining, .digging, .blocking]
        images = poses.map { pose in
            if GameArtworkSkin.lixEnabled || artwork == nil,
               let activity = Self.lixActivity(pose), let frame = GameArtworkResources.lixArtwork?.frame(activity: activity, animationFrame: 3, facingLeft: false) {
                return Self.image(rgba: Data(frame.rgba), width: frame.width, height: frame.height)
            }
            guard let frame = artwork?.lemming(pose: pose, left: false, tick: 3),
                  let provider = CGDataProvider(data: frame.rgba as CFData) else { return nil }
            return CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
                           bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                           provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        }
    }
    private static func lixActivity(_ pose: ClassicLemmingPose) -> LixArtwork.Activity? {
        switch pose {
        case .walking: .walker
        case .climbing: .climber
        case .floating: .floater
        case .building: .builder
        case .bashing: .basher
        case .mining: .miner
        case .digging: .digger
        case .blocking: .blocker
        default: nil
        }
    }
    private static func image(rgba: Data, width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: rgba as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent)
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
