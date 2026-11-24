import Foundation

public enum GameplayControlTip: Int, CaseIterable {
    case assignment, speed, rewind, map

    public enum Input { case mouse, touch, remote }

    public func text(for input: Input) -> String {
        switch (self, input) {
        case (.assignment, .mouse): L10n.text("Click a lemming to assign the selected skill.")
        case (.assignment, .touch): L10n.text("Tap a lemming to assign the selected skill.")
        case (.assignment, .remote): L10n.text("Aim at a lemming and press Select to assign.")
        case (.speed, .mouse): L10n.text("Press F to return to 1×.")
        case (.speed, .touch): L10n.text("Tap Speed again to return to 1×.")
        case (.speed, .remote): L10n.text("Choose 1× in Game controls to reset speed.")
        case (.rewind, _): L10n.text("Press Rewind again to go further back.")
        case (.map, .remote): L10n.text("Select a point on the map to move the view.")
        case (.map, _): L10n.text("Drag the map to move the view.")
        }
    }
}

public struct GameplayControlTips {
    private let defaults: UserDefaults
    private let key: String

    public init(profileID: String, defaults: UserDefaults, previouslyPlayed: @autoclosure () -> Bool) {
        self.defaults = defaults
        key = "GameplayControlTips.v1." + profileID
        if defaults.object(forKey: key) == nil { defaults.set(!previouslyPlayed(), forKey: key) }
    }

    public var enabled: Bool {
        get { defaults.bool(forKey: key) }
        nonmutating set { defaults.set(newValue, forKey: key) }
    }

    public func needs(_ tip: GameplayControlTip) -> Bool {
        enabled && defaults.integer(forKey: key + ".seen") & (1 << tip.rawValue) == 0
    }

    public func didShow(_ tip: GameplayControlTip) {
        let seen = key + ".seen"
        defaults.set(defaults.integer(forKey: seen) | (1 << tip.rawValue), forKey: seen)
    }

    public var toggleTitle: String {
        enabled ? L10n.text("Hide control tips") : L10n.text("Show control tips")
    }
}
