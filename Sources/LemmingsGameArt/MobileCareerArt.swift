import Foundation
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit

/// Career pages use the same bitmap composition in the app and headless audit.
public enum MobileCareerArt {
    private static func sourceLabel(_ level: ArcadeLevel) -> String {
        guard let conditions = level.conditions else { return "" }
        if conditions.gameID == L10n.text("fan") || conditions.gameID == L10n.text("neolemmix") { return L10n.text("Fan-made") }
        return ClassicTitle(rawValue: conditions.gameID) == nil ? "" : L10n.text("Official")
    }

    public static func players(_ profiles: MobileProfiles, subtitle: String, draft: String? = nil,
                               creating: Bool = false, portrait: Int = 0,
                               canDelete: Bool = false, confirmingDelete: Bool = false,
                               hotSeatTurn: String? = nil, holdToEdit: Bool = false,
                               editingPlayerID: String? = nil, hasSavedHotSeats: Bool = false) -> GameFrontEnd.Page {
        if let draft {
            var page: GameFrontEnd.Page
            if confirmingDelete && !creating {
                page = .init(title: L10n.text("Delete player?"), subtitle: subtitle,
                    details: [L10n.text("Deletes this player's records and saved progress on linked devices.")],
                    footer: [.init("playerDeleteCancel", L10n.text("Cancel")),
                             .init("playerDelete", L10n.text("Confirm delete"), enabled: canDelete)])
            } else {
                page = .init(title: creating ? L10n.text("New player") : L10n.text("Edit player"), subtitle: subtitle,
                    rows: [.init("nameField", L10n.text("Initials: \(String(draft.uppercased().prefix(3)))_"), selected: true),
                           .init("playerPortrait", ArcadeProfile.portraitNames[portrait], portrait: portrait)]
                        + (creating ? [] : [.init("playerDelete", L10n.text("Delete"), enabled: canDelete)]),
                    footer: [.init("nameCancel", L10n.text("Cancel")), .init("nameDone", L10n.text("Done"), primary: true)])
            }
            if !creating, let player = profiles.players.first(where: { $0.id == (editingPlayerID ?? profiles.activeID) }) {
                page.subtitle = player.name + (subtitle.isEmpty ? "" : "\n" + subtitle)
                page.subtitleRuns = GameSemanticText.named(page.subtitle, name: player.name)
            }
            return page
        }
        var rows = profiles.players.map {
            GameFrontEnd.Action("player." + $0.id, $0.name, selected: $0.id == profiles.activeID, portrait: $0.portrait)
        }
        if !holdToEdit { rows.append(.init("playerRename", L10n.text("Edit: \(profiles.active.name)"))) }
        rows.append(.init("playerNew", L10n.text("New player"), enabled: profiles.players.count < MobileProfiles.maximum))
        rows.append(.init("hotSeat", hotSeatTurn.map { L10n.text("Hot Seat: \($0)") } ?? L10n.text("Hot Seat")))
        if hasSavedHotSeats { rows.append(.init("seatSaved", L10n.text("Saved Hot Seats"))) }
        return .init(title: L10n.text("Players"), subtitle: subtitle, rows: rows,
            footer: [.init("home", L10n.text("Back"))])
    }

    public static func hotSeat(_ profiles: MobileProfiles, subtitle: String, roster: MobileHotSeatRoster,
                               policy: MobileHotSeat.TurnPolicy, active: Bool, hasSaved: Bool,
                               confirmingRestart: Bool = false, ghostsVisible: Bool = true) -> GameFrontEnd.Page {
        var rows = profiles.players.map { player in
            GameFrontEnd.Action("seat." + player.id, player.name + (player.id == roster.host ? "  Host" : ""),
                                enabled: player.id != roster.host, selected: roster.contains(player.id), portrait: player.portrait)
        }
        rows.append(.init("seatNew", L10n.text("New player"), enabled: profiles.players.count < MobileProfiles.maximum,
                          primary: profiles.players.count < MobileHotSeat.minimumPlayers))
        rows.append(.init("seatRule", L10n.text("Turns: \(policy.title)")))
        rows.append(.init("seatGhosts", ghostsVisible ? L10n.text("Ghosts on") : L10n.text("Ghosts off"), selected: ghostsVisible))
        if hasSaved { rows.append(.init("seatSaved", L10n.text("Saved Hot Seats"))) }
        if active {
            rows.append(.init("seatRestart", confirmingRestart ? L10n.text("Confirm new Hot Seat") : L10n.text("New Hot Seat"), selected: confirmingRestart))
            rows.append(.init("seatSolo", L10n.text("Return to solo")))
        }
        return .init(title: L10n.text("Hot Seat"), subtitle: subtitle.isEmpty ? L10n.text("Players: \(roster.players.count) / 2 minimum") : subtitle, rows: rows,
                     footer: [.init("seatBack", L10n.text("Back")),
                              .init("seatStart", L10n.text("Choose a game"), enabled: roster.canStart, primary: roster.canStart)])
    }

