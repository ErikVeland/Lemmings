#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

extension MobileLibraryViewController {
    var learningStorage: MobileStorage { .standard(profile: hotSeat?.scope ?? profiles.activeID) }
    var learning: MobileLearningState {
        get {
            var saved = learningStorage.load(MobileLearningState.self, name: "learning") ?? .init()
            let original = saved
            if let snapshot = GameProgressPreferences.journeySession(profileID: profiles.activeID, sessionID: hotSeat?.id) {
                saved.importJourneySession(snapshot)
            }
            saved.progress = GameProgressValue.mergeLearning(saved.progress,
                GameProgressPreferences.learning(profileID: profiles.activeID, sessionID: hotSeat?.id))
            if saved.journeySession == nil, saved.run?.source == .playlist(LearningJourney.playlistID) {
                saved.refreshJourneySession()
            }
            if let run = saved.run, let journey = bundledJourney {
                do {
                    let completed = saved.progress.completed
                    let campaign = LevelPlaylistStore.classicCampaignWins { [self] in solvedLevels(for: "release/" + $0) }
                    let migration = try journey.migration(of: run) { completed.contains($0) || campaign($0) }
                    let migrated = migration.run
                    if migrated != run {
                        var updated = saved; updated.run = migrated
                        // Skipped earlier lessons stay available in "Come back to these".
                        for identity in migration.deferred { updated.progress.record(identity, won: false) }
                        updated.refreshJourneySession()
                        saved = updated
                    }
                } catch { notice = error.localizedDescription }
            }
            if saved != original {
                do { try learningStorage.save(saved, name: "learning") }
                catch { notice = error.localizedDescription }
            }
            return saved
        }
        set {
            do { try saveLearningState(newValue) }
            catch { notice = error.localizedDescription }
        }
    }
    func saveLearningState(_ value: MobileLearningState) throws {
        var saved = value; saved.refreshJourneySession()
        try learningStorage.save(saved, name: "learning")
        try GameProgressPreferences.saveLearning(saved.progress, profileID: profiles.activeID, sessionID: hotSeat?.id)
        if let snapshot = saved.journeySession {
            try GameProgressPreferences.saveJourneySession(snapshot, profileID: profiles.activeID, sessionID: hotSeat?.id)
        }
        arcadeStore.notifyProgressChanged()
    }
    var bundledJourney: LearningJourney? { LearningJourneyLibrary.journey }
    var shownJourneyProgress: LearningJourneyProgress { learning.progress }
    var canStartJourney: Bool {
        hotSeat == nil && learning.run == nil && activeRun == nil && pendingCheckpoint == nil
    }
    var resumableLearningJourney: MobileLearningResume? {
        _ = learning
        return MobileLearningResume.find(owner: profiles.activeID, seats: hotSeats, storage: MobileStorage.standard)
    }

    var resumableLearningRun: MobileLearningResume? {
        _ = learning
        return MobileLearningResume.find(owner: profiles.activeID, seats: hotSeats, storage: MobileStorage.standard,
                                  journeyOnly: false, currentSessionOnly: true)
    }

    /// All engines compare the saved level identity before resuming a route.
    func checkpointResumesLearningRun(_ checkpoint: MobileCheckpointEnvelope) -> Bool {
        guard checkpointMatchesSession(checkpoint),
              let saved = resumableLearningRun, let run = saved.state.run,
              let catalogue else { return false }
        let queue = MobileJourneyLibrary(entries: run.entries, name: run.pool.summary, catalogue: catalogue)
        guard let identifier = try? queue.checkpointLevelIdentifier(at: run.currentIndex) else { return false }
        return identifier == checkpoint.levelIdentifier
    }

