import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileCoreTests {
    private enum ImportFixtureError: Error {
        case rejected
    }

    @Test func safeAreaLayoutKeepsTouchTargetsOnScreen() {
        let portrait = MobileLayoutEngine.make(
            container: MobileSize(width: 390, height: 844),
            safeArea: MobileInsets(top: 47, bottom: 34),
            controlCount: 13
        )
        #expect(portrait.orientation == .portrait)
        #expect(portrait.controlFrames.count == 13)
        #expect(portrait.controlFrames.allSatisfy {
            $0.width >= MobileLayoutEngine.minimumControlExtent
                && $0.height >= MobileLayoutEngine.minimumControlExtent
                && portrait.safeFrame.contains(MobilePoint(x: $0.minX, y: $0.minY))
                && portrait.safeFrame.contains(MobilePoint(x: $0.maxX, y: $0.maxY))
        })
        #expect(portrait.playfieldFrame.height > 400)

        let landscape = MobileLayoutEngine.make(
            container: MobileSize(width: 844, height: 390),
            safeArea: MobileInsets(top: 0, left: 44, bottom: 21, right: 44),
            controlCount: 13
        )
        #expect(landscape.orientation == .landscape)
        #expect(Set(landscape.controlFrames.map(\.y)).count == 1)
        #expect(landscape.playfieldFrame.minX == landscape.safeFrame.minX)
        #expect(landscape.controlsFrame.maxY == landscape.safeFrame.maxY)

        for (container, insets) in [
            (MobileSize(width: 1_024, height: 1_366), MobileInsets(top: 24, bottom: 20)),
            (MobileSize(width: 1_366, height: 1_024), MobileInsets(top: 24, bottom: 20)),
        ] {
            let tablet = MobileLayoutEngine.make(
                container: container,
                safeArea: insets,
                controlCount: 15
            )
            #expect(tablet.controlFrames.count == 15)
            #expect(tablet.controlFrames.allSatisfy {
                $0.width >= MobileLayoutEngine.minimumControlExtent
                    && $0.height >= MobileLayoutEngine.minimumControlExtent
                    && tablet.safeFrame.contains(MobilePoint(x: $0.minX, y: $0.minY))
                    && tablet.safeFrame.contains(MobilePoint(x: $0.maxX, y: $0.maxY))
            })
            #expect(tablet.playfieldFrame.width > 0)
            #expect(tablet.playfieldFrame.height > 0)
        }
    }

    @Test func viewportZoomKeepsTheGestureAnchorStable() {
        let portrait = MobileViewport(
            levelSize: MobileSize(width: 1_600, height: 160),
            viewSize: MobileSize(width: 390, height: 620),
            pixelAspect: 1.2
        )
        #expect(portrait.visibleLevelSize.width >= 320)

        var firstLayout = MobileViewport(
            levelSize: MobileSize(width: 1_600, height: 160),
            viewSize: MobileSize(width: 1, height: 1),
            pixelAspect: 1.2
        )
        firstLayout.fitGameplay(in: MobileSize(width: 756, height: 300))
        #expect(firstLayout.zoom > 1)
        #expect(firstLayout.visibleLevelSize.width >= 320)

        var viewport = MobileViewport(
            levelSize: MobileSize(width: 1_600, height: 160),
            viewSize: MobileSize(width: 760, height: 250),
            origin: MobilePoint(x: 300, y: 0),
            zoom: 2,
            pixelAspect: 1.2
        )
        let anchor = MobilePoint(x: 520, y: 100)
        let before = viewport.levelPoint(fromView: anchor)
        viewport.magnify(by: 1.7, around: anchor)
        let after = viewport.levelPoint(fromView: anchor)
        #expect(abs(before.x - after.x) < 0.001)
        #expect(abs(before.y - after.y) < 0.001)

        viewport.pan(viewDelta: MobilePoint(x: 10_000, y: -10_000))
        #expect(viewport.origin.x == 0)
        #expect(viewport.origin.y <= viewport.levelSize.height)
    }

    @Test func touchTargetingPrefersEligibilityFollowersAndTools() {
        let viewport = MobileViewport(
            levelSize: MobileSize(width: 320, height: 160),
            viewSize: MobileSize(width: 640, height: 320),
            zoom: 2
        )
        let touch = viewport.viewPoint(fromLevel: MobilePoint(x: 101, y: 75))
        let candidates = [
            MobileTargetCandidate(
                id: 1,
                point: MobilePoint(x: 100, y: 75),
                direction: 1,
                assignment: .eligible,
                isBuilding: true
            ),
            MobileTargetCandidate(
                id: 2,
                point: MobilePoint(x: 95, y: 75),
                direction: 1,
                assignment: .eligible
            ),
            MobileTargetCandidate(
                id: 3,
                point: MobilePoint(x: 101, y: 75),
                direction: -1,
                assignment: .unavailable,
                hasTool: true
            ),
        ]
        #expect(MobileTargetSelector.select(
            candidates: candidates,
            touch: touch,
            viewport: viewport
        )?.id == 2)
        #expect(MobileTargetSelector.select(
            candidates: candidates,
            touch: touch,
            viewport: viewport,
            preference: .toolHolder,
            favourApproaching: false
        )?.id == 3)
    }

    @Test func touchRouterDoesNotAssignAfterAPan() {
        var router = MobileTouchRouter(movementThreshold: 8)
        #expect(router.began(id: 1, at: MobilePoint(x: 20, y: 20), time: 1) == [
            .preview(MobilePoint(x: 20, y: 20)),
        ])
        let moved = router.moved(id: 1, to: MobilePoint(x: 40, y: 20))
        #expect(moved.first == .cancelPreview)
        #expect(moved.last == .pan(MobilePoint(x: 20, y: 0)))
        #expect(router.ended(id: 1, at: MobilePoint(x: 40, y: 20), time: 1.2) == [.cancelPreview])

        _ = router.began(id: 2, at: MobilePoint(x: 30, y: 30), time: 2)
        #expect(router.ended(id: 2, at: MobilePoint(x: 31, y: 30), time: 2.2) == [
            .commit(MobilePoint(x: 31, y: 30)),
        ])
    }

    @Test func lifecycleSavesOnceAndRequiresExplicitResume() {
        var state = MobileLifecycleState()
        let inactive = state.handle(.becameInactive)
        #expect(inactive.contains(.pauseSimulation))
        #expect(inactive.contains(.saveCheckpoint(.suspension)))
        #expect(state.isPaused)
        #expect(state.requiresPlayerResume)
        #expect(!state.handle(.enteredBackground).contains(.saveCheckpoint(.suspension)))

        let active = state.handle(.becameActive)
        #expect(active.contains(.showResumeControl))
        #expect(state.isPaused)
        #expect(state.handle(.playerRequestedResume) == [.resumeSimulation, .resumeAudio])
        #expect(!state.isPaused)

        let interrupted = state.handle(.audioInterruptionBegan)
        #expect(interrupted.contains(.saveCheckpoint(.audioInterruption)))
        #expect(!state.handle(.audioInterruptionBegan).contains(.saveCheckpoint(.audioInterruption)))
        _ = state.handle(.enteredBackground)
        #expect(state.handle(.audioInterruptionEnded).isEmpty)
        #expect(state.handle(.becameActive).contains(.showResumeControl))
        #expect(state.isPaused)
    }

    @Test func thermalPolicyNeverChangesSimulationRules() {
        let nominal = MobileThermalPolicy.budget(
            for: .nominal,
            lowPowerMode: false,
            reduceMotion: false,
            reduceFlashes: false
        )
        let critical = MobileThermalPolicy.budget(
            for: .critical,
            lowPowerMode: true,
            reduceMotion: false,
            reduceFlashes: false
        )
        #expect(nominal.framesPerSecond == 60)
        #expect(critical.framesPerSecond == 20)
        #expect(!critical.presentsMotionEffects)
        #expect(!critical.presentsFlashEffects)
        #expect(critical.audioVoiceLimit < nominal.audioVoiceLimit)
    }

    @Test func fixedTickClockDropsSuspensionTime() {
        var clock = MobileTickClock(ticksPerSecond: 20, maximumCatchUpTicks: 4)
        #expect(clock.advance(at: 10) == 0)
        #expect(clock.advance(at: 10.21) == 4)
        clock.suspend()
        #expect(clock.advance(at: 100) == 0)
        #expect(clock.advance(at: 100.05) == 1)
    }

    @Test func checkpointFallsBackToTheLastValidatedCopy() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MobileCheckpointTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("run.json")
        let store = MobileCheckpointStore(url: url)
        let first = checkpoint(tick: 10, payload: Data("first".utf8))
        let second = checkpoint(tick: 20, payload: Data("second".utf8))
        try await store.save(first)
        try await store.save(second)
        try Data("damaged".utf8).write(to: url, options: .atomic)

        let recovered = try await store.load()
        #expect(recovered == first)
        #expect(try await store.load() == first)
    }

    @Test func checkpointRejectsAnOlderWriter() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MobileCheckpointOrderTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MobileCheckpointStore(url: directory.appendingPathComponent("run.json"))
        let older = checkpoint(tick: 10, payload: Data("older".utf8))
        let newer = checkpoint(tick: 20, payload: Data("newer".utf8))
        try await store.save(newer)
        try await store.save(older)
        #expect(try await store.load() == newer)
    }

    @Test func contentImportStagesBeforeCommitAndPreservesTheLiveCopyOnFailure() throws {
        let manager = FileManager.default
        let temporary = manager.temporaryDirectory
            .appendingPathComponent("MobileContentTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? manager.removeItem(at: temporary) }
        let root = temporary.appendingPathComponent("Application Support", isDirectory: true)
        let accepted = temporary.appendingPathComponent("Accepted", isDirectory: true)
        try manager.createDirectory(at: accepted, withIntermediateDirectories: true)
        try Data("accepted".utf8).write(to: accepted.appendingPathComponent("marker.dat"))

        let store = MobileContentStore(root: root) { staged in
            guard staged.standardizedFileURL != accepted.standardizedFileURL,
                  try Data(contentsOf: staged.appendingPathComponent("marker.dat")) == Data("accepted".utf8) else {
                throw ImportFixtureError.rejected
            }
        }
        try store.install(directory: accepted)
        #expect(try Data(contentsOf: store.gameDataDirectory.appendingPathComponent("marker.dat"))
            == Data("accepted".utf8))

        let rejected = temporary.appendingPathComponent("Rejected", isDirectory: true)
        try manager.createDirectory(at: rejected, withIntermediateDirectories: true)
        try Data("rejected".utf8).write(to: rejected.appendingPathComponent("marker.dat"))
        let rejectingStore = MobileContentStore(root: root) { _ in throw ImportFixtureError.rejected }
        do {
            try rejectingStore.install(directory: rejected)
            Issue.record("An invalid staged import was committed.")
        } catch ImportFixtureError.rejected {
            #expect(try Data(contentsOf: store.gameDataDirectory.appendingPathComponent("marker.dat"))
                == Data("accepted".utf8))
        }

        let linked = temporary.appendingPathComponent("Linked", isDirectory: true)
        let outside = temporary.appendingPathComponent("outside.dat")
        try manager.createDirectory(at: linked, withIntermediateDirectories: true)
        try Data("outside".utf8).write(to: outside)
        try manager.createSymbolicLink(
            at: linked.appendingPathComponent("link.dat"),
            withDestinationURL: outside
        )
        let linkStore = MobileContentStore(root: root) { _ in }
        do {
            try linkStore.install(directory: linked)
            Issue.record("An import containing a symbolic link was committed.")
        } catch let error as MobileContentStoreError {
            #expect(error == .symbolicLink)
        }
    }

    @Test func classicJumpingRisesAcrossTheRemainingStepPixel() throws {
        let width = 96
        let height = 64
        let floorY = 40
        let stepX = 45
        var solid = [UInt8](repeating: 0, count: width * height)
        for x in 0..<width { solid[floorY * width + x] = 1 }
        for y in (floorY - 3)..<floorY { solid[y * width + stepX] = 1 }

        let terrain = try ClassicDOSTerrain(
            width: width,
            height: height,
            solidMask: Data(solid),
            steelMask: Data(repeating: 0, count: solid.count)
        )
        let configuration = ClassicDOSConfiguration(
            totalLemmings: 1,
            requiredToSave: 0,
            timeLimitTicks: 500,
            initialReleaseRate: 99,
            entrances: [ClassicDOSPoint(x: 20, y: 30)],
            maximumX: width - 1,
            maximumY: height - 1
        )
        var simulation = try ClassicDOSSimulation(terrain: terrain, configuration: configuration)
        for _ in 0..<200 where simulation.lemmings.first?.action != .jumping {
            _ = simulation.tick()
        }

        let before = try #require(simulation.lemmings.first)
        #expect(before.action == .jumping)
        _ = simulation.tick()
        let after = try #require(simulation.lemmings.first)
        #expect(after.foot.x == before.foot.x)
        #expect(after.foot.y == before.foot.y - 1)
        #expect(after.action == .walking)
    }

    @Test func classicSessionRestoresTheExactTick() throws {
        let initial = try Self.classicSimulation()
        let session = ClassicMobileSession(
            simulation: initial,
            levelIdentifier: "fixture/1",
            levelIndex: 0
        )
        for _ in 0..<45 { session.tick() }
        let payload = try session.checkpointPayload()
        let expected = session.snapshot

        let restored = ClassicMobileSession(
            simulation: initial,
            levelIdentifier: "fixture/1",
            levelIndex: 0
        )
        try restored.restoreCheckpointPayload(payload)
        #expect(restored.snapshot == expected)
        #expect(restored.levelFingerprint == session.levelFingerprint)
    }

    @Test @MainActor func sequelSessionsReplayTheirInputCheckpoints() throws {
        let l2Initial = try Self.lemmings2Runtime()
        let l2 = Lemmings2MobileSession(
            runtime: l2Initial,
            engineFingerprint: "l2-fixture-engine",
            levelIdentifier: "l2/fixture/1",
            levelIndex: 0,
            levelFingerprint: "l2-fixture-level"
        )
        #expect(l2.ticksPerSecond == 17.5)
        for _ in 0..<80 where !l2.targetCandidates(for: 0).contains(where: { $0.assignment == .eligible }) {
            l2.tick()
        }
        let l2Target = try #require(l2.targetCandidates(for: 0).first(where: { $0.assignment == .eligible }))
        #expect(l2.assign(control: 0, to: l2Target.id))
        for _ in 0..<25 { l2.tick() }
        let l2Payload = try l2.checkpointPayload()
        let l2Expected = l2.snapshot
        let l2Restored = Lemmings2MobileSession(
            runtime: l2Initial,
            engineFingerprint: "l2-fixture-engine",
            levelIdentifier: "l2/fixture/1",
            levelIndex: 0,
            levelFingerprint: "l2-fixture-level"
        )
        try l2Restored.restoreCheckpointPayload(l2Payload)
        #expect(l2Restored.snapshot == l2Expected)

        #expect(l2.beginEndRun())
        for _ in 0..<3 { l2.tick() }
        let endingPayload = try l2.checkpointPayload()
        let endingRestored = Lemmings2MobileSession(
            runtime: l2Initial,
            engineFingerprint: "l2-fixture-engine",
            levelIdentifier: "l2/fixture/1",
            levelIndex: 0,
            levelFingerprint: "l2-fixture-level"
        )
        try endingRestored.restoreCheckpointPayload(endingPayload)
        #expect(endingRestored.snapshot.isEndingRun)
        #expect(endingRestored.undoEndRun())
        #expect(!endingRestored.snapshot.isEndingRun)

        let l3Initial = try Self.lemmings3Runtime()
        let l3 = Lemmings3MobileSession(
            runtime: l3Initial,
            engineFingerprint: "l3-fixture-engine",
            levelIdentifier: "l3/fixture/1",
            levelIndex: 0,
            levelFingerprint: "l3-fixture-level"
        )
        for _ in 0..<80 where !l3.targetCandidates(for: 2).contains(where: { $0.assignment == .eligible }) {
            l3.tick()
        }
        let l3Target = try #require(l3.targetCandidates(for: 2).first(where: { $0.assignment == .eligible }))
        #expect(l3.assign(control: 2, to: l3Target.id))
        for _ in 0..<25 { l3.tick() }
        let l3Payload = try l3.checkpointPayload()
        let l3Expected = l3.snapshot
        let l3Restored = Lemmings3MobileSession(
            runtime: l3Initial,
            engineFingerprint: "l3-fixture-engine",
            levelIdentifier: "l3/fixture/1",
            levelIndex: 0,
            levelFingerprint: "l3-fixture-level"
        )
        try l3Restored.restoreCheckpointPayload(l3Payload)
        #expect(l3Restored.snapshot == l3Expected)
    }

    private func checkpoint(tick: Int, payload: Data) -> MobileCheckpointEnvelope {
        MobileCheckpointEnvelope(
            runID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            engine: "classic-dos",
            engineFingerprint: "engine",
            levelIdentifier: "fixture/1",
            levelIndex: 0,
            levelFingerprint: "level",
            tick: tick,
            selectedControl: 0,
            camera: MobileCameraState(origin: MobilePoint(x: 0, y: 0), zoom: 2),
            payload: payload,
            savedAt: Date(timeIntervalSince1970: Double(tick))
        )
    }

    private static func classicSimulation() throws -> ClassicDOSSimulation {
        let width = 160
        let height = 80
        var solid = [UInt8](repeating: 0, count: width * height)
        for y in 50..<height {
            for x in 0..<width { solid[y * width + x] = 1 }
        }
        let terrain = try ClassicDOSTerrain(
            width: width,
            height: height,
            solidMask: Data(solid),
            steelMask: Data(repeating: 0, count: solid.count)
        )
        let configuration = ClassicDOSConfiguration(
            totalLemmings: 5,
            requiredToSave: 1,
            timeLimitTicks: 1_000,
            initialReleaseRate: 50,
            entrances: [ClassicDOSPoint(x: 20, y: 20)],
            initialSkills: [.climber: 5, .builder: 5],
            maximumX: width - 1,
            maximumY: height - 1
        )
        return try ClassicDOSSimulation(terrain: terrain, configuration: configuration)
    }

    private static func lemmings2Runtime() throws -> Lemmings2Runtime {
        let width = 120
        let height = 80
        var pixels = [UInt8](repeating: 0, count: width * height)
        var solid = [Bool](repeating: false, count: width * height)
        for y in 60..<height {
            for x in 0..<width {
                pixels[y * width + x] = 6
                solid[y * width + x] = true
            }
        }
        let frame = Lemmings2SpriteFrame(
            x: 0,
            y: 0,
            width: 1,
            height: 1,
            pixels: [7],
            opaque: [true]
        )
        let masks = try Lemmings2TerrainMasks(
            digger: frame,
            basher: Array(repeating: frame, count: 8),
            miner: Array(repeating: frame, count: 4),
            exploder: frame,
            brick: frame,
            stacker: Array(repeating: frame, count: 2),
            platformer: frame
        )
        return try Lemmings2Runtime(configuration: .init(
            width: width,
            height: height,
            pixels: pixels,
            solid: solid,
            palette: [UInt8](repeating: 255, count: 1_024),
            entrance: .init(x: 20, y: 45, width: 1, height: 1),
            exits: [.init(x: 100, y: 50, width: 16, height: 16)],
            skills: [.jumper],
            supplies: [3],
            total: 2,
            timeLimit: 120,
            releaseInterval: 20,
            terrainMasks: masks,
            firstReleaseTick: 1
        ))
    }

    private static func lemmings3Runtime() throws -> Lemmings3Runtime {
        let width = 128
        let height = 64
        var attributes = [UInt16](repeating: 0x1000, count: width * height)
        for y in 48..<height {
            for x in 0..<width { attributes[y * width + x] = 0x20 }
        }
        return try Lemmings3Runtime(configuration: .init(
            width: width,
            height: height,
            attributes: attributes,
            entrance: .init(x: 20, y: 40),
            exits: [.init(x: 110, y: 46)],
            total: 2,
            releaseInterval: 20,
            releaseDelay: 0
        ))
    }
}
