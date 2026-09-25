import AppKit

/// Game artwork supplies the visible controls; AppKit retains input and accessibility.
@MainActor enum GameControlText {
    static func draw(_ text: String, in rect: CGRect, alignment: NSTextAlignment = .left, enabled: Bool = true, role: GameTypography.Role = .body) {
        if let renderer = GameMenuArtwork.renderer() {
            let height = renderer.height(face: role.face, scale: 1)
            renderer.menuLine(text, in: CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height),
                face: role.face, alignment: alignment, alpha: enabled ? 1 : 0.45, palette: role.palette)
        } else { GamePixelText.draw(MacInterfaceRenderer.menuText(text), in: rect, maxScale: role == .title ? 3 : 1, palette: role.palette) }
    }
    static func focus(_ control: NSControl) {
        guard control.window?.firstResponder === control else { return }
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: control.bounds.insetBy(dx: 2, dy: 2))
        path.lineWidth = 2
        path.setLineDash([3, 3], count: 2, phase: 0)
        path.stroke()
    }
}

@MainActor class GameButton: NSButton {
    var isCheck: Bool { false }
    override var intrinsicContentSize: NSSize {
        let width = GameMenuArtwork.renderer()?.width(of: MacInterfaceRenderer.menuText(title), face: .small, scale: 1) ?? CGFloat(title.count * 8)
        return NSSize(width: width + (isCheck ? 32 : 24), height: max(28, super.intrinsicContentSize.height))
    }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let selected = state == .on || isHighlighted
        let socket = isCheck ? CGRect(x: 0, y: bounds.midY - 10, width: 20, height: 20) : bounds
        GameStoneButton.draw(socket, selected: selected, pixel: 1)
        if isCheck && selected {
            GamePixelText.draw("X", in: socket.insetBy(dx: 5, dy: 5))
        }
        let caption = isCheck ? CGRect(x: 28, y: 0, width: bounds.width - 28, height: bounds.height) : bounds.insetBy(dx: 8, dy: 2)
        GameControlText.draw(title, in: caption, alignment: isCheck ? .left : .center, enabled: isEnabled, role: selected ? .heading : .body)
        GameControlText.focus(self)
    }
}

@MainActor final class GameCheckButton: GameButton {
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        performClick(nil)
        return true
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        window?.makeFirstResponder(self)
        var inside = bounds.contains(convert(event.locationInWindow, from: nil))
        highlight(inside)
        defer { highlight(false) }
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            inside = bounds.contains(convert(next.locationInWindow, from: nil))
            highlight(inside)
            if next.type == .leftMouseUp {
                if inside { performClick(nil) }
                return
            }
        }
    }
    override var isCheck: Bool { true }
    init(title: String, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.title = title; self.target = target; self.action = action
        setButtonType(.switch)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

@MainActor final class GameLabel: NSTextField {
    var role: GameTypography.Role = .body {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }
    private var measuredWidth: CGFloat = 0
    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize {
        guard let renderer = GameMenuArtwork.renderer(), let face = renderer.font(role.face) else { return NSSize(width: CGFloat(stringValue.count * 6), height: 13) }
        let natural = renderer.width(of: MacInterfaceRenderer.menuText(stringValue), face: role.face, scale: 1)
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width > 0 ? bounds.width : 600
        let lines = cell?.wraps == true ? MacInterfaceRenderer.menuLines(stringValue, columns: max(1, Int(width) / face.cellWidth)).count : 1
        return NSSize(width: natural, height: CGFloat(max(1, lines) * (face.cellHeight + 6)))
    }
    override func layout() {
        super.layout()
        if bounds.width != measuredWidth { measuredWidth = bounds.width; invalidateIntrinsicContentSize() }
    }
    override func draw(_ dirtyRect: NSRect) {
        if cell?.wraps == true, let renderer = GameMenuArtwork.renderer(), bounds.height >= 32 {
            renderer.menuParagraph(stringValue, in: bounds, alignment: alignment, face: role.face, palette: role.palette, alpha: isEnabled ? 1 : 0.45)
        } else {
            GameControlText.draw(stringValue, in: bounds, alignment: alignment, enabled: isEnabled, role: role)
        }
    }
}

@MainActor final class GameReadOnlyText: NSTextView {
    override func draw(_ dirtyRect: NSRect) {
        if let renderer = GameMenuArtwork.renderer() {
            renderer.menuParagraph(string, in: bounds.insetBy(dx: 5, dy: 5), alignment: .left)
        } else { GamePixelText.draw(string, in: bounds) }
    }
}

@MainActor final class GameSliderCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        GameStoneButton.draw(CGRect(x: rect.minX, y: rect.midY - 3, width: rect.width, height: 6), selected: true, pixel: 1)
    }
    override func drawKnob(_ knobRect: NSRect) {
        GameStoneButton.draw(knobRect, selected: isHighlighted, pixel: 1)
    }
}

