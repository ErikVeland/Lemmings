#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

@MainActor private enum MobileResultAwardsCache {
    static var values: [UUID: (stars: Int, ornament: Bool)] = [:]
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

    func recordsPage(subtitle: String) -> GameFrontEnd.Page {
        if confirmingRecordsReset { return GameRecoveryArt.recordsReset(arcadeStore.storageError ?? "") }
        var page = MobileCareerArt.recordsPage(records: arcadeStore.records, profileID: profiles.activeID,
                                    profileName: profiles.active.name, subtitle: arcadeStore.storageError ?? subtitle)
        if arcadeStore.storageError != nil { page.rows.insert(.init("recordsFix", L10n.text("Fix records")), at: 0) }
        return page
    }
    func recordLevelPage(_ key: String, subtitle: String) -> GameFrontEnd.Page {
        MobileCareerArt.recordLevelPage(key, records: arcadeStore.records, profileID: profiles.activeID,
                                        profileName: profiles.active.name, subtitle: subtitle)
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

    func recordMobileCompletion(_ run: ArcadeRun, session: (any MobileGameSession)? = nil) -> (details: [String], error: String?) {
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
        if MobileResultAwardsCache.values.count > 128 { MobileResultAwardsCache.values.removeAll() }
        MobileResultAwardsCache.values[run.id] = (celebration.goals.stars,
            ResultAwards.ornament(report: report, celebration: celebration, history: arcadeStore.records.trolley))
        let campaignAfter = mobileCampaignProgress(profileID: run.profileID).unlocked
        var details = report.earned.map(\.title) + celebration.newAwards.map { $0.award.title }
        details += ClassicAchievement.catalog.filter { campaignAfter.contains($0.id) && !campaignBefore.contains($0.id) }.map(\.title)
        if report.newRescueBest { details.insert(L10n.text("New rescue record"), at: 0) }
        if report.newSkillBest { details.append(L10n.text("New skill record")) }
        if run.qualifies, bestTime.map({ run.seconds < $0 }) ?? true { details.append(L10n.text("New time record  \(Int(run.seconds) / 60):\(String(format: "%05.2f", run.seconds.truncatingRemainder(dividingBy: 60)))")) }
        if report.earnedLevelSkip { details.append(L10n.text("Level skip earned")) }
        if let classic = session as? ClassicMobileSession {
            do {
                if let data = try classic.replayDocument() {
                    let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: data)
                    let commands = try replay.events.map(LeaderboardActionReplay.Command.classic)
                    arcadeStore.preserveActions(run: run, initial: .classic(classic.initialSimulation),
                                               final: .classic(classic.finalSimulation), commands: commands)
                }
            } catch { notice = error.localizedDescription }
        }
        mobileRankings.completed(run.profileID, history: arcadeStore.records.trolley)
        return (details, nil)
    }
}
#endif
