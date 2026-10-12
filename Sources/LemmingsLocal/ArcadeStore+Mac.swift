#if os(macOS)
import Foundation
import LemmingsAppCore
import NxlvKit

extension ArcadeStore {
    static var shared = ArcadeStore()

    /// The Mac services that follow record changes.
    static var macHooks: Hooks {
        Hooks(runRecorded: { GameCenterScores.shared.completed(profileID: $0, history: $1) },
              rankingEvidenceAdded: { HostedRankings.shared.completed(profileID: $0) },
              profileDeleted: { HostedRankings.shared.profileDeleted($0) },
              profileSettingsRemoved: { PrecisionZoomController.shared.removeProfile($0) })
    }

    /// Opens the Mac records. The arguments and defaults are the same as before the move to LemmingsAppCore.
    convenience init(file: URL? = nil, bundledProofs: TrolleyBundledProofs? = .load(), defaults: UserDefaults = .standard,
                     checkpoints: RunRecoveryStore? = nil,
                     playlistDataRemover: @escaping (String) throws -> Void = {
                         try LevelPlaylistStore.removeDataChecked(at: LevelPlaylistStore.fileURL(profileID: $0))
                     }) {
        self.init(storage: .current(), file: file, bundledProofs: bundledProofs, defaults: defaults,
                  checkpoints: checkpoints, playlistDataRemover: playlistDataRemover, hooks: Self.macHooks)
    }
}

extension RecordLevelNavigation {
    /// Unplayed entries have empty boards. Saved entries retain their exact rules.
    static func levels(current: ArcadeLevel, entries: [(id: String, title: String)]) -> [ArcadeLevel] {
        levels(current: current, entries: entries, records: ArcadeStore.shared.records)
    }

    static func savedLevels(current: ArcadeLevel?) -> [ArcadeLevel] {
        savedLevels(current: current, records: ArcadeStore.shared.records)
    }
}
#endif
