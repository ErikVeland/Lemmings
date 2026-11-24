#if os(iOS) || os(tvOS)
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

extension MobileLibraryViewController {
    var previewBrowseLevels: [MobileLevelSummary] {
        if levelsBackRoute == .levelCatalogue, !cataloguePreviewLevels.isEmpty { return cataloguePreviewLevels }
        return library?.levels ?? []
    }

    func openLevelCatalogue(back: Route) {
        cataloguePreviewLevels = []
        catalogueReturn = back
        catalogueQuery = ""
        catalogueFilter = .all
        cataloguePageIndex = 0
        levelsBackRoute = .levelCatalogue
        navigate(.levelCatalogue)
    }

    func levelCataloguePage(subtitle: String) -> GameFrontEnd.Page {
        let neo = library as? NeoLemmixMobileLibrary
        let packs = neo?.cataloguePacks ?? [library?.levels ?? []]
        let unavailable = neo?.unavailableIndices ?? []
        return CatalogueLevelArt.page(title: currentPack?.title ?? library?.displayName ?? L10n.text("Levels"),
            packs: packs, cleared: solved, unavailable: unavailable, query: catalogueQuery, filter: catalogueFilter,
            editing: searchField.isFirstResponder, pageIndex: cataloguePageIndex, status: subtitle)
    }

    func handleLevelCatalogue(_ id: String) -> Bool {
        guard route == .levelCatalogue else { return false }
        switch id {
        case "catalogueBack":
            if catalogueReturn == .home { navigateToBrowseRoot() } else { navigate(catalogueReturn) }
        case "catalogueProgress":
            catalogueFilter = catalogueFilter.next
            cataloguePageIndex = 0
            scrollView.setContentOffset(.zero, animated: false)
            rebuild()
        case "catalogueReset":
            catalogueQuery = ""
            searchField.text = ""
            catalogueFilter = .all
            cataloguePageIndex = 0
            scrollView.setContentOffset(.zero, animated: false)
            rebuild()
        case "cataloguePrevious", "catalogueNext":
            guard canvas.page.footer.contains(where: { $0.id == id && $0.enabled }) else { return true }
            cataloguePageIndex += id == "catalogueNext" ? 1 : -1
            scrollView.setContentOffset(.zero, animated: false)
            rebuild()
        default:
            let prefix = "catalogue.level."
            guard id.hasPrefix(prefix), let index = Int(id.dropFirst(prefix.count)),
                  canvas.page.rows.contains(where: { $0.id == id && $0.enabled }) else { return false }
            let neo = library as? NeoLemmixMobileLibrary
            let unavailable = neo?.unavailableIndices ?? []
            cataloguePreviewLevels = CatalogueLevelArt.matchingLevels(packs: neo?.cataloguePacks ?? [library?.levels ?? []],
                cleared: solved, query: catalogueQuery, filter: catalogueFilter).filter { !unavailable.contains($0.index) }
            selectedIndex = index
            selectedPreview = nil
            browserShown = false
            navigate(.levels)
            selectLevel(index)
        }
        return true
    }
}
#endif
