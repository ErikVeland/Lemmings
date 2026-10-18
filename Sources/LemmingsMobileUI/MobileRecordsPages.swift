#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

@MainActor private enum MobileResultAwardsCache {
    static var values: [UUID: (stars: Int, ornament: Bool)] = [:]
    static var achievements: [UUID: [MobileResultAchievementsArt.Item]] = [:]
}

extension MobileLibraryViewController {
    func mobileResultAwards(runID: UUID) -> (stars: Int, ornament: Bool) {
        if let saved = MobileResultAwardsCache.values[runID] { return saved }
        guard let run = arcadeStore.records.runs.first(where: { $0.id == runID }) else { return (0, false) }
        let maximum = run.level.conditions.map {
            arcadeStore.records.trolley.maximum(conditions: $0, assisted: run.assisted)
        } ?? TrolleyMaximum()
        return (TrolleyRescueGoals(run: run, maximum: maximum).stars, false)
    }

    func mobileResultAchievements(runID: UUID) -> [MobileResultAchievementsArt.Item] {
        if let saved = MobileResultAwardsCache.achievements[runID] { return saved }
        guard let run = arcadeStore.records.runs.first(where: { $0.id == runID }) else { return [] }
        let maximum = run.level.conditions.map {
            arcadeStore.records.trolley.maximum(conditions: $0, assisted: run.assisted)
        } ?? TrolleyMaximum()
        return MobileResultAchievementsArt.goals(TrolleyRescueGoals(run: run, maximum: maximum))
    }

    func recordsPage(subtitle: String) -> GameFrontEnd.Page {
        if confirmingRecordsReset { return GameRecoveryArt.recordsReset(arcadeStore.storageError ?? "") }
        var page = MobileCareerArt.recordsPage(records: arcadeStore.records, profileID: profiles.activeID,
                                    profileName: profiles.active.name, subtitle: arcadeStore.storageError ?? subtitle)
        if arcadeStore.storageError != nil { page.rows.insert(.init("recordsFix", L10n.text("Fix records")), at: 0) }
        return page
    }
    func recordLevelPage(_ key: String, subtitle: String) -> GameFrontEnd.Page {
        MobileCareerArt.recordLevelPage(key, records: arcadeStore.records, profileID: profiles.activeID,
                                        profileName: profiles.active.name, subtitle: subtitle,
                                        replayRunID: recordReplayRun(key)?.id)
    }

    /// The fastest clear, as on the Mac replay boards, else the most saved. Only engines iOS can play back.
    func recordReplayRun(_ key: String) -> ArcadeRun? {
        let (board, assisted) = MobileCareerArt.recordBoard(key)
        let runs = arcadeStore.records.runs.filter {
            $0.profileID == profiles.activeID && $0.level.boardID == board && $0.assisted == assisted
        }
        let ordered = runs.filter(\.qualifies).sorted { $0.seconds < $1.seconds } + runs.sorted { $0.saved > $1.saved }
        return ordered.first { run in
            guard let game = run.level.conditions?.gameID, !["lemmings2", "lemmings3", "neolemmix"].contains(game) else { return false }
            return arcadeStore.actionReplayURL(attemptID: run.id) != nil
        }
    }

    private func watchRecordReplay(_ runID: UUID) {
        do {
            guard let run = arcadeStore.records.runs.first(where: { $0.id == runID }),
                  let url = arcadeStore.actionReplayURL(attemptID: runID) else { throw MobileSessionError.invalidCheckpoint }
            let replay = try JSONDecoder().decode(LeaderboardActionReplay.self, from: Data(contentsOf: url))
            showRankedActionReplay(replay, title: run.level.title)
        } catch { notice = error.localizedDescription; rebuild() }
    }
    func mobileCampaignProgress(profileID: String) -> ClassicAchievementProgress {
        let packs = catalogue.map { value in value.families.flatMap { value.packs(in: $0) } } ?? []
        let counts = Dictionary(packs.compactMap { pack -> (String, Int)? in
            guard case let .release(_, title) = pack.source, let count = pack.levelCount else { return nil }
            return (title.rawValue, count)
        }, uniquingKeysWith: { first, _ in first })
        return MobileCareerArt.campaignProgress(records: arcadeStore.records, profileID: profileID, levelCounts: counts)
    }
    func achievementsPage(subtitle: String) -> GameFrontEnd.Page {
        MobileCareerArt.achievementsPage(records: arcadeStore.records, profileID: profiles.activeID,
            profileName: profiles.active.name, subtitle: subtitle, campaign: mobileCampaignProgress(profileID: profiles.activeID))
    }

