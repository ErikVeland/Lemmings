#if os(macOS)
import AppKit
#if canImport(NxlvKit)
import NxlvKit
#endif
import LemmingsAppCore
import LemmingsGameArt

@MainActor final class CloudLibraryView: NSView, GameDialogCustomNavigation, NSSearchFieldDelegate {
    let sync: CloudLibrarySync
    private let typography: GameMenuTypography?
    private let accessible = GameAccessibleElements()
    private var message = ""
    private var busy = false
    private var focus: String? = "syncMake"
    private var code = ""
    private var draft: String?
    private let codeField = GameSearchField(frame: .zero)
    var onBack: (() -> Void)?
    var page: GameFrontEnd.Page {
        CloudSyncArt.page(testerEnabled: sync.testerSyncEnabled, busy: busy, message: message, status: sync.status, code: code, draft: draft)
    }
    var pageLayout: GameFrontEnd.Layout { GameFrontEnd.layout(page, width: bounds.width, minimumHeight: bounds.height) }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    init(sync: CloudLibrarySync, typography: GameMenuTypography? = nil) {
        self.sync = sync
        self.typography = typography ?? Bundle.main.resourceURL.flatMap { GameMenuTypography(directory: $0.appendingPathComponent("MacArtwork/lemmings")) }
        super.init(frame: CGRect(x: 0, y: 0, width: 1120, height: 720))
        codeField.delegate = self
        codeField.placeholderString = L10n.text("12-character code")
        codeField.setAccessibilityLabel(L10n.text("12-character code"))
        codeField.isHidden = true
        addSubview(codeField)
    }
    required init?(coder: NSCoder) { nil }
    override func layout() {
        super.layout()
        codeField.isHidden = draft == nil
        codeField.isEnabled = !busy
        if let target = pageLayout.targets.first(where: { $0.action.id == "syncCode" }) {
            codeField.frame = target.frame
        }
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) { handle("syncJoin"); return true }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { handle("syncCancel"); return true }
        return false
    }
    func controlTextDidChange(_ notification: Notification) {
        draft = String(AppleCloudLibraryTransport.cleanCode(codeField.stringValue).prefix(12))
        codeField.stringValue = draft ?? ""
        needsDisplay = true
    }
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
        if event.keyCode == 53 { handle(draft != nil || !code.isEmpty ? "syncCancel" : "syncBack") }
        else if [48, 123, 124, 125, 126].contains(event.keyCode) {
            let actions = (page.rows + page.footer).filter(\.enabled)
            let backward = event.keyCode == 48 ? event.modifierFlags.contains(.shift) : [123, 126].contains(event.keyCode)
            let index = actions.firstIndex { $0.id == focus } ?? (backward ? 0 : -1)
            if !actions.isEmpty { focus = actions[(index + (backward ? -1 : 1) + actions.count) % actions.count].id }
        } else if [36, 76].contains(event.keyCode) {
            let selected = focus
            if let action = (page.rows + page.footer).first(where: { $0.enabled && $0.id == selected })
                ?? (page.rows + page.footer).first(where: { $0.enabled && $0.primary }) { handle(action.id) }
        } else { super.keyDown(with: event) }
        needsDisplay = true
    }
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityChildren() -> [Any]? {
        let layout = pageLayout
        var elements: [Any] = [accessible.element(id: "status", owner: self, label: page.subtitle, frame: layout.subtitle)]
        for (index, detail) in page.details.enumerated() {
            elements.append(accessible.element(id: "detail-\(index)", owner: self, label: detail, frame: layout.details[index]))
        }
        if draft != nil { elements.append(codeField) }
        for target in layout.targets where target.action.id != "syncCode" {
            let id = target.action.id
            let element = accessible.element(id: id, owner: self, label: target.action.title, frame: target.frame,
                press: target.action.enabled ? { [weak self] in self?.handle(id) } : nil)
            element.setAccessibilityEnabled(target.action.enabled)
            element.onFocus = { [weak self] in self?.focus = id; self?.needsDisplay = true }
            elements.append(element)
        }
        return elements
    }
    func handle(_ id: String) {
        guard (page.rows + page.footer).contains(where: { $0.id == id && $0.enabled }) else { return }
        message = ""
        switch id {
        case "syncBack": onBack?()
        case "syncCancel":
            draft = nil; code = ""; codeField.stringValue = ""; focus = "syncMake"
            window?.makeFirstResponder(self)
        case "syncEnter":
            draft = ""; codeField.stringValue = ""; needsLayout = true; layoutSubtreeIfNeeded()
            window?.makeFirstResponder(codeField)
        case "syncCode": window?.makeFirstResponder(codeField)
        case "syncMake", "syncJoin":
            let input = draft ?? ""
            busy = true
            Task { [weak self] in
                guard let self else { return }
                do {
                    if id == "syncMake" { code = try await sync.makeLink() }
                    else { try await sync.join(input); draft = nil; message = L10n.text("Device linked") }
                } catch { message = error.localizedDescription }
                busy = false; focus = draft == nil && code.isEmpty ? "syncBack" : "syncCancel"; needsDisplay = true; needsLayout = true
            }
        default: break
        }
        needsDisplay = true; needsLayout = true
    }
}
#endif
