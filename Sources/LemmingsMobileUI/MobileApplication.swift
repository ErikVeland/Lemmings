#if os(iOS) || os(tvOS)
import UIKit

/**
 * Selects the app's content and player-data boundary.
 */
public enum LemmingsMobileConfiguration: Equatable, Sendable {
    case preservation
    case ultimateLemmix

    public static var current: Self {
        Bundle.main.object(forInfoDictionaryKey: "UltimateLemmixStore") as? Bool == true
            ? .ultimateLemmix : .preservation
    }
}

public enum LemmingsMobileApplication {
    @MainActor public static func makeRootViewController(
        configuration: LemmingsMobileConfiguration = .current
    ) -> UIViewController {
        MobileLibraryViewController(configuration: configuration)
    }
}
#endif
