import Foundation
import Testing
@testable import NxlvKit

struct LearningJourneyTests {
    func candidate(_ index: Int, score: Double, concepts: [String] = ["builder"], confidence: DifficultyConfidence = .medium) throws -> ProgressionCandidate {
        let identity = LevelCatalogueIdentity(engine: .classic, packID: "test", levelID: "\(index)")
        let key = DifficultyCacheKey(identity: identity, levelRevision: "v1")
        let profile = DifficultyProfile(key: key, confidence: confidence,
            components: .init(techniqueBurden: score, solutionComplexity: score, executionPrecision: score,
                              concurrencyBurden: score, constraintPressure: score, deductionComplexityProxy: score),
            detectedTechniques: concepts)
        let entry = try LevelPlaylistEntry(identity: identity, catalogueRevision: "v1", sourceRevision: "v1",
            packNameSnapshot: "Test", levelNameSnapshot: "Level \(index)", levelNumberSnapshot: index + 1)
        return .init(entry: entry, profile: profile, isOfficial: true, campaignOrder: index)
    }
    @Test func keepsTheWholeCampaignAndFillsTheRetailJump() throws {
        let values = try (0..<352).map { try candidate($0, score: Double($0) * 2) }
        let journey = try LearningJourney.generate(values.reversed())
        #expect(journey.lessons.count == 352)
        #expect(Set(journey.lessons.map { $0.entry.identity }) == Set(values.map { $0.entry.identity }))
        #expect(try journey == LearningJourney.generate(values))
        #expect(zip(journey.lessons, journey.lessons.dropFirst()).allSatisfy { $1.score - $0.score <= LearningJourney.maximumScoreStep })
    }
    @Test func officialLevelsLeadComparablePortLevelsWithoutOverridingDifficulty() throws {
        let low = try candidate(7, score: 40, concepts: ["miner"])
        let high = try candidate(0, score: 300, concepts: ["digger"])
        let fan = ProgressionCandidate(entry: low.entry, profile: low.profile, isOfficial: false, campaignOrder: 999)
        let journey = try LearningJourney.generate([high, fan])
        #expect(journey.lessons.map(\.score) == [40, 300])
        #expect(journey.lessons.first?.entry.identity == fan.entry.identity)
        let reversedOrigins = [ProgressionCandidate(entry: high.entry, profile: high.profile, isOfficial: false, campaignOrder: 0), low]
        #expect(try LearningJourney.generate(reversedOrigins) == journey)
        let official = try candidate(1, score: 40, concepts: ["miner"])
        let comparable = try LearningJourney.generate([fan, official])
        #expect(comparable.lessons.first?.entry.identity == official.entry.identity)
    }
    @Test func authoredObjectivesSeparateIntroductionsFromCombinations() throws {
        let dig = try candidate(0, score: 40, concepts: ["digger"])
        let build = try candidate(1, score: 50, concepts: ["builder"])
        let combine = try candidate(2, score: 80, concepts: ["builder", "digger"])
        let objectives = [dig.entry.identity: "introduce:digger", build.entry.identity: "introduce:builder",
                          combine.entry.identity: "chain:digger:builder"]
        let result = try LearningJourney.generate([combine, build, dig], objectives: objectives)
        #expect(result.lessons.map(\.stage) == [.fun, .fun, .intermediate])
        #expect(result.lessons.last?.score == combine.profile.overallScore)
        #expect(throws: LevelPlaylistError.self) {
            try LearningJourney.generate([dig, build], objectives: [dig.entry.identity: "same", build.entry.identity: "same"])
        }
    }
    @Test func complexRoutesWaitForSecondBasicSkillPractice() throws {
        let climb = try candidate(0, score: 55, concepts: ["climber"])
        let build = try candidate(1, score: 60, concepts: ["builder"])
        let short = try candidate(2, score: 260, concepts: ["climber", "builder"])
        let complex = try candidate(3, score: 225, concepts: ["climber", "builder", "release-rate-manipulation"])
        let result = try LearningJourney.generate([complex, short, build, climb])
        #expect(result.lessons.map(\.entry.identity) == [climb, build, short, complex].map(\.entry.identity))
        #expect(result.lessons.last?.preparationGaps.isEmpty == true)
        #expect(result.lessons.last?.score == complex.profile.overallScore)
        #expect(result.lessons.last!.demand >= result.lessons.last!.intrinsicDemand)
    }

    @Test func authoredIntroductionsFinishBeforeEarlyCombinations() throws {
        let dig = try candidate(0, score: 55, concepts: ["digger"])
        let block = try candidate(1, score: 138, concepts: ["blocker"])
        let mine = try candidate(2, score: 164, concepts: ["miner"])
        let combine = try candidate(3, score: 138, concepts: ["blocker", "digger"])
        let objectives = [dig.entry.identity: "introduce:digger", block.entry.identity: "introduce:blocker",
                          mine.entry.identity: "introduce:miner", combine.entry.identity: "split:blocker:digger"]
        let result = try LearningJourney.generate([combine, mine, block, dig], objectives: objectives)
        #expect(result.lessons.map(\.entry.identity) == [dig, block, mine, combine].map(\.entry.identity))
        #expect(result.lessons.last?.score == combine.profile.overallScore)
        #expect(result.lessons.last?.demand == mine.profile.overallScore)
        #expect(result.lessons.last?.stage == .intermediate)
    }

    @Test func introductionDoesNotConcealIntermediateDemand() throws {
        let first = try candidate(0, score: 138, concepts: ["blocker"])
        let mine = try candidate(1, score: 234, concepts: ["miner"])
        let result = try LearningJourney.generate([mine, first], objectives: [
            first.entry.identity: "introduce:blocker", mine.entry.identity: "introduce:miner"])
        #expect(result.lessons.last?.stage == .intermediate)
        #expect(result.lessons.last?.needsSupport == true)
        #expect(result.lessons.last?.score == mine.profile.overallScore)
    }
    @Test func multiplayerSourcesCannotEnterTheLearningPath() throws {
        for (pack, name, level) in [("fan:lldb-404", "Renamed pack", "0"),
            ("test", "Genesis 2P 2", "0"), ("test", "Amiga Two Player", "0"),
            ("ohYesMoreLemmings-OHYES-60", "Oh Yes!", "0:Lemmings Versus:1:0:0")] {
            let entry = try LevelPlaylistEntry(identity: .init(engine: .classic, packID: pack, levelID: level),
                catalogueRevision: "v1", sourceRevision: "v1", packNameSnapshot: name,
                levelNameSnapshot: "Puzzle", levelNumberSnapshot: 1)
            let profile = DifficultyProfile(key: .init(identity: entry.identity, levelRevision: "v1"), confidence: .medium, components: .init())
            #expect(!LearningJourney.isSinglePlayer(entry))
            #expect(throws: LevelPlaylistError.self) {
                try LearningJourney.generate([.init(entry: entry, profile: profile, isOfficial: true)])
            }
        }
        #expect(LearningJourney.isSinglePlayer(try candidate(1, score: 40).entry))
    }
    @Test func aLowAverageCannotHideExpertTiming() throws {
        let timed = try candidate(0, score: 0, concepts: ["builder"])
        let precise = DifficultyProfile(key: timed.profile.key, confidence: .medium,
            components: .init(executionPrecision: 950), detectedTechniques: ["builder"])
        let ordinary = try candidate(1, score: 300, concepts: ["builder"])
        let result = try LearningJourney.generate([.init(entry: timed.entry, profile: precise, isOfficial: false), ordinary])
        #expect(precise.overallScore < ordinary.profile.overallScore)
        #expect(result.lessons.last?.entry.identity == timed.entry.identity)
        #expect(result.lessons.last?.stage == .expert)
    }
    @Test func isolatedPracticePrecedesCombinationsAndPassiveLevelsDoNotOpen() throws {
        let passive = try candidate(0, score: 40, concepts: [])
        let dig = try candidate(1, score: 50, concepts: ["digger"])
        let build = try candidate(2, score: 200, concepts: ["builder"])
        let combine = try candidate(3, score: 60, concepts: ["builder", "digger"])
        let result = try LearningJourney.generate([combine, build, passive, dig])
        #expect(result.lessons.first?.entry.identity == dig.entry.identity)
        let builderIndex = result.lessons.firstIndex { $0.entry.identity == build.entry.identity }!
        let combinationIndex = result.lessons.firstIndex { $0.entry.identity == combine.entry.identity }!
        #expect(builderIndex < combinationIndex)
        #expect(result.lessons[combinationIndex].preparationGaps.isEmpty)
    }
    @Test func nearEqualRepetitionsAreSpacedAndOriginDoesNotChooseTheOpening() throws {
        let dig1 = try candidate(1, score: 45, concepts: ["digger"])
        let dig2 = try candidate(2, score: 46, concepts: ["digger"])
        let float = try candidate(3, score: 48, concepts: ["floater"])
        let result = try LearningJourney.generate([dig2, float, dig1])
        #expect(result.lessons.map(\.concepts) == [["digger"], ["floater"], ["digger"]])
    }
    @Test func rawReplayScoreKeepsAComparableDemandBandSmooth() throws {
        let first = try candidate(0, score: 240, concepts: ["digger"])
        let high = try candidate(1, score: 260, concepts: ["builder"])
        let low = try candidate(2, score: 0, concepts: ["builder"])
        let precise = DifficultyProfile(key: low.profile.key, confidence: .medium,
            components: .init(executionPrecision: 300), detectedTechniques: ["builder"])
        #expect(precise.overallScore + 10 < high.profile.overallScore)
        let fan = ProgressionCandidate(entry: low.entry, profile: precise, isOfficial: false)
        let result = try LearningJourney.generate([high, fan, first])
        #expect(result.lessons.map(\.entry.identity) == [first.entry.identity, low.entry.identity, high.entry.identity])
        #expect(result.lessons.allSatisfy { $0.preparationGaps.isEmpty })
    }
    @Test func unsupportedGapsAreFlaggedAndPriorsRejected() throws {
        let first = try candidate(0, score: 10)
        let hard = try candidate(1, score: 900, concepts: ["builder", "miner", "blocker"])
        let result = try LearningJourney.generate([hard, first])
        #expect(result.lessons.last?.needsSupport == true)
        let unknown = try candidate(2, score: 50, confidence: .low)
        #expect(throws: LevelPlaylistError.self) {
            try LearningJourney.generate([first, unknown])
        }
    }
    @Test func DifficultyOrderAndParkingDoesNotAwardAWin() throws {
        let values = try [candidate(0, score: 30, concepts: ["digger"]), candidate(1, score: 50), candidate(2, score: 70, concepts: ["builder", "digger"])]
        let journey = try LearningJourney.generate(values.reversed())
        #expect(journey.lessons.map { $0.entry.identity } == values.map { $0.entry.identity })
        var progress = LearningJourneyProgress()
        progress.record(values[0].entry.identity, won: false)
        #expect(progress.completed.isEmpty)
        #expect(progress.revisit(in: journey).map(\.identity) == [values[0].entry.identity])
        #expect(progress.unseen(in: journey).count == 2)
        progress.record(values[0].entry.identity, won: true)
        progress.record(values[0].entry.identity, won: false)
        #expect(progress.completed.count == 1)
        #expect(progress.later.isEmpty)
        // A win on a level that a later journey removed stays saved but does not count.
        progress.record(try candidate(9, score: 40).entry.identity, won: true)
        #expect(progress.completed.count == 2)
        #expect(progress.solvedCount(in: journey) == 1)
        #expect(try JSONDecoder().decode(LearningJourneyProgress.self, from: JSONEncoder().encode(progress)) == progress)
    }
}