    /// Leaderboards rank players. The toolbar picks who (World or This device) and what (category).
    /// Rows are the ranking itself. Back is the only footer navigation.
    public static func leaderboards(world: Bool, category: HostedCategory, rows: [GameFrontEnd.Action],
                                    busy: Bool, status: String, sharing: Bool?, gameCenter: Bool) -> GameFrontEnd.Page {
        var page = GameFrontEnd.Page(title: L10n.text("Leaderboards"), subtitle: category.title,
            rows: rows, details: busy ? [L10n.text("Loading...")] : rows.isEmpty ? [status.isEmpty ? L10n.text("No scores") : status] : [],
            footer: [.init("home", L10n.text("Back"))])
        if world, let sharing {
            var share = GameFrontEnd.Action("rankShare", L10n.text("Share my records"), selected: sharing)
            share.toggleValue = sharing
            page.footer.append(share)
        }
        if gameCenter { page.footer.append(.init("rankGameCenter", L10n.text("Game Center"))) }
        page.singleColumnRows = true
        page.listTools = [.init("rankScope.world", L10n.text("World"), selected: world),
                          .init("rankScope.local", L10n.text("This device"), selected: !world)]
            + HostedCategory.worldwide.map { .init("rankCategory.\($0.rawValue)", $0.title, selected: $0 == category) }
        return page
    }

    /// One ranked row reads the same in World and This device: rank, player, then every career total.
    public static func careerRowTitle(rank: Int, name: String, stars: Int, clears: Int, perfect: Int) -> String {
        "\(rank).  \(name)   " + L10n.text("\(stars) stars   \(clears) cleared   \(perfect) three-star")
    }

    /// Local players ranked by the career category, from this device's direct runs.
    public static func localLeaderboardRows(records: ArcadeRecords, category: HostedCategory, activeID: String) -> [GameFrontEnd.Action] {
        let history = records.trolley
        let attempts = history.attempts.compactMap { attempt in
            attempt.run.level.conditions.map { attempt.assessed(using: history.maximum(conditions: $0, assisted: attempt.run.assisted)) }
        }
        func value(_ score: TrolleyCareerScore) -> Int {
            switch category {
            case .clears: score.clearedLevels
            case .perfect: score.threeStarLevels
            default: score.stars
            }
        }
        let ranked = TrolleyCareerScore.rank(attempts: attempts, assisted: false).sorted {
            value($0) != value($1) ? value($0) > value($1) : $0.stars > $1.stars
        }
        var rank = 0, previous: Int?
        return ranked.enumerated().map { index, score in
            if value(score) != previous { rank = index + 1; previous = value(score) }
            return .init("progress.player.\(score.profileID)", careerRowTitle(rank: rank, name: playerName(records, score.profileID),
                                                                         stars: score.stars, clears: score.clearedLevels, perfect: score.threeStarLevels),
                         selected: score.profileID == activeID, portrait: records.profile(score.profileID)?.portrait)
        }
    }

