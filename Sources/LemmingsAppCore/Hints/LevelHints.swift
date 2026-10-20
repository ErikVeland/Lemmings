import Foundation
import NxlvKit

public struct LevelHintCatalogue: Decodable, Sendable {
    public struct Move: Decodable, Equatable, Sendable {
        public let skill: String, lemmingID: Int, x: Int, y: Int, tick: Int
        public let facingLeft: Bool
    }
    public struct Rate: Decodable, Sendable { public let tick: Int, value: Int }
    public struct Level: Decodable, Sendable {
        public let fingerprint: String, title: String, rank: String
        public let number: Int, width: Int, height: Int
        public let opening: [Move], skillOrder: [String], rates: [Rate]

        public var deck: LevelHintDeck {
            let first = opening.first?.skill ?? ""
            let reasoning = LevelHintDeck.obstacleReasoning[fingerprint]
            let nudge = reasoning?.nudge ?? LevelHintDeck.nudges[first]
                ?? L10n.text("Trace a path from the entrance to the exit. Check the landing places before changing the terrain.")
            let openingSkills = opening.map { SkillVocabulary.title($0.skill) }.joined(separator: " → ")
            let later = skillOrder.filter { skill in !opening.contains { $0.skill == skill } }
            var approach = opening.isEmpty
                ? L10n.text("This checked route does not need a skill assignment. Watch where the lemmings walk before intervening.")
                : L10n.text("One working route opens with:\n\(openingSkills)\n\n\(LevelHintDeck.jobs[first] ?? L10n.text("Watch the worker's direction before assigning a skill."))")
            if !later.isEmpty { approach += L10n.text("\n\nKeep \(later.map { SkillVocabulary.title($0) }.joined(separator: ", ")) available for later.") }
            if let reasoning { approach += "\n\n" + reasoning.approach }
            var instructions: [String] = []
            for (index, move) in opening.enumerated() {
                let worker: String
                if index > 0, opening[index - 1].lemmingID == move.lemmingID { worker = L10n.text("the same worker") }
                else if move.lemmingID == 0 { worker = L10n.text("the first lemming") }
                else if move.lemmingID == 1 { worker = L10n.text("the second lemming") }
                else { worker = L10n.text("lemming \(move.lemmingID + 1) in the release order") }
                instructions.append(L10n.text("\(index + 1). Give \(worker) \(SkillVocabulary.title(move.skill)) at marker \(index + 1), facing \(move.facingLeft ? L10n.text("left") : L10n.text("right"))."))
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
                    rateNotes.append(L10n.text("Before move \(index + 1): \(values.joined(separator: " → "))."))
                }
            }
            let rateContext = rateNotes.isEmpty ? "" : L10n.text("\n\nRelease rate in this example:\n")
                + rateNotes.joined(separator: "\n")
                + L10n.text("\n\nThese changes affect crowd spacing. Their timing matters too. Pause to check the worker and direction at each marker.")
            let openingText = instructions.isEmpty ? L10n.text("Let the lemmings walk. Watch the route before using skills.") : instructions.joined(separator: "\n")
            return LevelHintDeck(title: "\(rank) \(number) · \(title)", checked: true, stages: [
                .init(title: L10n.text("A gentle nudge"), body: nudge),
                .init(title: L10n.text("The approach"), body: approach),
                .init(title: L10n.text("Opening moves"), body: L10n.text("Examples from the start of a winning route:\n\n\(openingText)\(rateContext)"),
                      moves: opening, width: width, height: height)
            ])
        }
    }
    public let schemaVersion: Int, engineFingerprint: String, levels: [Level]

    public func level(for fingerprint: String, engine: String) -> Level? {
        guard schemaVersion == 1, engineFingerprint == engine, !fingerprint.isEmpty else { return nil }
        let matches = levels.filter { $0.fingerprint == fingerprint }
        guard matches.count == 1, let level = matches.first, level.width > 0, level.height > 0,
              level.opening.count <= 3,
              level.opening.allSatisfy({ $0.x >= 0 && $0.x < level.width && $0.y >= 0 && $0.y < level.height
                  && LevelHintDeck.jobs[$0.skill] != nil }) else { return nil }
        return level
    }

