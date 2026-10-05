import Foundation

/// Routes NeoLemmix events through the selected Classic sound bank.
public enum NeoLemmixSoundCue {
    public static func positionedCues(
        for events: [NeoLemmixEvent],
        lemmings: [NeoLemmixLemming],
        entrances: [NeoLemmixEntrance]
    ) -> [PositionedSoundCue] {
        let positions = Dictionary(uniqueKeysWithValues: lemmings.map {
            ($0.id, GameplaySoundPoint(x: Double($0.position.x), y: Double($0.position.y)))
        })
        return events.flatMap { event -> [PositionedSoundCue] in
            var effects: [ClassicSoundEffect] = []
            var id: Int?
            switch event {
            case .entrancesOpened:
                return entrances.flatMap { entrance in
                    [.doorOpen, .letsGo].map { effect in
                        PositionedSoundCue(effect, at: .init(
                            x: Double(entrance.position.x), y: Double(entrance.position.y)))
                    }
                }
            case let .assignment(.assigned(lemmingID, _)):
                id = lemmingID; effects = [.assignSkill]
            case .nukeStarted:
                effects = [.nuke]
            case let .actionChanged(lemmingID, _, action):
                id = lemmingID
                switch action {
                case .ohNo: effects = [.ohNo]
                case .exploding: effects = [.explode]
                case .splatting: effects = [.splat]
                case .drowning: effects = [.drown]
                case .vaporizing: effects = [.vaporize]
                default: break
                }
            case let .removed(lemmingID, reason):
                id = lemmingID
                switch reason {
                case .saved: effects = [.exitLevel, .yippee]
                case .fellOut: effects = [.fallOut]
                case .trapped: effects = [.vaporize]
                default: break // Death animations already emitted their sound.
                }
            default: break
            }
            return effects.map { PositionedSoundCue($0, at: id.flatMap { positions[$0] }) }
        }
    }
}
