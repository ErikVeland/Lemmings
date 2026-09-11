import Testing
@testable import NxlvKit

struct AssignmentFocusTests {
    @Test func cycleTracksSuccessfulAssignments() {
        var focus = AssignmentFocus()
        #expect(focus.next(activeIDs: [3, 1, 2], direction: 1) == 1)
        focus.record(id: 1, skill: 4, tick: 10)
        #expect(focus.next(activeIDs: [1, 2, 3], direction: 1) == 2)
        #expect(focus.next(activeIDs: [1, 2, 3], direction: -1) == 3)
        #expect(focus.lastSkill == 4)
        #expect(focus.lastID == 1)
        #expect(focus.next(activeIDs: [1], direction: 1) == nil)
        focus.rewind(to: 9)
        #expect(focus.lastSkill == nil)
        #expect(focus.next(activeIDs: [1, 2], direction: 1) == 1)
    }
}
