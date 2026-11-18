import LemmingsAppCore
import NxlvKit

/// Shared inspection layout for touch, keyboard and TV navigation.
public enum LemmingInspectionArt {
    /// Builds the compact story card used while a player points at an individual.
    public static func hoverPage(_ individual: LemmingInspection.Individual) -> GameFrontEnd.Page {
        let recent = Array(individual.actions.suffix(3).map(\.text))
        let details = [individual.preference, individual.want, individual.status]
            + (recent.isEmpty ? [] : [L10n.text("Recent actions")] + recent)
        var page = GameFrontEnd.Page(title: individual.title, details: details)
        if !recent.isEmpty { page.detailHeadings = [3] }
        return page
    }

    public static func page(_ snapshot: LemmingInspection, index requested: Int = 0, historyPage: Int = 0) -> GameFrontEnd.Page {
        let index = min(max(0, requested), max(0, snapshot.individuals.count - 1))
        guard snapshot.individuals.indices.contains(index) else {
            return .init(title: L10n.text("Lemmings"), details: snapshot.lines(for: index),
                footer: [.init("0", L10n.text("BACK"), primary: true)])
        }
        let individual = snapshot.individuals[index]
        let hasNext = index + 1 < snapshot.individuals.count
        var actions: [GameFrontEnd.Action] = [
            .init("0", L10n.text("BACK"), primary: !hasNext),
            .init("1", L10n.text("PREVIOUS"), enabled: index > 0),
            .init("2", L10n.text("NEXT"), enabled: hasNext, primary: hasNext)
        ]
        if LemmingInspection.lastHistoryPage(for: individual) > 0 {
            actions += [
                .init("3", L10n.text("EARLIER ACTIONS"), enabled: historyPage > 0),
                .init("4", L10n.text("LATER ACTIONS"), enabled: historyPage < LemmingInspection.lastHistoryPage(for: individual))
            ]
        }
        var page = GameFrontEnd.Page(title: individual.title,
            details: snapshot.lines(for: index, historyPage: historyPage), footer: actions)
        page.detailHeadings = [3]
        return page
    }
}