    public static func recordsPage(records: ArcadeRecords, profileID: String, profileName: String, subtitle: String) -> GameFrontEnd.Page {
        let runs = records.runs.filter { $0.profileID == profileID }
        var seen = Set<String>()
        let levels = runs.sorted { $0.date > $1.date }.filter {
            seen.insert(($0.assisted ? "assisted|" : "direct|") + $0.level.boardID).inserted
        }
        return .init(title: L10n.text("Records"), subtitle: subtitle.isEmpty ? profileName : subtitle,
            rows: levels.map { .init("record." + ($0.assisted ? "assisted|" : "direct|") + $0.level.boardID,
                                    $0.level.title + ($0.assisted ? "  Rewind" : "") + (sourceLabel($0.level).isEmpty ? "" : "\n" + sourceLabel($0.level))) },
            details: levels.isEmpty ? [L10n.text("No records")] : [], footer: [.init("records", L10n.text("Back"))])
    }

    /// Progress is the active local player's own career: totals first, then their records, awards and insights.
    public static func progressPage(records: ArcadeRecords, profileID: String, profileName: String, subtitle: String,
                                    campaign: ClassicAchievementProgress = .init(),
                                    insightsAvailable: Bool = true,
                                    selectablePlayers: [MobileProfile] = []) -> GameFrontEnd.Page {
        let history = records.trolley
        let attempts = history.attempts.compactMap { attempt in
            attempt.run.level.conditions.map { attempt.assessed(using: history.maximum(conditions: $0, assisted: attempt.run.assisted)) }
        }
        let career = TrolleyCareerScore(profileID: profileID, attempts: attempts, assisted: false)
        let awards = achievementsPage(records: records, profileID: profileID, profileName: profileName,
                                      subtitle: "", campaign: campaign).rows
        var page = GameFrontEnd.Page(title: L10n.text("Progress"), subtitle: subtitle.isEmpty ? profileName : subtitle,
            rows: [.init("recordList", L10n.text("Records")),
                   .init("achievements", L10n.text("Achievements") + "  \(awards.filter(\.selected).count)/\(awards.count)"),
                   .init("playInsights", L10n.text("Play Insights"), enabled: insightsAvailable)],
            details: [L10n.text("Career stars: \(career.stars)"), L10n.text("Levels cleared: \(career.clearedLevels)"),
                      L10n.text("Three-star levels: \(career.threeStarLevels)")],
            footer: [.init("home", L10n.text("Back"))])
        page.singleColumnRows = true
        page.listTools = selectablePlayers.map { player in
            .init("progress.profile.\(player.id)", player.name, selected: player.id == profileID, portrait: player.portrait)
        }
        return page
    }

    public static func progressPlayerPage(records: ArcadeRecords, profileID: String, metric: String) -> GameFrontEnd.Page {
        let playerRuns = records.runs.filter { $0.profileID == profileID && !$0.assisted }
        let runs = metric == "lost" ? distinctMostLostRuns(playerRuns)
            : distinctBestRuns(playerRuns)
        let profile = playerName(records, profileID)
        let sorted: [ArcadeRun]
        switch metric {
        case "lost": sorted = runs.sorted { losses($0) == losses($1) ? $0.level.title < $1.level.title : losses($0) > losses($1) }
        default: sorted = runs.sorted { $0.saved == $1.saved ? $0.level.title < $1.level.title : $0.saved > $1.saved }
        }
        let rows = sorted.prefix(200).map { run in
            let value = metric == "lost" ? L10n.text("\(losses(run)) lost")
                : L10n.text("\(run.saved) saved")
            return GameFrontEnd.Action("progress.level.\(recordID(run))", "\(run.level.title)   \(value)")
        }
        return .init(title: profile, subtitle: L10n.text("Best result per level"), rows: rows,
            details: [L10n.text("Direct runs only. Lost counts use population minus saved from one retained result per level.")],
            footer: [.init("progressBack", L10n.text("Back"))])
    }

