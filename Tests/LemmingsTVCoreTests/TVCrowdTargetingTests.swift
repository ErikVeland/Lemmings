import Foundation
import NxlvKit
import LemmingsMobileCore
import Testing
@testable import LemmingsTVCore

struct TVCrowdTargetingTests {
    private var viewport: MobileViewport {
        .init(levelSize: .init(width: 160, height: 100), viewSize: .init(width: 640, height: 400), zoom: 4)
    }
    private func actor(_ id: Int, x: Double = 40, y: Double = 40,
                       state: MobileAssignmentState = .eligible, bounds: MobileRect? = nil) -> MobileTargetCandidate {
        .init(id: id, point: .init(x: x, y: y), direction: 1, assignment: state, pointerBounds: bounds)
    }

    @Test func tinyBackAndForthMovementsReachEveryActorInAnEightyLemmingStack() {
        let actors = (0..<80).map { actor($0) }
        var point = viewport.viewPoint(fromLevel: actors[0].point)
        var lock = TVTargetLock()
        lock.select(0)
        var visited: Set<Int> = [0]
        for step in 0..<80 {
            let direction = step.isMultiple(of: 2) ? 1.0 : -1.0
            for _ in 0..<4 {
                point.x += direction * 0.5
                let selected = lock.aim(at: point, movement: .init(x: direction * 0.5, y: 0), displayed: nil,
                    candidates: actors.reversed(), viewport: viewport, granular: true)
                if let id = selected?.id { visited.insert(id) }
            }
        }
        #expect(visited == Set(0..<80))
        #expect(lock.id == 0)
    }

