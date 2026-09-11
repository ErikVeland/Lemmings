import Foundation
import NxlvKit

let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let root = project.appendingPathComponent("Sources/Ports/LEM3CD")
let fixtures = URL(fileURLWithPath: ProcessInfo.processInfo.environment["L3_COMPLETION_FIXTURES"] ?? "Tests/Lemmings3CompletionTests/Fixtures")
let discover = CommandLine.arguments.contains("discover")
let selected = CommandLine.arguments.compactMap(Int.init).first
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try FileManager.default.createDirectory(at: fixtures, withIntermediateDirectories: true)
var wins = 0, unknown: [Int] = []
for tribe in Lemmings3ClassicCampaign.Tribe.allCases {
    let campaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
    let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
    for (index, level) in campaign.levels.enumerated() {
        let number = tribe.firstLevel + index
        if let selected, number != selected { continue }
        let perm = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
        let temp = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
        let base = try Lemmings3Runtime(level: level, style: style, permanent: perm, temporary: temp, total: 20)
        let file = fixtures.appendingPathComponent(String(format: "%03d.json", number))
        var best: L3Replay?
        if FileManager.default.fileExists(atPath: file.path) {
            best = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: file))
        }
        if let best {
            guard best.level == number else { throw SequelDataError.invalid("Replay level number does not match its fixture") }
            _ = try best.replay(from: base, levelData: level.rawData)
        }
        if discover {
            for policy in -1...7 where best == nil || best!.expected.lost > 0 {
                var game = base, inputs: [L3Replay.Input] = []
                func action(_ name: String, _ id: Int, _ direction: String? = nil) {
                    let input = L3Replay.Input(tick: game.tick, action: name, lemming: id, direction: direction)
                    if L3Replay.apply(input, to: &game) { inputs.append(input) }
                }
                while !game.isComplete && game.tick < 10_000 {
                    for lem in game.lemmings where lem.active && policy >= 0 {
                        if policy == 0 {
                            if number == 1 && lem.state == .walking && lem.y >= 144 && lem.x > 104 {
                                if lem.direction == 1 { action("walker", lem.id) }
                                if lem.y > 144 { action("jumper", lem.id) }
                            }
                            if number == 2 && lem.tool == .spade && lem.state == .walking {
                                if lem.y == 88 { action("use", lem.id, "down") }
                                else if lem.y == 120 && lem.direction > 0 && game.isSolid(lem.x + 1, lem.y - 8) { action("use", lem.id, "right") }
                            }
                            if number == 3 && lem.state == .walking && lem.tool == .spade && (52...60).contains(lem.x) && lem.y < 136 { action("use", lem.id, "down") }
                            if number == 201 && lem.state == .walking && lem.tool == .spade && lem.x >= 240 && lem.y <= 80 { action("use", lem.id, "down") }
                            if number == 101 {
                                if lem.state == .walking {
                                    let fetch = lem.tool == nil && lem.y == 140 && (272..<300).contains(lem.x) && game.pickups.contains { $0.quantity > 0 }
                                    if (fetch && lem.direction > 0) || (!fetch && lem.direction < 0) { action("walker", lem.id) }
                                    if lem.tool == .bricks && lem.x >= 272 && lem.y > 96 { action("use", lem.id, "upRight") }
                                    else if game.isSolid(lem.x + 12, lem.y - 1) || (lem.y < 140 && !game.isSolid(lem.x + 4, lem.y)) { action("jumper", lem.id) }
                                }
                                if lem.state == .building && lem.y <= 92 { action("walker", lem.id) }
                            }
                        } else if lem.state == .walking {
                            let exit = game.configuration.exits.min { abs($0.x - lem.x) + abs($0.y - lem.y) < abs($1.x - lem.x) + abs($1.y - lem.y) }!
                            let heading = exit.x < lem.x ? -1 : 1
                            if policy % 2 == 0 && abs(exit.x - lem.x) > 12 && lem.direction != heading { action("walker", lem.id) }
                            let dx = policy % 2 == 0 ? heading : lem.direction
                            let wall = game.isSolid(lem.x + dx * 4, lem.y - 8)
                            let gap = !game.isSolid(lem.x + dx * 6, lem.y)
                            if policy >= 3 && lem.tool == .spade && (wall || exit.y > lem.y + 24) {
                                action("use", lem.id, exit.y > lem.y + 24 ? "down" : dx > 0 ? "right" : "left")
                            } else if policy >= 3 && lem.tool == .bricks && (gap || wall) {
                                action("use", lem.id, dx > 0 ? "upRight" : "upLeft")
                            } else if wall || (gap && policy < 5) || (policy >= 5 && game.tick % 16 == 0) { action("jumper", lem.id) }
                        }
                    }
                    game.step()
                    if game.saved > 0 && game.tick >= 8000 && !game.isComplete {
                        let input = L3Replay.Input(tick: game.tick, action: "abort", lemming: nil, direction: nil)
                        if L3Replay.apply(input, to: &game) { inputs.append(input) }
                    }
                }
                guard game.isComplete && game.saved > 0 else { continue }
                if let best {
                    let retained = best.expected.saved + best.expected.reserves
                    if game.survivors < retained || (game.survivors == retained && game.saved <= best.expected.saved) { continue }
                }
                let replay = L3Replay(level: number, levelSHA256: L3Replay.digest(level.rawData), population: 20,
                    initialStateHash: L3Replay.stateHash(base), inputs: inputs, expected: .init(game))
                _ = try replay.replay(from: base, levelData: level.rawData)
                _ = try replay.replay(from: base, levelData: level.rawData)
                try encoder.encode(replay).write(to: file, options: .atomic); best = replay
                print("FOUND", number, "saved", game.saved, "lost", game.lost, "reserve", game.reserve, "policy", policy); fflush(stdout)
            }
        }
        if let best {
            _ = try best.replay(from: base, levelData: level.rawData)
            _ = try best.replay(from: base, levelData: level.rawData)
            wins += 1
            print("PASS", number, "saved", best.expected.saved, "lost", best.expected.lost, "reserve", best.expected.reserves)
        } else { unknown.append(number) }
        fflush(stdout)
    }
}
print("Verified \(wins) distinct L3 levels. No fixture for \(unknown.count): \(unknown)")
if !discover && (wins == 0 || ((selected != nil || CommandLine.arguments.contains("--require-all")) && !unknown.isEmpty)) { exit(1) }
