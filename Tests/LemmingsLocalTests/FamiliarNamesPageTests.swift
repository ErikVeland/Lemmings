#if os(macOS)
import AppKit
import Contacts
import ContactsUI
import ImageIO
import LemmingsAppCore
import LemmingsGameArt
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class FamiliarNamesPageTests: XCTestCase {
    @MainActor func testDraftApplyPickerForgetAndRenderedTargets() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FamiliarNamesStore(directory: root)
        try store.replace(with: ["Sarah", "Alex"])
        _ = try store.names(for: "retained")
        let artworkURL = URL(fileURLWithPath: TestMenuArtwork.path)
        let typography = try XCTUnwrap(GameMenuTypography(directory: artworkURL))
        let renderer = MacInterfaceRenderer(interface: try XCTUnwrap(ClassicMacUserInterface(artwork: try ClassicMacArtwork(directory: artworkURL))))
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/familiar-names-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var windows: [NSWindow] = []
        defer { windows.forEach { $0.close() } }
        let originalLanguage = L10n.currentLanguagePreference
        defer { L10n.setLanguage(originalLanguage) }
        for language in L10n.languageOptions where language != .system {
            L10n.setLanguage(language)
            XCTAssertLessThanOrEqual(GameTextLayout.height(FamiliarNamesArt.privacy + "\n" + FamiliarNamesArt.retention,
                width: 928, font: renderer.font(.small)), 108, language.rawValue)
            for size in [CGSize(width: 640, height: 480), CGSize(width: 1120, height: 720)] {
                let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                windows.append(window)
                let page = GameMenuArtwork.withRenderer(renderer) { FamiliarNamesPage(store: store) }
                window.contentView = page; page.layoutSubtreeIfNeeded()
                window.makeFirstResponder(page.controllerBackButton)
                page.field.stringValue = "Sarah, Alex, Jo, Ali, Emile, Anne Marie, Robin"
                page.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
                XCTAssertEqual(try store.names(), ["Sarah", "Alex"])
                let contact = CNMutableContact()
                contact.givenName = "Alex"; contact.familyName = "NeverStoreThis"; contact.organizationName = "NeverStoreThisEither"
                // Invoke only the delegate with a fixture. Never open the real contact picker.
                page.contactPicker(CNContactPicker(), didSelect: contact)
                XCTAssertFalse(page.field.stringValue.contains("NeverStore"))
                XCTAssertEqual(FamiliarNamesStore.typed(page.field.stringValue).filter { $0 == "Alex" }.count, 1)
                for button in DialogKeyboardNavigation().controls(in: page).compactMap({ $0 as? NSButton }) where button.isEnabled && !button.isHidden {
                    let rect = button.convert(button.bounds, to: page)
                    XCTAssertTrue(page.bounds.contains(rect), button.title)
                    let point = page.convert(CGPoint(x: rect.midX, y: rect.midY), to: page.superview)
                    XCTAssertTrue(page.hitTest(point) === button, button.title)
                }
                let fieldRect = page.field.convert(page.field.bounds, to: page)
                XCTAssertTrue(page.bounds.contains(fieldRect))
                let fieldPoint = page.convert(CGPoint(x: fieldRect.midX, y: fieldRect.midY), to: page.superview)
                XCTAssertTrue(page.hitTest(fieldPoint) === page.field)
                let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
                GameMenuArtwork.withRenderer(renderer) {
                    @MainActor func invalidate(_ view: NSView) { view.needsDisplay = true; view.subviews.forEach(invalidate) }
                    invalidate(page)
                    if let context = NSGraphicsContext(bitmapImageRep: bitmap) {
                        page.displayIgnoringOpacity(page.bounds, in: context)
                    }
                }
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("mac-\(language.rawValue)-\(Int(size.width)).png"))
                let controls = DialogKeyboardNavigation().controls(in: page).compactMap { $0 as? NSButton }
                try XCTUnwrap(controls.first { $0.title == L10n.text("Next") }).performClick(nil)
                let labels = page.body.subviews.flatMap(\.subviews).compactMap { $0 as? NSTextField }
                XCTAssertTrue(labels.contains { $0.stringValue == "Robin" })
                try XCTUnwrap(DialogKeyboardNavigation().controls(in: page).compactMap { $0 as? NSButton }
                    .first { $0.title == L10n.text("Previous") }).performClick(nil)
            }
        }
        L10n.setLanguage(.english)
        let page = FamiliarNamesPage(store: store)
        page.field.stringValue = "Jo, JO, Anne Marie"; page.save()
        XCTAssertEqual(try store.names(), ["Jo", "Anne Marie"])
        XCTAssertEqual(try store.names(for: "retained"), ["Sarah", "Alex"])
        page.forgetNames()
        XCTAssertEqual(try store.names(for: "retained"), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        for (state, draft, editing, failure, confirming) in [
            ("empty", "", false, false, false),
            ("preview", "Sarah, Alex, Jo, Ali, Emile, Anne Marie, Robin", false, false, false),
            ("typing", "Sarah, Alex, Jo, Anne Marie", true, false, false),
            ("failure", "", false, true, false),
            ("forget", "Sarah", false, false, true)] {
            for size in [CGSize(width: 320, height: 568), CGSize(width: 844, height: 390), CGSize(width: 1920, height: 1080)] {
                let page = FamiliarNamesArt.page(draft: draft, offset: 0, contactsAvailable: size.width != 1920,
                    editing: editing, notice: failure ? "Could not load familiar names." : "", loadFailed: failure, confirmingForget: confirming)
                let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                let bounds = CGRect(origin: .zero, size: layout.size)
                for target in layout.targets {
                    XCTAssertTrue(bounds.contains(target.frame))
                    XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)), target.action.enabled ? target.action.id : nil)
                    for detail in layout.details { XCTAssertFalse(detail.intersects(target.frame)) }
                }
                let context = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height), bitsPerComponent: 8,
                    bytesPerRow: Int(layout.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "names.back", in: context)
                let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(output.appendingPathComponent("\(state)-\(Int(size.width)).png") as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
                XCTAssertTrue(CGImageDestinationFinalize(destination))
            }
        }
    }
}
#endif
