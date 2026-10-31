#if os(macOS)
import AppKit
import ImageIO
import NxlvKit
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
            ("automatic", CloudSyncArt.page()),
            ("enabling", CloudSyncArt.page(busy: true)),
            ("tester-on", CloudSyncArt.page(testerEnabled: true)),
            ("syncing", CloudSyncArt.page(testerEnabled: true, status: "Syncing")),
            ("offline", CloudSyncArt.page(testerEnabled: true, status: "Offline")),
            ("pending", CloudSyncArt.page(testerEnabled: true, status: "Saved on this device")),
            ("synced", CloudSyncArt.page(testerEnabled: true, status: "Synced")),
            ("failed", CloudSyncArt.page(message: "The library key could not be saved."))]
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
                GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "syncTester", in: context)
                let image = try #require(context.makeImage())
                let destination = try #require(CGImageDestinationCreateWithURL(output.appendingPathComponent("\(device)-\(name).png") as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil); #expect(CGImageDestinationFinalize(destination))
            }
        }
    }
    @Test func publicLinkingKeepsTesterLibrariesSeparate() {
        let page = CloudSyncArt.page()
        #expect(page.rows.map(\.id) == ["syncMake", "syncEnter"])
        #expect(page.footer.map(\.id) == ["syncBack"])
        let tester = CloudSyncArt.page(testerEnabled: true)
        #expect(tester.rows.isEmpty)
        #expect(tester.footer.map(\.id) == ["syncBack"])
        #expect(CloudSyncArt.page(draft: "SHORT").footer.last?.enabled == false)
        #expect(CloudSyncArt.page(draft: "ABCD2345EFGH").footer.last?.enabled == true)
        #expect(CloudSyncArt.page(busy: true, draft: "ABCD2345EFGH").footer.last?.enabled == false)
    }
    @Test func syncErrorsKeepTheirActionableMessage() {
        let error: Error = SequelDataError.invalid("Return to the library before linking devices.")
        #expect(error.localizedDescription == "Return to the library before linking devices.")
        let offline = CloudSyncArt.page(testerEnabled: true, status: "Offline")
        #expect(offline.subtitle == "Offline")
        #expect(CloudSyncArt.page(busy: true, status: "Offline").subtitle == "Connecting")
        #expect(CloudSyncArt.page(message: "Try again", status: "Synced").subtitle == "Try again")
    }
    @Test func linkAccessibilityAndKeyboardUseTheSameTargets() throws {
        let storage = try AppStorage.temporary(named: "cloud-view")
        defer { storage.removeTemporaryFiles() }
        let sync = CloudLibrarySync(store: ArcadeStore(storage: storage, bundledProofs: nil), storage: storage, transport: UICloudTransport(), identities: [CloudLibraryIdentity()])
        let view = CloudLibraryView(sync: sync)
        #expect(view.page.title == "Cloud saves")
        let enable = try #require(view.accessibilityChildren()?.compactMap { $0 as? GameAccessibleElement }.first { $0.accessibilityLabel() == "Enter code" })
        #expect(enable.accessibilityRole() == .button)
        let enter = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 36))
        view.handle("syncEnter")
        #expect(view.page.rows.first?.id == "syncCode")
        #expect(view.page.footer.last?.enabled == false)
        view.handle("syncCancel")
        #expect(view.page.rows.first?.id == "syncMake")
        _ = enter
        var returned = false
        view.onBack = { returned = true }
        let escape = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 53))
        view.keyDown(with: escape)
        #expect(returned)
    }
}
#endif
