import Foundation
import NxlvKit

/// Platform adapters share commands while retaining their native event delivery.
public enum GameplayCommand: Equatable, Sendable {
    case pause, library, hints, help, settings, rewind, retry, endRun, djShuffle
    case step(Int), skill(Int), cycle(Int), focusUnassigned(Int), focusLast, assign, repeatAssignment
    case centre(Bool), rate(Int), speed, speedStep(Int), speedReset, zoom(Bool), pan(Int, Int)
}

public struct KeyChord: Hashable, Sendable {
    public let key: String
    public let shift: Bool
    public let command: Bool
    public init(_ key: String, shift: Bool = false, command: Bool = false) {
        self.key = key.lowercased(); self.shift = shift; self.command = command
    }
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
            .init("j"): .djShuffle,
            .init("r"): .rewind, .init("r", shift: true): .retry,
            .init(","): .step(-1), .init("."): .step(1),
            .init("z", command: true): .step(-1),
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
    public static func command(key: String, shift: Bool = false, command: Bool = false) -> GameplayCommand? {
        let exact = bindings[KeyChord(key, shift: shift, command: command)]
        if command { return exact }
        return exact ?? bindings[KeyChord(key)]
    }
    public static let help = [
        L10n.text("Space / P: Pause"), "1-8: Skill", L10n.text("Tab: Next skill"), L10n.text("Shift+Tab: Previous skill"),
        L10n.text("F: Fast speed"), L10n.text("R: Rewind"), L10n.text(", / .: Step back / forward"), L10n.text("Shift+R: Retry"),
        L10n.text("Command+Z: Step back"),
        L10n.text("J: DJ shuffle"),
        L10n.text("H / Home: Entrance"), L10n.text("G / End: Goal"), L10n.text("Arrow keys: Pan"), L10n.text("Z / Shift+Z: Zoom"),
        L10n.text("[ / ]: Unassigned lemming"), L10n.text("Return: Repeat assignment"), L10n.text("N: End run / undo"),
        "/ / I / F1: Hints", L10n.text("?: Controls"), L10n.text("Escape / Q: Library"),
    ]
}
