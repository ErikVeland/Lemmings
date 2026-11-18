import AppKit
import LemmingsGameArt
import NxlvKit

/// The same timeline buttons and hit regions serve all three game panels.
@MainActor final class TimelinePanelControls {
    enum Action: Int, CaseIterable {
        case rewind, backward, forward, hints
        var label: String {
            switch self {
            case .rewind: return "Rewind two seconds"
            case .backward: return "Step backward one tick"
            case .forward: return "Step forward one tick"
            case .hints: return "Level hints (H)"
            }
        }
        var glyph: PanelGlyph? {
            switch self {
            case .rewind: return .rewind
            case .backward: return .stepBackward
            case .forward: return .stepForward
            case .hints: return nil
            }
        }
    }
    var frame = CGRect.zero
    var groupFrame: CGRect?
    var monochrome = false
    var rock: ((CGSize) -> NSImage?)?
    var enabled: (Action) -> Bool = { _ in false }
    var perform: (Action) -> Void = { _ in }
    private let accessibility = GameAccessibleElements()

    func rect(for action: Action) -> CGRect {
        let unit = frame.width / 4.5
        return CGRect(x: frame.minX + CGFloat(action.rawValue) * unit, y: frame.minY,
                      width: (action == .hints ? unit * 1.5 : unit) - 2, height: frame.height)
    }
    func draw() {
        NSColor.black.setFill(); frame.fill()
        for action in Action.allCases {
            let box = rect(for: action)
            if LixInterfaceRenderer.shared.isEnabled {
                let control: LixInterfaceArtwork.Control
                switch action {
                case .rewind: control = .rewind
                case .backward: control = .stepBackward
                case .forward: control = .stepForward
                case .hints: control = .help
                }
                if let context = NSGraphicsContext.current?.cgContext {
                    GameControlGroupArt.draw(in: context, frame: box, group: groupFrame ?? frame,
                        selected: false, face: action == .hints ? .hints : .rewind, monochrome: monochrome)
                }
                LixInterfaceRenderer.shared.drawControl(control, in: box.insetBy(dx: 2, dy: 2), enabled: enabled(action))
                continue
            }
            if let context = NSGraphicsContext.current?.cgContext {
                let face: GamePlayButtonArt.Face = action == .rewind ? .rewind : action == .backward ? .stepBackward : .stepForward
                GameControlGroupArt.draw(in: context, frame: box, group: groupFrame ?? frame,
                    selected: false, face: face, monochrome: monochrome)
            }
            let alpha: CGFloat = enabled(action) ? 1 : 0.3
            if let image = (monochrome ? action.glyph?.monochromeImage(fitting: box.insetBy(dx: 4, dy: 4).size) : action.glyph?.image(fitting: box.insetBy(dx: 4, dy: 4).size)) {
                image.draw(in: CGRect(x: box.midX - image.size.width / 2, y: box.midY - image.size.height / 2,
                    width: image.size.width, height: image.size.height), from: .zero, operation: .sourceOver,
                    fraction: alpha, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
            } else {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current?.cgContext.setAlpha(alpha)
                GamePixelText.draw("HINT", in: box.insetBy(dx: 4, dy: 4), maxScale: 2)
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
    /// Consume gaps and disabled buttons so input never reaches the playfield.
    @discardableResult func click(at point: CGPoint) -> Bool {
        guard frame.contains(point) else { return false }
        if let action = Action.allCases.first(where: { rect(for: $0).contains(point) }), enabled(action) {
            perform(action)
        }
        return true
    }
    func accessibleControls(owner: NSView, transform: (CGRect) -> CGRect = { $0 }) -> [Any] {
        Action.allCases.map { action in
            let element = accessibility.element(id: "timeline-\(action.rawValue)", owner: owner,
                label: action.label, frame: transform(rect(for: action))) { [weak self] in
                    guard let self, self.enabled(action) else { return }
                    self.perform(action)
                }
            element.setAccessibilityEnabled(enabled(action))
            return element
        }
    }
}
