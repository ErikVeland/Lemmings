#if os(macOS)
import AppKit
#if canImport(NxlvKit)
import NxlvKit
#endif
import LemmingsAppCore
import LemmingsGameArt
import UniformTypeIdentifiers

@MainActor final class CloudLibraryView: NSView, GameDialogCustomNavigation {
    let sync: CloudLibrarySync
    private let typography: GameMenuTypography?
    private let accessible = GameAccessibleElements()
    private var code: String?
    private var draft: String?
    private var password: String?
    private var message = ""
    private var busy = false
    private var focus: String?
    var onBack: (() -> Void)?
    var page: GameFrontEnd.Page {
        CloudSyncArt.page(status: sync.status, providers: sync.providerNames, enabled: sync.enabled,
            busy: busy || sync.state == .syncing, code: code, draft: draft, password: password, message: message)
    }
    var pageLayout: GameFrontEnd.Layout { GameFrontEnd.layout(page, width: bounds.width, minimumHeight: bounds.height) }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    init(sync: CloudLibrarySync, typography: GameMenuTypography? = nil) {
        self.sync = sync
        self.typography = typography ?? Bundle.main.resourceURL.flatMap { GameMenuTypography(directory: $0.appendingPathComponent("MacArtwork/lemmings")) }
        super.init(frame: CGRect(x: 0, y: 0, width: 1120, height: 720))
    }
    required init?(coder: NSCoder) { nil }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, let typography else { return }
        GameFrontEnd.draw(page, layout: pageLayout, typography: typography, highlighted: focus, in: context)
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if let id = pageLayout.action(at: convert(event.locationInWindow, from: nil)) { focus = id; handle(id) }
    }
    override func keyDown(with event: NSEvent) {
        if event.isARepeat && [36, 76, 53].contains(event.keyCode) { return }
        if password != nil, handlePasswordKey(event) { needsDisplay = true; return }
        if draft != nil, event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "v" {
            draft = String(AppleCloudLibraryTransport.cleanCode(NSPasteboard.general.string(forType: .string) ?? "").prefix(12))
        } else if event.keyCode == 53 { handle(draft != nil || code != nil || password != nil ? "syncCancel" : "syncBack") }
        else if [48, 123, 124, 125, 126].contains(event.keyCode) {
            let actions = (page.rows + page.footer).filter(\.enabled)
            let backward = event.keyCode == 48 ? event.modifierFlags.contains(.shift) : [123, 126].contains(event.keyCode)
            let index = actions.firstIndex { $0.id == focus } ?? (backward ? 0 : -1)
            if !actions.isEmpty { focus = actions[(index + (backward ? -1 : 1) + actions.count) % actions.count].id }
        } else if [36, 76].contains(event.keyCode) {
            if let action = (page.rows + page.footer).first(where: { $0.enabled && $0.id == focus })
                ?? (page.rows + page.footer).first(where: { $0.enabled && $0.primary }) { handle(action.id) }
        } else if draft != nil, event.keyCode == 51 { draft = String(draft!.dropLast()) }
        else if draft != nil, event.modifierFlags.intersection([.command, .control, .option]).isEmpty, let characters = event.characters {
            draft = String((draft! + AppleCloudLibraryTransport.cleanCode(characters)).prefix(12))
        } else { super.keyDown(with: event) }
        needsDisplay = true
    }
    /// Password text is free-form, so it bypasses the device-code filter.
    private func handlePasswordKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .control, .option])
        if flags == .command, event.charactersIgnoringModifiers?.lowercased() == "v" {
            let pasted = (NSPasteboard.general.string(forType: .string) ?? "").filter { !$0.isNewline }
            password = String((password! + pasted).prefix(CloudSyncArt.passwordMaximum))
        } else if event.keyCode == 51 { password = String(password!.dropLast()) }
        else if flags.isEmpty, ![36, 76, 53, 48].contains(event.keyCode) {
            // Drop control characters and the private-use codes of arrow and function keys.
            let typed = (event.characters ?? "").filter { character in
                character.unicodeScalars.allSatisfy { $0.value >= 0x20 && $0.value != 0x7F && !(0xF700...0xF8FF).contains($0.value) }
            }
            guard !typed.isEmpty else { return false }
            password = String((password! + typed).prefix(CloudSyncArt.passwordMaximum))
        } else { return false }
        return true
    }
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityChildren() -> [Any]? {
        let layout = pageLayout
        var elements: [Any] = [accessible.element(id: "status", owner: self, label: page.subtitle, frame: layout.subtitle)]
        for (index, detail) in page.details.enumerated() {
            elements.append(accessible.element(id: "detail-\(index)", owner: self, label: detail, frame: layout.details[index]))
        }
        for target in layout.targets {
            let id = target.action.id
            let element = accessible.element(id: id, owner: self, label: target.action.title, frame: target.frame,
                press: target.action.enabled ? { [weak self] in self?.handle(id) } : nil)
            element.setAccessibilityEnabled(target.action.enabled)
            element.onFocus = { [weak self] in self?.focus = id; self?.needsDisplay = true }
            if id == "syncPasswordField" {
                element.setAccessibilityRole(.textField)
                element.setAccessibilitySubrole(.secureTextField)
                element.readValue = { [weak self] in CloudSyncArt.masked(self?.password ?? "") }
                element.writeValue = { [weak self] value in self?.password = String(value.prefix(CloudSyncArt.passwordMaximum)); self?.needsDisplay = true }
            }
            if id == "syncCodeField" {
                element.setAccessibilityRole(.textField)
                element.readValue = { [weak self] in self?.draft ?? "" }
                element.writeValue = { [weak self] value in self?.draft = String(AppleCloudLibraryTransport.cleanCode(value).prefix(12)); self?.needsDisplay = true }
            }
            elements.append(element)
        }
        return elements
    }
    func handle(_ id: String) {
        guard (page.rows + page.footer).contains(where: { $0.id == id && $0.enabled }) else { return }
        message = ""
        switch id {
        case "syncBack": onBack?()
        case "syncToggle": sync.enabled.toggle()
        case "syncCancel": code = nil; draft = nil; password = nil; focus = nil
        case "syncEnterCode": draft = ""; focus = "syncCodeField"
        case "syncCodeField", "syncPasswordField": focus = id
        case "syncEnterPassword": password = ""; focus = "syncPasswordField"
        case "syncCopy":
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(code ?? "", forType: .string); message = L10n.text("Copied")
        case "syncExportKey", "syncImportKey":
            guard let window else { break }
            busy = true
            Task { [weak self] in
                guard let self else { return }
                do {
                    if id == "syncExportKey" {
                        let data = try sync.recoveryData()
                        let panel = NSSavePanel(); panel.nameFieldStringValue = "Ultimate Lemmings Recovery.lemmingssync"
                        panel.message = L10n.text("Keep this recovery key private. It grants access to every profile and Hot Seat in your library.")
                        let response: NSApplication.ModalResponse = await withCheckedContinuation { continuation in
                            panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
                        }
                        if response == .OK, let url = panel.url { try data.write(to: url, options: .atomic); message = L10n.text("Recovery key saved") }
                    } else {
                        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
                        let response: NSApplication.ModalResponse = await withCheckedContinuation { continuation in
                            panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
                        }
                        if response == .OK, let url = panel.url {
                            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 16385
                            guard size <= 16384 else { throw CocoaError(.fileReadCorruptFile) }
                            try sync.restoreRecoveryData(Data(contentsOf: url)); await sync.syncNow()
                        }
                    }
                } catch { message = error.localizedDescription }
                busy = false; needsDisplay = true
            }
        case "syncNow", "syncMakeLink", "syncJoin", "syncJoinPassword":
            busy = true
            Task { [weak self] in
                guard let self else { return }
                do {
                    if id == "syncNow" { await sync.syncNow() }
                    else if id == "syncMakeLink" { code = try await sync.makeLink(); focus = "syncCopy" }
                    else if id == "syncJoinPassword" { try await sync.joinPassword(password ?? ""); password = nil }
                    else { try await sync.join(draft ?? ""); draft = nil; await sync.syncNow() }
                } catch { message = error.localizedDescription }
                busy = false; needsDisplay = true
            }
        default: break
        }
        needsDisplay = true
    }
}
#endif
