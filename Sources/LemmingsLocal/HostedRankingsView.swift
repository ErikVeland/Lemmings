import AppKit
import NxlvKit

@MainActor extension ArcadeView {
    func openWorldwideBoard() {
        usesGameCenter = false; boardScope = .worldwide; hostedPage = 0
        if level?.conditions == nil { hostedCategory = .stars }
        page(.records)
        HostedRankings.shared.onChange = { [weak self] in self?.needsDisplay = true }
        HostedRankings.shared.onSyncComplete = { [weak self] in self?.refreshHostedBoard() }
        HostedRankings.shared.completed(profileID: player.id)
        refreshHostedBoard()
    }
    func refreshHostedBoard() {
        guard boardScope == .worldwide, !usesGameCenter else { return }
        HostedRankings.shared.refresh(conditions: level?.conditions, category: hostedCategory, assisted: assisted, page: hostedPage)
    }
    func drawWorldwideBoard() {
        if usesGameCenter { drawGameCenterBoard(); return }
        header("Worldwide leaderboard"); tabs(); boardScopeLinks()
        let service = HostedRankings.shared
        let choices = HostedCategory.allCases.filter { $0.career || level?.conditions != nil }
        let index = choices.firstIndex(of: hostedCategory) ?? 0
        button("‹", CGRect(x: 64, y: 212, width: 66, height: 44)) { [weak self] in
            guard let self else { return }
            hostedCategory = choices[(index + choices.count - 1) % choices.count]; hostedPage = 0; refreshHostedBoard()
        }
        text(hostedCategory.title, 153, 218, 520)
        button("›", CGRect(x: 687, y: 212, width: 66, height: 44)) { [weak self] in
            guard let self else { return }
            hostedCategory = choices[(index + 1) % choices.count]; hostedPage = 0; refreshHostedBoard()
        }
        rewindFilter()
        text("RANK", 80, 273, 130); text("PLAYER", 230, 273, 240)
        text("RESULT", 495, 273, 250); text("REPLAY", 780, 273, 270)
        if let board = service.board {
            for (i, row) in board.entries.prefix(5).enumerated() {
                let y = CGFloat(306 + i * 47)
                text("#\(row.rank)", 80, y, 130); text(row.name, 230, y, 240)
                text(hostedCategory.score(row.score), 495, y, 250)
                if row.replay {
                    link("Play replay >", CGRect(x: 780, y: y - 5, width: 270, height: 40), alignment: .left) { [weak self] in
                        service.playback(row) { [weak self] url, title in
                            if let review = self?.onStoredReplay { review(url, title) }
                            else { ReplayMovieWindow.shared.open(url, title: title, save: false) }
                        }
                    }
                } else { text("-", 780, y, 270, alpha: 0.5) }
            }
            if board.entries.isEmpty { text("No shared records yet.", 80, 324, 960) }
            button("‹", CGRect(x: 812, y: 550, width: 64, height: 40), enabled: hostedPage > 0 && !service.busy) { [weak self] in
                guard let self else { return }; hostedPage -= 1; refreshHostedBoard()
            }
            text("\(hostedPage + 1)", 887, 557, 66, alignment: .center)
            button("›", CGRect(x: 975, y: 550, width: 64, height: 40), enabled: board.hasMore && !service.busy) { [weak self] in
                guard let self else { return }; hostedPage += 1; refreshHostedBoard()
            }
        }
        text(service.status, 80, 558, 450, height: 26, alpha: 0.8)
        let sharing = service.sharing(player.id)
        if sharing { text(service.syncStatus, 80, 601, 960, height: 25, alpha: 0.8) }
        if !sharing { text("Public: initials, scores and available replays.", 80, 601, 960, height: 25, alpha: 0.8) }
        link("Game Center >", CGRect(x: 540, y: 550, width: 252, height: 42), alignment: .left) { [weak self] in
            self?.usesGameCenter = true; self?.openGameCenterBoard()
        }
        if sharing || service.hasShared(player.id) {
            link("Remove shared records", CGRect(x: 343, y: 639, width: 363, height: 42), alignment: .left) { [weak self] in
                guard let self else { return }; service.remove(profile: player.id)
            }
        }
        button(service.syncing ? "Sharing..." : sharing ? "Refresh" : "Share as \(player.initials)",
               CGRect(x: 728, y: 632, width: 312, height: 50), selected: !sharing,
               enabled: !service.syncing && !service.busy) { [weak self] in
            guard let self else { return }
            if !sharing { service.setSharing(true, profile: player.id) }
            else { service.completed(profileID: player.id) }
            refreshHostedBoard()
        }
        pageFooter()
        setAccessibilityLabel("Worldwide community leaderboard. \(hostedCategory.title). Rewinds \(assisted ? "used" : "unused"). \(service.status). " +
            (service.board?.entries.map { "Rank \($0.rank), \($0.name), \(hostedCategory.score($0.score))." }.joined(separator: " ") ?? ""))
    }
}
