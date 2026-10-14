import Foundation
import NxlvKit

/// The iPad preferences wrap the shared Classic settings without changing their format.
public struct MobileSettings: Codable, Equatable, Sendable {
    public var classic: ClassicSettings
    public var pauseToAssign: Bool
    public private(set) var skillSelectionPauseCount: Int
    public private(set) var skillSelectionPauseChoiceMade: Bool
    public static let skillSelectionTutorialUses = 10
    public var fastSpeed: Int
    public var musicEnabled: Bool
    public var soundtrack: String
    public var djShuffleScope: SoundtrackCatalogue.ShuffleScope
    public static let defaultsKey = "mobile.settings.v1"
    public static let activeProfileKey = "mobile.settings.player.v1"
    public static let fastSpeeds = [2, 3, 5, 10]

    public init(classic: ClassicSettings = ClassicSettings(), pauseToAssign: Bool = true,
                fastSpeed: Int = 2, musicEnabled: Bool = true, soundtrack: String = "Original",
                skillSelectionPauseCount: Int = 0, skillSelectionPauseChoiceMade: Bool = false,
                djShuffleScope: SoundtrackCatalogue.ShuffleScope = .sameTrack) {
        self.classic = classic
        self.pauseToAssign = pauseToAssign
        self.skillSelectionPauseCount = min(Self.skillSelectionTutorialUses, max(0, skillSelectionPauseCount))
        self.skillSelectionPauseChoiceMade = skillSelectionPauseChoiceMade || !pauseToAssign
        self.fastSpeed = Self.fastSpeeds.contains(fastSpeed) ? fastSpeed : 2
        self.musicEnabled = musicEnabled
        self.soundtrack = soundtrack
        self.djShuffleScope = djShuffleScope
    }

    private enum CodingKeys: String, CodingKey {
        case classic, pauseToAssign, fastSpeed, musicEnabled, soundtrack
        case skillSelectionPauseCount, skillSelectionPauseChoiceMade
        case djShuffleScope
    }
    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        self.init(classic: try fields.decodeIfPresent(ClassicSettings.self, forKey: .classic) ?? ClassicSettings(),
                  pauseToAssign: try fields.decodeIfPresent(Bool.self, forKey: .pauseToAssign) ?? true,
                  fastSpeed: try fields.decodeIfPresent(Int.self, forKey: .fastSpeed) ?? 2,
                  musicEnabled: try fields.decodeIfPresent(Bool.self, forKey: .musicEnabled) ?? true,
                  soundtrack: try fields.decodeIfPresent(String.self, forKey: .soundtrack) ?? "Original",
                  skillSelectionPauseCount: try fields.decodeIfPresent(Int.self, forKey: .skillSelectionPauseCount) ?? 0,
                  skillSelectionPauseChoiceMade: try fields.decodeIfPresent(Bool.self, forKey: .skillSelectionPauseChoiceMade) ?? false,
                  djShuffleScope: try fields.decodeIfPresent(SoundtrackCatalogue.ShuffleScope.self, forKey: .djShuffleScope) ?? .sameTrack)
    }

    /// Migrate once. Keep legacy keys so a downgrade can still read its saved preferences.
    public static func load(from defaults: UserDefaults) -> MobileSettings {
        if let data = defaults.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(Self.self, from: data) { return saved }
        #if os(tvOS)
        let planning = false
        #else
        let planning = !defaults.bool(forKey: "mobile.continuousSkillSelection")
        #endif
        let migrated = Self(pauseToAssign: planning,
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

    public static func load(from defaults: UserDefaults, profileID: String) -> Self {
        var value = load(from: defaults)
        value.classic = PlayerControlSettings.load(from: defaults, profileID: profileID, legacy: value.classic).applying(to: value.classic)
        return value
    }

    public static func activateProfile(_ profileID: String, in defaults: UserDefaults) {
        _ = load(from: defaults, profileID: profileID)
        defaults.set(profileID, forKey: activeProfileKey)
    }

    public static func current(from defaults: UserDefaults) -> Self {
        guard let profileID = defaults.string(forKey: activeProfileKey) else { return load(from: defaults) }
        return load(from: defaults, profileID: profileID)
    }

    public func save(to defaults: UserDefaults, profileID: String) {
        var device = self
        device.classic = PlayerControlSettings(Self.load(from: defaults).classic).applying(to: classic)
        device.save(to: defaults)
        PlayerControlSettings(classic).save(to: defaults, profileID: profileID)
    }

    public var shouldOfferSkillSelectionPauseChoice: Bool {
        pauseToAssign && !skillSelectionPauseChoiceMade && skillSelectionPauseCount >= Self.skillSelectionTutorialUses
    }

    /// Count automatic pauses, not skill changes within an existing planning pause or a replay.
    public mutating func recordSkillSelectionPause(wasRunning: Bool, isReadOnly: Bool) {
        guard pauseToAssign, wasRunning, !isReadOnly, !skillSelectionPauseChoiceMade else { return }
        skillSelectionPauseCount = min(Self.skillSelectionTutorialUses, skillSelectionPauseCount + 1)
    }

    /// A choice in the prompt or Settings ends the tutorial reminder.
    public mutating func chooseSkillSelectionPause(_ enabled: Bool) {
        pauseToAssign = enabled
        skillSelectionPauseChoiceMade = true
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
