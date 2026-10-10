import Foundation
import Testing
@testable import NxlvKit

struct DifficultyTests {
    func key(_ id: String = "level", version: String = DifficultyModel.version) -> DifficultyCacheKey {
        .init(identity: .init(engine: .classic, packID: "pack", levelID: id), levelRevision: "v1", analyserVersion: version)
    }
    func solution(concurrent: Int = 1, spare: Int = 10, advanced: Bool = false) -> DifficultySolutionEvidence {
        var value = DifficultySolutionEvidence()
        value.assignments = [.init(frame: 30, worker: 0, skill: "builder"), .init(frame: 70, worker: 0, skill: "builder")]
        value.maximumConcurrentWorkers = concurrent
        value.maximumConcurrentRegions = concurrent
        value.remainingSkills = ["builder": spare]
        if advanced {
            value.assignments.append(.init(frame: 80, worker: 0, skill: "miner"))
            value.observedConcepts = ["skill-cancellation", "multiple-worker-coordination"]
        }
        return value
    }
    let metadata = DifficultyMetadataEvidence(availableSkills: ["builder": 12], population: 10, rescueRequirement: 5)
    @Test func gradeBoundaries() {
        #expect(DifficultyGrade(score: -1) == .beginner)
        #expect(DifficultyGrade(score: 99.999) == .beginner)
        for grade in DifficultyGrade.allCases {
            #expect(DifficultyGrade(score: Double(grade.rawValue - 1) * 100) == grade)
        }
        #expect(DifficultyGrade(score: 1000) == .master)
        #expect(DifficultyGrade(score: .infinity) == .beginner)
    }
    @Test func mechanicalOrderingAndResources() {
        let basic = DifficultyScorer.analyse(key: key(), metadata: metadata, solution: solution())
        let complex = DifficultyScorer.analyse(key: key(), metadata: metadata, solution: solution(concurrent: 3, spare: 0, advanced: true))
        #expect(complex.overallScore > basic.overallScore)
        let concurrent = DifficultyScorer.analyse(key: key(), metadata: metadata, solution: solution(concurrent: 3))
        #expect(concurrent.components.concurrencyBurden > basic.components.concurrencyBurden)
        let tight = DifficultyScorer.analyse(key: key(), metadata: metadata, solution: solution(spare: 0))
        #expect(tight.components.constraintPressure > basic.components.constraintPressure)
        #expect(DifficultyTechniques.burden(["builder", "skill-cancellation"]) > DifficultyTechniques.burden(["builder"]))
    }
    @Test func forgivingAndNarrowWindows() throws {
        let commands = [NeoLemmixReplayCommand(tick: 32, sequence: 0, command: .assign(lemmingID: 0, skill: .builder))]
        let forgiving = try DifficultyPerturbation.analyse(commands: commands) { _ in true }
        let precise = try DifficultyPerturbation.analyse(commands: commands) { $0[0].tick == 32 }
        #expect(forgiving.medianTolerance == 16)
        #expect(precise.narrowestTolerance == 0)
        #expect(precise.actions[0].isNarrow)
        #expect(precise.burden > forgiving.burden)
        let broad = DifficultyScorer.analyse(key: key(), metadata: metadata, solution: solution(), precision: forgiving, exactReplay: true)
        let narrow = DifficultyScorer.analyse(key: key(), metadata: metadata, solution: solution(), precision: precise, exactReplay: true)
        #expect(broad.overallScore < narrow.overallScore)
        #expect(broad.confidence == .high)
        let limited = try DifficultyPerturbation.analyse(commands: commands, maximumRuns: 2) { _ in true }
        #expect(!limited.completed)
        #expect(DifficultyScorer.analyse(key: key(), metadata: metadata, solution: solution(), precision: limited, exactReplay: true).confidence == .medium)
    }
    @Test func unknownTechniquesAreNotInvented() {
        let unknown = DifficultyScorer.analyse(key: key(), metadata: metadata)
        #expect(unknown.confidence == .low)
        #expect(unknown.detectedTechniques.isEmpty)
        var observed = solution()
        observed.observedConcepts = ["terrain-mask-sensitive", "sacrifice-required"]
        #expect(!DifficultyTechniques.detect(observed).contains("terrain-mask-sensitive"))
    }
    @Test func cacheVersionsAndRoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("cache.json")
        let cache = DifficultyProfileCache(file: file)
        let profile = DifficultyScorer.analyse(key: key(), metadata: metadata)
        try await cache.store(profile)
        #expect(await cache.profile(for: key()) == profile)
        #expect(await cache.profile(for: key(version: "new")) == nil)
        let identity = key().identity
        for changed in [
            DifficultyCacheKey(identity: identity, levelRevision: "v2"),
            DifficultyCacheKey(identity: identity, levelRevision: "v1", replayRevision: "changed"),
            DifficultyCacheKey(identity: identity, levelRevision: "v1", assetsRevision: "changed"),
            DifficultyCacheKey(identity: identity, levelRevision: "v1", simulationVersion: "changed")
        ] { #expect(await cache.profile(for: changed) == nil) }
        #expect(await DifficultyProfileCache(file: file).profile(for: key()) == profile)
        let encoded = try JSONEncoder().encode(profile)
        #expect(try JSONDecoder().decode(DifficultyProfile.self, from: encoded) == profile)
    }
    func candidate(_ id: String, score: Double, official: Bool = false, concepts: [String] = [], precision: Double? = nil) throws -> ProgressionCandidate {
        let profile = DifficultyProfile(key: key(id), confidence: .medium,
            components: .init(techniqueBurden: score, solutionComplexity: score, executionPrecision: precision ?? score,
                              concurrencyBurden: score, constraintPressure: score, deductionComplexityProxy: score),
            detectedTechniques: concepts)
        let entry = try LevelPlaylistEntry(identity: profile.key.identity, catalogueRevision: "catalogue", sourceRevision: "v1",
                                          packNameSnapshot: "Pack", levelNameSnapshot: id, levelNumberSnapshot: 1)
        return .init(entry: entry, profile: profile, isOfficial: official)
    }
    @Test func deterministicGenerationAndStableTies() throws {
        let candidates = try [candidate("b", score: 50), candidate("a", score: 50), candidate("c", score: 100)]
        let a = try ProgressionGenerator.generate(candidates: candidates, policy: .smooth)
        let b = try ProgressionGenerator.generate(candidates: candidates.reversed(), policy: .smooth)
        #expect(a.entries.map(\.identity) == b.entries.map(\.identity))
        #expect(a.diagnostics == b.diagnostics)
        #expect(a.entries.first?.identity.levelID == "a")
        #expect(try a.playlist().entries == a.entries)
    }
    @Test func completeOriginalPlusRetainsEveryAnchorBeyondOneHundred() throws {
        var anchors: [ProgressionCandidate] = []
        for index in 0..<350 {
            let value = try candidate("official-\(index)", score: index == 1 ? 400 : 50, official: true)
            anchors.append(.init(entry: value.entry, profile: value.profile, isOfficial: true, campaignOrder: index))
        }
        let bridge = try candidate("fan-bridge", score: 180)
        var config = ProgressionConfiguration(); config.maximumLevels = LevelPlaylist.maximumEntries
        let result = try ProgressionGenerator.generate(candidates: anchors + [bridge], policy: .originalPlus, configuration: config)
        #expect(result.entries.filter { $0.identity.levelID.hasPrefix("official-") }.map(\.identity) == anchors.map { $0.entry.identity })
        #expect(result.entries.contains { $0.identity == bridge.entry.identity })
        let reverse = try ProgressionGenerator.generate(candidates: (anchors + [bridge]).reversed(), policy: .originalPlus, configuration: config)
        #expect(reverse.diagnostics == result.diagnostics)
    }
    @Test func officialPreferenceCannotBuyLargeJump() throws {
        var config = ProgressionConfiguration(); config.maximumLevels = 1
        let comparable = try ProgressionGenerator.generate(candidates: [candidate("community", score: 30), candidate("official", score: 30, official: true)], policy: .smooth, configuration: config)
        #expect(comparable.entries.first?.identity.levelID == "official")
        let gap = try ProgressionGenerator.generate(candidates: [candidate("community", score: 30), candidate("official", score: 500, official: true)], policy: .smooth, configuration: config)
        #expect(gap.entries.first?.identity.levelID == "community")
    }
    @Test func conceptIntroductionAndLowPrecision() throws {
        var config = ProgressionConfiguration(); config.maximumLevels = 1
        let simple = try candidate("simple", score: 50, concepts: ["builder"])
        let compound = try candidate("compound", score: 50, concepts: ["builder", "miner", "skill-cancellation"])
        #expect(try ProgressionGenerator.generate(candidates: [compound, simple], policy: .smooth, configuration: config).entries.first?.identity.levelID == "simple")
        let precise = try candidate("precise", score: 50, precision: 800)
        #expect(try ProgressionGenerator.generate(candidates: [precise, simple], policy: .lowPrecision, configuration: config).entries.first?.identity.levelID == "simple")
        config.maximumLevels = 2; config.technique = "builder"
        #expect(try ProgressionGenerator.generate(candidates: [compound, simple], policy: .techniqueCurriculum, configuration: config).entries.map(\.identity.levelID) == ["simple", "compound"])
    }
    @Test func corpusInferenceRequiresRepeatedAsymmetricEvidence() throws {
        let profiles = try (0..<15).map { try candidate("\($0)", score: 50, concepts: $0 < 5 ? ["builder", "skill-cancellation"] : ["builder"]).profile }
        let stats = DifficultyCorpusStatistics(profiles: profiles)
        #expect(stats.prerequisites.count == 1)
        #expect(stats.prerequisites.first?.prerequisite == "builder")
        #expect(stats.isCurrent(for: profiles.reversed()))
        #expect(!stats.isCurrent(for: Array(profiles.dropLast())))
    }
    @Test func timingProbesUseRealSimulationOutcomes() throws {
        let width = 96, height = 512
        let solid = (0..<(width * height)).map { $0 / width >= 480 ? UInt8(1) : UInt8(0) }
        let empty = Array(repeating: UInt8(0), count: width * height)
        let terrain = try NeoLemmixTerrain(width: width, height: height, solidMask: solid,
                                          steelMask: empty, oneWayMask: empty)
        let config = try NeoLemmixConfiguration(totalLemmings: 1, requiredToSave: 1,
            timeLimitTicks: 1500, spawnInterval: 10, entrances: [],
            zones: [.init(id: 0, effect: .exit, bounds: .init(x: 64, y: 478, width: 32, height: 8))],
            preplacedLemmings: [.init(position: .init(x: 32, y: 20), direction: .right)],
            skills: [.floater: .finite(1)])
        func wins(_ frame: Int) throws -> Bool {
            var simulation = try NeoLemmixSimulation(terrain: terrain, configuration: config)
            simulation.enqueue(.assign(lemmingID: 0, skill: .floater), atTick: frame)
            while !simulation.isComplete && simulation.tickCount < 1500 { simulation.tick() }
            return simulation.didWin
        }
        let winning = try (1...300).filter { try wins($0) }
        let last = try #require(winning.last)
        #expect(last > 33 && last < 300)
        func probe(_ frame: Int) throws -> DifficultyPrecisionEvidence {
            try DifficultyPerturbation.analyse(commands: [.init(tick: frame, sequence: 1,
                command: .assign(lemmingID: 0, skill: .floater))]) { try wins($0[0].tick) }
        }
        let forgiving = try probe(last / 2)
        let boundary = try probe(last)
        #expect(forgiving.medianTolerance == 16)
        #expect(boundary.actions.first?.outcomes[1] == false)
        #expect(!boundary.actions[0].isNarrow)
        #expect(boundary.burden == forgiving.burden)

        let bridgeWidth = 128, bridgeHeight = 128
        let bridgeSolid = (0..<(bridgeWidth * bridgeHeight)).map { index -> UInt8 in
            let x = index % bridgeWidth, y = index / bridgeWidth
            return y >= 80 && (x < 40 || x >= 67) ? 1 : 0
        }
        let bridgeEmpty = Array(repeating: UInt8(0), count: bridgeWidth * bridgeHeight)
        let bridgeTerrain = try NeoLemmixTerrain(width: bridgeWidth, height: bridgeHeight,
            solidMask: bridgeSolid, steelMask: bridgeEmpty, oneWayMask: bridgeEmpty)
        let bridgeConfig = try NeoLemmixConfiguration(totalLemmings: 1, requiredToSave: 1,
            timeLimitTicks: 1000, spawnInterval: 10, entrances: [],
            zones: [.init(id: 0, effect: .exit, bounds: .init(x: 90, y: 78, width: 16, height: 8))],
            preplacedLemmings: [.init(position: .init(x: 20, y: 80), direction: .right)],
            skills: [.builder: .finite(1)])
        func bridgeWins(_ frame: Int) throws -> Bool {
            var simulation = try NeoLemmixSimulation(terrain: bridgeTerrain, configuration: bridgeConfig)
            simulation.enqueue(.assign(lemmingID: 0, skill: .builder), atTick: frame)
            while !simulation.isComplete && simulation.tickCount < 1000 { simulation.tick() }
            return simulation.didWin
        }
        let bridgeFrames = try (1...40).filter { try bridgeWins($0) }
        let bridgeFrame = try #require(bridgeFrames.first)
        let narrow = try DifficultyPerturbation.analyse(commands: [.init(tick: bridgeFrame, sequence: 1,
            command: .assign(lemmingID: 0, skill: .builder))]) { try bridgeWins($0[0].tick) }
        #expect(narrow.actions[0].isNarrow)
        #expect(narrow.burden > forgiving.burden)
    }

