#if os(macOS)
import AppKit
import LemmingsAppCore
import NxlvKit

@MainActor extension ArcadeView {
    func openWorldwideBoard() {
        usesGameCenter = false; boardScope = .worldwide; hostedPage = 0
        if !hostedCategory.career { hostedCategory = .stars }
        page(.records)
        HostedRankings.shared.onChange = { [weak self] in self?.needsDisplay = true }
        HostedRankings.shared.onSyncComplete = { [weak self] in self?.refreshHostedBoard() }
        HostedRankings.shared.completed(profileID: player.id)
        refreshHostedBoard()
    }
    func refreshHostedBoard() {
        guard boardScope == .worldwide, !usesGameCenter else { return }
        // Worldwide is one list of every shared player. Level rankings live on each level's result screen.
        HostedRankings.shared.refresh(conditions: nil, category: hostedCategory, assisted: false, page: hostedPage)
    }
    func drawWorldwideBoard() {
        if usesGameCenter { drawGameCenterBoard(); return }
        leaderboardTabs()
        let service = HostedRankings.shared
        // Same columns as This Mac. Older servers send only the selected total, so the others show a dash.
        text(L10n.text("RANK"), 80, 214, 90); text(L10n.text("PLAYER"), 174, 214, 300); text(L10n.text("STARS"), 524, 214, 140)
        text(L10n.text("CLEARED"), 724, 214, 160); text(L10n.text("3-STAR"), 924, 214, 120)
        if let board = service.board {
            for (i, row) in board.entries.prefix(6).enumerated() {
                let y = CGFloat(254 + i * 47)
                let rect = CGRect(x: 80, y: y - 5, width: 960, height: 44)
                GameStyle.fill(rect, row.name == player.initials ? GameStyle.gold.withAlphaComponent(0.12) : .clear)
                func total(_ value: Int?, _ category: HostedCategory) -> String {
                    value.map(String.init) ?? (hostedCategory == category ? String(row.score) : "-")
                }
                rowText("\(row.rank)", x: 96, width: 60, row: rect)
                rowText(row.name, x: 174, width: 300, row: rect, palette: .green)
                rowText(total(row.stars, .stars), x: 524, width: 140, row: rect)
                rowText(total(row.clears, .clears), x: 724, width: 160, row: rect)
                rowText(total(row.perfect, .perfect), x: 924, width: 120, row: rect)
            }
            if board.entries.isEmpty { text(L10n.text("No scores"), 80, 300, 960, alignment: .center) }
            if hostedPage > 0 || board.hasMore {
                button("‹", CGRect(x: 812, y: 550, width: 64, height: 40), enabled: hostedPage > 0 && !service.busy) { [weak self] in
                    guard let self else { return }; hostedPage -= 1; refreshHostedBoard()
                }
                text("\(hostedPage + 1)", 887, 557, 66, alignment: .center)
                button("›", CGRect(x: 975, y: 550, width: 64, height: 40), enabled: board.hasMore && !service.busy) { [weak self] in
                    guard let self else { return }; hostedPage += 1; refreshHostedBoard()
                }
            }
        } else {
            // Loading keeps the table header in place; the status sits where the first row will appear.
            text(service.status, 80, 300, 960, alignment: .center, alpha: 0.8)
        }
        let sharing = service.sharing(player.id)
        button(service.syncing ? L10n.text("Sharing...") : L10n.text("Share my records"),
               CGRect(x: 736, y: 634, width: 320, height: 48), selected: sharing,
               enabled: service.endpoint != nil && !service.syncing && !service.busy) { [weak self] in
            guard let self else { return }
            if sharing { service.remove(profile: player.id) } else { service.setSharing(true, profile: player.id) }
            refreshHostedBoard()
        }
        pageFooter()
        let entries = service.board?.entries.map { L10n.text("Rank \($0.rank), \($0.name), \(hostedCategory.score($0.score)).") }.joined(separator: " ") ?? ""
        setAccessibilityLabel(L10n.text("Leaderboards. World. \(hostedCategory.title). \(service.status). \(entries)"))
    }
}
#endif