    public static func load(storage: AppStorage = .current()) -> (Self, String)? {
        let root = storage.resources
        guard let bytes = try? Data(contentsOf: root.appendingPathComponent("Hints/classic.json")),
              let catalogue = try? JSONDecoder().decode(Self.self, from: bytes),
              let engine = try? String(contentsOf: root.appendingPathComponent("Trolley/engine-fingerprint.txt"), encoding: .utf8) else { return nil }
        return (catalogue, engine.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public struct LevelHintDeck: Sendable {
    /// Presentation names the evidence before showing any advice, on every platform.
    public struct Presentation: Sendable {
        public let title: String, progress: String, section: String, body: String
        public var accessibilityText: String { [title, progress, section, body].joined(separator: ". ") }
    }
    public struct Stage: Sendable {
        public let title: String, body: String
        public var moves: [LevelHintCatalogue.Move] = []
        public var width = 0, height = 0
        public init(title: String, body: String, moves: [LevelHintCatalogue.Move] = [], width: Int = 0, height: Int = 0) {
            self.title = title; self.body = body; self.moves = moves; self.width = width; self.height = height
        }
    }
    public let title: String, checked: Bool, stages: [Stage]
    public init(title: String, checked: Bool, stages: [Stage]) {
        self.title = title; self.checked = checked; self.stages = stages
    }
    public var evidenceTitle: String {
        checked ? L10n.text("Checked example route") : L10n.text("General coaching")
    }
    public func presentation(at index: Int) -> Presentation {
        let stage = stages[index]
        return .init(title: evidenceTitle,
            progress: checked ? L10n.text("HINT \(index + 1) OF \(stages.count)") : L10n.text("COACHING \(index + 1) OF \(stages.count)"),
            section: stage.title,
            body: checked ? stage.body : L10n.text("No level-specific hints available.") + "\n\n" + stage.body)
    }

    fileprivate struct ObstacleReasoning: Sendable {
        let nudge: String, approach: String
    }
    // These notes apply only to the exact original Fun 1 and Fun 2 identities.
    // The catalogue's engine check runs before a level can offer a checked deck.
    fileprivate static var obstacleReasoning: [String: ObstacleReasoning] { [
        "b603237c23a1b4149e60349ae55c487f41b4d7b956d3fe35c64962ff186f4d15": .init(
            nudge: L10n.text("The exit is below the platform carrying the crowd. Look for a place to open the floor above the lower path."),
            approach: L10n.text("A hole joins the upper platform to the lower path. Other lemmings can follow without needing their own skill.")),
        "35373ea4a608102e97666e1d53ddc9f84b8058708b04fe5afde61856fef3b9bd": .init(
            nudge: L10n.text("The danger is the fall after the entrance. Think about protecting the lemmings before they land."),
            approach: L10n.text("Floaters protect individual lemmings. Giving this skill to one worker does not protect the next arrival."))
    ] }
    public static var nudges: [String: String] { [
        "blocker": L10n.text("Think about giving one worker room to prepare the route. The whole crowd does not need to move together."),
        "builder": L10n.text("Look for the first gap or change in height. Work out where a staircase could reach firm ground."),
        "basher": L10n.text("Look at the first wall in the route. Think about opening a passage at the height where the lemmings walk."),
        "miner": L10n.text("Look for a diagonal route through the ground. Check where it would emerge and what lies below it."),
        "digger": L10n.text("Look below the lemmings. Changing the floor can open a route or keep the crowd in one place."),
        "climber": L10n.text("One lemming may need to take a route the crowd cannot follow yet. Check the vertical faces."),
        "floater": L10n.text("Check the first long drop. A safe landing is the first part of the route."),
        "bomber": L10n.text("A small opening can change the route. Check how much ground needs to be removed.")
    ] }
    public static var jobs: [String: String] { [
        "blocker": L10n.text("A Blocker turns other lemmings back. Leave room for the worker who will prepare the path."),
        "builder": L10n.text("A Builder makes a short rising staircase. Check its landing point and leave room for the next staircase."),
        "basher": L10n.text("A Basher cuts horizontally through ground. Choose the side and height of the passage carefully."),
        "miner": L10n.text("A Miner cuts diagonally downwards. Check both the tunnel direction and its landing point."),
        "digger": L10n.text("A Digger cuts straight down. Watch the ground below and decide where digging should stop."),
        "climber": L10n.text("A Climber can scale vertical walls. Check where the worker will walk after reaching the top."),
        "floater": L10n.text("A Floater survives long falls. Give the skill before the lemming hits the ground."),
        "bomber": L10n.text("A Bomber removes nearby ground after a countdown. A moving lemming can travel during the countdown.")
    ] }

    public static func practice(title: String, skills: [String], chronicles: Bool = false) -> Self {
        let available = skills.filter { jobs[$0.lowercased()] != nil }
        let tips = available.prefix(3).compactMap { jobs[$0.lowercased()] }.joined(separator: "\n\n")
        let advice = tips.isEmpty ? L10n.text("Try one skill at normal speed, then pause and inspect the result. Watch where the worker lands and turns.") : tips
        return Self(title: title, checked: false, stages: [
            .init(title: L10n.text("Observe"), body: L10n.text("Pause and follow the route from the entrance to the exit. Find the first place a lemming cannot pass safely.")),
            .init(title: L10n.text("Plan"), body: chronicles
                ? L10n.text("Inspect the tools on the level. Decide which worker needs each tool, then prepare one part of the route at a time.")
                : L10n.text("Match the first obstacle to an available skill. Check what happens after that skill finishes. Keep some supplies for the next obstacle.")),
            .init(title: L10n.text("Practise"), body: L10n.text("\(advice)\n\nChange one part of your plan at a time when you retry."))
        ])
    }
}
