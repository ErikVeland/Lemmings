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
            controlCount: 15
        )
        #expect(portrait.orientation == .portrait)
        #expect(portrait.controlFrames.count == 15)
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
        #expect(landscape.controlsPlacement == .trailingRail)
        #expect(landscape.playfieldFrame.minX == landscape.safeFrame.minX)
        #expect(landscape.playfieldFrame.maxX == landscape.controlsFrame.minX)
        #expect(landscape.controlFrames.allSatisfy {
            $0.width >= MobileLayoutEngine.minimumControlExtent
                && $0.height >= MobileLayoutEngine.minimumControlExtent
                && landscape.safeFrame.contains(MobilePoint(x: $0.minX, y: $0.minY))
                && landscape.safeFrame.contains(MobilePoint(x: $0.maxX, y: $0.maxY))
        })

        for (container, insets) in [
            (MobileSize(width: 1_024, height: 1_366), MobileInsets(top: 24, bottom: 20)),
            (MobileSize(width: 1_366, height: 1_024), MobileInsets(top: 24, bottom: 20)),
            (MobileSize(width: 834, height: 1_112), MobileInsets(top: 20, bottom: 0)),
            (MobileSize(width: 1_112, height: 834), MobileInsets(top: 20, bottom: 0)),
            (MobileSize(width: 375, height: 834), MobileInsets(top: 24, bottom: 20)),
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

    @Test func duoAspectRatiosKeepPlayfieldAndOneHandedControlsUsable() {
        let regularPhone = MobileLayoutEngine.make(
            container: MobileSize(width: 390, height: 844),
            safeArea: MobileInsets(top: 47, bottom: 34),
            controlCount: 16
        )
        let duoClosed = MobileLayoutEngine.make(
            container: MobileSize(width: 330, height: 460),
            safeArea: MobileInsets(top: 12, bottom: 12),
            controlCount: 16
        )
        let duoOpen = MobileLayoutEngine.make(
            container: MobileSize(width: 650, height: 465),
            safeArea: MobileInsets(top: 12, bottom: 12),
            controlCount: 16
        )
        let duoClosedRightToLeft = MobileLayoutEngine.make(
            container: MobileSize(width: 330, height: 460),
            safeArea: MobileInsets(top: 12, bottom: 12),
            controlCount: 16,
            direction: .rightToLeft
        )

        #expect(regularPhone.controlsPlacement == .bottom)
        #expect(duoClosed.controlsPlacement == .trailingRail)
        #expect(duoOpen.controlsPlacement == .trailingRail)
        #expect(duoOpen.playfieldFrame.width > duoClosed.playfieldFrame.width)
        #expect(duoClosed.controlFrames.count == 16)
        #expect(duoClosed.controlFrames.allSatisfy {
            $0.width >= MobileLayoutEngine.minimumControlExtent
                && $0.height >= MobileLayoutEngine.minimumControlExtent
                && duoClosed.safeFrame.contains(MobilePoint(x: $0.minX, y: $0.minY))
                && duoClosed.safeFrame.contains(MobilePoint(x: $0.maxX, y: $0.maxY))
        })
        #expect(duoClosedRightToLeft.controlsFrame.minX == duoClosedRightToLeft.safeFrame.minX)
        #expect(duoClosedRightToLeft.playfieldFrame.minX == duoClosedRightToLeft.controlsFrame.maxX)
    }

    @Test func lemmings3DirectionPickerKeepsAllTouchTargetsInsidePlayfield() throws {
        let directionFrames = MobileDirectionPickerLayout.gridDirections.compactMap {
            $0.map(MobileDirectionPickerLayout.frameIndex(for:))
        }
        #expect(directionFrames == [7, 0, 1, 6, 2, 5, 4, 3])
        #expect(MobileDirectionPickerLayout.gridDirections[4] == nil)

        for (bounds, target) in [
            (MobileRect(x: 0, y: 47, width: 390, height: 763), MobilePoint(x: 4, y: 52)),
            (MobileRect(x: 44, y: 24, width: 756, height: 900), MobilePoint(x: 794, y: 914)),
            (MobileRect(x: 0, y: 12, width: 220, height: 436), MobilePoint(x: 110, y: 230))
        ] {
            let frame = try #require(MobileDirectionPickerLayout.frame(centredAt: target, within: bounds))
            #expect(frame.width == 132)
            #expect(frame.height == 132)
            #expect(frame.minX >= bounds.minX && frame.maxX <= bounds.maxX)
            #expect(frame.minY >= bounds.minY && frame.maxY <= bounds.maxY)
            #expect(MobileDirectionPickerLayout.cellExtent >= 44)
        }
        #expect(MobileDirectionPickerLayout.frame(
            centredAt: MobilePoint(x: 0, y: 0),
            within: MobileRect(x: 0, y: 0, width: 131, height: 200)
        ) == nil)
    }

    @Test func freshCameraFitsHeightAndCentresEntranceAcrossEngines() {
        for (level, aspect) in [(MobileSize(width: 1600, height: 160), 1.2),
                                (.init(width: 1600, height: 320), 1.0),
                                (.init(width: 1024, height: 512), 1.0)] {
            for view in [MobileSize(width: 390, height: 540), .init(width: 756, height: 149),
                         .init(width: 834, height: 872)] {
                var camera = MobileViewport(levelSize: level, viewSize: .init(width: 1, height: 1), pixelAspect: aspect)
                camera.fitGameplay(in: view, centring: .init(x: level.width / 2, y: 60))
                #expect(abs(camera.contentFrame.height - view.height) < 0.001)
                #expect(abs(camera.viewPoint(fromLevel: .init(x: level.width / 2, y: 60)).x - view.width / 2) < 0.001)
                #expect(camera.origin.y == 0)
                camera.fitGameplay(in: view, centring: .init(x: 2, y: 60))
                #expect(camera.origin.x == 0)
            }
        }
    }

    @Test func viewportZoomKeepsTheGestureAnchorStable() {
        let portrait = MobileViewport(
            levelSize: MobileSize(width: 1_600, height: 160),
            viewSize: MobileSize(width: 390, height: 620),
            pixelAspect: 1.2
        )
        #expect(abs(portrait.zoom * portrait.levelSize.height - portrait.viewSize.height) < 0.001)

        var firstLayout = MobileViewport(
            levelSize: MobileSize(width: 1_600, height: 160),
            viewSize: MobileSize(width: 1, height: 1),
            pixelAspect: 1.2
        )
        firstLayout.fitGameplay(in: MobileSize(width: 756, height: 300))
        #expect(firstLayout.zoom > 1)
        #expect(abs(firstLayout.zoom * firstLayout.levelSize.height - firstLayout.viewSize.height) < 0.001)

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

    @Test func viewportResizeKeepsCameraCentreAndRestoredOrigin() {
        var viewport = MobileViewport(
            levelSize: MobileSize(width: 1_600, height: 1_000),
            viewSize: MobileSize(width: 320, height: 160),
            origin: MobilePoint(x: 400, y: 200),
            zoom: 2
        )
        let oldCentre = MobilePoint(
            x: viewport.origin.x + viewport.visibleLevelSize.width / 2,
            y: viewport.origin.y + viewport.visibleLevelSize.height / 2
        )
        viewport.resize(MobileSize(width: 640, height: 320))
        let newCentre = MobilePoint(
            x: viewport.origin.x + viewport.visibleLevelSize.width / 2,
            y: viewport.origin.y + viewport.visibleLevelSize.height / 2
        )
        #expect(abs(oldCentre.x - newCentre.x) < 0.001)
        #expect(abs(oldCentre.y - newCentre.y) < 0.001)

        var restored = MobileViewport(
            levelSize: MobileSize(width: 1_600, height: 1_000),
            viewSize: MobileSize(width: 1, height: 1),
            origin: MobilePoint(x: 500, y: 200),
            zoom: 2
        )
        restored.resizeKeepingOrigin(MobileSize(width: 650, height: 465))
        #expect(restored.origin == MobilePoint(x: 500, y: 200))
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

    @Test func planningDoesNotBypassReadyInterruptionOrResults() {
        var state = MobilePlayState()
        #expect(state.isPaused && !state.canEdit && !state.canStep)
        #expect(state.pauseForPlanning() == false)
        #expect(state.resume(isForeground: false, isInterrupted: false) == false)
        #expect(state.resume(isForeground: true, isInterrupted: false) == true)
        #expect(!state.isPaused && state.canEdit && !state.canStep)
        #expect(state.pauseForPlanning() == true)
        #expect(state.isPaused && state.canEdit && state.canStep)
        state.suspend()
        #expect(state.isPaused && !state.canEdit && !state.canStep)
        #expect(state.pauseForPlanning() == false)
        #expect(state.resume(isForeground: true, isInterrupted: true) == false)
        #expect(state.resume(isForeground: true, isInterrupted: false) == true)
        state.complete()
        state.suspend()
        #expect(state.phase == .completed)
        #expect(state.resume(isForeground: true, isInterrupted: false) == false)
    }

    @Test func heldTouchCommitsButCancellationAndReleaseOnlyDragDoNot() {
        var router = MobileTouchRouter(movementThreshold: 8)
        let point = MobilePoint(x: 20, y: 30)
        _ = router.began(id: 1, at: point, time: 1)
        #expect(router.ended(id: 1, at: point, time: 6) == [.commit(point)])
        _ = router.began(id: 2, at: point, time: 7)
        #expect(router.cancel() == [.cancelPreview])
        #expect(router.ended(id: 2, at: point, time: 8).isEmpty)
        _ = router.began(id: 3, at: point, time: 9)
        #expect(router.ended(id: 3, at: MobilePoint(x: 60, y: 30), time: 9.1) == [.cancelPreview])
    }

    @Test func loupeKeepsExactPixelsAndClipsAtLevelEdges() throws {
        let pixels = Data((0..<48).map(UInt8.init))
        let frame = try MobilePixelFrame(width: 4, height: 3, rgba: pixels)
        let first = try frame.cropped(around: MobilePoint(x: 0, y: 0), width: 2, height: 2)
        #expect(first.rgba == Data(Array(pixels[0..<8]) + Array(pixels[16..<24])))
        let last = try frame.cropped(around: MobilePoint(x: 4, y: 3), width: 2, height: 2)
        #expect(last.rgba == Data(Array(pixels[24..<32]) + Array(pixels[40..<48])))
        #expect(try frame.cropped(around: MobilePoint(x: 2, y: 1), width: 64, height: 40) == frame)
        #expect(throws: MobileSessionError.invalidFrame) {
            try frame.cropped(around: MobilePoint(x: .infinity, y: 1), width: 2, height: 2)
        }
    }

    @Test @MainActor func pausePopulationCountsExcludeActorsLostByAllThreeEngines() throws {
        let sessions: [any MobileGameSession] = [
            ClassicMobileSession(simulation: try Self.classicSimulation(), levelIdentifier: "fixture", levelIndex: 0),
            Lemmings2MobileSession(runtime: try Self.lemmings2Runtime(), engineFingerprint: "l2", levelIdentifier: "fixture", levelIndex: 0, levelFingerprint: "l2"),
            Lemmings3MobileSession(runtime: try Self.lemmings3Runtime(), engineFingerprint: "l3", levelIdentifier: "fixture", levelIndex: 0, levelFingerprint: "l3")
        ]
        for session in sessions {
            for _ in 0..<300 where session.activeLemmingCount == 0 && !session.snapshot.isComplete { session.tick() }
            #expect(session.activeLemmingCount > 0)
            #expect(session.beginEndRun())
            for _ in 0..<600 where !session.snapshot.isComplete { session.tick() }
            #expect(session.activeLemmingCount == 0)
            let info = MobilePauseSummary(level: .init(index: 0, rank: "Test", number: 1, title: "Population"),
                snapshot: session.snapshot, activeCount: session.activeLemmingCount,
                ticksPerSecond: session.ticksPerSecond, speed: 1, assignedSkills: session.assignedSkillCount,
                supportsRewind: session.supportsRewind, usedRewind: session.usedRewind, isReplay: false,
                soundtrack: "Original", track: nil, audio: "Music off")
            #expect(info.active == 0 && info.lost == session.snapshot.released - session.snapshot.saved)
            #expect(info.lost > 0)
            #expect(session.assignedSkillCount == 0)
        }
    }

    @Test @MainActor func allThreeGamesAssignDuringPlanningWithoutAdvancingTime() throws {
        let classic = ClassicMobileSession(simulation: try Self.classicSimulation(), levelIdentifier: "fixture/1", levelIndex: 0)
        let l2 = Lemmings2MobileSession(runtime: try Self.lemmings2Runtime(), engineFingerprint: "l2-engine", levelIdentifier: "l2/1", levelIndex: 0, levelFingerprint: "l2-level")
        let l3 = Lemmings3MobileSession(runtime: try Self.lemmings3Runtime(), engineFingerprint: "l3-engine", levelIdentifier: "l3/1", levelIndex: 0, levelFingerprint: "l3-level")
        #expect(classic.entrancePoint == MobilePoint(x: 20, y: 20))
        #expect(l2.entrancePoint == MobilePoint(x: 20, y: 45))
        #expect(l3.entrancePoint == MobilePoint(x: 20, y: 40))
        for (session, control) in [(classic as any MobileGameSession, 0), (l2 as any MobileGameSession, 0), (l3 as any MobileGameSession, 2)] {
            for _ in 0..<80 where !session.targetCandidates(for: control).contains(where: { $0.assignment == .eligible }) { session.tick() }
            var state = MobilePlayState()
            #expect(state.resume(isForeground: true, isInterrupted: false) == true)
            #expect(state.pauseForPlanning() == true)
            let tick = session.snapshot.tick
            let target = try #require(session.targetCandidates(for: control).first(where: { $0.assignment == .eligible }))
            let viewport = MobileViewport(levelSize: session.levelSize, viewSize: session.levelSize, zoom: 1)
            let pointer = viewport.viewPoint(fromLevel: target.point)
            let hovered = MobileTargetSelector.select(candidates: [target], touch: pointer, viewport: viewport,
                favourApproaching: false, input: .precision)
            #expect(hovered?.id == target.id && hovered?.state == .eligible)
            if session.engineIdentifier != "classic-dos" {
                #expect(target.pointerBounds == MobileRect(x: -9, y: -12, width: 18, height: 24))
            }
            #expect(state.canEdit && session.assign(control: control, to: target.id))
            #expect(session.assignedSkillCount == 1)
            #expect(session.snapshot.tick == tick)
            #expect(state.isPaused)
            let payload = try session.checkpointPayload()
            let assigned = session.snapshot
            session.tick()
            #expect(session.snapshot.tick == tick + 1)
            try session.restoreCheckpointPayload(payload)
            #expect(session.snapshot == assigned)
        }
    }

    @Test @MainActor func sequelSessionsDeliverSoundEventsWithoutReplayNoise() throws {
        let l2 = Lemmings2MobileSession(runtime: try Self.lemmings2Runtime(),
            engineFingerprint: "l2-audio", levelIdentifier: "l2/audio", levelIndex: 0,
            levelFingerprint: "l2-audio-level")
        var l2Played = false
        for _ in 0..<120 where !l2Played {
            l2.tick()
            l2Played = !l2.drainLemmings2SoundRequests().isEmpty
        }
        #expect(l2Played)
        for _ in 0..<20 { l2.tick() }
        #expect(l2.rewind(seconds: 5 / l2.ticksPerSecond))
        #expect(l2.drainLemmings2SoundRequests().isEmpty)

        let l3 = Lemmings3MobileSession(runtime: try Self.lemmings3Runtime(),
            engineFingerprint: "l3-audio", levelIdentifier: "l3/audio", levelIndex: 0,
            levelFingerprint: "l3-audio-level")
        var l3Cues: [PositionedSoundCue] = []
        for _ in 0..<120 where l3Cues.isEmpty {
            l3.tick()
            l3Cues = l3.drainSoundCues()
        }
        #expect(l3Cues.contains { $0.effect == .doorOpen || $0.effect == .letsGo })

        for _ in 0..<20 { l3.tick() }
        #expect(l3.rewind(seconds: 5 / l3.ticksPerSecond))
        #expect(l3.drainSoundCues().isEmpty)
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
        let older = MobileThermalPolicy.budget(for: .nominal, lowPowerMode: false,
            reduceMotion: false, reduceFlashes: false, constrainedDevice: true)
        #expect(older.framesPerSecond == 30)
        var clock = MobileTickClock(ticksPerSecond: 17, maximumCatchUpTicks: older.maximumCatchUpTicks)
        _ = clock.advance(at: 0)
        let ticks = (1...30).reduce(0) { count, frame in count + clock.advance(at: Double(frame) / 30) }
        #expect(ticks == 17)
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

    @Test(arguments: ["classic-dos", "lemmings2", "lemmings3"])
    func completedRunRejectsLateCheckpointWrites(engine: String) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MobileRetiredRunTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MobileCheckpointStore(url: directory.appendingPathComponent("run.json"))
        let run = checkpoint(tick: 10, payload: Data("completed".utf8), engine: engine)
        try await store.save(run)
        try await store.retire(runID: run.runID)
        try await store.save(checkpoint(tick: 20, payload: Data("late".utf8), engine: engine))
        #expect(try await store.load() == nil)
        let backupURL = await store.backupURL
        #expect(!FileManager.default.fileExists(atPath: backupURL.path))
    }

    @Test(arguments: ["classic-dos", "lemmings2", "lemmings3"])
    func previousRunCleanupPreservesRetryCheckpoint(engine: String) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MobileRetryRunTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MobileCheckpointStore(url: directory.appendingPathComponent("run.json"))
        let previous = checkpoint(tick: 10, payload: Data("previous".utf8), engine: engine)
        let retry = checkpoint(tick: 20, payload: Data("retry".utf8), runID: UUID(), engine: engine)
        try await store.save(previous)
        try await store.save(retry)
        try await store.retire(runID: previous.runID)
        #expect(try await store.load() == retry)
        try await store.save(checkpoint(tick: 30, payload: Data("late".utf8), engine: engine))
        #expect(try await store.load() == retry)
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

    @Test func gameDataImportsUseIndependentDestinations() throws {
        let manager = FileManager.default
        let temporary = manager.temporaryDirectory
            .appendingPathComponent("MobileGameDataKinds-\(UUID().uuidString)", isDirectory: true)
        defer { try? manager.removeItem(at: temporary) }
        let classic = temporary.appendingPathComponent("Classic", isDirectory: true)
        let sequel = temporary.appendingPathComponent("L2", isDirectory: true)
        try manager.createDirectory(at: classic, withIntermediateDirectories: true)
        try manager.createDirectory(at: sequel, withIntermediateDirectories: true)
        try Data("classic".utf8).write(to: classic.appendingPathComponent("marker.dat"))
        try Data("lemmings2".utf8).write(to: sequel.appendingPathComponent("marker.dat"))

        let store = MobileContentStore(root: temporary.appendingPathComponent("Support")) { staged in
            guard FileManager.default.fileExists(atPath: staged.appendingPathComponent("marker.dat").path) else {
                throw ImportFixtureError.rejected
            }
        }
        try store.install(directory: classic)
        let sequelStore = MobileContentStore(root: temporary.appendingPathComponent("Support"), validators: [
            .classic: { _ in },
            .lemmings2: { staged in
                guard try Data(contentsOf: staged.appendingPathComponent("marker.dat")) == Data("lemmings2".utf8) else {
                    throw ImportFixtureError.rejected
                }
            },
        ])
        try sequelStore.install(directory: sequel, for: .lemmings2)

        #expect(try Data(contentsOf: store.gameDataDirectory.appendingPathComponent("marker.dat")) == Data("classic".utf8))
        #expect(try Data(contentsOf: store.dataDirectory(for: .lemmings2).appendingPathComponent("marker.dat")) == Data("lemmings2".utf8))
        #expect(store.dataDirectory(for: .lemmings2) != store.gameDataDirectory)
        try store.install(directory: classic)
        #expect(try Data(contentsOf: store.dataDirectory(for: .lemmings2).appendingPathComponent("marker.dat")) == Data("lemmings2".utf8))

        let rejected = temporary.appendingPathComponent("Rejected L2", isDirectory: true)
        try manager.createDirectory(at: rejected, withIntermediateDirectories: true)
        try Data("rejected".utf8).write(to: rejected.appendingPathComponent("marker.dat"))
        let rejectingSequelStore = MobileContentStore(root: temporary.appendingPathComponent("Support"), validators: [
            .lemmings2: { _ in throw ImportFixtureError.rejected },
        ])
        do {
            try rejectingSequelStore.install(directory: rejected, for: .lemmings2)
            Issue.record("An invalid L2 replacement was committed.")
        } catch ImportFixtureError.rejected {
            #expect(try Data(contentsOf: store.gameDataDirectory.appendingPathComponent("marker.dat")) == Data("classic".utf8))
            #expect(try Data(contentsOf: store.dataDirectory(for: .lemmings2).appendingPathComponent("marker.dat")) == Data("lemmings2".utf8))
        }
    }

    @Test func neoLemmixImportResolvesInstallAndPackLayouts() throws {
        let manager = FileManager.default
        let temporary = manager.temporaryDirectory
            .appendingPathComponent("MobileNeoLemmixLayouts-\(UUID().uuidString)", isDirectory: true)
        defer { try? manager.removeItem(at: temporary) }
        let levels = temporary.appendingPathComponent("levels", isDirectory: true)
        let styles = temporary.appendingPathComponent("styles", isDirectory: true)
        let pack = levels.appendingPathComponent("Example", isDirectory: true)
        try manager.createDirectory(at: pack, withIntermediateDirectories: true)
        try manager.createDirectory(at: styles.appendingPathComponent("default", isDirectory: true),
                                   withIntermediateDirectories: true)

        #expect(MobileNeoLemmixDataLayout.levelsRoot(in: temporary) == levels)
        #expect(MobileNeoLemmixDataLayout.stylesRoot(in: temporary) == styles)

        let directPack = temporary.appendingPathComponent("DirectPack", isDirectory: true)
        try manager.createDirectory(at: directPack, withIntermediateDirectories: true)
        try Data("TITLE Direct Pack\n".utf8).write(to: directPack.appendingPathComponent("info.nxmi"))
        #expect(MobileNeoLemmixDataLayout.levelsRoot(in: directPack) == directPack)
        #expect(MobileNeoLemmixDataLayout.stylesRoot(in: directPack) == directPack)
        #expect(NeoLemmixMobileSupport.animationName(for: .walking) == "walker")
        #expect(NeoLemmixMobileSupport.animationName(for: .teleporting) == nil)
        #expect(NeoLemmixMobileSupport.requiredAnimationNames.contains("drowner"))
    }

    @Test func lemmings3ImportValidatesCreatureSpriteBanksBeforeInstall() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MobileL3CreatureBank-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let graphics = root.appendingPathComponent("GRAPHICS", isDirectory: true)
        try FileManager.default.createDirectory(at: graphics, withIntermediateDirectories: true)
        let prefix = graphics.appendingPathComponent("CREAT002")
        try Data([2, 0, 1, 0, 2, 0, 2, 0, 1, 0, 2, 0])
            .write(to: prefix.appendingPathExtension("IND"))
        try Data(repeating: 255, count: 16).write(to: prefix.appendingPathExtension("CMP"))
        try Data(repeating: 0, count: 96).write(to: prefix.appendingPathExtension("PAL"))
        let palette = [UInt8](repeating: 0, count: 1024)

        try MobileContentStore.validateLemmings3CreatureSpriteBanks(
            directory: root, kinds: [.mole], palette: palette)

        try Data(repeating: 255, count: 4).write(to: prefix.appendingPathExtension("CMP"))
        do {
            try MobileContentStore.validateLemmings3CreatureSpriteBanks(
                directory: root, kinds: [.mole], palette: palette)
            Issue.record("A truncated creature sprite bank passed import validation.")
        } catch {
            #expect(error is SequelDataError)
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

    @Test @MainActor func sequelSessionsReplayTheirInputCheckpoints() async throws {
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
        let l2Captured = l2.prepareCheckpointPayload()
        let l2Expected = l2.snapshot
        for _ in 0..<10 { l2.tick() }
        let l2Payload = try await Task.detached { try l2Captured.encode() }.value
        let l2Restored = Lemmings2MobileSession(
            runtime: l2Initial,
            engineFingerprint: "l2-fixture-engine",
            levelIdentifier: "l2/fixture/1",
            levelIndex: 0,
            levelFingerprint: "l2-fixture-level"
        )
        try l2Restored.restoreCheckpointPayload(l2Payload)
        #expect(l2Restored.snapshot == l2Expected)

        #expect(l2Restored.supportsRewind)
        for _ in 0..<5 { l2Restored.tick() }
        let l2RewindTarget = l2Restored.snapshot
        for _ in 0..<20 { l2Restored.tick() }
        #expect(l2Restored.rewind(seconds: 20 / l2Restored.ticksPerSecond))
        #expect(l2Restored.snapshot == l2RewindTarget)
        #expect(l2Restored.usedRewind)
        #expect(l2Restored.stepBackward())
        #expect(l2Restored.stepForward())
        #expect(l2Restored.snapshot == l2RewindTarget)
        let l2RewindCheckpoint = try l2Restored.checkpointPayload()
        let l2RewindRestored = Lemmings2MobileSession(
            runtime: l2Initial,
            engineFingerprint: "l2-fixture-engine",
            levelIdentifier: "l2/fixture/1",
            levelIndex: 0,
            levelFingerprint: "l2-fixture-level"
        )
        try l2RewindRestored.restoreCheckpointPayload(l2RewindCheckpoint)
        #expect(l2RewindRestored.usedRewind)
        #expect(l2RewindRestored.rewindCount == l2Restored.rewindCount)

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
        #expect(endingRestored.nukeCount == 1)
        #expect(endingRestored.undoEndRun())
        #expect(!endingRestored.snapshot.isEndingRun)
        #expect(endingRestored.usedRewind)
        #expect(endingRestored.undoCount == 1)

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
        let l3Captured = try l3.prepareCheckpointPayload()
        let l3Expected = l3.snapshot
        for _ in 0..<10 { l3.tick() }
        let l3Payload = try await Task.detached { try l3Captured.encode() }.value
        let l3Restored = Lemmings3MobileSession(
            runtime: l3Initial,
            engineFingerprint: "l3-fixture-engine",
            levelIdentifier: "l3/fixture/1",
            levelIndex: 0,
            levelFingerprint: "l3-fixture-level"
        )
        try l3Restored.restoreCheckpointPayload(l3Payload)
        #expect(l3Restored.snapshot == l3Expected)

        #expect(l3Restored.supportsRewind)
        for _ in 0..<5 { l3Restored.tick() }
        let l3RewindTarget = l3Restored.snapshot
        for _ in 0..<20 { l3Restored.tick() }
        #expect(l3Restored.rewind(seconds: 20 / l3Restored.ticksPerSecond))
        #expect(l3Restored.snapshot == l3RewindTarget)
        #expect(l3Restored.usedRewind)
        #expect(l3Restored.stepBackward())
        #expect(l3Restored.stepForward())
        #expect(l3Restored.snapshot == l3RewindTarget)
        let l3RewindCheckpoint = try l3Restored.checkpointPayload()
        let l3RewindRestored = Lemmings3MobileSession(
            runtime: l3Initial,
            engineFingerprint: "l3-fixture-engine",
            levelIdentifier: "l3/fixture/1",
            levelIndex: 0,
            levelFingerprint: "l3-fixture-level"
        )
        try l3RewindRestored.restoreCheckpointPayload(l3RewindCheckpoint)
        #expect(l3RewindRestored.usedRewind)
        #expect(l3RewindRestored.rewindCount == l3Restored.rewindCount)
    }

    @Test func lemmings3MobileDirectionalToolUseReplaysFromCheckpoint() throws {
        let width = 128
        let height = 64
        var attributes = [UInt16](repeating: 0x1000, count: width * height)
        for y in 48..<height {
            for x in 0..<width { attributes[y * width + x] = 0x20 }
        }
        let runtime = try Lemmings3Runtime(configuration: .init(
            width: width,
            height: height,
            attributes: attributes,
            entrance: .init(x: 20, y: 40),
            exits: [.init(x: 110, y: 46)],
            total: 1,
            releaseInterval: 20,
            releaseDelay: 1_000,
            pickups: [.init(id: 0, tool: .bricks, x: 20, y: 48)],
            extras: [.init(x: 20, y: 48, direction: 1)]
        ))
        let renderer: Lemmings3MobileRenderer = { runtime, _ in
            var rgba = [UInt8](repeating: 0, count: width * height * 4)
            for index in runtime.terrainEdits.keys where (0..<width * height).contains(index) {
                let offset = index * 4
                rgba[offset] = 255
                rgba[offset + 3] = 255
            }
            return try MobilePixelFrame(width: width, height: height, rgba: Data(rgba))
        }
        func makeSession() -> Lemmings3MobileSession {
            Lemmings3MobileSession(runtime: runtime, engineFingerprint: "l3-direction",
                levelIdentifier: "l3/direction", levelIndex: 0,
                levelFingerprint: "l3-direction-level", renderer: renderer)
        }

        let upward = makeSession()
        upward.tick()
        #expect(upward.targetCandidates(for: 3).first?.assignment == .eligible)
        #expect(!upward.useTool(direction: .down, to: 0))
        #expect(upward.useTool(direction: .up, to: 0))
        for _ in 0..<40 { upward.tick() }
        let upwardFrame = try upward.render(highlight: nil)
        let checkpoint = try upward.checkpointPayload()
        let restored = makeSession()
        try restored.restoreCheckpointPayload(checkpoint)
        #expect(try restored.render(highlight: nil) == upwardFrame)

        let rightward = makeSession()
        rightward.tick()
        #expect(rightward.useTool(direction: .right, to: 0))
        for _ in 0..<40 { rightward.tick() }
        #expect(try rightward.render(highlight: nil) != upwardFrame)
    }

    @Test @MainActor func lemmings2CompletionIsReportedOnceForCampaignPersistence() throws {
        var completions = 0
        let session = Lemmings2MobileSession(
            runtime: try Self.lemmings2Runtime(),
            engineFingerprint: "l2-fixture-engine",
            levelIdentifier: "lemmings2/fixture",
            levelIndex: 0,
            levelFingerprint: "l2-fixture-level",
            onCompletion: { _ in completions += 1 }
        )

        for _ in 0..<5_000 where !session.snapshot.isComplete { session.tick() }

        #expect(session.snapshot.isComplete)
        #expect(completions == 1)
        session.tick()
        #expect(completions == 1)
    }

    @Test @MainActor func lemmings3CompletionIsReportedOnceForCampaignPersistence() throws {
        var completions = 0
        let session = Lemmings3MobileSession(
            runtime: try Self.lemmings3Runtime(),
            engineFingerprint: "l3-fixture-engine",
            levelIdentifier: "lemmings3/fixture",
            levelIndex: 0,
            levelFingerprint: "l3-fixture-level",
            onCompletion: { _ in completions += 1 }
        )

        #expect(session.beginEndRun())
        session.tick()
        session.tick()

        #expect(session.snapshot.isComplete)
        #expect(completions == 1)
    }

    @Test func neoLemmixSessionRestoresCheckpointAndReportsCompletionOnce() throws {
        struct LegacyCheckpoint: Codable {
            var version = 1
            let levelFingerprint: String
            let simulation: NeoLemmixSimulation
            let simulationBeforeNuke: NeoLemmixSimulation?
            let requestedSpawnInterval: Int?
        }

        var terrain = try NeoLemmixTerrain(width: 64, height: 32)
        for x in 0..<64 { terrain.setSolid(true, x: x, y: 20) }
        let configuration = try NeoLemmixConfiguration(
            totalLemmings: 1,
            requiredToSave: 0,
            spawnInterval: 30,
            entrances: [],
            preplacedLemmings: [.init(position: .init(x: 20, y: 20))],
            skills: [.builder: .infinite]
        )
        let initial = try NeoLemmixSimulation(terrain: terrain, configuration: configuration)
        var legacyState = initial
        for _ in 0..<7 { _ = legacyState.tick() }
        let legacySession = NeoLemmixMobileSession(
            simulation: initial,
            controls: [.builder],
            engineFingerprint: "neo-fixture-engine",
            levelIdentifier: "neo/fixture/1",
            levelIndex: 0,
            levelFingerprint: "neo-fixture-level"
        )
        try legacySession.restoreCheckpointPayload(JSONEncoder().encode(LegacyCheckpoint(
            levelFingerprint: "neo-fixture-level",
            simulation: legacyState,
            simulationBeforeNuke: nil,
            requestedSpawnInterval: nil
        )))
        #expect(legacySession.snapshot.tick == 7)
        for _ in 0..<5 { legacySession.tick() }
        let legacyRewindTarget = legacySession.snapshot
        for _ in 0..<2 { legacySession.tick() }
        #expect(legacySession.rewind(seconds: 2 / legacySession.ticksPerSecond))
        #expect(legacySession.snapshot == legacyRewindTarget)

        var completions = 0
        let session = NeoLemmixMobileSession(
            simulation: initial,
            controls: [.builder],
            engineFingerprint: "neo-fixture-engine",
            levelIdentifier: "neo/fixture/1",
            levelIndex: 0,
            levelFingerprint: "neo-fixture-level",
            onCompletion: { _ in completions += 1 }
        )

        let target = try #require(session.targetCandidates(for: 0).first)
        #expect(target.assignment == .eligible)
        #expect(session.assign(control: 0, to: target.id))
        #expect(session.snapshot.releaseRate == 46)
        #expect(session.adjustReleaseRate(by: 2))
        session.tick()
        #expect(session.snapshot.releaseRate == 50)
        let expected = session.snapshot
        let payload = try session.checkpointPayload()
        session.tick()

        let restored = NeoLemmixMobileSession(
            simulation: initial,
            controls: [.builder],
            engineFingerprint: "neo-fixture-engine",
            levelIdentifier: "neo/fixture/1",
            levelIndex: 0,
            levelFingerprint: "neo-fixture-level"
        )
        try restored.restoreCheckpointPayload(payload)
        #expect(restored.snapshot == expected)
        #expect(restored.supportsRewind)
        for _ in 0..<20 { restored.tick() }
        #expect(restored.rewind(seconds: 20 / restored.ticksPerSecond))
        #expect(restored.snapshot == expected)
        #expect(restored.usedRewind)
        #expect(restored.stepBackward())
        #expect(restored.stepForward())
        #expect(restored.snapshot == expected)
        let rewindPayload = try restored.checkpointPayload()
        let rewindRestored = NeoLemmixMobileSession(
            simulation: initial,
            controls: [.builder],
            engineFingerprint: "neo-fixture-engine",
            levelIdentifier: "neo/fixture/1",
            levelIndex: 0,
            levelFingerprint: "neo-fixture-level"
        )
        try rewindRestored.restoreCheckpointPayload(rewindPayload)
        #expect(rewindRestored.usedRewind)
        #expect(rewindRestored.rewindCount == restored.rewindCount)

        #expect(session.beginEndRun())
        for _ in 0..<5 { session.tick() }
        let nukePayload = try session.checkpointPayload()
        let restoredNuke = NeoLemmixMobileSession(
            simulation: initial,
            controls: [.builder],
            engineFingerprint: "neo-fixture-engine",
            levelIdentifier: "neo/fixture/1",
            levelIndex: 0,
            levelFingerprint: "neo-fixture-level"
        )
        try restoredNuke.restoreCheckpointPayload(nukePayload)
        #expect(restoredNuke.snapshot.isEndingRun)
        #expect(restoredNuke.nukeCount == 1)
        #expect(restoredNuke.undoEndRun())
        #expect(session.undoEndRun())
        #expect(!session.snapshot.isEndingRun)
        #expect(session.usedRewind)
        #expect(session.undoCount == 1)
        #expect(session.beginEndRun())
        for _ in 0..<5_000 where !session.snapshot.isComplete { session.tick() }
        #expect(session.snapshot.isComplete)
        #expect(completions == 1)
        session.tick()
        #expect(completions == 1)
    }

    @Test func neoLemmixMobileSessionDeliversAndClearsSoundCues() throws {
        var terrain = try NeoLemmixTerrain(width: 64, height: 32)
        for x in 0..<64 { terrain.setSolid(true, x: x, y: 20) }
        let configuration = try NeoLemmixConfiguration(
            totalLemmings: 1,
            requiredToSave: 0,
            spawnInterval: 30,
            entranceOpenTick: 1,
            entrances: [.init(id: 0, position: .init(x: 10, y: 20))],
            preplacedLemmings: [.init(position: .init(x: 20, y: 20))],
            skills: [.builder: .infinite]
        )
        let simulation = try NeoLemmixSimulation(terrain: terrain, configuration: configuration)
        let session = NeoLemmixMobileSession(
            simulation: simulation,
            controls: [.builder],
            engineFingerprint: "neo-audio-engine",
            levelIdentifier: "neo/audio/1",
            levelIndex: 0,
            levelFingerprint: "neo-audio-level",
            gadgetSounds: [0: "test/trap"]
        )

        session.tick()
        #expect(session.drainSoundCues().map(\.effect) == [.doorOpen, .letsGo])
        let target = try #require(session.targetCandidates(for: 0).first)
        #expect(session.assign(control: 0, to: target.id))
        #expect(session.drainSoundCues().map(\.effect) == [.assignSkill])

        session.tick()
        #expect(session.rewind(seconds: 1 / session.ticksPerSecond))
        #expect(session.drainSoundCues().isEmpty)
        #expect(session.beginEndRun())
        session.tick()
        #expect(session.undoEndRun())
        #expect(session.drainSoundCues().isEmpty)
    }

    private func checkpoint(tick: Int, payload: Data,
                            runID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                            engine: String = "classic-dos") -> MobileCheckpointEnvelope {
        MobileCheckpointEnvelope(
            runID: runID,
            engine: engine,
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
