import CoreGraphics
import LemmingsMobileCore
import NxlvKit

public enum MobileSettingsTabsArt {
    /**
     * Keeps the same settings groups and restrictions as the portrait index.
     */
    public static func actions(selected: MobileSettingsGroup, inGame: Bool, television: Bool = false) -> [GameFrontEnd.Action] {
        MobileSettingsGroup.allCases.filter { (!inGame && !television) || $0 != .deskClock }.map {
            .init("settingsTab." + $0.rawValue, $0.title, selected: $0 == selected)
        } + (inGame ? [] : [.init("data", L10n.text("Game Data"))])
    }

    public static func usesTabs(width: CGFloat, height: CGFloat) -> Bool {
        width > height
    }

    /**
     * Full captions retain their own targets. Narrow shelves scroll horizontally.
     */
    public static func layout(width: CGFloat, actions: [GameFrontEnd.Action], television: Bool = false) -> GameFrontEnd.Layout {
        let height: CGFloat = television ? 76 : 44
        var x: CGFloat = 6
        let targets = actions.map { action in
            let extent = max(88, GameTextLayout.width(of: action.title) + 32)
            defer { x += extent + 8 }
            return GameFrontEnd.Target(action: action, frame: CGRect(x: x, y: 6, width: extent, height: height))
        }
        return .init(size: CGSize(width: max(width, x - 2), height: height + 12), board: .zero,
            heading: .zero, subtitle: .zero, preview: .zero, details: [], targets: targets)
    }
}
