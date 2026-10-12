import Foundation
import LemmingsAppCore
import NxlvKit

/// Reads authored levels before the shared scorer chooses a progression queue.
public enum MobileProgressionBuilder {
    public struct Corpus: Sendable {
        public let inputs: [DifficultyLibrary.Input]
        public let failures: [String]
    }

    public static func generate(portsRoot: URL, fanFolders: [URL], entries: [LevelPlaylistEntry]? = nil,
                                policy: ProgressionPolicy, technique: String? = nil,
                                storage: AppStorage = .current(),
                                progress: @Sendable (Int, Int) async -> Void = { _, _ in }) async throws -> ProgressionResult {
        let corpus = try inputs(portsRoot: portsRoot, fanFolders: fanFolders, entries: entries)
        let analysed = try await DifficultyLibrary.analyse(corpus.inputs, sourceFailures: corpus.failures,
                                                          storage: storage, progress: progress)
        try Task.checkCancellation()
        var configuration = ProgressionConfiguration(); configuration.technique = technique
        let result = try ProgressionGenerator.generate(candidates: analysed.candidates, policy: policy,
            configuration: configuration, statistics: analysed.statistics)
        try DifficultyLibrary.saveDiagnostics(result, storage: storage)
        return result
    }

    public static func inputs(portsRoot: URL, fanFolders: [URL], entries: [LevelPlaylistEntry]? = nil) throws -> Corpus {
        let catalogue = MobileCatalogue(portsRoot: portsRoot, fanFolders: fanFolders)
        var inputs: [DifficultyLibrary.Input] = []
        var failures: [String] = []
        if let entries {
            let journey = MobileJourneyLibrary(entries: entries, name: "Progression", catalogue: catalogue)
            for (position, entry) in entries.enumerated() {
                try Task.checkCancellation()
                do {
                    let origin = try journey.origin(of: position)
                    inputs.append(try input(entry: entry, library: origin.library, index: origin.index,
                                            campaignOrder: position))
                } catch is CancellationError { throw CancellationError() }
                catch { failures.append(entry.levelNameSnapshot + ": " + error.localizedDescription) }
            }
        } else {
            let staged = (try? Data(contentsOf: portsRoot.appendingPathComponent("source-revisions.json")))
                .flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
            var order = 0
            for family in MobileFamily.allCases {
                for pack in catalogue.packs(in: family) {
                    try Task.checkCancellation()
                    do {
                        let library = try catalogue.library(for: pack)
                        if let fan = library as? ClassicFanMobileLibrary {
                            for (index, item) in fan.entries.enumerated() {
                                try Task.checkCancellation()
                                let entry = try LevelPlaylistEntry(identity: .init(engine: .classic,
                                    packID: "fan:" + fan.catalogueID, levelID: item.key),
                                    catalogueRevision: "1.2-runtime-v2", sourceRevision: fan.pack.fingerprint,
                                    packNameSnapshot: fan.displayName, levelNameSnapshot: item.label,
                                    levelNumberSnapshot: index + 1)
                                do { inputs.append(try input(entry: entry, library: fan, index: index, campaignOrder: 0)) }
                                catch { failures.append(item.label + ": " + error.localizedDescription) }
                            }
                        } else {
                            let dataSet: ClassicDataSet
                            let revision: String?
                            if let stock = library as? ClassicMobileLibrary {
                                dataSet = stock.dataSet
                                revision = staged[dataSet.identifierKey] ?? staged[dataSet.title?.rawValue ?? ""]
                                    ?? ClassicSourceRevision.bundledCampaign(dataSet.title, root: stock.directory)
                            } else if let exclusive = library as? ClassicOhYesMobileLibrary {
                                dataSet = exclusive.dataSet
                                revision = staged[dataSet.identifierKey] ?? staged[dataSet.title?.rawValue ?? ""]
                                    ?? ClassicSourceRevision.bundledCampaign(dataSet.title, root: portsRoot)
                            } else { throw MobileSessionError.changedLevel }
                            guard let revision else { throw MobileSessionError.changedLevel }
                            for (index, item) in dataSet.campaign.levels.enumerated() {
                                try Task.checkCancellation()
                                let entry = try LevelPlaylistEntry(identity: .init(engine: .classic,
                                    packID: dataSet.identifierKey,
                                    levelID: "\(index):\(item.rank):\(item.number):\(item.archiveFile):\(item.archiveSection)"),
                                    catalogueRevision: "1.2-runtime-v2", sourceRevision: revision,
                                    packNameSnapshot: dataSet.name, levelNameSnapshot: item.level.title,
                                    levelNumberSnapshot: index + 1)
                                inputs.append(try input(entry: entry, library: library, index: index, campaignOrder: order))
                                order += 1
                            }
                        }
                    } catch is CancellationError { throw CancellationError() }
                    catch { failures.append(pack.title + ": " + error.localizedDescription) }
                }
            }
        }
        return Corpus(inputs: inputs, failures: failures)
    }

    private static func input(entry: LevelPlaylistEntry, library: any MobileGameLibrary,
                              index: Int, campaignOrder: Int) throws -> DifficultyLibrary.Input {
        if let stock = library as? ClassicMobileLibrary {
            let authored = stock.dataSet.campaign.levels[index]
            return .init(entry: entry, source: .classic(authored.level, root: stock.directory,
                rank: authored.rank, number: authored.number), isOfficial: true, campaignOrder: campaignOrder)
        }
        if let exclusive = library as? ClassicOhYesMobileLibrary {
            let authored = exclusive.dataSet.campaign.levels[index]
            let root = PortExclusivePack.artworkDirectory(for: authored, portsRoot: exclusive.portsRoot)
            return .init(entry: entry, source: .classic(authored.level, root: root,
                rank: authored.rank, number: authored.number), isOfficial: true, campaignOrder: campaignOrder)
        }
        if let fan = library as? ClassicFanMobileLibrary {
            let level = try fan.pack.level(fan.entries[index]).0
            return .init(entry: entry, source: .fan(level: { level }), isOfficial: false, campaignOrder: 0)
        }
        throw MobileSessionError.changedLevel
    }
}
