#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

/// Home and Play share one view of the selected session's saved routes.
extension MobileLibraryViewController {
    struct HomeContinuations {
        /// The Journey row. Always present so the Journey stays reachable from Play.
        var journey: GameFrontEnd.Action?
        /// Saved level, sequence and playlist rows, in their established order.
        var resume: [GameFrontEnd.Action]
        /// The single action Home offers first.
        var continueAction: GameFrontEnd.Action?
    }

    func homeContinuations() -> HomeContinuations {
        var resume: [GameFrontEnd.Action] = []
        var candidates: [ContinueResolver.Candidate] = []
        let savedLevel = pendingCheckpoint.flatMap { checkpointMatchesSession($0) ? $0 : nil }
        let journeyAttempt = savedLevel.flatMap { checkpointResumesLearningRun($0, journeyOnly: true) ? $0.savedAt : nil }
        let sequenceAttempt = savedLevel.flatMap { checkpointResumesLearningRun($0) ? $0.savedAt : nil }
        if let saved = savedLevel, sequenceAttempt == nil, journeyAttempt == nil {
            let owner = saved.owner ?? profiles.activeID
            resume.append(.init("resume", L10n.text("Resume level - \(playerName(owner))")))
            candidates.append(.savedLevel(savedAt: saved.savedAt, owner: owner))
        }
        if catalogue != nil, let saved = resumableLearningRun, let run = saved.state.run,
           run.source != .playlist(LearningJourney.playlistID) {
            let session = saved.seat?.id != hotSeat?.id ? saved.seat.map { " - " + $0.players.map(playerName).joined(separator: " vs ") } ?? " - " + profiles.active.name : ""
            resume.append(.init("learningRunResume", saved.resumeTitle + session))
            candidates.append(.sequence(title: run.pool.summary, position: run.currentIndex + 1,
                                        total: run.entries.count, attemptSavedAt: sequenceAttempt))
        }
        if catalogue != nil, let run = playlists.run,
           run.playlist != LearningJourney.playlistID {
            resume.append(.init("runResume", L10n.text("Resume \(run.name)  \(run.position + 1)/\(run.entries.count)")))
            candidates.append(.playlist(name: run.name, position: run.position + 1, total: run.entries.count))
        }
        let journeyRun = resumableLearningJourney?.state.run
        if bundledJourney != nil, let run = journeyRun {
            candidates.append(.journey(position: run.currentIndex + 1, total: run.entries.count,
                                       attemptSavedAt: journeyAttempt))
        }
        let journeyAvailable = catalogue != nil && bundledJourney != nil
        let journey = MobileHomeArt.journeyAction(run: journeyRun, enabled: journeyAvailable)
        let continueAction: GameFrontEnd.Action? = switch ContinueResolver.resolve(candidates, journeyAvailable: journeyAvailable) {
        case let .resume(candidate):
            candidate.actionID == "journey" ? journey : resume.first { $0.id == candidate.actionID }
        case .startJourney: journey
        case .none: nil
        }
        return HomeContinuations(journey: journey, resume: resume, continueAction: continueAction)
    }

    /// One row per game. A missing game offers its import instead of disappearing.
    func gameFamilyActions() -> [GameFrontEnd.Action] {
        let count = library?.levels.count ?? 0
        return MobileFamily.allCases.map { family in
            let packs = catalogue?.packs(in: family) ?? []
            if catalogue == nil, family == .classic {
                return .init("classic", L10n.text("Classic Lemmings  \(solved.count)/\(count)"), enabled: count > 0)
            }
            let total = packs.reduce(0) { $0 + ($1.levelCount ?? 0) }
            let passed = packs.reduce(0) { $0 + solvedLevels(for: $1.id).count }
            let title = family.title + (packs.isEmpty ? L10n.text(" - No data") : "  \(passed)/\(total)")
            return .init("family." + family.rawValue, title,
                         enabled: !packs.isEmpty || (MobileResourceAccess.isStore && catalogue != nil && !loading))
        } + [.init("neolemmix", hasNeoLemmixData ? L10n.text("NeoLemmix Preview") : L10n.text("Import NeoLemmix data")),
             .init("l2", hasLemmings2Data ? L10n.text("Lemmings 2") : L10n.text("Import Lemmings 2 data"), gameLogo: .lemmings2),
             .init("l3", hasLemmings3Data ? Lemmings3Brand.current.displayName : L10n.text("Import \(Lemmings3Brand.current.displayName) data"), enabled: true, gameLogo: .lemmings3)]
    }

    /// Back from a page under Play returns to Play. Main menu still goes straight Home.
    func navigateToBrowseRoot() {
        navigate(cameFromPlay ? .play : .home)
    }

    func handleHome(_ id: String) -> Bool {
        switch id {
        case "play": navigate(.play)
        case "playBack": navigate(.home)
        case "profile": navigate(.progress)
        default: return false
        }
        return true
    }
}
#endif
