#if os(iOS) || os(tvOS)
import LemmingsMobileCore
import UIKit

extension MobileLibraryViewController {
    /// Measuring stays on the metadata actor while the current page remains usable.
    func measureMobileFanPacks() {
        guard game == nil, !preparingCloudLevel, let catalogue else { return }
        fanCountsTask?.cancel()
        let generation = UUID(); fanCountGeneration = generation
        let folders = catalogue.fanFolders
        let counter = MobileFanCountStore()
        fanCountsTask = Task { [weak self] in
            do {
                _ = try await counter.measure(fanFolders: folders) { [weak self] counts in
                    await MainActor.run {
                        guard let self, self.fanCountGeneration == generation,
                              self.game == nil, !self.preparingCloudLevel else { return }
                        self.catalogue?.updateMeasuredCounts(counts)
                        if self.route == .family(.fan) { self.rebuild() }
                        else if case .fanGroup = self.route { self.rebuild() }
                    }
                }
            } catch is CancellationError { }
            catch { /* A failed metadata cache does not block opening a pack. */ }
            if self?.fanCountGeneration == generation { self?.fanCountsTask = nil }
        }
    }
}
#endif
