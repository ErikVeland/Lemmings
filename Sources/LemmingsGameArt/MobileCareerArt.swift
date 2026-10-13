import Foundation
import LemmingsMobileCore
import NxlvKit

/// Career pages use the same bitmap composition in the app and headless audit.
public enum MobileCareerArt {
    public static func players(_ profiles: MobileProfiles, subtitle: String, draft: String? = nil,
                               creating: Bool = false, portrait: Int = 0,
                               canDelete: Bool = false, confirmingDelete: Bool = false) -> GameFrontEnd.Page {
        if let draft {
            return .init(title: creating ? "New player" : "Edit player", subtitle: subtitle,
                rows: [.init("nameField", "Initials: " + String(draft.uppercased().prefix(3)) + "_", selected: true),
                       .init("playerPortrait", ArcadeProfile.portraitNames[portrait], portrait: portrait)],
                footer: [.init("nameCancel", "Cancel"), .init("nameDone", "Done", primary: true)])
        }
        var rows = profiles.players.map {
            GameFrontEnd.Action("player." + $0.id, $0.name, selected: $0.id == profiles.activeID, portrait: $0.portrait)
        }
        rows.append(.init("playerNew", "New player", enabled: profiles.players.count < MobileProfiles.maximum))
        return .init(title: "Players", subtitle: subtitle, rows: rows,
            footer: [.init("playerRename", "Edit"),
                     .init("playerDelete", confirmingDelete ? "Confirm delete" : "Delete",
                           enabled: canDelete, selected: confirmingDelete), .init("home", "Back")])
    }

    public static func rankings(community: Bool, subtitle: String, busy: Bool,
                                status: String, rows: [GameFrontEnd.Action],
                                connected: Bool, available: Bool) -> GameFrontEnd.Page {
        .init(title: "Worldwide", subtitle: busy ? "Loading..." : subtitle,
            rows: [.init("rankCommunity", "Community", selected: community),
                   .init("rankGameCenter", "Game Center", selected: !community)] + rows,
            details: status.isEmpty ? [] : [status],
            footer: [.init("records", "Back"),
                     .init("rankRefresh", community || connected ? "Refresh" : "Connect",
                           enabled: !busy && available, primary: true)], footerColumns: 1)
    }

    public static func recordsPage(records: ArcadeRecords, profileID: String, profileName: String, subtitle: String) -> GameFrontEnd.Page {
        let runs = records.runs.filter { $0.profileID == profileID }
        var seen = Set<String>()
        let levels = runs.sorted { $0.date > $1.date }.filter {
            seen.insert(($0.assisted ? "assisted|" : "direct|") + $0.level.boardID).inserted
        }
        return .init(title: "Records", subtitle: subtitle.isEmpty ? profileName : subtitle,
            rows: levels.map { .init("record." + ($0.assisted ? "assisted|" : "direct|") + $0.level.boardID,
                                    $0.level.title + ($0.assisted ? "  Rewind" : "")) },
            details: levels.isEmpty ? ["No records"] : [], footer: [.init("home", "Back"), .init("achievements", "Achievements"), .init("worldwide", "Worldwide")], footerColumns: 1)
    }

    public static func recordLevelPage(_ key: String, records: ArcadeRecords, profileID: String, profileName: String, subtitle: String) -> GameFrontEnd.Page {
        let assisted = key.hasPrefix("assisted|")
        let board = String(key.dropFirst(assisted ? 9 : key.hasPrefix("direct|") ? 7 : 0))
        let runs = records.runs.filter { $0.profileID == profileID && $0.level.boardID == board && $0.assisted == assisted }
        guard let level = runs.first?.level else { return recordsPage(records: records, profileID: profileID, profileName: profileName, subtitle: subtitle) }
        let best = runs.map(\.saved).max() ?? 0
        let time = runs.filter(\.qualifies).map(\.seconds).min()
        let stats = records.stats(level: level, profileID: profileID, assisted: assisted)
        var details = ["Most saved: \(best)/\(level.total)", "Attempts: \(stats.attempts)  Clears: \(stats.clears)"]
        if let time { details.append(String(format: "Best time: %.1f S", time)) }
        if let conditions = level.conditions {
            let maximum = records.trolley.maximum(conditions: conditions, assisted: assisted)
            details.append("Maximum: " + (maximum.value.map(String.init) ?? "?"))
        } else { details.append("Maximum: " + (best == level.total ? String(level.total) : "?")) }
        let awards = stats.achievements.sorted { $0.rawValue < $1.rawValue }.map(\.title)
        return .init(title: level.title, subtitle: subtitle.isEmpty ? profileName : subtitle,
                     details: details + awards, footer: [.init("records", "Back")])
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
        return .init(title: "Achievements", subtitle: subtitle.isEmpty ? profileName : subtitle,
            rows: levelRows + careerRows + ClassicAchievement.catalog.map {
                .init("campaignAward." + $0.id.rawValue, $0.title, selected: campaign.isUnlocked($0.id))
            }, footer: [.init("home", "Back")])
    }

}
