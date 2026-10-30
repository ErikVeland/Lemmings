import Foundation

/// Discovers bundled and imported packs away from the first-frame/UI thread.
public actor MobileCatalogueLoader {
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        MobilePreparationExecutor.shared.asUnownedSerialExecutor()
    }

    public init() {}

    /// The worker relinquishes the catalogue; only the receiving menu uses it.
    public func load(resources: URL?, support: URL?) -> sending MobileCatalogue? {
        guard let resources else { return nil }
        let ports = resources.appendingPathComponent("Ports", isDirectory: true)
        guard FileManager.default.fileExists(atPath: ports.path) else { return nil }
        var fan = [resources.appendingPathComponent("LevelPacks", isDirectory: true)]
        if let support { fan.append(support.appendingPathComponent("Fan Levels", isDirectory: true)) }
        return MobileCatalogue(portsRoot: ports, fanFolders: fan)
    }
}
