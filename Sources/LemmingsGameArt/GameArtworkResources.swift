import Foundation
import LemmingsAppCore
import NxlvKit

/**
 * Shares decoded presentation assets while keeping the cleared fallback app-owned.
 */
public enum GameArtworkResources {
    private struct Original: Sendable {
        let artwork: ClassicMacArtwork
        let interface: ClassicMacUserInterface
    }
    private final class OriginalCache: @unchecked Sendable {
        private let lock = NSLock()
        private var revision: String?
        private var original: Original?
        func value() -> Original? {
            lock.lock(); defer { lock.unlock() }
            let next = GameResources.revision
            if revision != next {
                revision = next
                original = nil
                let directories = [GameResources.directory("MacArtwork/lemmings"),
                    Bundle.main.resourceURL?.appendingPathComponent("Fonts/OriginalLemmings"),
                    GameResources.directory("Fonts/OriginalLemmings")].compactMap { $0 }
                for directory in directories {
                    guard let artwork = try? ClassicMacArtwork(directory: directory),
                          let interface = ClassicMacUserInterface(artwork: artwork),
                          ClassicMacUserInterface.Face.allCases.allSatisfy({ interface.font($0) != nil }) else { continue }
                    original = Original(artwork: artwork, interface: interface)
                    break
                }
            }
            return original
        }
    }
    private static let original = OriginalCache()
    public static var originalArtwork: ClassicMacArtwork? { original.value()?.artwork }
    public static var interface: ClassicMacUserInterface? { original.value()?.interface }
    private static let clearedInterface: ClassicMacUserInterface? = Bundle.main.resourceURL.flatMap {
        guard let artwork = try? ClassicMacArtwork(directory: $0.appendingPathComponent("Fonts/LixInterface")) else { return nil }
        return ClassicMacUserInterface(artwork: artwork)
    }
    public static var menuInterface: ClassicMacUserInterface? { interface ?? clearedInterface }
    public static var originalInterfaceAvailable: Bool { interface != nil }
    public static var lixAvailable: Bool { lixArtwork != nil && lixInterface != nil && clearedInterface != nil }
    public static var revision: String { GameResources.revision }
    public static let changed = GameResources.changed
    public static let lixArtwork: LixArtwork? = Bundle.main.resourceURL.flatMap {
        try? LixArtwork(directory: $0.appendingPathComponent("AlternativeAssets/Lix"))
    }
    public static let lixInterface: LixInterfaceArtwork? = Bundle.main.resourceURL.flatMap {
        try? LixInterfaceArtwork(directory: $0.appendingPathComponent("AlternativeAssets/Lix"))
    }
    public static let lixFont: LixInterfaceText? = Bundle.main.resourceURL.flatMap {
        try? LixInterfaceText(directory: $0.appendingPathComponent("Fonts/Lix"))
    }
}

/**
 * Keeps the existing artwork choice independent from distribution identity.
 */
public enum GameArtworkSkin {
    private static let isLemmix = Bundle.main.object(forInfoDictionaryKey: "UltimateLemmixStore") as? Bool == true
    public static let key = isLemmix ? "LemmixCharactersEnabledV1" : "LixCharactersEnabledV1"
    public static let changed = Notification.Name("LixCharactersChanged")
    public static var lixEnabled: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? (isLemmix ? !GameMenuLogo.usesRestoredArtwork : GameResources.directory("MacArtwork/lemmings") == nil)
    }
    public static var usesLixInterface: Bool {
        GameArtworkResources.lixInterface != nil && (lixEnabled || GameArtworkResources.interface == nil)
    }
    @discardableResult public static func setLixEnabled(_ enabled: Bool) -> Bool {
        guard !enabled || GameArtworkResources.lixArtwork != nil else { return false }
        UserDefaults.standard.set(enabled, forKey: key)
        NotificationCenter.default.post(name: changed, object: nil)
        return true
    }
}
