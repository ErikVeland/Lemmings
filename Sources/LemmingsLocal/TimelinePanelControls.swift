#if os(macOS)
import AppKit
import LemmingsGameArt
#if canImport(NxlvKit)
import NxlvKit
#endif

/// The same timeline buttons and hit regions serve all three game panels.
@MainActor final class TimelinePanelControls {
    enum Action: Int, CaseIterable {
        case rewind, backward, forward
        var label: String {
            switch self {
            case .rewind: return L10n.text("Rewind two seconds")
            case .backward: return L10n.text("Step backward one tick")
            case .forward: return L10n.text("Step forward one tick")
            }
        }
        var glyph: PanelGlyph? {
            switch self {
            case .rewind: return .rewind
            case .backward: return .stepBackward
            case .forward: return .stepForward
            }
        }
    }
    var frame = CGRect.zero
    var monochrome = false
    var rock: ((CGSize) -> NSImage?)?
    var enabled: (Action) -> Bool = { _ in false }
    var perform: (Action) -> Void = { _ in }
    private let accessibility = GameAccessibleElements()

    func rect(for action: Action) -> CGRect {
        let unit = frame.width / CGFloat(Action.allCases.count)
        return CGRect(x: frame.minX + CGFloat(action.rawValue) * unit, y: frame.minY,
                      width: unit, height: frame.height)
    }
    func draw() {
        NSColor.black.setFill(); frame.fill()
        for action in Action.allCases {
            let box = rect(for: action)
            let face: GamePlayButtonArt.Face
            switch action {
            case .rewind: face = .rewind
            case .backward: face = .stepBackward
            case .forward: face = .stepForward
            }
            if let context = NSGraphicsContext.current?.cgContext {
                GameControlGroupArt.draw(in: context, frame: box, group: frame,
                    selected: false, face: face, monochrome: monochrome)
            }
            let alpha: CGFloat = monochrome ? 1 : enabled(action) ? 1 : 0.3
            let size = box.insetBy(dx: 4, dy: 4).size
            if let image = monochrome ? action.glyph?.monochromeImage(fitting: size) : action.glyph?.image(fitting: size) {
                image.draw(in: CGRect(x: box.midX - image.size.width / 2, y: box.midY - image.size.height / 2,
                    width: image.size.width, height: image.size.height), from: .zero, operation: .sourceOver,
                    fraction: alpha, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
            }
            if monochrome && !enabled(action), let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.setFillColor(CGColor(gray: 0, alpha: 1))
                for y in Int(box.minY + 4)..<max(Int(box.minY + 4), Int(box.maxY - 4)) {
                    for x in stride(from: Int(box.minX + 4) + y % 2, to: Int(box.maxX - 4), by: 2) {
                        context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                    }
                }
                context.restoreGState()
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
#endif
