import Foundation
import LemmingsMobileCore
import NxlvKit

/// Career pages use the same bitmap composition in the app and headless audit.
public enum MobileCareerArt {
    private static func sourceLabel(_ level: ArcadeLevel) -> String {
        guard let conditions = level.conditions else { return "" }
        if conditions.gameID == L10n.text("fan") || conditions.gameID == L10n.text("neolemmix") { return L10n.text(L10n.text("Fan-made")) }
        return ClassicTitle(rawValue: conditions.gameID) == nil ? "" : L10n.text("Official")
    }

    public static func players(_ profiles: MobileProfiles, subtitle: String, draft: String? = nil,
                               creating: Bool = false, portrait: Int = 0,
                               canDelete: Bool = false, confirmingDelete: Bool = false,
                               hotSeatTurn: String? = nil) -> GameFrontEnd.Page {
        if let draft {
            return .init(title: creating ? L10n.text("New player") : L10n.text("Edit player"), subtitle: subtitle,
                rows: [.init("nameField", L10n.text("Initials: ") + String(draft.uppercased().prefix(3)) + "_", selected: true),
                       .init("playerPortrait", ArcadeProfile.portraitNames[portrait], portrait: portrait)],
                footer: [.init("nameCancel", L10n.text("Cancel")), .init("nameDone", L10n.text("Done"), primary: true)])
        }
        var rows = profiles.players.map {
            GameFrontEnd.Action("player." + $0.id, $0.name, selected: $0.id == profiles.activeID, portrait: $0.portrait)
        }
        rows.append(.init("playerRename", L10n.text("Edit: ") + profiles.active.name))
        rows.append(.init("playerNew", L10n.text("New player"), enabled: profiles.players.count < MobileProfiles.maximum))
        rows.append(.init("hotSeat", hotSeatTurn.map { L10n.text("Hot Seat: ") + $0 } ?? L10n.text("Hot Seat")))
        return .init(title: L10n.text("Players"), subtitle: subtitle, rows: rows,
            footer: [.init("playerDelete", confirmingDelete ? L10n.text("Confirm delete") : L10n.text("Delete"),
                           enabled: canDelete, selected: confirmingDelete), .init("home", L10n.text("Back"))])
    }

    public static func hotSeat(_ profiles: MobileProfiles, subtitle: String, roster: MobileHotSeatRoster,
                               policy: MobileHotSeat.TurnPolicy, active: Bool, hasSaved: Bool,
                               confirmingRestart: Bool = false) -> GameFrontEnd.Page {
        var rows = profiles.players.map { player in
            GameFrontEnd.Action("seat." + player.id, player.name + (player.id == roster.host ? "  Host" : ""),
                                enabled: player.id != roster.host, selected: roster.contains(player.id), portrait: player.portrait)
        }
        rows.append(.init("seatNew", L10n.text("New player"), enabled: profiles.players.count < MobileProfiles.maximum,
                          primary: profiles.players.count < MobileHotSeat.minimumPlayers))
        rows.append(.init("seatRule", L10n.text("Turns: \(policy.title)")))
        if hasSaved { rows.append(.init("seatSaved", L10n.text("Saved Hot Seats"))) }
        if active {
            rows.append(.init("seatRestart", confirmingRestart ? L10n.text("Confirm new Hot Seat") : L10n.text("New Hot Seat"), selected: confirmingRestart))
            rows.append(.init("seatSolo", L10n.text("Return to solo")))
        }
        return .init(title: L10n.text("Hot Seat"), subtitle: subtitle.isEmpty ? L10n.text("Players: \(roster.players.count) / 2 minimum") : subtitle, rows: rows,
                     footer: [.init("seatBack", L10n.text("Back")),
                              .init("seatStart", L10n.text("Choose a game"), enabled: roster.canStart, primary: roster.canStart)])
    }

    public static func rankings(community: Bool, subtitle: String, busy: Bool,
                                status: String, rows: [GameFrontEnd.Action],
                                connected: Bool, available: Bool) -> GameFrontEnd.Page {
        .init(title: L10n.text("Worldwide"), subtitle: busy ? L10n.text("Loading...") : subtitle,
            rows: [.init("rankCommunity", L10n.text("Community"), selected: community),
                   .init("rankGameCenter", L10n.text("Game Center"), selected: !community)] + rows,
            details: status.isEmpty ? [] : [status],
            footer: [.init("records", L10n.text("Back")),
                     .init("rankRefresh", community || connected ? L10n.text("Refresh") : L10n.text("Connect"),
                           enabled: !busy && available, primary: true)], footerColumns: 1)
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
            details: levels.isEmpty ? [L10n.text("No records")] : [], footer: [.init("home", L10n.text("Back")), .init("achievements", L10n.text("Achievements")), .init("worldwide", L10n.text("Worldwide"))], footerColumns: 1)
    }

    public static func recordLevelPage(_ key: String, records: ArcadeRecords, profileID: String, profileName: String, subtitle: String) -> GameFrontEnd.Page {
        let assisted = key.hasPrefix("assisted|")
        let board = String(key.dropFirst(assisted ? 9 : key.hasPrefix("direct|") ? 7 : 0))
        let runs = records.runs.filter { $0.profileID == profileID && $0.level.boardID == board && $0.assisted == assisted }
        guard let level = runs.first?.level else { return recordsPage(records: records, profileID: profileID, profileName: profileName, subtitle: subtitle) }
        let best = runs.map(\.saved).max() ?? 0
        let time = runs.filter(\.qualifies).map(\.seconds).min()
        let stats = records.stats(level: level, profileID: profileID, assisted: assisted)
        var details = [L10n.text("Most saved: \(best)/\(level.total)"), L10n.text("Attempts: \(stats.attempts)  Clears: \(stats.clears)")]
        if let time { details.append(String(format: "Best time: %.1f S", time)) }
        if let conditions = level.conditions {
            let maximum = records.trolley.maximum(conditions: conditions, assisted: assisted)
            details.append(L10n.text("Maximum: ") + (maximum.value.map(String.init) ?? "?"))
        } else { details.append(L10n.text("Maximum: ") + (best == level.total ? String(level.total) : "?")) }
        let awards = stats.achievements.sorted { $0.rawValue < $1.rawValue }.map(\.title)
        return .init(title: level.title, subtitle: [subtitle.isEmpty ? profileName : subtitle, sourceLabel(level)].filter { !$0.isEmpty }.joined(separator: "\n"),
                     details: details + awards, footer: [.init("records", L10n.text("Back"))])
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
            }, footer: [.init("home", L10n.text("Back"))])
    }

}
