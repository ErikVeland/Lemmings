import CoreGraphics
import NxlvKit

/// A fixed shelf outside the scrolling page. Back remains part of the page beneath it.
public enum GameNavigationArt {
    public static func actions(back: Bool = false, backTitle: String? = nil, secondary: String? = nil) -> [GameFrontEnd.Action] {
        (back ? [.init("navigation.back", backTitle ?? L10n.text("Back"), backNavigation: true)] : [])
            + [.init("navigation.home", L10n.text("Main menu"), backNavigation: false)]
            + (secondary.map { [.init("navigation.secondary", $0, backNavigation: false)] } ?? [])
    }

    public static func layout(width: CGFloat, actions: [GameFrontEnd.Action], television: Bool = false) -> GameFrontEnd.Layout {
        let buttonHeight: CGFloat = television ? 76 : 44
        let gap: CGFloat = 8
        let inset: CGFloat = 6
        let available = max(0, width - inset * 2)
        let minimum = actions.map { GameTextLayout.width(of: $0.title) + 24 }.max() ?? 44
        let columns = max(1, min(actions.count, Int((available + gap) / (minimum + gap))))
        let cell = min(television ? 320 : 220, (available - CGFloat(columns - 1) * gap) / CGFloat(columns))
        let rows = max(1, Int(ceil(Double(actions.count) / Double(columns))))
        let height = inset * 2 + CGFloat(rows) * buttonHeight + CGFloat(rows - 1) * gap
        let targets = actions.enumerated().map { index, action in
            GameFrontEnd.Target(action: action, frame: CGRect(x: inset + CGFloat(index % columns) * (cell + gap),
                y: inset + CGFloat(index / columns) * (buttonHeight + gap), width: cell, height: buttonHeight))
        }
        return GameFrontEnd.Layout(size: CGSize(width: width, height: height), board: .zero, heading: .zero, subtitle: .zero,
            preview: .zero, details: [], targets: targets)
    }
}