    /// Level boards use the shared level metrics, Fastest 100% first, whatever the all-levels metric is.
    public static let levelMetrics: [(id: String, title: String)] = [("full", L10n.text("Fastest 100%")),
        ("clear", L10n.text("Fastest clear")), ("skills", L10n.text("Least skills")), ("saved", L10n.text("Most saved"))]
    public static func progressLevelPage(records: ArcadeRecords, key: String, metric: String,
                                         parentProfileID: String? = nil) -> GameFrontEnd.Page {
        let (boardID, assisted) = recordBoard(key)
        let runs = records.runs.filter { $0.level.boardID == boardID && $0.assisted == assisted }
        guard let level = runs.first?.level else {
            let backID = parentProfileID.map { "progress.playerBack.\($0)" } ?? "progressBack"
            return .init(title: L10n.text("Level records"), details: [L10n.text("No records yet.")], footer: [.init(backID, L10n.text("Back"))])
        }
        let metric = levelMetrics.contains { $0.id == metric } ? metric : "full"
        let eligible = runs.filter { run in
            switch metric {
            case "full": run.qualifies && run.saved >= run.population
            case "clear", "skills": run.qualifies
            default: true
            }
        }
        func precedes(_ a: ArcadeRun, _ b: ArcadeRun) -> Bool {
            switch metric {
            case "full", "clear": if a.seconds != b.seconds { return a.seconds < b.seconds }
            case "skills": if a.skillCount != b.skillCount { return a.skillCount < b.skillCount }
            default: break
            }
            if a.saved != b.saved { return a.saved > b.saved }
            if a.skillCount != b.skillCount { return a.skillCount < b.skillCount }
            return a.seconds < b.seconds
        }
        let ranked = Dictionary(grouping: eligible, by: \.profileID).compactMap { $0.value.sorted(by: precedes).first }.sorted(by: precedes)
        let details = ranked.enumerated().map { index, run in
            let value = ["full", "clear"].contains(metric) ? time(run.seconds)
                : metric == "skills" ? L10n.text("\(run.skillCount) skills") : L10n.text("\(run.saved) saved")
            return "\(index + 1). \(playerName(records, run.profileID))   \(value)"
        }
        var page = GameFrontEnd.Page(title: level.title, subtitle: L10n.text("\(level.total) Lemmings   Save \(level.required)"),
            details: details.isEmpty ? [L10n.text("No records yet.")] : details,
            footer: [.init(parentProfileID.map { "progress.playerBack.\($0)" } ?? "progressBack", L10n.text("Back"))])
        page.listTools = levelMetrics.map { .init("progress.levelMetric.\($0.id)", $0.title, selected: metric == $0.id) }
        return page
    }

    private static func distinctBestRuns(_ runs: [ArcadeRun]) -> [ArcadeRun] {
        Dictionary(grouping: runs, by: { "\($0.profileID)|\($0.assisted)|\($0.level.boardID)" }).values.compactMap { group in
            group.sorted {
                if $0.saved != $1.saved { return $0.saved > $1.saved }
                if $0.qualifies != $1.qualifies { return $0.qualifies }
                return $0.seconds < $1.seconds
            }.first
        }
    }

    private static func distinctMostLostRuns(_ runs: [ArcadeRun]) -> [ArcadeRun] {
        Dictionary(grouping: runs, by: { "\($0.profileID)|\($0.assisted)|\($0.level.boardID)" }).values.compactMap { group in
            group.max { losses($0) < losses($1) }
        }
    }


    private static func playerTotals(_ runs: [ArcadeRun], lost: Bool) -> [(profileID: String, value: Int)] {
        Dictionary(grouping: runs, by: \.profileID).map { profileID, values in
            (profileID, values.reduce(0) { $0 + (lost ? losses($1) : $1.saved) })
        }.sorted { $0.value == $1.value ? $0.profileID < $1.profileID : $0.value > $1.value }
    }


    private static func losses(_ run: ArcadeRun) -> Int { max(0, run.population - run.saved) }
    private static func playerName(_ records: ArcadeRecords, _ profileID: String) -> String {
        records.profile(profileID)?.initials ?? L10n.text("LEM")
    }
    private static func recordID(_ run: ArcadeRun) -> String {
        (run.assisted ? "assisted|" : "direct|") + run.level.boardID
    }
    private static func time(_ seconds: Double) -> String {
        String(format: "%d:%05.2f", Int(seconds) / 60, seconds.truncatingRemainder(dividingBy: 60))
    }

    /// Strips the "direct|" or "assisted|" prefix from a record key and returns the board ID and assisted flag.
    private static func recordBoard(_ key: String) -> (String, Bool) {
        let assisted = key.hasPrefix("assisted|")
        return (String(key.dropFirst(assisted ? 9 : key.hasPrefix("direct|") ? 7 : 0)), assisted)
    }

