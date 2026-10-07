import Foundation

/// Routes NeoLemmix events through the selected Classic sound bank.
public enum NeoLemmixSoundCue {
    /// Keep object sound names outside simulation and recovery identity.
    public static func gadgetSounds(for gadgets: [NxlvRenderedGadget],
                                    resolution: NxlvStyleResolution) -> [Int: String] {
        var names: [Int: String] = [:]
        for (id, gadget) in gadgets.enumerated() {
            if let asset = resolution.assets.first(where: {
                $0.reference.kind == .object
                    && $0.reference.style.caseInsensitiveCompare(gadget.style) == .orderedSame
                    && $0.reference.piece?.caseInsensitiveCompare(gadget.piece) == .orderedSame
            }), let name = asset.objectMetadata?.sound, !name.isEmpty {
                names[id] = name
            }
        }
        return names
    }

    public static func positionedCues(
        for events: [NeoLemmixEvent],
        lemmings: [NeoLemmixLemming],
        entrances: [NeoLemmixEntrance],
        zones: [NeoLemmixZone] = [],
        gadgetSounds: [Int: String] = [:]
    ) -> [PositionedSoundCue] {
        let positions = Dictionary(uniqueKeysWithValues: lemmings.map {
            ($0.id, GameplaySoundPoint(x: Double($0.position.x), y: Double($0.position.y)))
        })
        let disarmed = Set(events.compactMap { event -> Int? in
            if case let .zoneDisarmed(_, zoneID) = event { return zoneID }
            return nil
        })
        let customTrapIDs = Set(events.compactMap { event -> Int? in
            if case let .hazardTriggered(id, zoneID, effect) = event,
               [.trap, .oneShotTrap].contains(effect), !disarmed.contains(zoneID),
               let zone = zones.first(where: { $0.id == zoneID }),
               gadgetSounds[zone.visualGadgetID ?? zone.id] != nil { return id }
            return nil
        })
        func gadgetCue(_ id: Int, _ zoneID: Int, fallback: Bool) -> [PositionedSoundCue] {
            guard let zone = zones.first(where: { $0.id == zoneID }),
                  let name = gadgetSounds[zone.visualGadgetID ?? zone.id] else { return [] }
            return [PositionedSoundCue(.vaporize, at: positions[id], sampleName: name,
                                       allowsFallback: fallback)]
        }
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
            case let .builderWarning(lemmingID):
                id = lemmingID; effects = [.builderWarning]
            case let .hitSteel(lemmingID):
                id = lemmingID; effects = [.hitSteel]
            case let .hazardTriggered(lemmingID, zoneID, effect):
                guard !disarmed.contains(zoneID) else { return [] }
                if [.trap, .oneShotTrap, .teleporter, .animation, .animationOnce].contains(effect) {
                    return gadgetCue(lemmingID, zoneID, fallback: [.trap, .oneShotTrap].contains(effect))
                }
            case let .buttonPressed(lemmingID, zoneID):
                return gadgetCue(lemmingID, zoneID, fallback: false)
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
                case .trapped: effects = customTrapIDs.contains(lemmingID) ? [] : [.vaporize]
                default: break // Death animations already emitted their sound.
                }
            default: break
            }
            return effects.map { PositionedSoundCue($0, at: id.flatMap { positions[$0] }) }
        }
    }
}
