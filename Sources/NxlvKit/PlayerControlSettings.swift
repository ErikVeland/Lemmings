import Foundation

/// Personal input and accessibility choices overlay shared device settings.
public struct PlayerControlSettings: Codable, Equatable, Sendable {
    public var controllerEnabled: Bool
    public var controllerTapSpeed: Bool
    public var controllerSwapSticks: Bool
    public var controllerMappings: [String: String]
    public var interfaceSize: ClassicInterfaceSize
    public var reduceMotion: Bool
    public var staticHomeScreen: Bool
    public var reduceFlashes: Bool
    public var showSongInfo: Bool
    public var inspectWhilePaused: Bool
    public var fadeMenuButton: Bool

    public init(_ settings: ClassicSettings) {
        controllerEnabled = settings.controllerEnabled
        controllerTapSpeed = settings.controllerTapSpeed
        controllerSwapSticks = settings.controllerSwapSticks
        controllerMappings = ControllerBindings.validatedMapping(settings.controllerMappings)
        interfaceSize = settings.interfaceSize
        reduceMotion = settings.reduceMotion
        staticHomeScreen = settings.staticHomeScreen
        reduceFlashes = settings.reduceFlashes
        showSongInfo = settings.showSongInfo
        inspectWhilePaused = settings.inspectWhilePaused
        fadeMenuButton = settings.fadeMenuButton
    }

    private enum CodingKeys: String, CodingKey {
        case controllerEnabled, controllerTapSpeed, controllerSwapSticks, controllerMappings
        case inspectWhilePaused, interfaceSize, reduceMotion, staticHomeScreen, reduceFlashes, showSongInfo, fadeMenuButton
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        controllerEnabled = try values.decode(Bool.self, forKey: .controllerEnabled)
        controllerTapSpeed = try values.decode(Bool.self, forKey: .controllerTapSpeed)
        controllerSwapSticks = try values.decode(Bool.self, forKey: .controllerSwapSticks)
        controllerMappings = try values.decode([String: String].self, forKey: .controllerMappings)
        interfaceSize = try values.decode(ClassicInterfaceSize.self, forKey: .interfaceSize)
        reduceMotion = try values.decode(Bool.self, forKey: .reduceMotion)
        staticHomeScreen = try values.decodeIfPresent(Bool.self, forKey: .staticHomeScreen) ?? false
        reduceFlashes = try values.decode(Bool.self, forKey: .reduceFlashes)
        showSongInfo = try values.decode(Bool.self, forKey: .showSongInfo)
        inspectWhilePaused = try values.decodeIfPresent(Bool.self, forKey: .inspectWhilePaused) ?? true
        fadeMenuButton = try values.decode(Bool.self, forKey: .fadeMenuButton)
    }

    public func applying(to settings: ClassicSettings) -> ClassicSettings {
        var value = settings
        value.controllerEnabled = controllerEnabled
        value.controllerTapSpeed = controllerTapSpeed
        value.controllerSwapSticks = controllerSwapSticks
        value.controllerMappings = ControllerBindings.validatedMapping(controllerMappings)
        value.interfaceSize = interfaceSize
        value.reduceMotion = reduceMotion
        value.staticHomeScreen = staticHomeScreen
        value.reduceFlashes = reduceFlashes
        value.showSongInfo = showSongInfo
        value.inspectWhilePaused = inspectWhilePaused
        value.fadeMenuButton = fadeMenuButton
        return value
    }

    public static func defaultsKey(profileID: String) -> String {
        "PlayerControls.v1." + Data(profileID.utf8).base64EncodedString()
    }

    /// Retain the legacy baseline so an unvisited player cannot inherit another player's edits.
    public static func load(from defaults: UserDefaults, profileID: String, legacy: ClassicSettings) -> Self {
        if let data = defaults.data(forKey: defaultsKey(profileID: profileID)),
           let value = try? JSONDecoder().decode(Self.self, from: data) { return value }
        let value = Self(legacy)
        value.save(to: defaults, profileID: profileID)
        return value
    }

    public func save(to defaults: UserDefaults, profileID: String) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.defaultsKey(profileID: profileID)) }
    }
}
