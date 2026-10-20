#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

/// Artwork, hints and catalogue location for one record card. Only catalogue levels load these.
struct MobileRecordDetail {
    let key: String
    var preview: CGImage?
    var previewSource: CGRect?
    var pack: MobileContentPack?
    var index: Int?
    var deck: LevelHintDeck?
    var solution: VerifiedSolution?
    var initial: ClassicDOSSimulation?
    var stage = 0
}

@MainActor private enum MobileResultAwardsCache {
    static var values: [UUID: (stars: Int, ornament: Bool)] = [:]
    static var achievements: [UUID: [MobileResultAchievementsArt.Item]] = [:]
    static var rewards: [UUID: [ResultAwards.EarnedReward]] = [:]
}

extension MobileLibraryViewController {
    func mobileResultRewards(runID: UUID) -> [ResultAwards.EarnedReward] {
        MobileResultAwardsCache.rewards[runID] ?? []
    }
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
    func progressPage(subtitle: String) -> GameFrontEnd.Page {
        if confirmingRecordsReset { return GameRecoveryArt.recordsReset(arcadeStore.storageError ?? "") }
        var page = MobileCareerArt.progressPage(records: arcadeStore.records, profileID: profiles.activeID,
            profileName: profiles.active.name, subtitle: arcadeStore.storageError ?? subtitle,
            campaign: mobileCampaignProgress(profileID: profiles.activeID))
        if arcadeStore.storageError != nil { page.rows.insert(.init("recordsFix", L10n.text("Fix records")), at: 0) }
        return page
    }
    func recordLevelPage(_ key: String, subtitle: String) -> GameFrontEnd.Page {
        let detail = recordDetail?.key == key ? recordDetail : nil
        return MobileCareerArt.recordLevelPage(key, records: arcadeStore.records, profileID: profiles.activeID,
                                        profileName: profiles.active.name, subtitle: subtitle,
                                        replayAvailable: recordReplay(key) != nil, hintAvailable: detail?.deck != nil,
                                        playable: detail?.pack != nil, preview: detail?.preview != nil)
    }
    func recordHintPage(_ key: String) -> GameFrontEnd.Page {
        guard let detail = recordDetail, detail.key == key, let deck = detail.deck, !deck.stages.isEmpty else {
            return recordLevelPage(key, subtitle: "")
        }
        let stage = min(max(0, detail.stage), deck.stages.count - 1)
        let level = arcadeStore.records.runs.last { recordKey($0) == key }?.level.title ?? deck.title
        return MobileCareerArt.recordHintPage(level: level, deck: deck,
            stage: stage, solution: detail.solution != nil && detail.initial != nil,
            playable: detail.pack != nil, preview: detail.preview != nil)
    }
    func showRecordPreview(_ key: String) {
        guard let detail = recordDetail, detail.key == key, let image = detail.preview else { canvas.preview = nil; return }
        canvas.preview = image
        canvas.previewSource = detail.previewSource
    }
    private func recordKey(_ run: ArcadeRun) -> String { (run.assisted ? "assisted|" : "direct|") + run.level.boardID }

