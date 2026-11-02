import Testing
@testable import NxlvKit
@testable import LemmingsMobileCore

struct MobileWorkerHistoryTests {
    private var viewport: MobileViewport {
        .init(levelSize: .init(width: 160, height: 100), viewSize: .init(width: 160, height: 100), zoom: 1)
    }
    private let aim = MobilePoint(x: 80, y: 60)

    private func select(favoured: Bool, state: MobileAssignmentState = .eligible,
                        enabled: Bool = true) -> Int? {
        let worker = MobileTargetCandidate(id: 2, point: .init(x: 76, y: 60), direction: -1,
            assignment: state, isPerformingSkill: favoured)
        let walker = MobileTargetCandidate(id: 1, point: aim, direction: 1, assignment: .eligible)
        return MobileTargetSelector.select(candidates: [walker, worker], touch: aim, viewport: viewport,
            favourActiveWorkers: enabled, input: .precision, retaining: walker.id,
            wallDirectionForTarget: { _ in 1 })?.id
    }

    @Test func walkingClimberKeepsBridgePriorityUntilFallingAndDoesNotRegainItOnLanding() {
        var lemming = ClassicDOSLemming(id: 2, foot: .init(x: 76, y: 65))
        lemming.hasClimber = true
        lemming.action = .walking
        #expect(select(favoured: lemming.hasSkillTargetPriority) == 1)
        lemming.action = .building
        lemming.action = .shrugging
        lemming.action = .walking
        #expect(select(favoured: lemming.hasSkillTargetPriority) == lemming.id)
        #expect(select(favoured: lemming.hasSkillTargetPriority, enabled: false) == 1)
        #expect(select(favoured: lemming.hasSkillTargetPriority, state: .alreadyAssigned) == 1)
        lemming.action = .falling
        #expect(select(favoured: lemming.hasSkillTargetPriority) == 1)
        lemming.action = .walking
        #expect(lemming.hasClimber)
        #expect(select(favoured: lemming.hasSkillTargetPriority) == 1)
    }

    @Test func neoPreplacedWorkerCarriesPriorityIntoWalkingButPermanentTraitsAloneDoNot() {
        var lemming = NeoLemmixLemming(id: 2, position: .init(x: 76, y: 65), direction: .left,
            action: .building, traits: [.climber])
        lemming.action = .walking
        #expect(select(favoured: lemming.hasSkillTargetPriority) == lemming.id)
        lemming.action = .falling
        lemming.action = .walking
        #expect(select(favoured: lemming.hasSkillTargetPriority) == 1)
        #expect(lemming.traits.contains(.climber))
    }
}
