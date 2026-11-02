import Foundation
import Testing
@testable import LemmingsMobileCore

struct MobileWorkerTargetingTests {
    private let point = MobilePoint(x: 80, y: 60)
    private var viewport: MobileViewport {
        .init(levelSize: .init(width: 160, height: 100), viewSize: .init(width: 160, height: 100), zoom: 1)
    }

    private func actor(_ id: Int, x: Double = 80, direction: Int = 1,
                       state: MobileAssignmentState = .eligible, working: Bool = false,
                       building: Bool = false, blocking: Bool = false,
                       bombBlocker: Bool = false, tool: Bool = false) -> MobileTargetCandidate {
        .init(id: id, point: .init(x: x, y: 60), direction: direction, assignment: state,
            isBuilding: building, isBlocking: blocking, isPerformingSkill: working,
            isBombBlocker: bombBlocker, hasTool: tool)
    }

    @Test(arguments: [MobileTargetInput.touch, .precision])
    func activeWorkerBeatsCloserApproachingAndRetainedWalker(input: MobileTargetInput) {
        let worker = actor(2, x: 76, direction: -1, working: true)
        let walker = actor(1)
        for crowd in [[walker, worker], [worker, walker]] {
            let selected = MobileTargetSelector.select(candidates: crowd, touch: point, viewport: viewport,
                favourActiveWorkers: true, input: input, retaining: walker.id,
                wallDirectionForTarget: { _ in 1 })
            #expect(selected?.id == worker.id && selected?.state == .eligible)
        }
    }