    /// Loads the level artwork, hint deck and play location while the record card is open.
    private func loadRecordDetail(_ key: String) {
        recordDetail = MobileRecordDetail(key: key)
        guard let conditions = arcadeStore.records.runs.last(where: { recordKey($0) == key })?.level.conditions,
              let location = try? mobileRankedLocation(conditions), let catalogue else { return }
        recordDetail?.pack = location.pack; recordDetail?.index = location.index
        let ports = catalogue.portsRoot, fan = catalogue.fanFolders, pack = location.pack, index = location.index
        let settings = mobileSettings.classic
        let content = try? location.library.loadLevel(at: index)
        let initial = (content?.session as? ClassicMobileSession)?.initialSimulation
        let title = content?.summary.title ?? ""
        let skills = content?.session.snapshot.skills.filter { $0.count != 0 }.map(\.name) ?? []
        Task { [weak self] in
            let loader = MobileMenuPreviewLoader { try MobileCatalogue(portsRoot: ports, fanFolders: fan).library(for: pack) }
            let preview = try? await loader.load(index, settings: settings)
            let teaching = content == nil ? nil : await MobileTeachingLoader.shared.load(initial: initial, title: title, skills: skills,
                chronicles: content?.session is Lemmings3MobileSession)
            guard let self, self.recordDetail?.key == key else { return }
            if let preview, let image = MobileBitmapRenderer.image(preview.frame) {
                let source = preview.sourceRect
                self.recordDetail?.preview = image
                self.recordDetail?.previewSource = CGRect(x: source.x, y: source.y, width: source.width, height: source.height)
            }
            self.recordDetail?.deck = teaching?.0
            self.recordDetail?.solution = teaching?.1
            self.recordDetail?.initial = initial
            if case .recordLevel = self.route { self.rebuild() } else if case .recordHint = self.route { self.rebuild() }
        }
    }
    private func playRecordLevel() {
        guard let detail = recordDetail, let pack = detail.pack, let index = detail.index else { return }
        openPack(pack, back: .recordLevel(detail.key), play: index)
    }
    private func playRecordSolution() {
        guard let detail = recordDetail, let solution = detail.solution, let initial = detail.initial,
              let conditions = arcadeStore.records.runs.last(where: { recordKey($0) == detail.key })?.level.conditions else { return }
        do {
            let content = try loadMobileRankedContent(conditions)
            guard let classic = content.session as? ClassicMobileSession,
                  TrolleyCapture.classicFingerprint(classic.initialSimulation) == TrolleyCapture.classicFingerprint(initial),
                  let session = try classic.makeReplaySession(document: JSONEncoder().encode(solution.replay)) else { return }
            let store = MobileCheckpointStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("solution-replay-" + UUID().uuidString))
            let player = MobileGameViewController(summary: content.summary, session: session, checkpointStore: store, restoredCheckpoint: nil,
                settingsProfileID: settingsProfileID)
            player.modalPresentationStyle = .fullScreen
            present(player, animated: false)
        } catch { notice = error.localizedDescription; rebuild() }
    }
    /// The newest retained action replay for a record key. Only Classic sessions retain actions.
    func recordReplay(_ key: String) -> (url: URL, title: String)? {
        let assisted = key.hasPrefix("assisted|")
        let board = String(key.dropFirst(assisted ? 9 : key.hasPrefix("direct|") ? 7 : 0))
        for run in arcadeStore.records.runs.reversed()
            where run.profileID == profiles.activeID && run.level.boardID == board && run.assisted == assisted {
            if let url = arcadeStore.actionReplayURL(attemptID: run.id) { return (url, run.level.title) }
        }
        return nil
    }
    private func playRecordReplay(_ key: String) {
        guard let saved = recordReplay(key) else { return }
        do {
            let replay = try JSONDecoder().decode(LeaderboardActionReplay.self, from: Data(contentsOf: saved.url))
            showRankedActionReplay(replay, title: saved.title)
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
        case "records": navigate(.progress)
        case "recordList": navigate(.records)
        case "recordReplay": if case let .recordLevel(key) = route { playRecordReplay(key) }
        case "recordPlay": playRecordLevel()
        case "recordSolution": playRecordSolution()
        case "recordHint":
            guard let detail = recordDetail, detail.deck != nil else { return true }
            navigate(.recordHint(detail.key))
        case "recordHintBack": if let key = recordDetail?.key { navigate(.recordLevel(key)) }
        case "recordHintPrevious", "recordHintNext":
            recordDetail?.stage += id == "recordHintNext" ? 1 : -1; rebuild()
        case "achievements": navigate(.achievements)
        default:
            if id.hasPrefix("record.") {
                let key = String(id.dropFirst(7))
                navigate(.recordLevel(key)); loadRecordDetail(key)
            }
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
            MobileResultAwardsCache.rewards.removeAll()
        }
        MobileResultAwardsCache.values[run.id] = (celebration.goals.stars,
            ResultAwards.ornament(report: report, celebration: celebration, history: arcadeStore.records.trolley))
        let campaignAfter = mobileCampaignProgress(profileID: run.profileID).unlocked
        var achievementInfo = MobileResultAchievementsArt.goals(celebration.goals)
        let rewards = ResultAwards.earnedRewards(report: report, celebration: celebration)
        MobileResultAwardsCache.rewards[run.id] = rewards
        achievementInfo += rewards.map { reward in
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
        details += rewards.filter(\.isConsumable).map(\.title)
        if run.usedBonusSkill { details.insert(L10n.text("Bonus skill used"), at: 0) }
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
