import Foundation
import Testing
@testable import LemmingsAppCore
@testable import NxlvKit

struct TargetingHistoryRecoveryTests {
    @Test func neoTargetingHistoryDoesNotChangeGameplayIdentity() throws {
        let ordinary = NeoLemmixLemming(id: 1, position: .init(x: 40, y: 60),
            direction: .right, action: .walking, traits: [.climber])
        var worker = ordinary
        worker.action = .building
        worker.action = .shrugging
        worker.action = .walking
        #expect(worker.hasSkillTargetPriority && !ordinary.hasSkillTargetPriority)
        #expect(worker == ordinary)
        #expect(try RecoveryValueEncoding.data(worker) == RecoveryValueEncoding.data(ordinary))
        var moved = worker
        moved.position.x += 1
        #expect(moved != ordinary)
        #expect(try RecoveryValueEncoding.data(moved) != RecoveryValueEncoding.data(ordinary))
    }

    @Test func sequelTargetingHistoryDoesNotChangeGameplayIdentity() throws {
        var ordinary = Lemmings2Runtime.Lemming(id: 1, x: 40, y: 60)
        ordinary.state = .walking
        var worker = ordinary
        worker.state = .building
        worker.state = .shrugging
        worker.state = .walking
        #expect(worker.hasSkillTargetPriority && !ordinary.hasSkillTargetPriority)
        #expect(worker == ordinary)
        #expect(try RecoveryValueEncoding.data(worker) == RecoveryValueEncoding.data(ordinary))
        worker.x += 1
        #expect(worker != ordinary)
        #expect(try RecoveryValueEncoding.data(worker) != RecoveryValueEncoding.data(ordinary))
    }
}
