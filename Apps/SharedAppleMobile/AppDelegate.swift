#if os(tvOS)
import LemmingsTVUI
#else
import LemmingsMobileUI
#endif
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    #if os(iOS)
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        guard LemmingsMobileConfiguration.current == .ultimateLemmix else {
            completionHandler()
            return
        }
        LemmingsMobileApplication.handleGameAssetBackgroundEvents(identifier: identifier, completion: completionHandler)
    }
    #endif
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    #if os(iOS)
    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        openDeskClock(contexts)
    }

    private func openDeskClock(_ contexts: Set<UIOpenURLContext>) {
        if contexts.contains(where: {
            AppleMobileLaunchURL.opensDeskClock($0.url, info: Bundle.main.infoDictionary ?? [:])
        }) {
            LemmingsMobileApplication.openDeskClock(in: window?.rootViewController)
        }
    }
    #endif

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        #if os(tvOS)
        window.rootViewController = LemmingsTVApplication.makeRootViewController()
        #else
        window.rootViewController = LemmingsMobileApplication.makeRootViewController()
        #endif
        self.window = window
        window.makeKeyAndVisible()
        #if os(iOS)
        openDeskClock(connectionOptions.urlContexts)
        #endif
    }
}