@MainActor final class GameSlider: NSSlider {
    override class var cellClass: AnyClass? { get { GameSliderCell.self } set {} }
}

/// Choices open in a scrollable game page, including when activated by keyboard.
@MainActor final class GamePopUpButton: NSPopUpButton {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        GameStoneButton.draw(bounds, selected: false, pixel: 1)
        GameControlText.draw(titleOfSelectedItem ?? "", in: bounds.insetBy(dx: 12, dy: 2).offsetBy(dx: -4, dy: 0), enabled: isEnabled)
        GamePixelText.draw(">", in: CGRect(x: bounds.maxX - 18, y: bounds.midY - 6, width: 10, height: 12))
        GameControlText.focus(self)
    }
    override func mouseDown(with event: NSEvent) { showChoices() }
    override func performClick(_ sender: Any?) { showChoices() }
    override func keyDown(with event: NSEvent) {
        if [36, 49, 125, 126].contains(event.keyCode) { showChoices() }
        else { super.keyDown(with: event) }
    }
    private func showChoices() {
        guard isEnabled, numberOfItems > 0, let window else { return }
        let page = GameMenuPage(title: accessibilityLabel() ?? "Choose")
        page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        let scroll = NSScrollView(frame: page.body.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let list = NSView(frame: CGRect(x: 0, y: 0, width: 940, height: max(440, numberOfItems * 44)))
        for (index, item) in itemArray.enumerated() {
            let button = GameActionButton(title: item.title, primary: index == indexOfSelectedItem) { [weak self, weak page] in
                guard let self else { return }
                selectItem(at: index)
                if let page { GameScreen.shared.dismiss(page) }
                _ = sendAction(action, to: target)
                needsDisplay = true
            }
            button.isEnabled = item.isEnabled
            button.frame = CGRect(x: 6, y: list.bounds.height - CGFloat(index + 1) * 44, width: 920, height: 38)
            list.addSubview(button)
        }
        scroll.documentView = list; page.body.addSubview(scroll)
        GameScreen.shared.present(page, owner: window)
        scroll.contentView.scroll(to: CGPoint(x: 0, y: max(0, list.bounds.height - scroll.contentSize.height)))
    }
}

@MainActor final class GameTabButton: GameButton {}

@MainActor final class GameTabs: NSView, NSTabViewDelegate {
    private let tabs = NSTabView()
    private var buttons: [GameButton] = []
    var font: NSFont?
    override init(frame: NSRect) {
        super.init(frame: frame)
        tabs.tabViewType = .noTabsNoBorder
        tabs.delegate = self
        addSubview(tabs)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func addTabViewItem(_ item: NSTabViewItem) {
        tabs.addTabViewItem(item)
        let button = GameTabButton(title: item.label, target: self, action: #selector(selectTab))
        button.tag = buttons.count
        button.setButtonType(.pushOnPushOff)
        button.setAccessibilityLabel(item.label)
        addSubview(button); buttons.append(button)
        updateSelection()
    }
    @objc private func selectTab(_ sender: NSButton) {
        tabs.selectTabViewItem(at: sender.tag); updateSelection()
    }
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) { updateSelection() }
    private func updateSelection() {
        for (index, button) in buttons.enumerated() {
            button.state = tabs.selectedTabViewItem === tabs.tabViewItems[index] ? .on : .off
            button.needsDisplay = true
        }
    }
    override func layout() {
        super.layout()
        tabs.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - 42))
        let widths = buttons.map { $0.intrinsicContentSize.width }
        let extra = max(0, (bounds.width - widths.reduce(0, +)) / CGFloat(max(1, buttons.count)))
        var x: CGFloat = 0
        for (index, button) in buttons.enumerated() {
            let width = widths[index] + extra
            button.frame = CGRect(x: x, y: bounds.height - 38, width: width - 4, height: 34)
            x += width
        }
    }
}

