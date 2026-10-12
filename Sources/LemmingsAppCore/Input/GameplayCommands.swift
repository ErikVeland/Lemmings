import Foundation

/// Platform adapters share commands while retaining their native event delivery.
public enum GameplayCommand: Equatable, Sendable {
    case pause, library, hints, help, settings, rewind, retry, endRun
    case step(Int), skill(Int), cycle(Int), focusUnassigned(Int), focusLast, assign, repeatAssignment
    case centre(Bool), rate(Int), speed, speedStep(Int), speedReset, zoom(Bool), pan(Int, Int)
}

public struct KeyChord: Hashable, Sendable {
    public let key: String
    public let shift: Bool
    public init(_ key: String, shift: Bool = false) { self.key = key.lowercased(); self.shift = shift }
}

public enum GameplayCommands {
    public static let bindings: [KeyChord: GameplayCommand] = {
        var result: [KeyChord: GameplayCommand] = [
            .init(" "): .pause, .init("p"): .pause,
            .init("escape"): .library, .init("q"): .library,
            .init("/"): .hints, .init("i"): .hints, .init("f1"): .hints,
            .init("?", shift: true): .help, .init("/", shift: true): .help,
            .init("h"): .centre(true), .init("home"): .centre(true),
            .init("g"): .centre(false), .init("end"): .centre(false),
            .init("f"): .speed, .init("n"): .endRun,
            .init("r"): .rewind, .init("r", shift: true): .retry,
            .init(","): .step(-1), .init("."): .step(1),
            .init("["): .focusUnassigned(-1), .init("]"): .focusUnassigned(1),
            .init("[", shift: true): .speedStep(-1), .init("]", shift: true): .speedStep(1),
            .init("|", shift: true): .speedReset,
            .init("\\"): .focusLast, .init("return"): .repeatAssignment,
            .init("tab"): .cycle(1), .init("tab", shift: true): .cycle(-1),
            .init("-"): .rate(-1), .init("="): .rate(1), .init("+", shift: true): .rate(1),
            .init("z"): .zoom(false), .init("z", shift: true): .zoom(true),
            .init("left"): .pan(-1, 0), .init("right"): .pan(1, 0),
            .init("up"): .pan(0, -1), .init("down"): .pan(0, 1),
        ]
        for index in 0..<8 { result[.init(String(index + 1))] = .skill(index) }
        return result
    }()
    public static func command(key: String, shift: Bool = false) -> GameplayCommand? {
        bindings[KeyChord(key, shift: shift)] ?? bindings[KeyChord(key)]
    }
    public static let help = [
        "Space / P: Pause", "1-8: Skill", "Tab: Next skill", "Shift+Tab: Previous skill",
        "F: Fast speed", "R: Rewind", ", / .: Step back / forward", "Shift+R: Retry",
        "H / Home: Entrance", "G / End: Goal", "Arrow keys: Pan", "Z / Shift+Z: Zoom",
        "[ / ]: Unassigned lemming", "Return: Repeat assignment", "N: End run / undo",
        "/ / I / F1: Hints", "?: Controls", "Escape / Q: Library",
    ]
}
