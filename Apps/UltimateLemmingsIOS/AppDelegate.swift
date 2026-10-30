import LemmingsMobileUI
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        if contexts.contains(where: { $0.url.scheme == "ultimatelemmings" && $0.url.host == "desk-clock" }) {
            LemmingsMobileApplication.openDeskClock(in: window?.rootViewController)
        }
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.rootViewController = LemmingsMobileApplication.makeRootViewController()
        self.window = window
        window.makeKeyAndVisible()
        if connectionOptions.urlContexts.contains(where: { $0.url.scheme == "ultimatelemmings" && $0.url.host == "desk-clock" }) {
            LemmingsMobileApplication.openDeskClock(in: window.rootViewController)
        }
    }
}