    func learningPage(subtitle: String) -> GameFrontEnd.Page {
        guard let journey = bundledJourney else { return .init(title: L10n.text("Journey"), details: [L10n.text("Journey is unavailable")], footer: [.init("home", L10n.text("Back"))]) }
        let saved = learning
        var footer = [GameFrontEnd.Action("home", L10n.text("Back"))]
        if let run = resumableLearningJourney?.state.run {
            footer.append(.init("learningResume", L10n.text("Resume  \(run.currentIndex + 1)/\(run.entries.count)"), primary: true))
        }
        let unseen = saved.progress.unseen(in: journey), revisit = saved.progress.revisit(in: journey)
        footer.append(.init("learningStart", L10n.text("Continue journey  \(shownJourneyProgress.solvedCount(in: journey))/\(journey.lessons.count)"),
                            enabled: !unseen.isEmpty || MobileSettings.current(from: .standard).classic.unlockAllClassicLevels, primary: resumableLearningJourney == nil))
        let rows: [GameFrontEnd.Action] = [
            .init("learningBrowse", L10n.text("Choose level"), enabled: resumableLearningJourney != nil),
            .init("learningRevisit", L10n.text("Revisit  \(revisit.count)"), enabled: !revisit.isEmpty),
            .init("progression", L10n.text("Progression playlists"))]
        return .init(title: LearningJourney.title, subtitle: subtitle, rows: rows, footer: footer)
    }
    func progressionPage(subtitle: String) -> GameFrontEnd.Page {
        .init(title: L10n.text("Progression"), subtitle: subtitle,
              rows: ProgressionPolicy.allCases.map { .init("policy." + $0.rawValue, $0.name) },
              footer: [.init(progressionBackID, L10n.text("Back"))])
    }
    func techniquePage(subtitle: String) -> GameFrontEnd.Page {
        .init(title: L10n.text("Techniques"), subtitle: subtitle,
              rows: LevelHintDeck.jobs.keys.sorted().map { .init("technique." + $0, SkillVocabulary.title($0)) },
              footer: [.init("progression", L10n.text("Back"))])
    }
    func handleLearning(_ id: String) -> Bool {
        switch id {
        case "journey":
            guard resumableLearningJourney != nil || canStartJourney else { return true }
            navigate(.journey)
        case "learningResume": resumeLearningJourney()
        case "learningBrowse": resumeLearningJourney(browse: true)
        case "learningRunResume": resumeLearningJourney(journeyOnly: false)
        case "learningStart", "learningRevisit":
            guard resumableLearningJourney != nil || canStartJourney else { return true }
            if id == "learningStart", resumableLearningJourney != nil { resumeLearningJourney(browse: true); return true }
            guard let journey = bundledJourney else { return true }
            let entries = id == "learningStart"
                ? (MobileSettings.current(from: .standard).classic.unlockAllClassicLevels ? journey.lessons.map(\.entry) : learning.progress.unseen(in: journey))
                : learning.progress.revisit(in: journey)
            do {
                var saved = learning
                try saved.start(entries, name: LearningJourney.title, poolID: journey.version)
                try saveLearningState(saved); openLearningRun()
            } catch { notice = error.localizedDescription; rebuild() }
        case "progression":
            if route == .collections { progressionBackID = "collections" } else if route == .journey { progressionBackID = "journey" }
            navigate(.progression)
        default:
            if id.hasPrefix("policy."), let policy = ProgressionPolicy(rawValue: String(id.dropFirst(7))) {
                if policy == .techniqueCurriculum { navigate(.techniques) }
                else { prepareProgression(policy: policy, technique: nil) }
            } else if id.hasPrefix("technique.") { prepareProgression(policy: .techniqueCurriculum, technique: String(id.dropFirst(10))) }
            else { return false }
        }
        return true
    }
    func resumeLearningJourney(journeyOnly: Bool = true, browse: Bool = false) {
        guard let saved = journeyOnly ? resumableLearningJourney : resumableLearningRun,
              saved.owner == profiles.activeID, saved.seat?.id == hotSeat?.id else { return }
        if let seat = saved.seat {
            guard seat.players.allSatisfy({ id in profiles.players.contains { $0.id == id } }) else {
                notice = L10n.text("A saved player is unavailable"); rebuild(); return
            }
        }
        guard saveHotSeats() else { rebuild(); return }
        hotSeatRoster = nil; activeRun = nil
        reloadPlayerData()
        let owner = profiles.activeID, scope = hotSeat?.scope
        learningTask?.cancel()
        learningTask = Task { [weak self] in
            guard let self, let checkpointStore else { return }
            do {
                let checkpoint = try await checkpointStore.load(owner: owner, scope: scope)
                guard !Task.isCancelled, profiles.activeID == owner, hotSeat?.scope == scope else { return }
                let matching = checkpoint.flatMap { checkpointMatchesSession($0) ? $0 : nil }
                if browse, MobileSettings.current(from: .standard).classic.unlockAllClassicLevels,
                   let journey = bundledJourney, let current = learning.run,
                   current.pool.id.hasPrefix("learning-"),
                   let position = journey.lessons.firstIndex(where: { $0.entry.identity == current.currentEntry.identity }) {
                    var expanded = learning
                    expanded.run = try LevelSequenceRun(id: current.id, source: current.source, pool: current.pool,
                        entries: journey.lessons.map(\.entry), currentIndex: position, createdAt: current.createdAt)
                    try saveLearningState(expanded)
                }
                openLearningRun()
                if !browse, let run = learning.run { startLevel(run.currentIndex, checkpoint: matching, restoringMatchingCheckpoint: true) }
            } catch { notice = error.localizedDescription; rebuild() }
        }
    }
    func openLearningRun(checkpoint: MobileCheckpointEnvelope? = nil) {
        guard let catalogue, let run = learning.run else { return }
        let ports = catalogue.portsRoot, fan = catalogue.fanFolders, entries = run.entries, name = run.pool.summary
        library = MobileJourneyLibrary(entries: entries, name: name, catalogue: catalogue)
        currentPack = nil; activeRun = nil
        previewLoader = MobileMenuPreviewLoader {
            MobileJourneyLibrary(entries: entries, name: name, catalogue: MobileCatalogue(portsRoot: ports, fanFolders: fan))
        }
        selectedIndex = run.currentIndex; selectedPreview = nil; browserShown = false
        levelsBackRoute = .journey
        if let checkpoint { startLevel(run.currentIndex, checkpoint: checkpoint) }
        else { navigate(.levels); selectLevel(run.currentIndex) }
    }
    func recordLearningResult(_ snapshot: MobileGameSnapshot) throws {
        guard library is MobileJourneyLibrary else { return }
        var saved = learning; saved.record(won: snapshot.didWin); try saveLearningState(saved)
        arcadeStore.notifyProgressChanged()
    }
    func advanceLearningRun() throws -> Bool {
        var saved = learning
        let moved = saved.advance()
        try saveLearningState(saved)
        return moved
    }

