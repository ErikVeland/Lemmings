import AppKit
import NxlvKit

@MainActor final class NativePreviewDelegate: NSObject, NSApplicationDelegate {
    var controller: Lemmings3PlayWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let item = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Native Preview", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu; menu.addItem(item); NSApplication.shared.mainMenu = menu
        do {
            let root = try CommandLine.arguments.count > 1
                ? URL(fileURLWithPath: CommandLine.arguments[1]) : BundledGameResources.lemmings3()
            controller = try Lemmings3PlayWindow(root: root)
            controller?.present(); NSApplication.shared.activate(ignoringOtherApps: true)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Cannot start the native tutorial"
            alert.informativeText = String(describing: error)
            alert.runModal(); NSApplication.shared.terminate(nil)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let application = NSApplication.shared
let delegate = NativePreviewDelegate()
application.setActivationPolicy(.regular)
application.delegate = delegate
application.run()