    /// The record card. `preview` reserves the level artwork well; Play, Hint and Replay appear when available.
    public static func recordLevelPage(_ key: String, records: ArcadeRecords, profileID: String, profileName: String, subtitle: String,
                                       replayAvailable: Bool = false, hintAvailable: Bool = false,
                                       playable: Bool = false, preview: Bool = false) -> GameFrontEnd.Page {
        let (board, assisted) = recordBoard(key)
        let runs = records.runs.filter { $0.profileID == profileID && $0.level.boardID == board && $0.assisted == assisted }
        guard let level = runs.first?.level else { return recordsPage(records: records, profileID: profileID, profileName: profileName, subtitle: subtitle) }
        let best = runs.map(\.saved).max() ?? 0
        let time = runs.filter(\.qualifies).map(\.seconds).min()
        let stats = records.stats(level: level, profileID: profileID, assisted: assisted)
        var maximum = TrolleyMaximum()
        var maximumText = best == level.total ? String(level.total) : "?"
        if let conditions = level.conditions {
            maximum = records.trolley.maximum(conditions: conditions, assisted: assisted)
            maximumText = maximum.value.map(String.init) ?? "?"
        }
        var details = [L10n.text("Records"),
                       L10n.text("Most saved: \(best)/\(level.total)") + "   " + L10n.text("Maximum: \(maximumText)"),
                       L10n.text("Attempts: \(stats.attempts)  Clears: \(stats.clears)")]
        if let time { details.append(L10n.text("Best time: \(String(format: "%.1f", time)) S")) }
        var headings: Set<Int> = [0]
        let awards = stats.achievements.sorted { $0.rawValue < $1.rawValue }.map(\.title)
        if !awards.isEmpty {
            headings.insert(details.count)
            details += [L10n.text("Achievements"), awards.joined(separator: ", ")]
        }
        let identity = [subtitle.isEmpty ? profileName : subtitle, sourceLabel(level)].filter { !$0.isEmpty }.joined(separator: " - ")
        var footer: [GameFrontEnd.Action] = [.init("recordList", L10n.text("Back"))]
        if hintAvailable { footer.append(.init("recordHint", L10n.text("Hints"))) }
        if replayAvailable { footer.append(.init("recordReplay", L10n.text("Replay"), primary: !playable)) }
        if playable { footer.append(.init("recordPlay", stats.clears > 0 ? L10n.text("Play again") : L10n.text("Play"), primary: true)) }
        var page = GameFrontEnd.Page(title: level.title,
            subtitle: identity + "\n" + L10n.text("\(level.total) Lemmings   Save \(level.required)"),
            details: details, footer: footer, preview: preview, footerColumns: 2)
        page.detailHeadings = headings
        page.stars = runs.map { TrolleyRescueGoals(run: $0, maximum: maximum).stars }.max() ?? 0
        return page
    }

    public static func recordLevelPage(_ key: String, records: ArcadeRecords, profileID: String, profileName: String,
                                       subtitle: String, replayRunID: UUID? = nil) -> GameFrontEnd.Page {
        let (board, assisted) = recordBoard(key)
        let runs = records.runs.filter { $0.profileID == profileID && $0.level.boardID == board && $0.assisted == assisted }
        guard let level = runs.first?.level else { return recordsPage(records: records, profileID: profileID, profileName: profileName, subtitle: subtitle) }
        let best = runs.map(\.saved).max() ?? 0
        let time = runs.filter(\.qualifies).map(\.seconds).min()
        let stats = records.stats(level: level, profileID: profileID, assisted: assisted)
        var maximum = TrolleyMaximum()
        var maximumText = best == level.total ? String(level.total) : "?"
        if let conditions = level.conditions {
            maximum = records.trolley.maximum(conditions: conditions, assisted: assisted)
            maximumText = maximum.value.map(String.init) ?? "?"
        }
        var details = [L10n.text("Records"),
                       L10n.text("Most saved: \(best)/\(level.total)") + "   " + L10n.text("Maximum: \(maximumText)"),
                       L10n.text("Attempts: \(stats.attempts)  Clears: \(stats.clears)")]
        if let time { details.append(L10n.text("Best time: \(String(format: "%.1f", time)) S")) }
        var headings: Set<Int> = [0]
        let awards = stats.achievements.sorted { $0.rawValue < $1.rawValue }.map(\.title)
        if !awards.isEmpty {
            headings.insert(details.count)
            details += [L10n.text("Achievements"), awards.joined(separator: ", ")]
        }
        let identity = [subtitle.isEmpty ? profileName : subtitle, sourceLabel(level)].filter { !$0.isEmpty }.joined(separator: " - ")
        var footer: [GameFrontEnd.Action] = []
        if let runID = replayRunID {
            footer.append(.init("recordReplay." + runID.uuidString, L10n.text("Replay")))
        }
        footer.append(.init("records", L10n.text("Back")))
        var page = GameFrontEnd.Page(title: level.title,
            subtitle: identity + "\n" + L10n.text("\(level.total) Lemmings   Save \(level.required)"),
            details: details, footer: footer, preview: false, footerColumns: 2)
        page.detailHeadings = headings
        page.stars = runs.map { TrolleyRescueGoals(run: $0, maximum: maximum).stars }.max() ?? 0
        return page
    }

