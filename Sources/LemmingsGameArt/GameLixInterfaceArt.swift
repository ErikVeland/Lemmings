import CoreGraphics
import Foundation
import NxlvKit

/**
 * Draws the cleared Lix interface inside the existing control and input geometry.
 */
public enum GameLixInterfaceArt {
    private struct Raster: @unchecked Sendable { let image: CGImage }
    private static let images = GameAssetCache<Raster>(capacity: 128)

    @discardableResult public static func drawButton(in context: CGContext, frame: CGRect,
        selected: Bool, pressed: Bool = false, enabled: Bool = true, shape: GameControlShape = .square) -> Bool {
        let state: LixInterfaceArtwork.State = !enabled ? .disabled : pressed ? .pressed : selected ? .selected : .normal
        let width = max(1, Int(frame.width.rounded())), height = max(1, Int(frame.height.rounded()))
        guard let source = GameArtworkResources.lixInterface?.button(width: width, height: height, state: state),
              let image = image(source, key: "button-\(width)-\(height)-\(state)") else { return false }
        context.saveGState(); defer { context.restoreGState() }
        context.addPath(shape.path(in: frame)); context.clip()
        GameStoneArt.drawImage(image, in: frame, context: context)
        return true
    }

    @discardableResult public static func drawControl(_ control: LixInterfaceArtwork.Control, in frame: CGRect,
        context: CGContext, selected: Bool = false, enabled: Bool = true) -> Bool {
        let state: LixInterfaceArtwork.State = !enabled ? .disabled : selected ? .selected : .normal
        guard let source = GameArtworkResources.lixInterface?.control(control, state: state),
              let image = image(source, key: "control-\(control)-\(state)") else { return false }
        draw(image, in: frame, context: context); return true
    }

    @discardableResult public static func drawSkill(_ activity: LixArtwork.Activity, in frame: CGRect,
        context: CGContext, enabled: Bool = true) -> Bool {
        guard let source = GameArtworkResources.lixInterface?.skill(activity, enabled: enabled),
              let image = image(source, key: "skill-\(activity)-\(enabled)") else { return false }
        draw(image, in: frame, context: context); return true
    }

    @discardableResult public static func drawCheckbox(checked: Bool, in frame: CGRect,
        context: CGContext, selected: Bool = false, enabled: Bool = true) -> Bool {
        let state: LixInterfaceArtwork.State = !enabled ? .disabled : selected ? .selected : .normal
        guard let source = GameArtworkResources.lixInterface?.checkbox(checked: checked, state: state),
              let image = image(source, key: "check-\(checked)-\(state)") else { return false }
        draw(image, in: frame, context: context); return true
    }

    /// Fit the visible icon, excluding the transparent padding in its source cell.
    public static func iconImage(_ frame: LixInterfaceArtwork.Frame) -> CGImage? {
        let bytes = [UInt8](frame.rgba)
        var left = frame.width, top = frame.height, right = -1, bottom = -1
        for y in 0..<frame.height { for x in 0..<frame.width {
            if bytes[(y * frame.width + x) * 4 + 3] > 0 {
                left = min(left, x); right = max(right, x)
                top = min(top, y); bottom = max(bottom, y)
            }
        } }
        guard right >= left, bottom >= top,
              let provider = CGDataProvider(data: frame.rgba as CFData),
              let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: frame.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        return image.cropping(to: CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1))
    }

    private static func image(_ frame: LixInterfaceArtwork.Frame, key: String) -> CGImage? {
        if let raster = images.value(for: key) { return raster.image }
        if key.hasPrefix("control-") || key.hasPrefix("skill-"), let image = iconImage(frame) {
            images.insert(Raster(image: image), for: key)
            return image
        }
        guard let provider = CGDataProvider(data: frame.rgba as CFData),
              let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: frame.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        images.insert(Raster(image: image), for: key)
        return image
    }
    private static func draw(_ image: CGImage, in frame: CGRect, context: CGContext) {
        guard frame.width > 0, frame.height > 0 else { return }
        let fit = min(frame.width / CGFloat(image.width), frame.height / CGFloat(image.height))
        let scale = fit >= 0.5 ? floor(fit * 2) / 2 : fit
        let width = CGFloat(image.width) * scale, height = CGFloat(image.height) * scale
        GameStoneArt.drawImage(image, in: CGRect(x: floor(frame.midX - width / 2), y: floor(frame.midY - height / 2),
            width: width, height: height), context: context)
    }
}
