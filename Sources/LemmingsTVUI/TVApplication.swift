#if os(tvOS)
import LemmingsMobileCore
import LemmingsMobileUI
import LemmingsTVCore
import UIKit

public enum LemmingsTVApplication {
    /// Applications can register native Classic, L2 and L3 libraries through the same contract.
    @MainActor public static func makeRootViewController(sources: [TVLibrarySource]? = nil) -> UIViewController {
        if let sources { return TVLibraryViewController(sources: sources) }
        return LemmingsMobileApplication.makeRootViewController()
    }
}
#endif