    @Test func incompleteProbesAreUnknownRatherThanFailures() throws {
        let commands = (0..<3).map { NeoLemmixReplayCommand(tick: 32, sequence: UInt64($0),
            command: .assign(lemmingID: $0, skill: .builder)) }
        let partial = try DifficultyPerturbation.analyse(commands: commands, maximumRuns: 2) { _ in true }
        #expect(partial.burden == 0)
        #expect(partial.runCount == 2)
        #expect(!partial.completed)
        let one = try DifficultyPerturbation.analyse(commands: Array(commands.prefix(1))) { _ in false }
        let three = try DifficultyPerturbation.analyse(commands: commands) { _ in false }
        #expect(three.burden - one.burden > 170)
    }

    @Test func originalPlusPreservesOfficialOrderAndBridgesGaps() throws {
        func ordered(_ candidate: ProgressionCandidate, _ order: Int) -> ProgressionCandidate {
            .init(entry: candidate.entry, profile: candidate.profile, isOfficial: true, campaignOrder: order)
        }
        let first = try ordered(candidate("first", score: 20, official: true), 0)
        let last = try ordered(candidate("last", score: 300, official: true), 1)
        let middle = try candidate("bridge", score: 130)
        let result = try ProgressionGenerator.generate(candidates: [last, middle, first], policy: .originalPlus)
        #expect(result.entries.map(\.identity.levelID) == ["first", "bridge", "last"])
    }