@MainActor final class GameStarView: NSView {
    var earned = false
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let pixel = max(1, floor(min(bounds.width / 11, bounds.height / 9)))
        GameStar.draw(at: CGPoint(x: bounds.midX - 5.5 * pixel, y: bounds.midY - 4.5 * pixel), earned: earned, size: pixel)
    }
}

@MainActor final class GameProgressIndicator: NSProgressIndicator {
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.18, alpha: 1).setFill(); bounds.fill()
        GameStyle.accent.setFill()
        CGRect(x: 0, y: 0, width: bounds.width * max(0, min(1, doubleValue / max(1, maxValue))), height: bounds.height).fill()
    }
}

/// AppKit keeps text input, selection and undo; only game glyphs are painted.
@MainActor final class GameFieldEditor: NSTextView {
    private var cellWidth: CGFloat { CGFloat(GameMenuArtwork.renderer()?.font(.small)?.cellWidth ?? 8) }
    private var cellHeight: CGFloat { CGFloat(GameMenuArtwork.renderer()?.font(.small)?.cellHeight ?? 14) }
    private var textOrigin: CGPoint { CGPoint(x: textContainerOrigin.x, y: bounds.midY - cellHeight / 2) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); bounds.fill()
        let selection = selectedRange()
        if selection.length > 0 {
            NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.12, alpha: 1).setFill()
            CGRect(x: textOrigin.x + CGFloat(selection.location) * cellWidth, y: textOrigin.y,
                width: CGFloat(selection.length) * cellWidth, height: cellHeight).fill()
        }
        GameTypography.annotation(string, at: textOrigin, palette: .blue)
    }
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard flag else { needsDisplay = true; return }
        NSColor.green.setFill()
        CGRect(x: textOrigin.x + CGFloat(selectedRange().location) * cellWidth,
            y: textOrigin.y, width: 1, height: cellHeight).fill()
    }
    func prepare() {
        isFieldEditor = true; isRichText = false; drawsBackground = false
        // Match invisible AppKit layout metrics to the bitmap cells for hit testing.
        let metricFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let advance = ("M" as NSString).size(withAttributes: [.font: metricFont]).width
        font = NSFont.monospacedSystemFont(ofSize: 12 * cellWidth / advance, weight: .regular)
    }
}

@MainActor final class GameSearchFieldCell: NSSearchFieldCell {
    private let editor = GameFieldEditor()
    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        editor.prepare()
        return editor
    }
}

@MainActor final class GameSearchField: NSSearchField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        cell = GameSearchFieldCell(textCell: "")
        isEditable = true; isSelectable = true
        (cell as? NSTextFieldCell)?.isScrollable = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        GameStoneButton.draw(bounds, selected: window?.firstResponder === currentEditor(), pixel: 1)
        GameControlText.draw(stringValue.isEmpty ? (placeholderString ?? "Search") : stringValue,
            in: bounds.insetBy(dx: 10, dy: 2))
    }
}

@MainActor final class GameTableHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        GameStoneButton.draw(cellFrame, selected: false, pixel: 1)
        GameControlText.draw(stringValue, in: cellFrame.insetBy(dx: 8, dy: 2), role: .heading)
    }
}
