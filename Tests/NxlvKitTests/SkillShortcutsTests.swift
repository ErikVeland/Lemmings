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
        // Floater takes u for umbrella, because f is the fast-forward key, and
        // i is reserved for the level hints. Everything else falls out of that.
        #expect(bindings.letters == ["c", "u", "b", "l", "e", "a", "m", "d"])
        for index in 0..<8 {
            #expect(bindings.index(for: String(index + 1)) == index)
            #expect(bindings.index(for: bindings.letters[index]!.uppercased()) == index)
        }
        for key in ["f", "p", "r", "x", "z", "q", "n", "i", "9", "0", "12"] {
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

    @Test func reservedKeysNeverReachASkill() {
        // i opens the level hints. Without reserving it a skill takes i as a
        // fallback and its shortcut silently stops working.
        let classic = ["Climber", "Floater", "Bomber", "Blocker", "Builder", "Basher", "Miner", "Digger"]
        let bindings = SkillShortcuts(names: classic)
        for reserved in "zqnrpfxi" {
            #expect(!bindings.letters.contains(String(reserved)))
        }
        #expect(bindings.letters[1] == "u")
    }

    @Test func sharedInitialsCycleAndNumbersStayAbsolute() {
        let classic = ["Climber", "Floater", "Bomber", "Blocker", "Builder", "Basher", "Miner", "Digger"]
        let bindings = SkillShortcuts(names: classic)
        var current: Int?
        var visited: [String] = []
        for _ in 1...5 {
            current = bindings.index(for: "b", current: current)
            visited.append(current.map { classic[$0] } ?? "nil")
        }
        #expect(visited == ["Bomber", "Blocker", "Builder", "Basher", "Bomber"])
        // A unique initial does not cycle.
        #expect(bindings.index(for: "c", current: 0) == 0)
        // Numbers and letters both reach a skill. Numbers work in both modes.
        #expect(bindings.index(for: "7", current: nil) == 6)
        #expect(bindings.index(for: "m", current: nil) == 6)
        #expect(bindings.index(for: "7", current: nil, modern: false) == 6)
        #expect(bindings.index(for: "m", current: nil, modern: false) == nil)
    }
}
