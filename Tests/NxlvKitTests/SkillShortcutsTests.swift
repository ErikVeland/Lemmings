import Testing
@testable import NxlvKit

struct SkillShortcutsTests {
    @Test func cycleSkipsEmptySkillsAndWraps() {
        #expect(SkillShortcuts.cycle(from: 0, direction: 1, available: [true, false, true]) == 2)
        #expect(SkillShortcuts.cycle(from: 0, direction: -1, available: [true, false, true]) == 2)
        #expect(SkillShortcuts.cycle(from: 2, direction: 1, available: [true, false, true]) == 0)
        #expect(SkillShortcuts.cycle(from: 0, direction: 1, available: [false, false]) == nil)
        #expect(SkillShortcuts.cycle(from: 0, direction: 1, available: []) == nil)
    }

    @Test func classicBindings() {
        let bindings = SkillShortcuts(names: ["Climber", "Floater", "Bomber", "Blocker", "Builder", "Basher", "Miner", "Digger"])
        #expect(bindings.letters == ["c", "l", "b", "o", "u", "a", "m", "d"])
        for index in 0..<8 {
            #expect(bindings.index(for: String(index + 1)) == index)
            #expect(bindings.index(for: bindings.letters[index]!.uppercased()) == index)
        }
        for key in ["f", "p", "r", "x", "z", "q", "n", "9", "0", "12"] {
            #expect(bindings.index(for: key) == nil)
        }
    }

    @Test func initialsBeforeFallbacksAndLevelChanges() {
        let bindings = SkillShortcuts(names: ["Builder", "Bomber", "Laserer"])
        #expect(bindings.letters == ["b", "o", "l"])
        #expect(SkillShortcuts(names: ["Bomber"]).index(for: "b") == 0)
        #expect(SkillShortcuts(names: ["Walker", "Blocker", "Jumper", "Use tool", "Drop tool"]).letters == ["w", "b", "j", "u", "d"])
        #expect(SkillShortcuts(names: Array(repeating: "Skill", count: 10)).index(for: "0") == 9)
    }
}
