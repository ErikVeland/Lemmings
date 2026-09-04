import AppKit
import NxlvKit

@MainActor final class NativeL2Delegate: NSObject, NSApplicationDelegate {
    var controller: Lemmings2PlayWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Lemmings 2", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; menu.addItem(appItem); NSApplication.shared.mainMenu = menu
        do {
            // An explicit path remains available for data-reader development.
            // Normal launches always use the self-contained app bundle.
            let root = try CommandLine.arguments.count > 1
                ? URL(fileURLWithPath: CommandLine.arguments[1]) : BundledGameResources.lemmings2()
            controller = try Lemmings2PlayWindow(root: root)
            controller?.present()
            NSApplication.shared.activate(ignoringOtherApps: true)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Cannot start Lemmings 2"
            alert.informativeText = String(describing: error)
            alert.runModal(); NSApplication.shared.terminate(nil)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let application = NSApplication.shared
let delegate = NativeL2Delegate()
application.setActivationPolicy(.regular)
application.delegate = delegate
application.run()
