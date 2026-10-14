#if os(tvOS)
import LemmingsMobileCore
import LemmingsTVCore
import UIKit

public enum LemmingsTVApplication {
    /// Applications can register native Classic, L2 and L3 libraries through the same contract.
    @MainActor public static func makeRootViewController(sources: [TVLibrarySource]? = nil) -> UIViewController {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("BetaGameData")
        let defaults: [TVLibrarySource] = bundled.flatMap {
            FileManager.default.fileExists(atPath: $0.path) ? [TVLibrarySource.classic(directory: $0)] : nil
        } ?? []
        return TVLibraryViewController(sources: sources ?? defaults)
    }
}
#endif
