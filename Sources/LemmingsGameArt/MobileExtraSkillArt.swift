import LemmingsMobileCore
import NxlvKit

/// The same bitmap action list serves touch, controller and accessibility input.
public enum MobileExtraSkillArt {
    public static func page(_ choices: [MobileExtraSkillChoice]) -> GameFrontEnd.Page {
        .init(title: L10n.text("BONUS SKILL"), subtitle: L10n.text("Bonus records. No new rewards."),
            rows: choices.enumerated().map { .init(String($0.offset + 1), L10n.text("+1 \($0.element.title)")) },
            footer: [.init("0", L10n.text("BACK"))])
    }
}
