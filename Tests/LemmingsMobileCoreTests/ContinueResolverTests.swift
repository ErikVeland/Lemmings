import Foundation
import Testing
@testable import LemmingsMobileCore

@Suite struct ContinueResolverTests {
    private let earlier = Date(timeIntervalSince1970: 1_000)
    private let later = Date(timeIntervalSince1970: 2_000)

    @Test func noCandidatesOffersJourneyWhenAvailable() {
        #expect(ContinueResolver.resolve([], journeyAvailable: true) == .startJourney)
        #expect(ContinueResolver.resolve([], journeyAvailable: false) == .none)
    }

    @Test(arguments: [
        ContinueResolver.Candidate.savedLevel(savedAt: Date(timeIntervalSince1970: 1), owner: "EKV"),
        .journey(position: 4, total: 120, attemptSavedAt: nil),
        .sequence(title: "Builders", position: 2, total: 8, attemptSavedAt: nil),
        .playlist(name: "Favourites", position: 1, total: 5),
    ])
    func singleCandidateIsChosen(_ candidate: ContinueResolver.Candidate) {
        #expect(ContinueResolver.resolve([candidate], journeyAvailable: true) == .resume(candidate))
    }

    @Test func resultDoesNotDependOnInputOrder() {
        let candidates: [ContinueResolver.Candidate] = [
            .playlist(name: "Favourites", position: 1, total: 5),
            .journey(position: 4, total: 120, attemptSavedAt: earlier),
            .savedLevel(savedAt: later, owner: "EKV"),
            .sequence(title: "Builders", position: 2, total: 8, attemptSavedAt: nil),
        ]
        let expected = ContinueResolver.resolve(candidates, journeyAvailable: true)
        #expect(ContinueResolver.resolve(candidates.reversed(), journeyAvailable: true) == expected)
        #expect(ContinueResolver.resolve(candidates.shuffled(), journeyAvailable: true) == expected)
    }

    @Test func aResumableCandidateAlwaysBeatsStartJourney() {
        let only = ContinueResolver.Candidate.playlist(name: "Favourites", position: 1, total: 5)
        #expect(ContinueResolver.resolve([only], journeyAvailable: true) != .startJourney)
    }

    @Test func newestMidLevelAttemptWins() {
        let level = ContinueResolver.Candidate.savedLevel(savedAt: later, owner: "EKV")
        let journey = ContinueResolver.Candidate.journey(position: 4, total: 120, attemptSavedAt: earlier)
        #expect(ContinueResolver.resolve([journey, level], journeyAvailable: true) == .resume(level))
        let newerJourney = ContinueResolver.Candidate.journey(position: 4, total: 120, attemptSavedAt: later.addingTimeInterval(1))
        #expect(ContinueResolver.resolve([newerJourney, level], journeyAvailable: true) == .resume(newerJourney))
    }

    @Test func anAttemptBeatsARouteWithoutOne() {
        let sequence = ContinueResolver.Candidate.sequence(title: "Builders", position: 2, total: 8, attemptSavedAt: earlier)
        let journey = ContinueResolver.Candidate.journey(position: 4, total: 120, attemptSavedAt: nil)
        #expect(ContinueResolver.resolve([journey, sequence], journeyAvailable: true) == .resume(sequence))
    }

    @Test func withoutAttemptsJourneyLeadsThenSequenceThenPlaylist() {
        let journey = ContinueResolver.Candidate.journey(position: 4, total: 120, attemptSavedAt: nil)
        let sequence = ContinueResolver.Candidate.sequence(title: "Builders", position: 2, total: 8, attemptSavedAt: nil)
        let playlist = ContinueResolver.Candidate.playlist(name: "Favourites", position: 1, total: 5)
        #expect(ContinueResolver.resolve([playlist, sequence, journey], journeyAvailable: true) == .resume(journey))
        #expect(ContinueResolver.resolve([playlist, sequence], journeyAvailable: true) == .resume(sequence))
    }

    @Test func actionIDsMatchExistingHomeActions() {
        #expect(ContinueResolver.Candidate.savedLevel(savedAt: earlier, owner: "A").actionID == "resume")
        #expect(ContinueResolver.Candidate.journey(position: 1, total: 2, attemptSavedAt: nil).actionID == "journey")
        #expect(ContinueResolver.Candidate.sequence(title: "", position: 1, total: 2, attemptSavedAt: nil).actionID == "learningRunResume")
        #expect(ContinueResolver.Candidate.playlist(name: "", position: 1, total: 2).actionID == "runResume")
    }
}
