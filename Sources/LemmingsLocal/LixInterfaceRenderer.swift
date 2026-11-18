import AppKit
import NxlvKit
import LemmingsGameArt

/**
 * Caches the pinned Lix interface pixels for native controls.
 */
@MainActor final class LixInterfaceRenderer {
    static let shared = LixInterfaceRenderer()
    private let injectedDirectory: URL?
    private var loadedRevision: String?
    private var loadedArtwork: LixInterfaceArtwork?
    private let images = NSCache<NSString, NSImage>()
    private var artwork: LixInterfaceArtwork? {
        let revision = injectedDirectory?.path ?? GameResources.revision
        if loadedRevision != revision {
            loadedRevision = revision
            let directory = injectedDirectory ?? GameResources.directory("AlternativeAssets/Lix")
            loadedArtwork = directory.flatMap { try? LixInterfaceArtwork(directory: $0) }
            images.removeAllObjects()
        }
        return loadedArtwork
    }
    var isAvailable: Bool { artwork != nil }
    var isEnabled: Bool {
        isAvailable && (CharacterArtworkPreference.lixEnabled || GameMenuArtwork.renderer() == nil)
    }

    init(directory: URL? = nil) {
        injectedDirectory = directory
        images.totalCostLimit = 8 * 1024 * 1024
    }

    @discardableResult func drawButton(_ rect: CGRect, selected: Bool = false,
                                      pressed: Bool = false, enabled: Bool = true) -> Bool {
        let state = state(selected: selected, pressed: pressed, enabled: enabled)
        let width = max(1, Int(rect.width.rounded())), height = max(1, Int(rect.height.rounded()))
        guard let frame = artwork?.button(width: width, height: height, state: state, border: 2),
              let image = image(frame, key: "button-\(width)-\(height)-\(state)") else { return false }
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
                   respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
        return true
    }

    @discardableResult func drawControl(_ control: LixInterfaceArtwork.Control, in rect: CGRect,
                                       selected: Bool = false, enabled: Bool = true) -> Bool {
        let state = state(selected: selected, enabled: enabled)
        guard let frame = artwork?.control(control, state: state),
              let image = image(frame, key: "control-\(control)-\(state)") else { return false }
        draw(image, in: rect)
        return true
    }

    @discardableResult func drawSkill(named name: String, in rect: CGRect,
                                     selected: Bool = false, enabled: Bool = true) -> Bool {
        guard let activity = Self.activity(forSkill: name),
              let frame = artwork?.skill(activity, enabled: enabled),
              let image = image(frame, key: "skill-\(activity)-\(enabled)") else { return false }
        draw(image, in: rect)
        return true
    }

    @discardableResult func drawCheckbox(checked: Bool, in rect: CGRect,
                                        selected: Bool = false, enabled: Bool = true) -> Bool {
        let state = state(selected: selected, enabled: enabled)
        guard let frame = artwork?.checkbox(checked: checked, state: state),
              let image = image(frame, key: "checkbox-\(checked)-\(state)") else { return false }
        draw(image, in: rect)
        return true
    }

    private func state(selected: Bool, pressed: Bool = false, enabled: Bool) -> LixInterfaceArtwork.State {
        !enabled ? .disabled : pressed ? .pressed : selected ? .selected : .normal
    }

    private func image(_ frame: LixInterfaceArtwork.Frame, key: String) -> NSImage? {
        if let cached = images.object(forKey: key as NSString) { return cached }
        if key.hasPrefix("control-") || key.hasPrefix("skill-"),
           let bitmap = GameLixInterfaceArt.iconImage(frame) {
            let image = NSImage(cgImage: bitmap, size: CGSize(width: bitmap.width, height: bitmap.height))
            images.setObject(image, forKey: key as NSString, cost: frame.rgba.count)
            return image
        }
        guard let provider = CGDataProvider(data: frame.rgba as CFData),
              let bitmap = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: .init(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        let image = NSImage(cgImage: bitmap, size: CGSize(width: frame.width, height: frame.height))
        images.setObject(image, forKey: key as NSString, cost: frame.rgba.count)
        return image
    }

    private func draw(_ image: NSImage, in rect: CGRect) {
        guard rect.width > 0, rect.height > 0 else { return }
        let fit = min(rect.width / image.size.width, rect.height / image.size.height)
        let scale = fit >= 0.5 ? floor(fit * 2) / 2 : fit
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(x: floor(rect.midX - size.width / 2), y: floor(rect.midY - size.height / 2),
            width: size.width, height: size.height), from: .zero, operation: .sourceOver,
            fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
    }

    private static func activity(forSkill name: String) -> LixArtwork.Activity? {
        switch name.lowercased() {
        case "climber": .climber
        case "floater": .floater
        case "bomber": .imploder
        case "blocker": .blocker
        case "builder": .builder
        case "basher": .basher
        case "miner": .miner
        case "digger": .digger
        case "walker": .walker
        case "jumper": .jumper
        case "runner": .runner
        case "platformer": .platformer
        default: nil
        }
    }
}
