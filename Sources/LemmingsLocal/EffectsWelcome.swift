#if os(macOS)
import Foundation

/// Retains the old welcome marker without applying a preset to saved settings.
enum EffectsWelcome {
    static let choiceKey = "HDEffectsChoiceV1"

    static func acknowledgeDefaults(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: choiceKey)
    }
}
#endif
