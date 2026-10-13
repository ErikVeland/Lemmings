#if os(iOS)
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
            if hotSeat == nil {
                saved.progress = GameProgressValue.mergeLearning(saved.progress,
                    GameProgressPreferences.learning(profileID: profiles.activeID))
            }
            if let run = saved.run, let journey = bundledJourney {
                do {
                    let migrated = try journey.migrating(run)
                    if migrated != run {
                        var updated = saved; updated.run = migrated
                        try learningStorage.save(updated, name: "learning")
                        saved = updated
                    }
                } catch { notice = error.localizedDescription }
            }
            return saved
        }
        set {
            do { try learningStorage.save(newValue, name: "learning"); arcadeStore.notifyProgressChanged() }
            catch { notice = error.localizedDescription }
        }
    }
    var bundledJourney: LearningJourney? { LearningJourneyLibrary.journey }
    var resumableLearningJourney: MobileLearningResume? {
        MobileLearningResume.find(owner: profiles.activeID, seats: hotSeats, storage: MobileStorage.standard)
    }

    func learningPage(subtitle: String) -> GameFrontEnd.Page {
        guard let journey = bundledJourney else { return .init(title: "Journey", details: ["Journey is unavailable"], footer: [.init("home", "Back")]) }
        let saved = learning
        var rows: [GameFrontEnd.Action] = []
        if let run = resumableLearningJourney?.state.run {
            rows.append(.init("learningResume", "Resume  \(run.currentIndex + 1)/\(run.entries.count)", primary: true))
        }
        let unseen = saved.progress.unseen(in: journey), revisit = saved.progress.revisit(in: journey)
        var footer = [GameFrontEnd.Action("home", "Back")]
        footer += rows
        rows = []
        footer.append(.init("learningStart", "Continue journey  \(saved.progress.solvedCount(in: journey))/\(journey.lessons.count)",
                       enabled: !unseen.isEmpty, primary: resumableLearningJourney == nil))
        rows += [.init("learningRevisit", "Revisit  \(revisit.count)", enabled: !revisit.isEmpty),
                 .init("progression", "Progression playlists")]
        return .init(title: LearningJourney.title, subtitle: subtitle, rows: rows, footer: footer)
    }
    func progressionPage(subtitle: String) -> GameFrontEnd.Page {
        .init(title: "Progression", subtitle: subtitle,
              rows: ProgressionPolicy.allCases.map { .init("policy." + $0.rawValue, $0.name) },
              footer: [.init("journey", "Back")])
    }
    func techniquePage(subtitle: String) -> GameFrontEnd.Page {
        .init(title: "Techniques", subtitle: subtitle,
              rows: LevelHintDeck.jobs.keys.sorted().map { .init("technique." + $0, $0.capitalized) },
              footer: [.init("progression", "Back")])
    }
    func handleLearning(_ id: String) -> Bool {
        switch id {
        case "journey": navigate(.journey)
        case "learningResume": resumeLearningJourney()
        case "learningStart", "learningRevisit":
            if id == "learningStart", resumableLearningJourney != nil { resumeLearningJourney(); return true }
            guard let journey = bundledJourney else { return true }
            let entries = id == "learningStart" ? learning.progress.unseen(in: journey) : learning.progress.revisit(in: journey)
            do {
                var saved = learning
                try saved.start(entries, name: LearningJourney.title, poolID: journey.version)
                try learningStorage.save(saved, name: "learning"); openLearningRun()
            } catch { notice = error.localizedDescription; rebuild() }
        case "progression": navigate(.progression)
        default:
            if id.hasPrefix("policy."), let policy = ProgressionPolicy(rawValue: String(id.dropFirst(7))) {
                if policy == .techniqueCurriculum { navigate(.techniques) }
                else { prepareProgression(policy: policy, technique: nil) }
            } else if id.hasPrefix("technique.") { prepareProgression(policy: .techniqueCurriculum, technique: String(id.dropFirst(10))) }
            else { return false }
        }
        return true
    }
    func resumeLearningJourney() {
        guard let saved = resumableLearningJourney, saved.owner == profiles.activeID else { return }
        if let seat = saved.seat {
            guard seat.players.allSatisfy({ id in profiles.players.contains { $0.id == id } }) else {
                notice = "A saved player is unavailable"; rebuild(); return
            }
            if hotSeat?.id != seat.id { guard hotSeats.resume(id: seat.id) != nil else { return } }
        } else { hotSeats.endSession() }
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
                openLearningRun()
                if let run = learning.run { startLevel(run.currentIndex, checkpoint: checkpoint, restoringMatchingCheckpoint: true) }
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
        var saved = learning; saved.record(won: snapshot.didWin); try learningStorage.save(saved, name: "learning")
        arcadeStore.notifyProgressChanged()
    }
    func advanceLearningRun() throws -> Bool {
        var saved = learning
        let moved = saved.advance()
        try learningStorage.save(saved, name: "learning")
        return moved
    }

    /// The same scorer and policy generator serve the Mac and iPad.
    private func prepareProgression(policy: ProgressionPolicy, technique: String?) {
        guard bundledJourney != nil, !learningPreparing else { return }
        learningTask?.cancel()
        learningPreparing = true; notice = "Loading..."; rebuild()
        guard let catalogue else { learningPreparing = false; return }
        let ports = catalogue.portsRoot, folders = catalogue.fanFolders
        learningTask = Task {
            let result: Result<ProgressionResult, Error>
            do {
                result = .success(try await MobileProgressionBuilder.generate(portsRoot: ports, fanFolders: folders,
                    policy: policy, technique: technique, storage: .current(), progress: { _, _ in }))
            } catch { result = .failure(error) }
            guard !Task.isCancelled else { return }
            learningPreparing = false
            do {
                let result = try result.get()
                var saved = learning
                try saved.start(result.entries, name: result.policy.name, poolID: ProgressionModel.version, playlistID: UUID())
                try learningStorage.save(saved, name: "learning"); openLearningRun()
            } catch { notice = error.localizedDescription; rebuild() }
        }
    }

    func loadMobileRankedContent(_ conditions: TrolleyConditions) throws -> MobileLevelContent {
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
        let content = try source.loadLevel(at: index)
        guard let classic = content.session as? ClassicMobileSession,
              TrolleyCapture.classicFingerprint(classic.initialSimulation) == conditions.levelFingerprint else {
            throw MobileSessionError.changedLevel
        }
        return content
    }
}
#endif
