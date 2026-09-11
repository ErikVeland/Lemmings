import Foundation

struct LevelHintCatalogue: Decodable {
    struct Move: Decodable, Equatable {
        let skill: String, lemmingID: Int, x: Int, y: Int, tick: Int
        let facingLeft: Bool
    }
    struct Rate: Decodable { let tick: Int, value: Int }
    struct Level: Decodable {
        let fingerprint: String, title: String, rank: String
        let number: Int, width: Int, height: Int
        let opening: [Move], skillOrder: [String], rates: [Rate]

        var deck: LevelHintDeck {
            let first = opening.first?.skill ?? ""
            let nudge = LevelHintDeck.nudges[first]
                ?? "Trace a path from the entrance to the exit. Check the landing places before changing the terrain."
            let openingSkills = opening.map { $0.skill.capitalized }.joined(separator: " → ")
            let later = skillOrder.filter { skill in !opening.contains { $0.skill == skill } }
            var approach = opening.isEmpty
                ? "This checked route does not need a skill assignment. Watch where the lemmings walk before intervening."
                : "One working route opens with:\n\(openingSkills)\n\n\(LevelHintDeck.jobs[first] ?? "Watch the worker's direction before assigning a skill.")"
            if !later.isEmpty { approach += "\n\nKeep \(later.map { $0.capitalized }.joined(separator: ", ")) available for later." }
            var instructions: [String] = []
            for (index, move) in opening.enumerated() {
                let worker: String
                if index > 0, opening[index - 1].lemmingID == move.lemmingID { worker = "the same worker" }
                else if move.lemmingID == 0 { worker = "the first lemming" }
                else if move.lemmingID == 1 { worker = "the second lemming" }
                else { worker = "lemming \(move.lemmingID + 1) in the release order" }
                instructions.append("\(index + 1). Give \(worker) \(move.skill.capitalized) at marker \(index + 1), facing \(move.facingLeft ? "left" : "right").")
            }
            // Only the last rate at a tick affects the next simulation step.
            var effectiveRates: [Rate] = []
            for rate in rates {
                if effectiveRates.last?.tick == rate.tick { effectiveRates.removeLast() }
                effectiveRates.append(rate)
            }
            var rateNotes: [String] = []
            var previousRate: Int?
            for (index, move) in opening.enumerated() {
                let earlierTick = index == 0 ? -1 : opening[index - 1].tick
                let values = effectiveRates.filter { $0.tick > earlierTick && $0.tick <= move.tick }
                    .compactMap { rate -> String? in
                        defer { previousRate = rate.value }
                        return previousRate == rate.value ? nil : String(rate.value)
                    }
                if !values.isEmpty {
                    rateNotes.append("Before move \(index + 1): \(values.joined(separator: " → ")).")
                }
            }
            let rateContext = rateNotes.isEmpty ? "" : "\n\nRelease rate in this example:\n"
                + rateNotes.joined(separator: "\n")
                + "\n\nThese changes affect crowd spacing. Their timing matters too. Pause to check the worker and direction at each marker."
            let openingText = instructions.isEmpty ? "Let the lemmings walk. Watch the route before using skills." : instructions.joined(separator: "\n")
            return LevelHintDeck(title: "\(rank) \(number) · \(title)", checked: true, stages: [
                .init(title: "A gentle nudge", body: nudge),
                .init(title: "The approach", body: approach),
                .init(title: "Opening moves", body: "Examples from the start of a winning route:\n\n" + openingText + rateContext,
                      moves: opening, width: width, height: height)
            ])
        }
    }
    let schemaVersion: Int, engineFingerprint: String, levels: [Level]

    func level(for fingerprint: String, engine: String) -> Level? {
        guard schemaVersion == 1, engineFingerprint == engine, !fingerprint.isEmpty else { return nil }
        let matches = levels.filter { $0.fingerprint == fingerprint }
        guard matches.count == 1, let level = matches.first, level.width > 0, level.height > 0,
              level.opening.count <= 3,
              level.opening.allSatisfy({ $0.x >= 0 && $0.x < level.width && $0.y >= 0 && $0.y < level.height
                  && LevelHintDeck.jobs[$0.skill] != nil }) else { return nil }
        return level
    }

    static func load(in bundle: Bundle = .main) -> (Self, String)? {
        guard let root = bundle.resourceURL,
              let bytes = try? Data(contentsOf: root.appendingPathComponent("Hints/classic.json")),
              let catalogue = try? JSONDecoder().decode(Self.self, from: bytes),
              let engine = try? String(contentsOf: root.appendingPathComponent("Trolley/engine-fingerprint.txt"), encoding: .utf8) else { return nil }
        return (catalogue, engine.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct LevelHintDeck {
    struct Stage {
        let title: String, body: String
        var moves: [LevelHintCatalogue.Move] = []
        var width = 0, height = 0
    }
    let title: String, checked: Bool, stages: [Stage]
    static let nudges = [
        "blocker": "Think about giving one worker room to prepare the route. The whole crowd does not need to move together.",
        "builder": "Look for the first gap or change in height. Work out where a staircase could reach firm ground.",
        "basher": "Look at the first wall in the route. Think about opening a passage at the height where the lemmings walk.",
        "miner": "Look for a diagonal route through the ground. Check where it would emerge and what lies below it.",
        "digger": "Look below the lemmings. Changing the floor can open a route or keep the crowd in one place.",
        "climber": "One lemming may need to take a route the crowd cannot follow yet. Check the vertical faces.",
        "floater": "Check the first long drop. A safe landing is the first part of the route.",
        "bomber": "A small opening can change the route. Check how much ground needs to be removed."
    ]
    static let jobs = [
        "blocker": "A Blocker turns other lemmings back. Leave room for the worker who will prepare the path.",
        "builder": "A Builder makes a short rising staircase. Check its landing point and leave room for the next staircase.",
        "basher": "A Basher cuts horizontally through ground. Choose the side and height of the passage carefully.",
        "miner": "A Miner cuts diagonally downwards. Check both the tunnel direction and its landing point.",
        "digger": "A Digger cuts straight down. Watch the ground below and decide where digging should stop.",
        "climber": "A Climber can scale vertical walls. Check where the worker will walk after reaching the top.",
        "floater": "A Floater survives long falls. Give the skill before the lemming hits the ground.",
        "bomber": "A Bomber removes nearby ground after a countdown. A moving lemming can travel during the countdown."
    ]

    static func practice(title: String, skills: [String], chronicles: Bool = false) -> Self {
        let available = skills.filter { jobs[$0.lowercased()] != nil }
        let tips = available.prefix(3).compactMap { jobs[$0.lowercased()] }.joined(separator: "\n\n")
        return Self(title: title, checked: false, stages: [
            .init(title: "A gentle nudge", body: "Pause and follow the route from the entrance to the exit. Find the first place a lemming cannot pass safely."),
            .init(title: "Make a small plan", body: chronicles
                ? "Inspect the tools on the level. Decide which worker needs each tool, then prepare one part of the route at a time."
                : "Match the first obstacle to an available skill. Check what happens after that skill finishes. Keep some supplies for the next obstacle."),
            .init(title: "Try one idea", body: (tips.isEmpty
                ? "Try one skill at normal speed, then pause and inspect the result. Watch where the worker lands and turns."
                : tips) + "\n\nChange one part of your plan at a time when you retry.")
        ])
    }
}
