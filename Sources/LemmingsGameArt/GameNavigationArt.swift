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
        let minimum = actions.map { action in
            (action.title.split(whereSeparator: \.isWhitespace).map { GameTextLayout.width(of: String($0)) }.max() ?? 0) + 24
        }.max() ?? 44
        let columns = max(1, min(actions.count, Int((available + gap) / (minimum + gap))))
        var remaining = actions.filter { $0.id != "navigation.home" }
        var groups: [[GameFrontEnd.Action]] = []
        if let home = actions.first(where: { $0.id == "navigation.home" }) {
            let leading = min(remaining.count, columns - 1)
            groups.append(Array(remaining.prefix(leading)) + [home])
            remaining.removeFirst(leading)
        }
        while !remaining.isEmpty {
            groups.append(Array(remaining.prefix(columns)))
            remaining.removeFirst(min(columns, remaining.count))
        }
        var y = inset
        let targets = groups.flatMap { group in
            let cell = (available - CGFloat(group.count - 1) * gap) / CGFloat(group.count)
            let height = max(buttonHeight, group.map { GameTextLayout.height($0.title, width: cell - 24) + 12 }.max() ?? buttonHeight)
            defer { y += height + gap }
            return group.enumerated().map { column, action in
                GameFrontEnd.Target(action: action, frame: CGRect(x: inset + CGFloat(column) * (cell + gap),
                    y: y, width: cell, height: height))
            }
        }
        return GameFrontEnd.Layout(size: CGSize(width: width, height: max(inset * 2, y - gap + inset)), board: .zero, heading: .zero, subtitle: .zero,
            preview: .zero, details: [], targets: targets)
    }
}