    func handleRecords(_ id: String) -> Bool {
        switch id {
        case "recordsFix":
            if arcadeStore.reloadRecords() { _ = saveProfiles() }
            else { confirmingRecordsReset = true }
            rebuild()
        case "recordsResetCancel": confirmingRecordsReset = false; rebuild()
        case "recordsResetConfirm":
            guard confirmingRecordsReset else { return true }
            if arcadeStore.startNewRecords() {
                confirmingRecordsReset = false
                _ = saveProfiles()
            }
            rebuild()
        case "records": navigate(.records)
        case "achievements": navigate(.achievements)
        default:
            if id.hasPrefix("record.") { navigate(.recordLevel(String(id.dropFirst(7)))) }
            else if id.hasPrefix("recordReplay."), let runID = UUID(uuidString: String(id.dropFirst(13))) { watchRecordReplay(runID) }
            else if id.hasPrefix("award."), let award = ArcadeLevelAchievement(rawValue: String(id.dropFirst(6))) {
                canvas.page = .init(title: award.title, details: [award.detail], footer: [.init("achievements", L10n.text("Back"))])
            } else if id.hasPrefix("careerAward."), let award = TrolleyAchievement(rawValue: String(id.dropFirst(12))) {
                canvas.page = .init(title: award.title, details: [award.detail], footer: [.init("achievements", L10n.text("Back"))])
            } else if id.hasPrefix("campaignAward."), let award = ClassicAchievement.catalog.first(where: { $0.id.rawValue == String(id.dropFirst(14)) }) {
                canvas.page = .init(title: award.title, details: [award.detail], footer: [.init("achievements", L10n.text("Back"))])
            } else { return false }
        }
        return true
    }

    func recordMobileCompletion(_ run: ArcadeRun, session: (any MobileGameSession)? = nil,
                                hotSeat seat: MobileHotSeat? = nil) -> (details: [String], error: String?) {
        AnonymousTelemetry.shared.finish(run.level, hotSeat: hotSeat != nil, attemptID: run.id, won: run.didWin, saved: run.saved)
        // A completed checkpoint can reopen. The attempt UUID makes its result idempotent.
        if arcadeStore.records.runs.contains(where: { $0.id == run.id })
            || arcadeStore.records.trolley.attempts.contains(where: { $0.id == run.id }) { return ([], nil) }
        let bestTime = arcadeStore.records.runs.filter {
            $0.profileID == run.profileID && $0.level.boardID == run.level.boardID && $0.assisted == run.assisted && $0.qualifies
        }.map(\.seconds).min()
        let campaignBefore = mobileCampaignProgress(profileID: run.profileID).unlocked
        guard let report = arcadeStore.record(run) else {
            return ([], arcadeStore.storageError ?? L10n.text("Records were not saved. Retry the save before continuing."))
        }
        let celebration = TrolleyCelebration(report: report, history: arcadeStore.records.trolley)
        if MobileResultAwardsCache.values.count > 128 {
            MobileResultAwardsCache.values.removeAll(); MobileResultAwardsCache.achievements.removeAll()
        }
        MobileResultAwardsCache.values[run.id] = (celebration.goals.stars,
            ResultAwards.ornament(report: report, celebration: celebration, history: arcadeStore.records.trolley))
        let campaignAfter = mobileCampaignProgress(profileID: run.profileID).unlocked
        var achievementInfo = MobileResultAchievementsArt.goals(celebration.goals)
        achievementInfo += ResultAwards.earnedRewards(report: report, celebration: celebration).map { reward in
            let detail = TrolleyAchievement.allCases.first { $0.title == reward.title }
                .map { ResultAwards.explanation(for: $0) } ?? reward.reason
            return .init(reward.title, detail: detail)
        }
        achievementInfo += ClassicAchievement.catalog.filter {
            campaignAfter.contains($0.id) && !campaignBefore.contains($0.id)
        }.map { .init($0.title, detail: $0.detail) }
        MobileResultAwardsCache.achievements[run.id] = achievementInfo
        var details = report.earned.map(\.title) + celebration.newAwards.map { $0.award.title }
        details += ClassicAchievement.catalog.filter { campaignAfter.contains($0.id) && !campaignBefore.contains($0.id) }.map(\.title)
        if report.newRescueBest { details.insert(L10n.text("New rescue record"), at: 0) }
        if report.newSkillBest { details.append(L10n.text("New skill record")) }
        if run.qualifies, bestTime.map({ run.seconds < $0 }) ?? true { details.append(L10n.text("New time record  \(Int(run.seconds) / 60):\(String(format: "%05.2f", run.seconds.truncatingRemainder(dividingBy: 60)))")) }
        if report.earnedLevelSkip { details.append(L10n.text("Level skip earned")) }
        do {
            if let capture = try session?.actionCapture() {
                arcadeStore.preserveActions(run: run, initial: capture.initial, final: capture.final, commands: capture.commands)
                // Losses count too. The next player sees this turn behind their own lemmings.
                if let seat {
                    arcadeStore.preserveHotSeatGhost(run: run, sessionID: seat.id, players: seat.players,
                        initial: capture.initial, final: capture.final, commands: capture.commands)
                }
            }
        } catch { notice = error.localizedDescription }
        mobileRankings.completed(run.profileID, history: arcadeStore.records.trolley)
        return (details, nil)
    }
}
#endif