    @Test func noReplayLevelsStayInCandidatePoolAndConfidenceBreaksNearTies() throws {
        let lowProfile = DifficultyScorer.analyse(key: key("unknown"), metadata: metadata)
        let low = try candidate("unknown", score: lowProfile.overallScore)
        let unknown = ProgressionCandidate(entry: low.entry, profile: lowProfile, isOfficial: true)
        let known = try candidate("known", score: lowProfile.overallScore)
        let result = try ProgressionGenerator.generate(candidates: [unknown, known], policy: .smooth)
        #expect(result.entries.first?.identity.levelID == "known")
        #expect(try ProgressionGenerator.generate(candidates: [unknown], policy: .smooth).entries.count == 1)
    }

    @Test func inconclusiveProbesRetainUnknownEvidence() throws {
        let value = try DifficultyPerturbation.analyse(commands: [.init(tick: 32, sequence: 0,
            command: .assign(lemmingID: 0, skill: .builder))]) { _ in nil }
        #expect(!value.completed)
        #expect(value.burden == 0)
        #expect(value.medianTolerance == nil)
        #expect(value.narrowestTolerance == nil)
        #expect(value.actions.allSatisfy { !$0.isNarrow })
    }

    @Test func cancellationPropagatesWithoutReturningPartialSuccess() async {
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            return try DifficultyPerturbation.analyse(commands: [.init(tick: 32, sequence: 0,
                command: .assign(lemmingID: 0, skill: .builder))]) { _ in true }
        }
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled analysis returned success") }
        catch is CancellationError { }
        catch { Issue.record("Unexpected cancellation error: \(error)") }
    }

    @Test func curriculumDoesNotExhaustIdenticalMetadataPriors() throws {
        var candidates = try (0..<200).map { try candidate("easy-\($0)", score: 50) }
        candidates += try [candidate("middle", score: 130), candidate("later", score: 230)]
        let result = try ProgressionGenerator.generate(candidates: candidates, policy: .smooth)
        #expect(result.entries.count == 3)
        #expect(result.entries.last?.identity.levelID == "later")
    }

    @Test func classicReplayObservationPreservesTheVerifiedOutcome() throws {
        let width = 96, height = 96
        let terrain = try ClassicDOSTerrain(width: width, height: height,
            solidMask: Data((0..<(width * height)).map { $0 / width >= 64 ? UInt8(1) : UInt8(0) }),
            steelMask: Data(repeating: 0, count: width * height))
        let configuration = ClassicDOSConfiguration(totalLemmings: 1, requiredToSave: 1,
            timeLimitTicks: 1000, initialReleaseRate: 99, entrances: [.init(x: 16, y: 30)],
            triggers: [.init(id: 0, effect: .exit, bounds: .init(x1: 48, y1: 60, x2: 64, y2: 68))],
            maximumX: width - 1, maximumY: height - 1)
        let initial = try ClassicDOSSimulation(terrain: terrain, configuration: configuration)
        let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
        let replay = ClassicDOSReplay(rank: "Fixture", number: 1, title: "Walk", initialStateHash: hash, events: [])
        let expected = try ClassicDOSReplayPlayer.run(replay, simulation: initial)
        #expect(expected.didWin)
        let checked = ClassicDOSReplay(rank: replay.rank, number: 1, title: replay.title,
            initialStateHash: hash, events: [], expected: expected)
        var frames = 0
        let observed = try ClassicDOSReplayPlayer.run(checked, simulation: initial) { _ in frames += 1 }
        #expect(observed == expected)
        #expect(frames == expected.ticks)
        let profile = try ClassicDifficultyAnalysis.analyse(initial: initial, replay: checked, key: key())
        #expect(profile.confidence == .high)
        #expect(profile.grade == .beginner)
        #expect(profile.detectedTechniques.isEmpty)
    }

    @Test func classicDifficultyAnalysesAWinAtTheSourceClockLimit() throws {
        let width = 96, height = 96
        let terrain = try ClassicDOSTerrain(width: width, height: height,
            solidMask: Data((0..<(width * height)).map { $0 / width >= 64 ? UInt8(1) : UInt8(0) }),
            steelMask: Data(repeating: 0, count: width * height))
        let configuration = ClassicDOSConfiguration(totalLemmings: 1, requiredToSave: 0,
            timeLimitTicks: ClassicDOSReplayPlayer.defaultTickLimit + 2,
            initialReleaseRate: 99, entrances: [.init(x: 16, y: 30)],
            initialSkills: [.blocker: 1], maximumX: width - 1, maximumY: height - 1)
        let initial = try ClassicDOSSimulation(terrain: terrain, configuration: configuration)
        var probe = initial
        while !probe.lemmings.contains(where: { $0.action == .walking }), probe.tickCount < 200 { _ = probe.tick() }
        #expect(probe.lemmings.contains(where: { $0.action == .walking }))
        let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
        let event = ClassicDOSReplayEvent(tick: probe.tickCount,
            action: .assign(lemmingID: 0, skill: .blocker), afterTick: true)
        let replay = ClassicDOSReplay(rank: "Fixture", number: 1, title: "Timed blocker",
            initialStateHash: hash, events: [event])
        let expected = try ClassicDOSReplayPlayer.run(replay, simulation: initial,
            tickLimit: configuration.timeLimitTicks!)
        #expect(expected.didWin)
        #expect(expected.ticks == configuration.timeLimitTicks)
        let checked = ClassicDOSReplay(rank: replay.rank, number: replay.number, title: replay.title,
            initialStateHash: hash, events: replay.events, expected: expected)
        let profile = try ClassicDifficultyAnalysis.analyse(initial: initial, replay: checked,
            key: key("source-clock"), maximumProbeRuns: 1)
        #expect(profile.confidence != .low)
    }

    @Test func classicTimingBudgetOnlyMeasuresSuccessfulInputs() throws {
        let width = 96, height = 96
        let terrain = try ClassicDOSTerrain(width: width, height: height,
            solidMask: Data((0..<(width * height)).map { $0 / width >= 64 ? UInt8(1) : UInt8(0) }),
            steelMask: Data(repeating: 0, count: width * height))
        let configuration = ClassicDOSConfiguration(totalLemmings: 1, requiredToSave: 1,
            timeLimitTicks: 1000, initialReleaseRate: 55, entrances: [.init(x: 16, y: 30)],
            triggers: [.init(id: 0, effect: .exit, bounds: .init(x1: 48, y1: 60, x2: 64, y2: 68))],
            initialSkills: [.climber: 1],
            maximumX: width - 1, maximumY: height - 1)
        let initial = try ClassicDOSSimulation(terrain: terrain, configuration: configuration)
        var probe = initial
        while !probe.lemmings.contains(where: { $0.action == .walking }) { _ = probe.tick() }
        for live in [false, true] {
            var events = (1...12).map {
                ClassicDOSReplayEvent(tick: $0, action: .assign(lemmingID: 0, skill: .basher))
            }
            events += [.init(tick: live ? 0 : 1, action: .releaseRate(99), afterTick: live),
                       .init(tick: probe.tickCount, action: .assign(lemmingID: 0, skill: .climber), afterTick: live),
                       .init(tick: 2000, action: .assign(lemmingID: 0, skill: .miner))]
            let replay = ClassicDOSReplay(rank: "Fixture", number: 1, title: "Noisy inputs",
                initialStateHash: ClassicDOSReplayRecorder.stateHash(of: initial), events: events)
            let expected = try ClassicDOSReplayPlayer.run(replay, simulation: initial)
            #expect(expected.didWin)
            let checked = ClassicDOSReplay(rank: replay.rank, number: replay.number, title: replay.title,
                initialStateHash: replay.initialStateHash, events: events, expected: expected)
            let profile = try ClassicDifficultyAnalysis.analyse(initial: initial, replay: checked,
                key: key(), maximumProbeRuns: 10)
            #expect(profile.detectedTechniques == ["climber", "release-rate-manipulation"])
            #expect(profile.precision?.assignmentCount == 1)
            #expect(profile.precision?.runCount == 10)
            #expect(profile.precision?.completed == true)
            #expect(profile.precision?.actions.first?.sequence == 13)
        }
    }

    @Test func routineCrowdAssignmentsAreNotIndependentWorkers() {
        var many = solution()
        many.assignments = (0..<10).map { .init(frame: $0 * 20, worker: $0, skill: "builder") }
        let routine = DifficultyScorer.analyse(key: key(), metadata: metadata, solution: many)
        let basic = DifficultyScorer.analyse(key: key(), metadata: metadata, solution: solution())
        #expect(routine.components.solutionComplexity - basic.components.solutionComplexity < 30)
        #expect(DifficultyWorkerRegions.count([(0, 0), (20, 0), (40, 0)]) == 1)
        #expect(DifficultyWorkerRegions.count([(0, 0), (200, 0)]) == 2)
    }

    @Test func originalPlusKeepsSuitableOfficialTutorialSteps() throws {
        let first = try candidate("first", score: 30, official: true, concepts: ["digger"])
        let next = try candidate("next", score: 100, official: true, concepts: ["floater"])
        let anchor = ProgressionCandidate(entry: next.entry, profile: next.profile, isOfficial: true, campaignOrder: 1)
        let bridge = try candidate("unneeded-bridge", score: 65)
        let result = try ProgressionGenerator.generate(candidates: [first, anchor, bridge], policy: .originalPlus)
        #expect(Array(result.entries.prefix(2)).map(\.identity.levelID) == ["first", "next"])
    }

    @Test func originalPlusBridgesDoNotOvershootOrExtendPastTheCampaign() throws {
        let first = try candidate("first", score: 30, official: true)
        let last = try candidate("last", score: 180, official: true, concepts: ["climber"])
        let anchor = ProgressionCandidate(entry: last.entry, profile: last.profile, isOfficial: true, campaignOrder: 1)
        let harder = try candidate("overshoot", score: 220, concepts: ["climber"])
        let result = try ProgressionGenerator.generate(candidates: [first, anchor, harder], policy: .originalPlus)
        #expect(result.entries.map(\.identity.levelID) == ["first", "last"])
    }

}