    @Test func incomingWalkersDoNotReplaceTheChosenIndividualOrScrambleTheNextPick() {
        let point = viewport.viewPoint(fromLevel: .init(x: 40, y: 40))
        var lock = TVTargetLock(); lock.select(20)
        _ = lock.aim(at: point, movement: .init(x: 0.5, y: 0), displayed: nil,
            candidates: [actor(10), actor(20), actor(30)], viewport: viewport, granular: true)
        let arrived = [actor(30), actor(5), actor(20), actor(10)]
        #expect(lock.resolve(candidates: arrived, visible: viewport.visibleLevelRect)?.id == 20)
        #expect(lock.aim(at: point, movement: .init(x: 1.5, y: 0), displayed: nil,
            candidates: arrived, viewport: viewport, granular: true)?.id == 30)
        let changed = [actor(10), actor(30, state: .unavailable)]
        #expect(lock.resolve(candidates: changed, visible: viewport.visibleLevelRect)?.state == .unavailable)
        #expect(lock.id == 30)
    }

    @Test func nudgesCanChooseTheLowerWorkerAndPreserveItsAssignmentState() {
        let actors = [actor(1, y: 38), actor(2, y: 38), actor(3, y: 43, state: .alreadyAssigned)]
        let point = viewport.viewPoint(fromLevel: .init(x: 40, y: 40))
        var lock = TVTargetLock(); lock.select(1)
        #expect(lock.aim(at: point, movement: .init(x: 2, y: 0), displayed: nil,
            candidates: actors, viewport: viewport, granular: true)?.id == 2)
        let worker = lock.aim(at: point, movement: .init(x: -2, y: 0), displayed: nil,
            candidates: actors, viewport: viewport, granular: true)
        #expect(worker?.id == 3 && worker?.state == .alreadyAssigned)
        #expect(lock.resolve(candidates: actors, visible: viewport.visibleLevelRect)?.id == 3)
        #expect(lock.resolve(candidates: Array(actors.prefix(2)), visible: viewport.visibleLevelRect) == nil)
    }

    @Test func holdingStillAndSubPixelNoiseDoNotChangeTheSelectedIndividual() {
        let actors = [actor(1), actor(2)]
        let point = viewport.viewPoint(fromLevel: actors[0].point)
        var lock = TVTargetLock(); lock.select(1)
        for _ in 0..<200 {
            #expect(lock.aim(at: point, movement: .init(x: 0.01, y: 0), displayed: nil,
                candidates: actors, viewport: viewport, granular: true)?.id == 1)
        }
        #expect(lock.aim(at: point, movement: .init(x: 0, y: 0), displayed: nil,
            candidates: actors, viewport: viewport, granular: true)?.id == 1)
    }

    @Test func fastAimingLeavingTheCrowdAndExplicitSelectionsClearAccumulatedMotion() {
        let actors = [actor(1), actor(2)]
        let point = viewport.viewPoint(fromLevel: actors[0].point)
        var lock = TVTargetLock(); lock.select(1)
        _ = lock.aim(at: point, movement: .init(x: 1.5, y: 0), displayed: nil,
            candidates: actors, viewport: viewport, granular: true)
        #expect(lock.aim(at: point, movement: .init(x: 12, y: 0), displayed: nil,
            candidates: actors, viewport: viewport, granular: true) == nil)
        #expect(lock.id == nil)
        lock.select(1)
        #expect(lock.aim(at: point, movement: .init(x: 0.5, y: 0), displayed: nil,
            candidates: actors, viewport: viewport, granular: true)?.id == 1)
        #expect(lock.aim(at: viewport.viewPoint(fromLevel: .init(x: 100, y: 80)), movement: .init(x: 1, y: 0),
            displayed: nil, candidates: actors, viewport: viewport, granular: true) == nil)
        lock.select(1)
        #expect(lock.aim(at: point, movement: .init(x: 2, y: 0), displayed: nil,
            candidates: actors, viewport: viewport, granular: false) == nil)
        #expect(lock.id == nil)
    }

    @Test func gameSpecificPickBoundsZoomAndPixelAspectLimitTheCrowd() {
        // Bounds match the Classic, L2 and L3 session adapters' sprite-centre coordinates.
        for box in [MobileRect(x: -6, y: -9, width: 12, height: 19),
                    MobileRect(x: -9, y: -12, width: 18, height: 24),
                    MobileRect(x: -9, y: -12, width: 18, height: 24)] {
            for zoom in [1.0, 2.0, 4.0] {
                let viewport = MobileViewport(levelSize: .init(width: 160, height: 100),
                    viewSize: .init(width: 640, height: 400), zoom: zoom, pixelAspect: 1.2)
                let actors = [actor(1, bounds: box), actor(2, bounds: box), actor(3, x: 90, bounds: box)]
                let point = viewport.viewPoint(fromLevel: actors[0].point)
                var lock = TVTargetLock(); lock.select(1)
                #expect(lock.aim(at: point, movement: .init(x: 2, y: 0), displayed: nil,
                    candidates: actors, viewport: viewport, granular: true)?.id == 2)
                #expect(lock.aim(at: point, movement: .init(x: -2, y: 0), displayed: nil,
                    candidates: actors, viewport: viewport, granular: true)?.id == 1)
            }
        }
    }

    @Test @MainActor func selectedActorsReceiveTheAssignmentInAllThreeNativeSessions() throws {
        for session in try sessions() {
            for _ in 0..<400 where session.targetCandidates(for: 0).filter({ $0.assignment == .eligible }).count < 2
                && !session.snapshot.isComplete { session.tick() }
            let candidates = session.targetCandidates(for: 0)
            let eligible = candidates.filter { $0.assignment == .eligible }.sorted { $0.id < $1.id }
            #expect(eligible.count >= 2)
            let first = try #require(eligible.first)
            let second = try #require(eligible.dropFirst().first)
            let viewport = MobileViewport(levelSize: session.levelSize, viewSize: .init(width: 640, height: 400), zoom: 4)
            let point = viewport.viewPoint(fromLevel: .init(x: (first.point.x + second.point.x) / 2,
                y: (first.point.y + second.point.y) / 2))
            var lock = TVTargetLock(); lock.select(first.id)
            let before = session.snapshot
            let selection = lock.aim(at: point, movement: .init(x: 2, y: 0), displayed: nil,
                candidates: candidates, viewport: viewport, granular: true)
            let picked = try #require(selection)
            #expect(picked.id == second.id && picked.state == .eligible)
            #expect(session.snapshot == before)
            #expect(lock.resolve(candidates: candidates, visible: viewport.visibleLevelRect)?.id == picked.id)
            #expect(session.assign(control: 0, to: picked.id))
            #expect(session.assignedSkillCount == 1)
            #expect(session.lemmingInspection?.individuals.first(where: { $0.id == picked.id })?.actions.count == 1)
        }
    }

    @MainActor private func sessions() throws -> [any MobileGameSession] {
        let width = 128, height = 80
        var solid = Data(repeating: 0, count: width * height)
        for y in 60..<height { for x in 0..<width { solid[y * width + x] = 1 } }
        let classic = try ClassicDOSSimulation(terrain: .init(width: width, height: height, solidMask: solid,
            steelMask: Data(repeating: 0, count: solid.count)), configuration: .init(totalLemmings: 3, requiredToSave: 1,
                timeLimitTicks: 2_000, initialReleaseRate: 99, entrances: [.init(x: 40, y: 40)],
                initialSkills: [.climber: 3], maximumX: width - 1, maximumY: height - 1))
        let frame = Lemmings2SpriteFrame(x: 0, y: 0, width: 1, height: 1, pixels: [7], opaque: [true])
        let masks = try Lemmings2TerrainMasks(digger: frame, basher: Array(repeating: frame, count: 8),
            miner: Array(repeating: frame, count: 4), exploder: frame, brick: frame,
            stacker: Array(repeating: frame, count: 2), platformer: frame)
        let l2 = try Lemmings2Runtime(configuration: .init(width: width, height: height,
            pixels: Array(solid), solid: solid.map { $0 != 0 }, palette: [UInt8](repeating: 255, count: 1_024),
            entrance: .init(x: 40, y: 40, width: 1, height: 1), exits: [.init(x: 110, y: 50, width: 16, height: 16)],
            skills: [.jumper], supplies: [3], total: 3, timeLimit: 120, releaseInterval: 1,
            terrainMasks: masks, firstReleaseTick: 1))
        let l3 = try Lemmings3Runtime(configuration: .init(width: width, height: height,
            attributes: solid.map { $0 == 0 ? UInt16(0x1000) : UInt16(0x20) }, entrance: .init(x: 40, y: 40),
            exits: [.init(x: 110, y: 58)], total: 3, releaseInterval: 1, releaseDelay: 0))
        return [ClassicMobileSession(simulation: classic, levelIdentifier: "crowd", levelIndex: 0),
                Lemmings2MobileSession(runtime: l2, engineFingerprint: "l2", levelIdentifier: "crowd", levelIndex: 0, levelFingerprint: "l2"),
                Lemmings3MobileSession(runtime: l3, engineFingerprint: "l3", levelIdentifier: "crowd", levelIndex: 0, levelFingerprint: "l3")]
    }
}
