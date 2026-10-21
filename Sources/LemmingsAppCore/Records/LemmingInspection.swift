import Foundation
import CryptoKit
import NxlvKit

/// Optional character details derived from a frozen level state and its applied inputs.
/// This model never steps an engine or writes to the attempt's history.
public struct LemmingInspection: Sendable {
    public static let catalogueVersion = LemmingAssessmentCatalogue.version
    public struct Action: Equatable, Sendable {
        public let tick: Int
        public let title: String
        public let seconds: Int
        public let ticksSinceUse: Int
        public var text: String {
            ticksSinceUse == 1 ? L10n.text("\(title): 1 tick ago") : L10n.text("\(title): \(ticksSinceUse) ticks ago")
        }
    }
    public struct Individual: Identifiable, Equatable, Sendable {
        public let id: Int
        public let name: String
        public let preference: String
        public let want: String
        public let status: String
        public let actions: [Action]
        public var title: String { name + " #" + String(id + 1) }
    }
    public let individuals: [Individual]
    public let tick: Int
    public static let actionsPerPage = 5

    public init(initial: ActionReplayState, current: ActionReplayState,
                commands: [LeaderboardActionReplay.Command]) throws {
        tick = current.tick
        // Preserve the original identity seed so the new assessments do not rename
        // lemmings. Saved runs reconstruct this same initial state on every host.
        let scope = initial.engine + ":" + (try initial.hash()) + ":1"
        let seed = SHA256.hash(data: Data(scope.utf8)).prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        let actors: [(Int, String)]
        switch current {
        case .classic(let game):
            actors = game.lemmings.map {
                ($0.id, $0.outcome == .saved ? L10n.text("Reached the exit")
                    : $0.outcome == .lost ? L10n.text("Lost") : Self.activity($0.action.rawValue))
            }
        case .lemmings2(let game):
            actors = game.lemmings.map { ($0.id, Self.status($0.state.rawValue)) }
        case .lemmings3(let game):
            actors = game.lemmings.map { ($0.id, Self.status($0.state.rawValue)) }
        case .neolemmix:
            // Preplaced actors and clones need a separate identity contract.
            actors = []
        }
        var actions: [Int: [Action]] = [:]
        for command in commands where command.tick >= 0 && command.tick <= current.tick {
            guard let id = command.lemming, let title = Self.actionTitle(command, initial: initial) else { continue }
            actions[id, default: []].append(.init(tick: command.tick, title: title,
                seconds: Int(Double(command.tick) / current.ticksPerSecond), ticksSinceUse: current.tick - command.tick))
        }
        individuals = actors.filter { $0.0 >= 0 }.sorted { $0.0 < $1.0 }.map { id, status in
            let index = (Int(seed % UInt64(Self.names.count)) + id % Self.names.count) % Self.names.count
            let character = LemmingAssessmentCatalogue.story(at:
                LemmingAssessmentCatalogue.index(seed: seed, actorID: id))
            return Individual(id: id, name: Self.names[index], preference: character.0,
                want: character.1, status: status, actions: actions[id] ?? [])
        }
    }

    /// Presentation pages keep both the bitmap layout and the amount of text bounded.
    public func lines(for index: Int, historyPage: Int = 0) -> [String] {
        guard individuals.indices.contains(index) else { return [L10n.text("No lemmings released yet")] }
        let individual = individuals[index]
        let page = min(max(0, historyPage), Self.lastHistoryPage(for: individual))
        let start = page * Self.actionsPerPage
        let history = individual.actions.dropFirst(start).prefix(Self.actionsPerPage).map(\.text)
        return [individual.preference, individual.want, individual.status, L10n.text("Recorded actions")]
            + (history.isEmpty ? [L10n.text("No recorded assignments")] : Array(history))
    }

    public static func lastHistoryPage(for individual: Individual) -> Int {
        max(0, (individual.actions.count - 1) / actionsPerPage)
    }

    private static func status(_ raw: String) -> String {
        raw == "saved" ? L10n.text("Reached the exit") : raw == "dead" ? L10n.text("Lost") : activity(raw)
    }
    private static func activity(_ raw: String) -> String {
        let words = raw.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        return L10n.text(InterfaceMessage(stringLiteral: words.prefix(1).uppercased() + words.dropFirst()))
    }
    private static func actionTitle(_ command: LeaderboardActionReplay.Command, initial: ActionReplayState) -> String? {
        if command.action == "assign", let slot = command.skill {
            let name: String
            switch initial {
            case .classic:
                guard ClassicSkill.allCases.indices.contains(slot) else { return nil }
                name = ClassicSkill.allCases[slot].rawValue
            case .lemmings2(let game):
                guard game.configuration.skills.indices.contains(slot) else { return nil }
                name = game.configuration.skills[slot].name
            default: return nil
            }
            // Permanent assignments mark a new ability, even while the actor
            // is walking. Do not imply that a climb or landing has succeeded.
            switch name.lowercased() {
            case "climber": return L10n.text("Became a Climber")
            case "rock climber": return L10n.text("Became a Rock Climber")
            case "floater": return L10n.text("Became a Floater")
            case "parachuter": return L10n.text("Became a Parachuter")
            default: return SkillVocabulary.title(name)
            }
        }
        guard case .lemmings3 = initial else { return nil }
        // Only recorded equipment can identify a historical tool use.
        switch command.action {
        case "walker": return L10n.text("Walker")
        case "blocker": return L10n.text("Blocker")
        case "jumper": return L10n.text("Jumper")
        case "use":
            if let raw = command.skill, let tool = Lemmings3Runtime.Tool(rawValue: raw) {
                return SkillVocabulary.title(String(describing: tool))
            }
            return L10n.text("Used a tool")
        case "drop": return L10n.text("Dropped a tool")
        default: return nil
        }
    }

    private static let names = ["Pip", "Moss", "Nell", "Fern", "Bram", "Dot", "Kit", "Wren",
        "Ash", "Clover", "Flint", "Hazel", "Reed", "Robin", "Rowan", "Tansy",
        "Aster", "Brook", "Cedar", "Dale", "Elm", "Finch", "Glen", "Holly",
        "Ivy", "Juniper", "Lark", "Maple", "Oak", "Pebble", "Rue", "Willow",
        "Alder", "Anise", "Basil", "Bee", "Birch", "Briar", "Bud", "Burr",
        "Clay", "Clove", "Cob", "Copper", "Dew", "Dill", "Dune", "Echo",
        "Elder", "Fawn", "Fig", "Fir", "Fox", "Gale", "Goldie", "Gorse",
        "Heath", "Heron", "Indigo", "Ink", "Jade", "Jasper", "Jay", "Jem",
        "Jess", "Kelp", "Lilac", "Linden", "Linnet", "Loom", "Lupin", "Mallow",
        "Marsh", "Mica", "Mint", "Myrtle", "Nutmeg", "Olive", "Opal", "Peach",
        "Pearl", "Pollen", "Poppy", "Quill", "Rain", "Rook", "Rose", "Russet",
        "Sage", "Sedge", "Sorrel", "Sprig", "Sunny", "Teal", "Thistle", "Thyme"]
}
