import Foundation

/// Imports only game preferences, once, without replacing current choices.
enum LegacySaveMigration {
    static let currentIdentifier = "academy.glasscode.lemmings"
    static let previousIdentifier = "org.lemmingslocal.LemmingsLocal"
    static let marker = "LegacySaveMigration.v1"
    private static let preferences: Set<String> = [
        "ClassicDataDirectory", "ClassicGameDirectories", "NeoLemmixStylesDirectory",
        "MusicDirectory", "MusicUsesModernPreset", "MacintoshDiskImage", "ClassicSettings",
        "AudioMuted", "PreferMacArtworkV1", "SequelMacArtworkEnabledV2", "HDEffectsChoiceV1", "FanLevelFolder"
    ]
    private static func isProgress(_ key: String) -> Bool {
        ["ModernCampaignProgress", "ClassicAchievementProgress", "ClassicGameProgress", "FanLevelsPassed"].contains(key)
            || key.hasPrefix("ClassicGameProgress.") || key.hasPrefix("nativeL2Campaign.v1.")
            || key.hasPrefix("nativeL3ClassicPreview.v1.") || key.hasPrefix("nativeL3EgyptianPreview.v1.")
            || key.hasPrefix("nativeL3ShadowPreview.v1.") || key.hasPrefix("nativeL3SelectedTribe.v1.")
    }
    private static func isStandalonePreference(_ key: String) -> Bool {
        let l2 = "nativeL2Campaign.v1.bundled"
        if key.hasPrefix(l2) {
            let suffix = String(key.dropFirst(l2.count))
            return ["", ".musicMuted", ".soundsMuted"].contains(suffix)
                || (0..<8).contains { suffix == ".slot.\($0)" }
        }
        return key.hasPrefix("nativeL3") && key.hasSuffix(".bundled") && isProgress(key)
    }
    private static func isUnifiedPreference(_ key: String) -> Bool {
        if preferences.contains(key) || isProgress(key) { return true }
        guard key.hasPrefix("ArcadeProfile.") else { return false }
        let pieces = key.dropFirst("ArcadeProfile.".count).split(separator: ".", maxSplits: 1)
        return pieces.count == 2 && isProgress(String(pieces[1]))
    }
    @discardableResult static func migrate(
        bundleIdentifier: String?, defaults: UserDefaults = .standard,
        readDomain: ((String) -> [String: Any])? = nil
    ) -> Int {
        guard let bundleIdentifier, [currentIdentifier, previousIdentifier].contains(bundleIdentifier) else { return 0 }
        let read = readDomain ?? { defaults.persistentDomain(forName: $0) ?? [:] }
        var existing = read(bundleIdentifier)
        guard existing[marker] as? Bool != true else { return 0 }
        let sources = (bundleIdentifier == currentIdentifier ? [previousIdentifier] : [])
            + ["org.lemmingslocal.NativeL2", "org.lemmingslocal.NativeL3Preview"]
        var count = 0
        for source in sources {
            for (key, value) in read(source) {
                let supported = source == previousIdentifier ? isUnifiedPreference(key)
                    : isStandalonePreference(key)
                guard supported, existing[key] == nil else { continue }
                defaults.set(value, forKey: key)
                existing[key] = value
                count += 1
            }
        }
        defaults.set(true, forKey: marker)
        return count
    }
}
