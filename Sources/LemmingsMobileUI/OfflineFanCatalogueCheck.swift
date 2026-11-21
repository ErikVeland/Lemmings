#if targetEnvironment(simulator) && (os(iOS) || os(tvOS))
import Foundation
import LemmingsMobileCore

enum OfflineFanCatalogueCheck {
    struct Receipt: Codable {
        var classicPacks = 0
        var classicLevels = 0
        var neoLevels = 0
        var failures: [String] = []
        var complete = false
    }

    static func run() async {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let report = documents.appendingPathComponent("OfflineCatalogueCheck.json")
        var receipt = Receipt()
        func save() { try? JSONEncoder().encode(receipt).write(to: report, options: .atomic) }
        func open(_ library: any MobileGameLibrary) -> Int {
            var successes = 0
            for index in library.levels.indices {
                do {
                    try autoreleasepool {
                        let level = try library.loadLevel(at: index)
                        level.session.tick()
                    }
                    successes += 1
                } catch {
                    receipt.failures.append("\(library.displayName)/\(index): \(error)")
                }
            }
            return successes
        }
        do {
            guard let root = Bundle.main.resourceURL,
                  let catalogue = await MobileCatalogueLoader().load(resources: root, support: nil) else {
                throw CocoaError(.fileNoSuchFile)
            }
            for pack in catalogue.packs(in: .fan) {
                receipt.classicPacks += 1
                do {
                    let count = open(try catalogue.library(for: pack))
                    receipt.classicLevels += count
                } catch { receipt.failures.append("\(pack.id): \(error)") }
                if receipt.classicPacks.isMultiple(of: 10) { save() }
            }
            let store = try MobileContentStore()
            guard let neo = store.resolvedDataDirectory(for: .neoLemmix, bundledResources: root),
                  neo.standardizedFileURL == root.appendingPathComponent("NeoLemmix", isDirectory: true).standardizedFileURL else {
                throw CocoaError(.fileNoSuchFile)
            }
            let storage = MobileStorage(directory: documents.appendingPathComponent("CatalogueCheckProgress"))
            let count = open(try NeoLemmixMobileLibrary(directory: neo, storage: storage))
            receipt.neoLevels = count
        } catch { receipt.failures.append(String(describing: error)) }
        receipt.complete = true
        save()
    }
}
#endif
