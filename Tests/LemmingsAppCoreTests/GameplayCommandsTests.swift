import Testing
@testable import LemmingsAppCore

struct GameplayCommandsTests {
    @Test func testSharedPauseHintsAndReadyKeys() {
        #expect(GameplayCommands.command(key: " ") == .pause)
        #expect(GameplayCommands.command(key: "P") == .pause)
        #expect(GameplayCommands.command(key: "/") == .hints)
        #expect(GameplayCommands.command(key: "/", shift: true) == .help)
        #expect(GameplayCommands.command(key: "return") == .repeatAssignment)
        #expect(GameplayCommands.command(key: "q") == .library)
        #expect(GameplayCommands.command(key: "j") == .djShuffle)
        #expect(GameplayCommands.command(key: "j", command: true) == nil)
    }
    @Test func testSkillAndShiftBindingsRemainDistinct() {
        for index in 0..<8 { #expect(GameplayCommands.command(key: String(index + 1)) == .skill(index)) }
        #expect(GameplayCommands.command(key: "r") == .rewind)
        #expect(GameplayCommands.command(key: "r", shift: true) == .retry)
        #expect(GameplayCommands.command(key: "[") == .focusUnassigned(-1))
        #expect(GameplayCommands.command(key: "[", shift: true) == .speedStep(-1))
        #expect(GameplayCommands.command(key: "unknown") == nil)
    }
    @Test func testCommandRewindKeepsZoomAndSystemShortcutsDistinct() {
        #expect(GameplayCommands.command(key: "z", command: true) == .step(-1))
        #expect(GameplayCommands.command(key: "z") == .zoom(false))
        #expect(GameplayCommands.command(key: "z", shift: true) == .zoom(true))
        #expect(GameplayCommands.command(key: "z", shift: true, command: true) == nil)
        for key in ["q", "f", "r", "1"] {
            #expect(GameplayCommands.command(key: key, command: true) == nil)
        }
    }
}
