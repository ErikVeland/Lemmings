import Foundation
import NxlvKit

/// The iPad preferences wrap the shared Classic settings without changing their format.
public struct MobileSettings: Codable, Equatable, Sendable {
    public var classic: ClassicSettings
    public var pauseToAssign: Bool
    public var fastSpeed: Int
    public var musicEnabled: Bool
    public var soundtrack: String
    public static let defaultsKey = "mobile.settings.v1"
    public static let fastSpeeds = [2, 3, 5, 10]

    public init(classic: ClassicSettings = ClassicSettings(), pauseToAssign: Bool = true,
                fastSpeed: Int = 2, musicEnabled: Bool = true, soundtrack: String = "Original") {
        self.classic = classic
        self.pauseToAssign = pauseToAssign
        self.fastSpeed = Self.fastSpeeds.contains(fastSpeed) ? fastSpeed : 2
        self.musicEnabled = musicEnabled
        self.soundtrack = soundtrack
    }

    private enum CodingKeys: String, CodingKey { case classic, pauseToAssign, fastSpeed, musicEnabled, soundtrack }
    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        self.init(classic: try fields.decodeIfPresent(ClassicSettings.self, forKey: .classic) ?? ClassicSettings(),
                  pauseToAssign: try fields.decodeIfPresent(Bool.self, forKey: .pauseToAssign) ?? true,
                  fastSpeed: try fields.decodeIfPresent(Int.self, forKey: .fastSpeed) ?? 2,
                  musicEnabled: try fields.decodeIfPresent(Bool.self, forKey: .musicEnabled) ?? true,
                  soundtrack: try fields.decodeIfPresent(String.self, forKey: .soundtrack) ?? "Original")
    }

    /// Migrate once. Keep legacy keys so a downgrade can still read its saved preferences.
    public static func load(from defaults: UserDefaults) -> MobileSettings {
        if let data = defaults.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(Self.self, from: data) { return saved }
        let migrated = Self(pauseToAssign: !defaults.bool(forKey: "mobile.continuousSkillSelection"),
                            fastSpeed: defaults.integer(forKey: "mobile.fastSpeed"),
                            musicEnabled: defaults.object(forKey: "mobile.music") as? Bool ?? true,
                            soundtrack: defaults.string(forKey: "mobile.soundtrack") ?? "Original")
        migrated.save(to: defaults)
        return migrated
    }

    public func save(to defaults: UserDefaults) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(self) { defaults.set(data, forKey: Self.defaultsKey) }
    }

    public mutating func applyExperiencePreset(modern: Bool) {
        classic.applyExperiencePreset(modern: modern)
        if !modern, soundtrack == "Adaptive DJ" { soundtrack = "Original" }
    }
}

public enum MobileSettingsGroup: String, CaseIterable, Codable, Sendable {
    case gameplay, controller, graphics, display, audio, accessibility, privacy
    public var title: String { rawValue.capitalized }
}
