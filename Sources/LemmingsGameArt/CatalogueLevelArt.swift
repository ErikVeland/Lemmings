import Foundation
import LemmingsMobileCore
import NxlvKit

public enum CatalogueLevelArt {
    public static let pageSize = 16

    public static func matchingLevels(packs: [[MobileLevelSummary]], cleared: Set<Int>, query: String,
                                      filter: CatalogueProgressFilter) -> [MobileLevelSummary] {
        packs.flatMap { levels in
            filter.levelsInPack(levels, query: query, title: { [$0.packName, $0.rank, $0.title].joined(separator: " ") },
                                completed: { cleared.contains($0.index) })
        }
    }

    public static func page(title: String, packs: [[MobileLevelSummary]], cleared: Set<Int>,
                            unavailable: Set<Int>, query: String, filter: CatalogueProgressFilter,
                            editing: Bool, pageIndex: Int, status: String) -> GameFrontEnd.Page {
        let matches = matchingLevels(packs: packs, cleared: cleared, query: query, filter: filter)
        let last = max(0, (matches.count - 1) / pageSize)
        let current = min(max(0, pageIndex), last)
        let rows = matches.dropFirst(current * pageSize).prefix(pageSize).map { level in
            let prefix = packs.count > 1 ? level.packName + " / " : ""
            let completion = cleared.contains(level.index) ? "  (" + CatalogueProgressFilter.cleared.title + ")" : ""
            return GameFrontEnd.Action("catalogue.level.\(level.index)", prefix + "\(level.number)  " + level.title + completion,
                                       enabled: !unavailable.contains(level.index))
        }
        var footer = [GameFrontEnd.Action("catalogueBack", L10n.text("Back"))]
        if last > 0 {
            footer.append(.init("cataloguePrevious", L10n.text("Previous"), enabled: current > 0))
            footer.append(.init("catalogueNext", L10n.text("Next"), enabled: current < last))
        }
        let count = L10n.plural("count.levels", count: matches.count, one: "%ld level", other: "%ld levels")
        var page = GameFrontEnd.Page(title: title, subtitle: status.isEmpty ? count : status, rows: rows,
            details: rows.isEmpty ? [L10n.text("No matching levels")] : [], footer: footer)
        page.backActionID = "catalogueBack"
        page.pairsRows = true
        let caption = (query.isEmpty ? L10n.text("Search levels") : query) + (editing ? "_" : "")
        page.listTools = [.init("search", caption, selected: !query.isEmpty),
                          .init("catalogueProgress", filter.title, selected: filter != .all)]
        if !query.isEmpty || filter != .all {
            page.listTools.append(.init("catalogueReset", L10n.text("Clear filters")))
        }
        return page
    }
}
