import Foundation
import NxlvKit

/// The phone and TV library share the same bounded collection tree as the Mac.
public enum FanLevelLibraryArt {
    public static func page(root: FanLevelOrganisation.Group, path: [String], query: String = "",
                            editing: Bool = false, status: String = "", updating: Bool = false,
                            packDetails: [String: String] = [:]) -> GameFrontEnd.Page {
        let group = root.group(at: path) ?? root
        let rows = group.children.map { child -> GameFrontEnd.Action in
            if let pack = child.packID { return .init("pack." + pack, child.title + (packDetails[pack] ?? "")) }
            return .init("fanGroup." + child.id, child.title + "  (\(child.packIDs.count)) >")
        }
        let count = L10n.plural("count.packs", count: group.packIDs.count, one: "%ld pack", other: "%ld packs")
        let footer: [GameFrontEnd.Action] = [
            .init(path.isEmpty ? "home" : "fanGroupBack", L10n.text("Back"))
        ]
        var tools: [GameFrontEnd.Action] = [
            .init("search", L10n.text("Search") + (query.isEmpty ? "" : ": " + query) + (editing ? "_" : ""), selected: !query.isEmpty)
        ]
        if !query.isEmpty { tools.append(.init("searchClear", L10n.text("Clear"))) }
        if path.isEmpty {
            tools.append(.init("shuffleAll", L10n.text("Shuffle all"), enabled: !root.packIDs.isEmpty))
            tools.append(.init("fanUpdate", updating ? L10n.text("Checking for new packs...") : L10n.text("Check for new packs"), enabled: !updating))
        }
        var page = GameFrontEnd.Page(title: group.title, subtitle: status.isEmpty ? count : status,
                                     rows: rows, footer: footer, footerColumns: 2)
        page.pairsRows = true
        page.listTools = tools
        return page
    }
}
