#if os(macOS)
import AppKit
import ImageIO
import LemmingsAppCore
import LemmingsGameArt
import Testing
@testable import LemmingsLocal

@MainActor private final class UICloudTransport: CloudLibraryTransport {
    func discover(_ identities: [CloudLibraryIdentity]) async throws -> [CloudLibraryIdentity] { identities }
    func load(_ identity: CloudLibraryIdentity) async throws -> [Data] { throw URLError(.notConnectedToInternet) }
    func save(_ data: Data, identity: CloudLibraryIdentity, device: String) async throws {}
}

@MainActor struct CloudLibraryViewTests {
    @Test func bitmapStatesHaveOnePrimaryActionAndMatchingInputTargets() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let typography = try #require(GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let output = root.appendingPathComponent(".build/cloud-ui-evidence")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let states: [(String, GameFrontEnd.Page)] = [
            ("synced", CloudSyncArt.page(status: "Synced", providers: "Cloud + iCloud", enabled: true)),
            ("offline", CloudSyncArt.page(status: "Offline", providers: "", enabled: true)),
            ("syncing", CloudSyncArt.page(status: "Syncing", providers: "iCloud", enabled: true, busy: true)),
            ("paused", CloudSyncArt.page(status: "Cloud saves paused", providers: "", enabled: false)),
            ("failed", CloudSyncArt.page(status: "Cloud saves", providers: "Cloud", enabled: true, message: "Existing saves were kept.")),
            ("code", CloudSyncArt.page(status: "Synced", providers: "Cloud", enabled: true, code: "ABCD2345EFGH")),
            ("entry-empty", CloudSyncArt.page(status: "Synced", providers: "Cloud", enabled: true, draft: "")),
            ("entry-ready", CloudSyncArt.page(status: "Synced", providers: "Cloud", enabled: true, draft: "ABCD2345EFGH")),
            ("password-short", CloudSyncArt.page(status: "Synced", providers: "Cloud", enabled: true, password: "uva")),
            ("password-ready", CloudSyncArt.page(status: "Synced", providers: "Cloud", enabled: true, password: String(repeating: "x", count: 64)))]
        for (device, width, height) in [("mac", 1120, 720), ("iphone", 390, 763), ("narrow", 320, 548), ("landscape", 568, 300)] {
            for (name, page) in states {
                let layout = GameFrontEnd.layout(page, width: CGFloat(width), minimumHeight: CGFloat(height))
                #expect(layout.targets.filter { $0.action.enabled && $0.action.primary }.count <= 1)
                for target in layout.targets {
                    #expect(target.frame.width >= 44 && target.frame.height >= 44)
                    #expect(CGRect(origin: .zero, size: layout.size).contains(target.frame))
                    #expect(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil))
                }
                #expect(layout.action(at: CGPoint(x: layout.board.minX + 1, y: layout.heading.midY)) == nil)
                let context = try #require(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height), bitsPerComponent: 8,
                    bytesPerRow: Int(layout.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "syncNow", in: context)
                let image = try #require(context.makeImage())
                let destination = try #require(CGImageDestinationCreateWithURL(output.appendingPathComponent("\(device)-\(name).png") as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil); #expect(CGImageDestinationFinalize(destination))
            }
        }
    }
    @Test func nativeCodeEntryTargetsAccessibilityAndKeyboardUseTheSamePage() throws {
        let storage = try AppStorage.temporary(named: "cloud-view")
        defer { storage.removeTemporaryFiles() }
        let sync = CloudLibrarySync(store: ArcadeStore(storage: storage, bundledProofs: nil), storage: storage, transport: UICloudTransport(), identities: [CloudLibraryIdentity()])
        let view = CloudLibraryView(sync: sync)
        view.handle("syncEnterCode")
        #expect(view.page.title == "Link library")
        let field = try #require(view.accessibilityChildren()?.compactMap { $0 as? GameAccessibleElement }.first { $0.accessibilityRole() == .textField })
        field.writeValue?("abcd 2345 efgh")
        #expect(view.page.rows[0].title == "Code: ABCD 2345 EFGH_")
        #expect(view.page.footer.first { $0.id == "syncJoin" }?.enabled == true)
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 51))
        view.keyDown(with: event)
        #expect(view.page.footer.first { $0.id == "syncJoin" }?.enabled == false)
        view.handle("syncCancel")
        #expect(view.page.title == "Cloud saves")
        view.handle("syncEnterPassword")
        #expect(view.page.title == "Sync password")
        let secure = try #require(view.accessibilityChildren()?.compactMap { $0 as? GameAccessibleElement }.first { $0.accessibilityRole() == .textField })
        #expect(secure.accessibilitySubrole() == .secureTextField)
        secure.writeValue?("test")
        #expect(view.page.rows[0].title == "Password: ****_" && secure.readValue?() == "****")
        #expect(view.page.footer.first { $0.id == "syncJoinPassword" }?.enabled == true)
        view.keyDown(with: event)
        #expect(view.page.footer.first { $0.id == "syncJoinPassword" }?.enabled == false)
        let typed = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: "r", charactersIgnoringModifiers: "r", isARepeat: false, keyCode: 15))
        view.keyDown(with: typed)
        #expect(view.page.footer.first { $0.id == "syncJoinPassword" }?.enabled == true)
        view.handle("syncCancel")
        #expect(view.page.title == "Cloud saves")
        view.handle("syncToggle")
        #expect(!sync.enabled)
        #expect(view.page.rows.first { $0.id == "syncEnterPassword" }?.enabled == false)
        #expect(view.page.rows.first { $0.id == "syncNow" }?.enabled == false)
    }
}
#endif
