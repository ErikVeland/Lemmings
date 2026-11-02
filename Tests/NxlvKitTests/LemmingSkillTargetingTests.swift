import Foundation
import Testing
@testable import NxlvKit

struct LemmingSkillTargetingTests {
    @Test func classicBridgeCompletionKeepsPriorityUntilTheFirstFall() {
        var lemming = classicWalker()
        #expect(!lemming.hasSkillTargetPriority)
        for action in [ClassicDOSAction.building, .shrugging, .walking] {
            lemming.action = action
            #expect(lemming.hasSkillTargetPriority)
        }
        for _ in 0..<20 {
            lemming.foot.x += 1
            lemming.action = .walking
        }
        #expect(lemming.hasSkillTargetPriority)
        lemming.action = .falling
        #expect(!lemming.hasSkillTargetPriority)
        lemming.action = .walking
        #expect(!lemming.hasSkillTargetPriority)
    }

    @Test func neoBridgeCompletionKeepsPriorityUntilTheFirstFall() {
        var lemming = neoWalker()
        for action in [NeoLemmixAction.building, .shrugging, .walking] {
            lemming.action = action
            #expect(lemming.hasSkillTargetPriority)
        }
        lemming.action = .falling
        #expect(!lemming.hasSkillTargetPriority)
        lemming.action = .walking
        #expect(!lemming.hasSkillTargetPriority)
    }

    @Test func sequelBridgeCompletionKeepsPriorityUntilTheFirstFall() {
        var l2 = Lemmings2Runtime.Lemming(id: 1, x: 40, y: 60)
        for state in [Lemmings2Runtime.State.building, .shrugging, .walking] {
            l2.state = state
            #expect(l2.hasSkillTargetPriority)
        }
        l2.state = .falling
        #expect(!l2.hasSkillTargetPriority)
        l2.state = .walking
        #expect(!l2.hasSkillTargetPriority)

        var l3 = Lemmings3Runtime.Lemming(id: 1, x: 40, y: 60)
        l3.state = .building
        l3.state = .walking
        #expect(l3.hasSkillTargetPriority)
        l3.state = .falling
        #expect(!l3.hasSkillTargetPriority)
        l3.state = .walking
        #expect(!l3.hasSkillTargetPriority)
    }

    @Test func aFallBetweenTargetQueriesStillClearsThePreviousWorker() {
        var classic = classicWalker()
        classic.action = .digging
        classic.action = .walking
        classic.action = .falling
        classic.action = .walking
        #expect(!classic.hasSkillTargetPriority)

        var neo = neoWalker()
        neo.action = .platforming
        neo.action = .walking
        neo.action = .falling
        neo.action = .walking
        #expect(!neo.hasSkillTargetPriority)

        var l2 = Lemmings2Runtime.Lemming(id: 1, x: 40, y: 60)
        l2.state = .fencing
        l2.state = .walking
        l2.state = .falling
        l2.state = .walking
        #expect(!l2.hasSkillTargetPriority)

        var l3 = Lemmings3Runtime.Lemming(id: 1, x: 40, y: 60)
        l3.state = .digging
        l3.state = .walking
        l3.state = .falling
        l3.state = .walking
        #expect(!l3.hasSkillTargetPriority)
    }

    @Test func permanentTraitsAloneDoNotMakeAnOrdinaryWalkerPreferred() {
        var classic = classicWalker()
        classic.hasClimber = true
        classic.hasFloater = true
        #expect(!classic.hasSkillTargetPriority)

        let neo = NeoLemmixLemming(id: 1, position: .init(x: 40, y: 60), direction: .right,
            action: .walking, traits: [.climber, .floater, .swimmer, .slider, .disarmer])
        #expect(!neo.hasSkillTargetPriority)

        var l2 = Lemmings2Runtime.Lemming(id: 1, x: 40, y: 60)
        l2.state = .walking
        l2.climber = true
        l2.floater = true
        l2.swimmer = true
        #expect(!l2.hasSkillTargetPriority)

        var l3 = Lemmings3Runtime.Lemming(id: 1, x: 40, y: 60)
        l3.state = .walking
        l3.tool = .bricks
        l3.quantity = 8
        #expect(!l3.hasSkillTargetPriority)
    }

    @Test func copiedHistoryRestoresTheWalkingWorkerWhenRewinding() {
        var lemming = classicWalker()
        lemming.action = .building
        lemming.action = .walking
        let beforeFall = lemming
        lemming.action = .falling
        lemming.action = .walking
        let afterFall = lemming
        #expect(!afterFall.hasSkillTargetPriority)
        lemming = beforeFall
        #expect(lemming.hasSkillTargetPriority)
        lemming = afterFall
        #expect(!lemming.hasSkillTargetPriority)
        #expect(beforeFall.hasSkillTargetPriority)
    }

    @Test func actorsKeepIndependentHistoriesAndNewWorkRestoresPriority() {
        var first = classicWalker(id: 1)
        var second = classicWalker(id: 2)
        first.action = .building
        first.action = .walking
        #expect(first.hasSkillTargetPriority)
        #expect(!second.hasSkillTargetPriority)
        second.action = .digging
        second.action = .walking
        first.action = .falling
        first.action = .walking
        #expect(!first.hasSkillTargetPriority)
        #expect(second.hasSkillTargetPriority)
        first.action = .bashing
        first.action = .walking
        #expect(first.hasSkillTargetPriority)
    }

