#if os(iOS)
import UIKit

public enum LemmingsMobileApplication {
    @MainActor public static func makeRootViewController() -> UIViewController {
        MobileLibraryViewController()
    }
}
#endif