    /// One hint card for a recorded level, opened from its record card.
    public static func recordHintPage(level: String, deck: LevelHintDeck, stage: Int,
                                      solution: Bool, playable: Bool, preview: Bool) -> GameFrontEnd.Page {
        let hint = deck.presentation(at: stage)
        var footer: [GameFrontEnd.Action] = [.init("recordHintBack", L10n.text("Back"))]
        if stage > 0 { footer.append(.init("recordHintPrevious", L10n.text("Previous"))) }
        if stage + 1 < deck.stages.count { footer.append(.init("recordHintNext", deck.checked ? L10n.text("NEXT HINT") : L10n.text("Next coaching"))) }
        if solution { footer.append(.init("recordSolution", L10n.text("Solution"))) }
        if playable { footer.append(.init("recordPlay", L10n.text("Play"), primary: true)) }
        var page = GameFrontEnd.Page(title: hint.title, subtitle: level + "\n" + hint.progress,
            details: [hint.section] + hint.body.components(separatedBy: "\n").filter { !$0.isEmpty },
            footer: footer, preview: preview, footerColumns: 2)
        page.detailHeadings = [0]
        page.reading = true
        return page
    }

    public static func campaignProgress(records: ArcadeRecords, profileID: String,
                                        levelCounts: [String: Int]) -> ClassicAchievementProgress {
        var progress = ClassicAchievementProgress()
        // Only recorded wins in their actual order advance the shared campaign cursor.
        for run in records.runs where run.profileID == profileID && run.qualifies {
            guard let conditions = run.level.conditions, let title = ClassicTitle(rawValue: conditions.gameID),
                  conditions.levelID.hasPrefix("level-"), let index = Int(conditions.levelID.dropFirst(6)),
                  let count = levelCounts[title.rawValue] else { continue }
            _ = progress.recordWin(title: title, levelIndex: index, levelCount: count)
        }
        return progress
    }

    public static func achievementsPage(records: ArcadeRecords, profileID: String, profileName: String, subtitle: String, campaign: ClassicAchievementProgress = .init()) -> GameFrontEnd.Page {
        let earned = records.careerAchievements(profileID: profileID)
        let levelRows = ArcadeLevelAchievement.allCases.map {
            GameFrontEnd.Action("award." + $0.rawValue, $0.title, selected: earned.contains($0))
        }
        let careerRows = TrolleyAchievement.allCases.filter(\.isOffered).map { award in
            let progress = award.progress(attempts: records.trolley.attempts, profileID: profileID)
            return GameFrontEnd.Action("careerAward." + award.rawValue,
                award.title + (progress.goal > 1 ? "  \(progress.value)/\(progress.goal)" : ""), selected: progress.earned)
        }
        return .init(title: L10n.text("Achievements"), subtitle: subtitle.isEmpty ? profileName : subtitle,
            rows: levelRows + careerRows + ClassicAchievement.catalog.map {
                .init("campaignAward." + $0.id.rawValue, $0.title, selected: campaign.isUnlocked($0.id))
            }, footer: [.init("records", L10n.text("Back"))])
    }

}
