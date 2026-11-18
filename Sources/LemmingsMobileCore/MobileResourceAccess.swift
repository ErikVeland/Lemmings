import Foundation
import LemmingsAppCore

/**
 * Keeps complete player-owned resource imports outside the mobile application.
 */
public enum MobileResourceAccess {
    public static var isStore: Bool { Bundle.main.object(forInfoDictionaryKey: "UltimateLemmixStore") as? Bool == true }

    public static var library: OwnedResourceLibrary? {
        guard let resources = Bundle.main.resourceURL,
              let support = FileManager.default.urls(for: MobileStorage.localDirectory, in: .userDomainMask).first else { return nil }
        let name = isStore ? "Ultimate Lemmix" : "Ultimate Lemmings"
        return OwnedResourceLibrary(root: support.appendingPathComponent(name + "/ResourceBundles", isDirectory: true),
                                    bundledResources: resources)
    }

    public static var hasOriginalGameData: Bool {
        guard let store = try? MobileContentStore() else { return false }
        return MobileGameDataKind.allCases.contains { kind in
            guard let directory = store.resolvedDataDirectory(for: kind) else { return false }
            return kind != .classic || !GameStarterContent.isStarter(directory: directory)
        }
    }

    /**
     * Restores an immutable merged bundle, retaining the current app's trusted metadata.
     */
    public static func restoredBundleURL() throws -> URL? {
        guard let library else { return nil }
        return try library.refreshBaseIfNeeded()?.bundleURL ?? library.installedBundleURL()
    }
}