    /// The same scorer and policy generator serve the Mac and iPad.
    private func prepareProgression(policy: ProgressionPolicy, technique: String?) {
        guard bundledJourney != nil, !learningPreparing else { return }
        learningTask?.cancel()
        learningPreparing = true; notice = L10n.text("Loading..."); rebuild()
        guard let catalogue else { learningPreparing = false; return }
        let ports = catalogue.portsRoot, folders = catalogue.fanFolders
        let owner = profiles.activeID, scope = hotSeat?.scope
        learningTask = Task {
            let result: Result<ProgressionResult, Error>
            do {
                result = .success(try await MobileProgressionBuilder.generate(portsRoot: ports, fanFolders: folders,
                    policy: policy, technique: technique, storage: .current(), progress: { _, _ in }))
            } catch { result = .failure(error) }
            guard !Task.isCancelled else { return }
            guard profiles.activeID == owner, hotSeat?.scope == scope else { learningPreparing = false; return }
            learningPreparing = false
            do {
                let result = try result.get()
                var saved = learning
                try saved.start(result.entries, name: result.policy.name, poolID: ProgressionModel.version, playlistID: UUID())
                try saveLearningState(saved); openLearningRun()
            } catch { notice = error.localizedDescription; rebuild() }
        }
    }

    func loadMobileRankedContent(_ conditions: TrolleyConditions) throws -> MobileLevelContent {
        let location = try mobileRankedLocation(conditions)
        let content = try location.library.loadLevel(at: location.index)
        guard let classic = content.session as? ClassicMobileSession,
              TrolleyCapture.classicFingerprint(classic.initialSimulation) == conditions.levelFingerprint else {
            throw MobileSessionError.changedLevel
        }
        return content
    }
    /// The catalogue pack and level index that recorded conditions name.
    func mobileRankedLocation(_ conditions: TrolleyConditions) throws -> (pack: MobileContentPack, index: Int, library: any MobileGameLibrary) {
        guard let catalogue else { throw MobileSessionError.changedLevel }
        let pack: MobileContentPack?
        if conditions.gameID == "fan" {
            let id = ClassicFanPack.catalogueID(URL(fileURLWithPath: conditions.packID))
            pack = catalogue.pack(id: conditions.packID) ?? catalogue.pack(id: id)
        } else { pack = catalogue.pack(id: "release/" + conditions.gameID) }
        guard let pack else { throw MobileSessionError.changedLevel }
        let source = try catalogue.library(for: pack)
        let index: Int?
        if let fan = source as? ClassicFanMobileLibrary {
            let parts = conditions.levelID.split(separator: ":", omittingEmptySubsequences: false)
            let key = parts.count == 2 ? String(parts[0]) + "#" + (parts[1] == "whole-file" ? "-1" : String(parts[1])) : conditions.levelID
            index = fan.entries.firstIndex { $0.key == key || conditions.levelID.hasSuffix("/" + $0.key) }
        } else if conditions.levelID.hasPrefix("level-") { index = Int(conditions.levelID.dropFirst(6)) }
        else { index = source.levels.indices.first { conditions.levelID.hasSuffix("/" + source.levelKey(at: $0)) } }
        guard let index, source.levels.indices.contains(index) else { throw MobileSessionError.changedLevel }
        return (pack, index, source)
    }
}
#endif
