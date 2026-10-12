#if os(iOS)
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
        MobileCareerArt.recordsPage(records: arcadeStore.records, profileID: profiles.activeID,
                                    profileName: profiles.active.name, subtitle: subtitle)
    }
    func recordLevelPage(_ key: String, subtitle: String) -> GameFrontEnd.Page {
        MobileCareerArt.recordLevelPage(key, records: arcadeStore.records, profileID: profiles.activeID,
                                        profileName: profiles.active.name, subtitle: subtitle)
    }
    func achievementsPage(subtitle: String) -> GameFrontEnd.Page {
        MobileCareerArt.achievementsPage(records: arcadeStore.records, profileID: profiles.activeID,
                                        profileName: profiles.active.name, subtitle: subtitle)
    }

    func handleRecords(_ id: String) -> Bool {
        switch id {
        case "records": navigate(.records)
        case "achievements": navigate(.achievements)
        default:
            if id.hasPrefix("record.") { navigate(.recordLevel(String(id.dropFirst(7)))) }
            else if id.hasPrefix("award."), let award = ArcadeLevelAchievement(rawValue: String(id.dropFirst(6))) {
                canvas.page = .init(title: award.title, details: [award.detail], footer: [.init("achievements", "Back")])
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
        guard let report = arcadeStore.record(run) else {
            return ([], arcadeStore.storageError ?? "Records were not saved. Retry the save before continuing.")
        }
        let celebration = TrolleyCelebration(report: report, history: arcadeStore.records.trolley)
        if MobileResultAwardsCache.values.count > 128 { MobileResultAwardsCache.values.removeAll() }
        MobileResultAwardsCache.values[run.id] = (celebration.goals.stars,
            ResultAwards.ornament(report: report, celebration: celebration, history: arcadeStore.records.trolley))
        var details = report.earned.map(\.title)
        if report.newRescueBest { details.insert("New rescue record", at: 0) }
        if report.newSkillBest { details.append("New skill record") }
        if run.qualifies, bestTime.map({ run.seconds < $0 }) ?? true { details.append("New time record") }
        if report.earnedLevelSkip { details.append("Level skip earned") }
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