    @Test(arguments: [MobileAssignmentState.unavailable, .alreadyAssigned])
    func nativeEligibilityWinsOverActiveSkill(state: MobileAssignmentState) {
        let worker = actor(2, state: state, working: true)
        let walker = actor(1, x: 82)
        #expect(MobileTargetSelector.select(candidates: [worker, walker], touch: point, viewport: viewport,
            favourApproaching: false, favourActiveWorkers: true, input: .precision)?.id == walker.id)
        let unavailableWalker = actor(3, state: .unavailable)
        let unavailableWorker = actor(4, x: 76, state: .unavailable, working: true)
        #expect(MobileTargetSelector.select(candidates: [unavailableWorker, unavailableWalker], touch: point,
            viewport: viewport, favourActiveWorkers: true, input: .precision)?.id == unavailableWalker.id)
    }

    @Test func disablingWorkerPreferenceAndFinishingWorkRestoreOrdinarySelection() {
        let walker = actor(1)
        #expect(MobileTargetSelector.select(candidates: [walker, actor(2, x: 76, working: true)],
            touch: point, viewport: viewport, favourApproaching: false,
            favourActiveWorkers: false, input: .precision)?.id == walker.id)
        #expect(MobileTargetSelector.select(candidates: [walker, actor(2, x: 76)],
            touch: point, viewport: viewport, favourApproaching: false,
            favourActiveWorkers: true, input: .precision)?.id == walker.id)
    }

    @Test func activeWorkersKeepStableDistanceIdentifierAndRetentionRules() {
        let workers = [actor(3, x: 76, working: true), actor(2, x: 84, working: true)]
        for crowd in [workers, Array(workers.reversed())] {
            #expect(MobileTargetSelector.select(candidates: crowd, touch: point, viewport: viewport,
                favourActiveWorkers: true, input: .precision)?.id == 2)
            #expect(MobileTargetSelector.select(candidates: crowd, touch: point, viewport: viewport,
                favourActiveWorkers: true, input: .precision, retaining: 3)?.id == 3)
        }
        #expect(MobileTargetSelector.select(candidates: workers + [actor(4, x: 78, working: true)],
            touch: point, viewport: viewport, favourActiveWorkers: true, input: .precision)?.id == 4)
    }

    @Test func workerPreferenceDoesNotExtendPointerOrFingerReach() {
        let walker = actor(1)
        #expect(MobileTargetSelector.select(candidates: [walker, actor(2, x: 87, working: true)],
            touch: point, viewport: viewport, favourActiveWorkers: true, input: .precision)?.id == walker.id)
        #expect(MobileTargetSelector.select(candidates: [walker, actor(2, x: 107, working: true)],
            touch: point, viewport: viewport, favourActiveWorkers: true, input: .touch)?.id == walker.id)
        #expect(MobileTargetSelector.select(candidates: [actor(2, x: 107, working: true)],
            touch: point, viewport: viewport, favourActiveWorkers: true, input: .touch) == nil)
    }

    @Test func repeatBuildAndBombBlockersKeepTheirExplicitPriority() {
        let digger = actor(1, working: true)
        let builder = actor(2, x: 76, building: true)
        #expect(MobileTargetSelector.select(candidates: [digger, builder], touch: point, viewport: viewport,
            preference: .builder, favourActiveWorkers: true, input: .precision)?.id == builder.id)
        let blocker = actor(3, x: 84, blocking: true, bombBlocker: true)
        #expect(MobileTargetSelector.select(candidates: [digger, builder, blocker], touch: point,
            viewport: viewport, preference: .bombBlocker, favourActiveWorkers: true,
            favourBombBlockers: true, input: .precision)?.id == blocker.id)
        #expect(MobileTargetSelector.select(candidates: [digger, blocker], touch: point,
            viewport: viewport, favourActiveWorkers: true, favourBombBlockers: false,
            input: .precision)?.id == digger.id)
        #expect(MobileTargetSelector.select(candidates: [actor(1), blocker], touch: point,
            viewport: viewport, favourApproaching: false, favourActiveWorkers: true,
            favourBombBlockers: false, input: .precision)?.id == 1)
    }

    @Test func shruggingSupportsRepeatBuildWithoutInventingAnApproachingFollower() {
        let shrugging = MobileTargetCandidate(id: 2, point: point, direction: 1,
            assignment: .eligible, isBuilding: false, isBuilderContinuation: true)
        let aim = MobilePoint(x: 81, y: 60)
        #expect(!shrugging.isBuilding && shrugging.isPerformingSkill)
        #expect(MobileTargetSelector.select(candidates: [actor(1, x: 77), shrugging],
            touch: aim, viewport: viewport, favourActiveWorkers: false,
            input: .precision)?.id == shrugging.id)
        #expect(MobileTargetSelector.select(candidates: [actor(1, x: 81), shrugging],
            touch: aim, viewport: viewport, preference: .builder, favourActiveWorkers: true,
            input: .precision)?.id == shrugging.id)
    }

    @Test func carriedToolsAndL3BombOptOutRemainIndependentOfWorkerPreference() {
        let carrier = actor(1, tool: true)
        let emptyWorker = actor(2, x: 76, working: true)
        #expect(MobileTargetSelector.select(candidates: [carrier, emptyWorker], touch: point,
            viewport: viewport, preference: .toolHolder, favourActiveWorkers: true,
            input: .precision)?.id == carrier.id)
        let builder = actor(3, x: 76, building: true, tool: true)
        let bomber = actor(4, x: 84, blocking: true, bombBlocker: true, tool: true)
        #expect(MobileTargetSelector.select(candidates: [carrier, builder, bomber], touch: point,
            viewport: viewport, preference: .toolUser, favourActiveWorkers: true,
            favourBombBlockers: true, input: .precision)?.id == bomber.id)
        #expect(MobileTargetSelector.select(candidates: [carrier, builder, bomber], touch: point,
            viewport: viewport, preference: .toolUser, favourActiveWorkers: true,
            favourBombBlockers: false, input: .precision)?.id == builder.id)
        #expect(MobileTargetSelector.select(candidates: [carrier, bomber], touch: point,
            viewport: viewport, preference: .toolUser, favourApproaching: false,
            favourActiveWorkers: true, favourBombBlockers: false, input: .precision)?.id == carrier.id)
    }

    @Test func heldManualSelectionIsNotReplacedByAnActiveWorker() throws {
        let walker = actor(1), worker = actor(2, x: 76, working: true)
        let held = try #require(MobileTouchSelection(candidates: [walker, worker], touch: point,
            viewport: viewport, selectedID: walker.id))
        #expect(held.selection(in: [walker, worker])?.id == walker.id)
        #expect(held.selection(in: [worker]) == nil)
    }

    @Test func previousCandidateEncodingRetainsItsMeaning() throws {
        let old = Data("{\"id\":1,\"point\":{\"x\":80,\"y\":60},\"direction\":1,\"assignment\":\"eligible\",\"isBuilding\":true,\"isBlocking\":false,\"hasTool\":false}".utf8)
        let decoded = try JSONDecoder().decode(MobileTargetCandidate.self, from: old)
        #expect(decoded.isPerformingSkill && decoded.isBuilderContinuation && !decoded.isBombBlocker)
        let worker = actor(2, working: true, blocking: true, bombBlocker: true)
        #expect(try JSONDecoder().decode(MobileTargetCandidate.self, from: JSONEncoder().encode(worker)) == worker)
    }
}
