import Foundation
import Testing
@testable import NxlvKit

struct LearningJourneyTests {
    private func bundledJourney() throws -> LearningJourney {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(LearningJourney.self,
            from: Data(contentsOf: root.appendingPathComponent("Resources/Progression/learning.json"))).validated()
    }

    @Test func goldenPathKeepsReviewedFansAndExplicitSeasonalPlacements() throws {
        let journey = try bundledJourney()
        let official = journey.lessons.filter { !$0.entry.identity.packID.hasPrefix("fan:") }
        #expect(official.count * 5 >= journey.lessons.count * 4)
        let seasonal = journey.lessons.filter { LearningJourney.isOfficialSeasonal($0.entry) }
        #expect(seasonal.count == 70)
        #expect(seasonal.allSatisfy { $0.placement?.basis == "seasonalCurriculum"
            && $0.placement?.humanReviewPending == true && $0.needsSupport })
        #expect(!journey.lessons.contains { $0.entry.identity.packID.hasPrefix("fan:")
            && $0.placement?.basis == "solutionEstimate" })
        #expect(journey.lessons[0].entry.levelNameSnapshot == "Just dig!")
        #expect(journey.lessons[1].entry.levelNameSnapshot == "Cellbash")
        #expect(journey.lessons[1].placement?.basis == "userPlaytest")
        #expect(journey.lessons.contains { $0.entry.identity.levelID == "lm_set08.dat#5"
            && $0.placement?.basis == "userPlaytest" })
        #expect(journey.lessons.contains { $0.entry.identity.levelID == "50:Tricky:21:0:5" })
        for name in ["Come back!", "Stop, Block and Blow", "The COVOX Level", "Something Wrong?"] {
            #expect(!journey.lessons.contains { $0.entry.levelNameSnapshot == name })
        }
    }

    @Test func seasonalExpansionKeepsTheTestedOpeningAndResumesTheExistingRun() throws {
        let journey = try bundledJourney()
        let oldEntries = journey.lessons.filter { !LearningJourney.isOfficialSeasonal($0.entry) }.map(\.entry)
        #expect(oldEntries.count == 227)
        #expect(Array(journey.lessons.prefix(80).map(\.entry)) == Array(oldEntries.prefix(80)))
        let run = try LevelSequenceRun(source: .playlist(LearningJourney.playlistID),
            pool: .init(id: "learning-29", summary: "Existing journey"), entries: oldEntries, currentIndex: 80)
        let migrated = try #require(try journey.migrating(run))
        #expect(migrated.id == run.id && migrated.currentIndex == 80)
        #expect(Array(migrated.entries.prefix(80)) == Array(oldEntries.prefix(80)))
        #expect(migrated.entries.count == journey.lessons.count)
        #expect(Set(migrated.entries.map(\.identity)) == Set(journey.lessons.map(\.entry.identity)))
        #expect(try journey.migrating(migrated) == migrated)
        for lesson in journey.lessons where LearningJourney.isOfficialSeasonal(lesson.entry) {
            let rank = lesson.entry.identity.levelID.split(separator: ":").dropFirst().first
            if rank == "Blizzard" || rank == "Hail" { #expect(lesson.demand >= 900) }
        }
    }

    @Test func provisionalSeasonalEvidenceCannotClaimHumanApprovalOrAdmitOtherPacks() throws {
        let journey = try bundledJourney()
        let index = try #require(journey.lessons.firstIndex { LearningJourney.isOfficialSeasonal($0.entry) })
        var lessons = journey.lessons
        lessons[index].placement?.humanReviewPending = false
        #expect(throws: LevelPlaylistError.self) {
            try LearningJourney(version: journey.version, lessons: lessons,
                placementPolicy: journey.placementPolicy).validated()
        }
        let old = lessons[index].entry
        let fan = try LevelPlaylistEntry(identity: .init(engine: .classic, packID: "fan:holiday", levelID: "1"),
            catalogueRevision: old.catalogueRevision, sourceRevision: old.sourceRevision,
            packNameSnapshot: "Holiday fan pack", levelNameSnapshot: "Fan", levelNumberSnapshot: 1)
        #expect(!LearningJourney.isOfficialSeasonal(fan))
    }

    @Test func generousPracticePrecedesRestrictedPuzzles() throws {
        let journey = try bundledJourney()
        let beginner = journey.lessons.prefix { $0.stage == .fun }
        #expect(beginner.count == 30)
        #expect(beginner.filter { $0.entry.identity.packID == "ohNoMoreLemmings-DLVEL-100"
            && $0.entry.identity.levelID.contains(":Tame:") }.count == 20)
        #expect(beginner.allSatisfy { LearningJourney.teachingMinimumDemand(for: $0.entry) == 0 })
        #expect(journey.lessons[11].entry.levelNameSnapshot == "Honey, I Saved The Lemmings")
        let watson = try #require(journey.lessons.firstIndex { $0.entry.identity.levelID == "47:Tricky:18:9:5" })
        #expect(watson > 44 && journey.lessons[watson].stage == .expert)

        // An earlier counterpart position cannot bypass the protected practice section.
        var lessons = journey.lessons
        let index = try #require(lessons.firstIndex { $0.entry.identity.levelID == "51:Tricky:22:0:6" })
        let old = lessons[index]
        let placement = try #require(old.placement)
        #expect(LearningRouteSafety.minimumDemand(for: old.entry) == 0)
        let misplaced = LearningJourney.Lesson(entry: old.entry, objective: old.objective, score: old.score,
            intrinsicDemand: old.intrinsicDemand, demand: 175, stage: .fun,
            preparationGaps: [], concepts: old.concepts, introduced: [], focus: old.focus,
            needsSupport: false, placement: .init(basis: "reduxClassicCounterpart", reference: placement.reference,
                sourceURL: placement.sourceURL, position: 175, lower: 165, upper: 185,
                sourceRevision: placement.sourceRevision, replayRevision: placement.replayRevision))
        lessons.remove(at: index)
        lessons.insert(misplaced, at: 30)
        #expect(throws: LevelPlaylistError.self) {
            try LearningJourney(version: journey.version, lessons: lessons,
                placementPolicy: journey.placementPolicy).validated()
        }
    }

    @Test func migrationRestoresPracticeBeforeAnUnreportedCurrentWall() throws {
        let journey = try bundledJourney()
        var previous = journey.lessons.map(\.entry)
        let wall = try #require(previous.firstIndex { $0.identity.levelID == "42:Mega Drive Sunsoft:13:0:42" })
        previous.insert(previous.remove(at: wall), at: 8)
        let run = try LevelSequenceRun(source: .playlist(LearningJourney.playlistID),
            pool: .init(id: "learning-26", summary: "Previous journey"), entries: previous, currentIndex: 8)
        let migrated = try #require(try journey.migrating(run))
        #expect(migrated.id == run.id && migrated.currentIndex == run.currentIndex)
        #expect(Array(migrated.entries.prefix(8)) == Array(run.entries.prefix(8)))
        #expect(migrated.currentEntry == journey.lessons[8].entry)
        #expect(Set(migrated.entries.map(\.identity)) == Set(run.entries.map(\.identity)))
        #expect(try journey.migrating(migrated) == migrated)
    }

    /// Learning-17 opened with fan levels. A revised opening must not queue its beginner
    /// lessons after a long run, and campaign wins must not return.
    @Test func longOldRunResumesAtItsFrontierAndDefersSkippedOpeningLessons() throws {
        let journey = try bundledJourney()
        let lessons = journey.lessons.map(\.entry)
        func fan(_ number: Int) throws -> LevelPlaylistEntry {
            try LevelPlaylistEntry(identity: .init(engine: .classic, packID: "fan:retired", levelID: "old.dat#\(number)"),
                catalogueRevision: "v1", sourceRevision: "v1", packNameSnapshot: "Retired fan pack",
                levelNameSnapshot: "Fan \(number)", levelNumberSnapshot: number)
        }
        // Lessons 135 and 156 are far outliers. They must not move the resume point.
        let visitedPositions = Array(0...8) + [13, 14, 20, 25, 30, 33, 39, 40, 51, 52, 53, 134, 155]
        var past = try (1...28).map(fan)
        for (offset, position) in visitedPositions.enumerated() { past.insert(lessons[position], at: offset * 2) }
        let run = try LevelSequenceRun(source: .playlist(LearningJourney.playlistID),
            pool: .init(id: "learning-17", summary: "Previous journey"),
            entries: past + [try fan(99), lessons[80]], currentIndex: past.count)
        let campaignWin = lessons[100].identity
        let migration = try journey.migration(of: run) { $0 == campaignWin }
        let migrated = try #require(migration.run)

        #expect(migrated.id == run.id && migrated.currentIndex == past.count)
        #expect(Array(migrated.entries.prefix(past.count)) == past)
        #expect(migrated.currentEntry == lessons[54])
        let future = migrated.entries.dropFirst(past.count).map(\.identity)
        #expect(future == lessons.indices.filter { $0 > 53 && ![100, 134, 155].contains($0) }.map { lessons[$0].identity })
        let skipped = lessons.indices.filter { $0 < 53 && !visitedPositions.contains($0) }.map { lessons[$0].identity }
        #expect(migration.deferred == skipped)
        #expect(!migration.deferred.contains(campaignWin))

        // Deferred lessons appear in "Come back to these", not as wins.
        var progress = LearningJourneyProgress()
        for identity in migration.deferred { progress.record(identity, won: false) }
        #expect(progress.revisit(in: journey).map(\.identity) == skipped)
        #expect(progress.solvedCount(in: journey) == 0)
        #expect(try journey.migrating(migrated) == migrated)
    }

    @Test func reportedWallsKeepTheirFloorsAndDeferSavedAttempts() throws {
        let journey = try bundledJourney()
        for (levelID, demand, stage) in [
            ("11:Fun:12:0:7", 400.0, LearningJourney.Stage.difficult),
            ("58:Tricky:29:2:0", 620.0, .expert),
            ("26:Fun:27:4:6", 430.0, .difficult),
            ("lm_set08.dat#5", 600.0, .expert),
            ("34:Tricky:5:3:1", 440.0, .difficult),
            ("59:Tricky:30:1:7", 650.0, .expert),
            ("40:Wild:1:9:2", 630.0, .expert),
            ("47:Tricky:18:9:5", 640.0, .expert),
            ("45:Wild:6:7:5", 700.0, .expert)] {
            let index = try #require(journey.lessons.firstIndex { $0.entry.identity.levelID == levelID })
            let lesson = journey.lessons[index]
            #expect(lesson.demand >= demand && lesson.stage == stage)
            #expect(lesson.placement?.basis == "userPlaytest")
            #expect(lesson.demand >= LearningJourney.teachingMinimumDemand(for: lesson.entry))
            var previous = journey.lessons.map(\.entry)
            previous.insert(previous.remove(at: index), at: 12)
            for current in [0, 11, 12, 13, index, previous.count - 1] {
                let run = try LevelSequenceRun(source: .playlist(LearningJourney.playlistID),
                    pool: .init(id: "learning-27", summary: "Previous journey"),
                    entries: previous, currentIndex: current)
                let migrated = try #require(try journey.migrating(run))
                #expect(migrated.id == run.id && migrated.currentIndex == current)
                #expect(migrated.seed == run.seed && migrated.createdAt == run.createdAt)
                #expect(Array(migrated.entries.prefix(current)) == Array(previous.prefix(current)))
                #expect(Set(migrated.entries.map(\.identity)).count == journey.lessons.count)
                if current == 12 {
                    #expect(migrated.currentEntry == previous[13])
                    #expect(migrated.entries.firstIndex { $0.identity == lesson.entry.identity } == index)
                } else { #expect(migrated.currentEntry == run.currentEntry) }
                #expect(try journey.migrating(migrated) == migrated)
            }
        }
    }

    @Test func removedFanAndSeasonalLessonsLeaveFutureQueuesButKeepPastVisits() throws {
        let journey = try bundledJourney()
        for (pack, title, levelID) in [
            ("fan:lldb-547", "Stop, Block and Blow", "Ji Hoon Heaven 2.DAT#8"),
            ("fan:lldb-327", "Come back!", "JM01.DAT#7"),
            ("holidayLemmings1994-MACLEVL-32", "Seasonal puzzle", "retired")] {
            let retired = try LevelPlaylistEntry(identity: .init(engine: .classic, packID: pack, levelID: levelID),
                catalogueRevision: "v1", sourceRevision: "v1", packNameSnapshot: title,
                levelNameSnapshot: title, levelNumberSnapshot: 1)
            var previous = journey.lessons.map(\.entry)
            previous.insert(retired, at: 12)
            for current in [0, 12, 13, previous.count - 1] {
                let run = try LevelSequenceRun(source: .playlist(LearningJourney.playlistID),
                    pool: .init(id: "learning-22", summary: "Previous journey"),
                    entries: previous, currentIndex: current)
                let migrated = try #require(try journey.migrating(run))
                #expect(migrated.id == run.id && migrated.currentIndex == current)
                #expect(Array(migrated.entries.prefix(current)) == Array(previous.prefix(current)))
                #expect(!migrated.entries.dropFirst(current).contains { $0.identity == retired.identity })
                #expect(migrated.entries.count == journey.lessons.count + (current > 12 ? 1 : 0))
                if current == 12 { #expect(migrated.currentEntry == previous[13]) }
                else { #expect(migrated.currentEntry == run.currentEntry) }
                #expect(try journey.migrating(migrated) == migrated)
            }
            var progress = LearningJourneyProgress()
            progress.record(retired.identity, won: true)
            #expect(progress.completed == [retired.identity])
            #expect(progress.solvedCount(in: journey) == 0)
        }
    }

    @Test func unrelatedQueuesAndNewerSavedVersionsRemainUnchangedAcrossAllEngines() throws {
        let journey = try bundledJourney()
        for engine in [LevelSourceEngine.classic, .lemmings2, .lemmings3] {
            let entry = try LevelPlaylistEntry(identity: .init(engine: engine, packID: "campaign", levelID: "1"),
                catalogueRevision: "v1", sourceRevision: "v1", packNameSnapshot: "Campaign",
                levelNameSnapshot: "Level", levelNumberSnapshot: 1)
            let run = try LevelSequenceRun(source: .playlist(UUID()),
                pool: .init(id: "learning-22", summary: "Custom"), entries: [entry])
            #expect(try journey.migrating(run) == run)
        }
        let newer = try LevelSequenceRun(source: .playlist(LearningJourney.playlistID),
            pool: .init(id: "learning-999", summary: "Newer"), entries: journey.lessons.map(\.entry))
        #expect(try journey.migrating(newer) == newer)
    }

    @Test func publicationValidationRejectsEstimatedFanAndSeasonalCounterparts() throws {
        let journey = try bundledJourney()
        for (index, pack, name, basis) in [
            (1, "fan:lldb-547", "Fan puzzle", "solutionEstimate"),
            (0, "holidayLemmings1994-MACLEVL-32", "Holiday Lemmings", "reduxClassicCounterpart")] {
            var lessons = journey.lessons
            let old = lessons[index]
            let entry = try LevelPlaylistEntry(identity: .init(engine: .classic, packID: pack, levelID: "test"),
                catalogueRevision: "v1", sourceRevision: old.entry.sourceRevision,
                packNameSnapshot: name, levelNameSnapshot: "Looks easy", levelNumberSnapshot: 1)
            let placement = try #require(old.placement)
            lessons[index] = .init(entry: entry, objective: old.objective, score: old.score,
                intrinsicDemand: old.intrinsicDemand, demand: old.demand, stage: old.stage,
                preparationGaps: old.preparationGaps, concepts: old.concepts, introduced: old.introduced,
                focus: old.focus, needsSupport: old.needsSupport,
                placement: .init(basis: basis, reference: placement.reference, sourceURL: placement.sourceURL,
                    position: placement.position, lower: placement.lower, upper: placement.upper,
                    sourceRevision: placement.sourceRevision, replayRevision: placement.replayRevision))
            #expect(throws: LevelPlaylistError.self) {
                try LearningJourney(version: journey.version, lessons: lessons,
                    placementPolicy: journey.placementPolicy).validated()
            }
        }
    }

    func candidate(_ index: Int, score: Double, concepts: [String] = ["builder"], confidence: DifficultyConfidence = .medium) throws -> ProgressionCandidate {
        let identity = LevelCatalogueIdentity(engine: .classic, packID: "test", levelID: "\(index)")
        let key = DifficultyCacheKey(identity: identity, levelRevision: "v1")
        let profile = DifficultyProfile(key: key, confidence: confidence,
            components: .init(techniqueBurden: score, solutionComplexity: score, executionPrecision: score,
                              concurrencyBurden: score, constraintPressure: score, deductionComplexityProxy: score),
            detectedTechniques: concepts)
        let entry = try LevelPlaylistEntry(identity: identity, catalogueRevision: "v1", sourceRevision: "v1",
            packNameSnapshot: "Test", levelNameSnapshot: "Level \(index)", levelNumberSnapshot: index + 1)
        return .init(entry: entry, profile: profile, isOfficial: true, campaignOrder: index,
                     startingReleaseRate: 50, rescueRequirementRatio: 0.5)
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
        let fan = ProgressionCandidate(entry: low.entry, profile: low.profile, isOfficial: false,
            campaignOrder: 999, startingReleaseRate: low.startingReleaseRate,
            rescueRequirementRatio: low.rescueRequirementRatio)
        let journey = try LearningJourney.generate([high, fan])
        #expect(journey.lessons.map(\.score) == [40, 300])
        #expect(journey.lessons.first?.entry.identity == fan.entry.identity)
        let reversedOrigins = [ProgressionCandidate(entry: high.entry, profile: high.profile, isOfficial: false,
            campaignOrder: 0, startingReleaseRate: high.startingReleaseRate,
            rescueRequirementRatio: high.rescueRequirementRatio), low]
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
        #expect(result.lessons.map(\.stage) == [.fun, .fun, .fun])
        #expect(result.lessons.last?.score == combine.profile.overallScore)
        #expect(throws: LevelPlaylistError.self) {
            try LearningJourney.generate([dig, build], objectives: [dig.entry.identity: "same", build.entry.identity: "same"])
        }
    }
    @Test func highSourceConstraintsStartAtDifficult() throws {
        let baseline = try candidate(0, score: 40, concepts: ["digger"])
        let fastStart = ProgressionCandidate(entry: baseline.entry, profile: baseline.profile,
            isOfficial: true, startingReleaseRate: 99)
        let highQuota = ProgressionCandidate(entry: baseline.entry, profile: baseline.profile,
            isOfficial: true, rescueRequirementRatio: 0.95)
        for constrained in [fastStart, highQuota] {
            let journey = try LearningJourney.generate([constrained])
            #expect(journey.lessons.first?.stage == .difficult)
            #expect(journey.lessons.first?.demand == LearningJourney.demandingLevelFloor)
        }
        let belowThreshold = ProgressionCandidate(entry: baseline.entry, profile: baseline.profile,
            isOfficial: true, startingReleaseRate: 50, rescueRequirementRatio: 0.949)
        #expect(try LearningJourney.generate([belowThreshold]).lessons.first?.stage == .fun)
        let unverified = ProgressionCandidate(entry: baseline.entry, profile: baseline.profile,
            isOfficial: true)
        #expect(try LearningJourney.generate([unverified]).lessons.first?.stage == .difficult)
    }
    @Test func measuredNarrowTimingStartsAtDifficult() throws {
        let baseline = try candidate(0, score: 40, concepts: ["digger"])
        let precision = DifficultyPrecisionEvidence(
            actions: [.init(sequence: 0, outcomes: [-1: false, 1: false])],
            assignmentCount: 1, runCount: 2, completed: true)
        let profile = DifficultyProfile(key: baseline.profile.key, confidence: .high,
            components: .init(), detectedTechniques: ["digger"], precision: precision)
        #expect(profile.criticalActions == [0])
        let narrow = ProgressionCandidate(entry: baseline.entry, profile: profile, isOfficial: true,
            startingReleaseRate: 50, rescueRequirementRatio: 0.5)
        #expect(try LearningJourney.generate([narrow]).lessons.first?.stage == .difficult)
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
        let fan = ProgressionCandidate(entry: low.entry, profile: precise, isOfficial: false,
            startingReleaseRate: low.startingReleaseRate,
            rescueRequirementRatio: low.rescueRequirementRatio)
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