    @Test func fallingAndTerminalStatesOverridePreviousSkillHistory() {
        var history = LemmingSkillTargetingHistory()
        history.transition(wasPerformingSkill: false, isPerformingSkill: true, resets: false)
        #expect(history.isFavoured)
        history.transition(wasPerformingSkill: true, isPerformingSkill: true, resets: true)
        #expect(!history.isFavoured)
        history.transition(wasPerformingSkill: false, isPerformingSkill: false, resets: false)
        #expect(!history.isFavoured)

        for action in [ClassicDOSAction.falling, .splatting, .exiting, .drowning, .vaporizing, .ohNo, .exploding] {
            var lemming = classicWalker()
            lemming.action = .building
            lemming.action = action
            #expect(!lemming.hasSkillTargetPriority)
            lemming.action = .walking
            #expect(!lemming.hasSkillTargetPriority)
        }
        var saved = classicWalker()
        saved.action = .building
        saved.outcome = .saved
        #expect(!saved.hasSkillTargetPriority)
    }

    @Test func historyRoundTripPreservesTheRetainedFlag() throws {
        var history = LemmingSkillTargetingHistory()
        history.transition(wasPerformingSkill: true, isPerformingSkill: false, resets: false)
        let encoded = try JSONEncoder().encode(history)
        let restored = try JSONDecoder().decode(LemmingSkillTargetingHistory.self, from: encoded)
        #expect(restored.isFavoured)
        let empty = try JSONDecoder().decode(LemmingSkillTargetingHistory.self,
            from: JSONEncoder().encode(LemmingSkillTargetingHistory()))
        #expect(!empty.isFavoured)
    }

    @Test func encodedActorsRestoreWalkingPriorityAndReadOlderSaves() throws {
        var classic = classicWalker()
        classic.action = .building
        classic.action = .walking
        let encodedClassic = try JSONEncoder().encode(classic)
        let restoredClassic = try JSONDecoder().decode(ClassicDOSLemming.self, from: encodedClassic)
        #expect(restoredClassic.hasSkillTargetPriority)
        let legacyClassic = try JSONDecoder().decode(ClassicDOSLemming.self,
            from: removingHistory(encodedClassic))
        #expect(!legacyClassic.hasSkillTargetPriority)

        var neo = neoWalker()
        neo.action = .building
        neo.action = .walking
        let encodedNeo = try JSONEncoder().encode(neo)
        let restoredNeo = try JSONDecoder().decode(NeoLemmixLemming.self, from: encodedNeo)
        #expect(restoredNeo.hasSkillTargetPriority)
        let legacyNeo = try JSONDecoder().decode(NeoLemmixLemming.self,
            from: removingHistory(encodedNeo))
        #expect(!legacyNeo.hasSkillTargetPriority)
    }

    @Test func legacyActiveWorkerRetainsPriorityAfterFinishingItsTask() throws {
        var classic = classicWalker()
        classic.action = .building
        var decodedClassic = try JSONDecoder().decode(ClassicDOSLemming.self,
            from: removingHistory(JSONEncoder().encode(classic)))
        #expect(decodedClassic.hasSkillTargetPriority)
        decodedClassic.action = .walking
        #expect(decodedClassic.hasSkillTargetPriority)

        let neo = NeoLemmixLemming(id: 1, position: .init(x: 40, y: 60), direction: .right, action: .digging)
        var decodedNeo = try JSONDecoder().decode(NeoLemmixLemming.self,
            from: removingHistory(JSONEncoder().encode(neo)))
        #expect(decodedNeo.hasSkillTargetPriority)
        decodedNeo.action = .walking
        #expect(decodedNeo.hasSkillTargetPriority)
    }

    @Test func physicsEqualityIgnoresOnlyTargetHistory() {
        let untouched = classicWalker()
        var worked = untouched
        worked.action = .building
        worked.action = .walking
        #expect(worked.hasSkillTargetPriority && !untouched.hasSkillTargetPriority)
        #expect(worked == untouched)
        var moved = worked
        moved.foot.x += 1
        #expect(moved != untouched)
        var changedAction = worked
        changedAction.action = .digging
        #expect(changedAction != untouched)

        let untouchedNeo = neoWalker()
        var workedNeo = untouchedNeo
        workedNeo.action = .building
        workedNeo.action = .walking
        #expect(workedNeo.hasSkillTargetPriority && !untouchedNeo.hasSkillTargetPriority)
        #expect(workedNeo == untouchedNeo)
        workedNeo.position.x += 1
        #expect(workedNeo != untouchedNeo)

        var untouchedL2 = Lemmings2Runtime.Lemming(id: 1, x: 40, y: 60)
        untouchedL2.state = .walking
        var workedL2 = untouchedL2
        workedL2.state = .building
        workedL2.state = .walking
        #expect(workedL2.hasSkillTargetPriority && !untouchedL2.hasSkillTargetPriority)
        #expect(workedL2 == untouchedL2)
        workedL2.x += 1
        #expect(workedL2 != untouchedL2)

        var untouchedL3 = Lemmings3Runtime.Lemming(id: 1, x: 40, y: 60)
        untouchedL3.state = .walking
        var workedL3 = untouchedL3
        workedL3.state = .building
        workedL3.state = .walking
        #expect(workedL3.hasSkillTargetPriority && !untouchedL3.hasSkillTargetPriority)
        #expect(workedL3 == untouchedL3)
        workedL3.x += 1
        #expect(workedL3 != untouchedL3)
    }

    private func classicWalker(id: Int = 1) -> ClassicDOSLemming {
        var lemming = ClassicDOSLemming(id: id, foot: .init(x: 40, y: 60))
        lemming.action = .walking
        return lemming
    }

    private func neoWalker() -> NeoLemmixLemming {
        .init(id: 1, position: .init(x: 40, y: 60), direction: .right, action: .walking)
    }

    private func removingHistory(_ data: Data) throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "skillTargetingHistory")
        return try JSONSerialization.data(withJSONObject: object)
    }
}
