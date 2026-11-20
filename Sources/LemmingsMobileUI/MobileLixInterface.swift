#if os(iOS) || os(tvOS)
import NxlvKit
import UIKit

/**
 * Shares the bundled Lix interface pixels across touch and remote controls.
 */
@MainActor enum MobileLixInterface {
    static var enabled: Bool { LemmingsMobileConfiguration.current == .ultimateLemmix }
    private static let artwork = Bundle.main.resourceURL.flatMap {
        try? LixInterfaceArtwork(directory: $0.appendingPathComponent("AlternativeAssets/Lix"))
    }
    private static let images = NSCache<NSString, UIImage>()

    @discardableResult static func button(in rect: CGRect, selected: Bool = false,
        pressed: Bool = false, enabled: Bool = true) -> Bool {
        let state: LixInterfaceArtwork.State = !enabled ? .disabled : pressed ? .pressed : selected ? .selected : .normal
        let width = max(1, Int(rect.width.rounded())), height = max(1, Int(rect.height.rounded()))
        let key = "button-\(width)-\(height)-\(state)"
        if let cached = images.object(forKey: key as NSString) { cached.draw(in: rect); return true }
        guard let frame = artwork?.button(width: width, height: height, state: state),
              let image = image(key: key,
                width: frame.width, height: frame.height, rgba: frame.rgba) else { return false }
        image.draw(in: rect)
        return true
    }

    @discardableResult static func control(_ control: LixInterfaceArtwork.Control, in rect: CGRect,
        selected: Bool = false, enabled: Bool = true) -> Bool {
        let state: LixInterfaceArtwork.State = !enabled ? .disabled : selected ? .selected : .normal
        let key = "control-\(control)-\(state)"
        if let cached = images.object(forKey: key as NSString) { draw(cached, in: rect); return true }
        guard let frame = artwork?.control(control, state: state),
              let image = image(key: key, width: frame.width,
                height: frame.height, rgba: frame.rgba) else { return false }
        draw(image, in: rect)
        return true
    }

    @discardableResult static func skill(named name: String, in rect: CGRect, enabled: Bool) -> Bool {
        let activity: LixArtwork.Activity
        switch name.lowercased() {
        case "climber": activity = .climber
        case "floater": activity = .floater
        case "bomber": activity = .imploder
        case "blocker": activity = .blocker
        case "builder": activity = .builder
        case "basher": activity = .basher
        case "miner": activity = .miner
        case "digger": activity = .digger
        default: return false
        }
        let key = "skill-\(activity)-\(enabled)"
        if let cached = images.object(forKey: key as NSString) { draw(cached, in: rect); return true }
        guard let frame = artwork?.skill(activity, enabled: enabled),
              let image = image(key: key, width: frame.width,
                height: frame.height, rgba: frame.rgba) else { return false }
        draw(image, in: rect)
        return true
    }

    @discardableResult static func checkbox(checked: Bool, in rect: CGRect, enabled: Bool) -> Bool {
        guard let frame = artwork?.checkbox(checked: checked, state: enabled ? .normal : .disabled),
              let image = image(key: "check-\(checked)-\(enabled)", width: frame.width,
                height: frame.height, rgba: frame.rgba) else { return false }
        draw(image, in: rect)
        return true
    }

    private static func image(key: String, width: Int, height: Int, rgba: Data) -> UIImage? {
        if let cached = images.object(forKey: key as NSString) { return cached }
        guard let provider = CGDataProvider(data: rgba as CFData),
              let bitmap = CGImage(width: width, height: height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: .init(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        let image = UIImage(cgImage: bitmap)
        images.totalCostLimit = 8 * 1024 * 1024
        images.setObject(image, forKey: key as NSString, cost: rgba.count)
        return image
    }

    private static func draw(_ image: UIImage, in rect: CGRect) {
        let fit = min(rect.width / image.size.width, rect.height / image.size.height)
        guard fit > 0 else { return }
        let scale = fit >= 1 ? floor(fit) : fit >= 0.5 ? 0.5 : fit
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        UIGraphicsGetCurrentContext()?.saveGState()
        UIGraphicsGetCurrentContext()?.interpolationQuality = .none
        image.draw(in: CGRect(x: floor(rect.midX - size.width / 2), y: floor(rect.midY - size.height / 2),
                              width: size.width, height: size.height))
        UIGraphicsGetCurrentContext()?.restoreGState()
    }
}
#endif
