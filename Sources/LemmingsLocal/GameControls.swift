#if os(macOS)
import AppKit
import LemmingsGameArt
#if canImport(NxlvKit)
import NxlvKit
#endif

/// Game artwork supplies the visible controls; AppKit retains input and accessibility.
@MainActor enum GameControlText {
    static func draw(_ text: String, in rect: CGRect, alignment: NSTextAlignment = .left, enabled: Bool = true, role: GameTypography.Role = .body) {
        if let renderer = GameMenuArtwork.renderer() {
            let height = renderer.height(of: text, face: role.face, scale: 1)
            renderer.menuLine(text, in: CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height),
                face: role.face, alignment: alignment, alpha: enabled ? 1 : 0.45, palette: role.palette)
        } else if let context = NSGraphicsContext.current?.cgContext {
            GamePixelTypography.draw(MacInterfaceRenderer.menuText(text), in: rect, context: context, typography: nil,
                palette: role.palette == .blue ? .blue : .green, maximumScale: role == .title ? 3 : 1,
                alignment: alignment == .left ? .left : alignment == .right ? .right : .center,
                alpha: enabled ? 1 : 0.45, bitmapOnly: true)
        }
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
    override var acceptsFirstResponder: Bool { isEnabled }
    override func becomeFirstResponder() -> Bool { needsDisplay = true; return super.becomeFirstResponder() }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return super.resignFirstResponder() }
    override var intrinsicContentSize: NSSize {
        let plain = MacInterfaceRenderer.menuText(title)
        let width = GameMenuArtwork.renderer()?.width(of: plain, face: .small, scale: 1)
            ?? ceil(CGFloat(GamePixelTypography.width(of: plain) + 1) * 4 / 3)
        let bounds = GamePixelTypography.verticalBounds(of: plain)
        let height = GameMenuArtwork.renderer()?.height(of: title, face: .small, scale: 1) ?? CGFloat(max(18, bounds.bottom - bounds.top + 4))
        return NSSize(width: width + (isCheck ? 32 : 24), height: max(28, height + 4, super.intrinsicContentSize.height))
    }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let selected = state == .on || state == .mixed || isHighlighted
        let socket = isCheck ? CGRect(x: 0, y: bounds.midY - 10, width: 20, height: 20) : bounds
        GameStoneButton.draw(socket, selected: selected, pixel: 1)
        if isCheck && selected {
            GamePixelText.draw(state == .mixed ? "-" : "X", in: socket.insetBy(dx: 5, dy: 5))
        }
        let caption = isCheck ? CGRect(x: 28, y: 0, width: bounds.width - 28, height: bounds.height) : bounds.insetBy(dx: 8, dy: 2)
        GameControlText.draw(title, in: caption, alignment: isCheck ? .left : .center, enabled: isEnabled, role: .body)
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
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width > 0 ? bounds.width : 600
        let plain = MacInterfaceRenderer.menuText(stringValue)
        guard let renderer = GameMenuArtwork.renderer(), let face = renderer.font(role.face) else {
            let glyphs = GamePixelTypography.verticalBounds(of: plain)
            let lines = cell?.wraps == true ? GamePixelTypography.lines(stringValue, width: width).count : 1
            return NSSize(width: CGFloat(GamePixelTypography.width(of: plain) + 1),
                height: CGFloat(max(1, lines) * max(13, glyphs.bottom - glyphs.top + 6)))
        }
        let natural = renderer.width(of: plain, face: role.face, scale: 1)
        let lines = cell?.wraps == true ? GameTextLayout.lines(stringValue, width: width, face: role.face, font: face).count : 1
        let spacing = max(face.cellHeight + 6, face.height(of: MacInterfaceRenderer.menuText(stringValue)) + 2)
        return NSSize(width: natural, height: CGFloat(max(1, lines) * spacing))
    }
    override func layout() {
        super.layout()
        if bounds.width != measuredWidth { measuredWidth = bounds.width; invalidateIntrinsicContentSize() }
    }
    override func draw(_ dirtyRect: NSRect) {
        if cell?.wraps == true, let renderer = GameMenuArtwork.renderer(), bounds.height >= 32 {
            renderer.menuParagraph(stringValue, in: bounds, alignment: alignment, face: role.face, palette: role.palette, alpha: isEnabled ? 1 : 0.45)
        } else if cell?.wraps == true, GameMenuArtwork.renderer() == nil {
            let lines = GamePixelTypography.lines(stringValue, width: bounds.width)
            let glyphs = GamePixelTypography.verticalBounds(of: MacInterfaceRenderer.menuText(stringValue))
            let pitch = CGFloat(max(13, glyphs.bottom - glyphs.top + 6))
            for (index, line) in lines.enumerated() {
                GameControlText.draw(line, in: CGRect(x: bounds.minX, y: bounds.minY + CGFloat(index) * pitch,
                    width: bounds.width, height: pitch), alignment: alignment, enabled: isEnabled, role: role)
            }
        } else {
            GameControlText.draw(stringValue, in: bounds, alignment: alignment, enabled: isEnabled, role: role)
        }
    }
}

@MainActor final class GameFavouriteButton: GameButton {
    var onPress: (() -> Void)?
    init(onPress: (() -> Void)? = nil) {
        self.onPress = onPress
        super.init(frame: .zero)
        title = L10n.text("Favourite"); target = self; action = #selector(invoke)
        setButtonType(.momentaryPushIn)
        setAccessibilityLabel(L10n.text("Favourite"))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    @objc private func invoke() { onPress?() }
    override func draw(_ dirtyRect: NSRect) {
        GameStoneButton.draw(bounds, selected: isHighlighted, pixel: 1)
        GameStar.draw(at: CGPoint(x: 10, y: bounds.midY - 11), earned: state == .on, size: 2)
        GameControlText.draw(title, in: CGRect(x: 40, y: 0, width: bounds.width - 46, height: bounds.height),
                             enabled: isEnabled, role: .body)
        GameControlText.focus(self)
    }
    func showSaved(_ saved: Bool) {
        state = saved ? .on : .off
        setAccessibilityLabel(saved ? L10n.text("Remove favourite") : L10n.text("Add favourite"))
        setAccessibilityValue(saved ? 1 : 0)
        needsDisplay = true
    }
}

@MainActor final class GameReadOnlyText: NSTextView {
    override func draw(_ dirtyRect: NSRect) {
        if let renderer = GameMenuArtwork.renderer() {
            renderer.menuParagraph(string, in: bounds.insetBy(dx: 5, dy: 5), alignment: .left)
        } else { GamePixelText.draw(string, in: bounds) }
    }
}

/// A stone frame groups related options without adding another input target.
@MainActor final class GameControlGroup: NSStackView {
    init(controls: [NSView], label: String) {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 0
        edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        controls.forEach { addArrangedSubview($0) }
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(label)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        GameStoneButton.draw(bounds, selected: false, pixel: 1)
    }
}

@MainActor final class GameSliderCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        if !isEnabled { NSGraphicsContext.current?.cgContext.setAlpha(0.45) }
        GameStoneButton.draw(CGRect(x: rect.minX, y: rect.midY - 3, width: rect.width, height: 6), selected: true, pixel: 1)
    }
    override func drawKnob(_ knobRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        if !isEnabled { NSGraphicsContext.current?.cgContext.setAlpha(0.45) }
        GameStoneButton.draw(knobRect, selected: isHighlighted, pixel: 1)
    }
}

@MainActor final class GameSlider: NSSlider {
    override class var cellClass: AnyClass? { get { GameSliderCell.self } set {} }
    override var acceptsFirstResponder: Bool { isEnabled }
    override func draw(_ dirtyRect: NSRect) { super.draw(dirtyRect); GameControlText.focus(self) }
}

/// Choices open in a scrollable game page, including when activated by keyboard.
@MainActor final class GamePopUpButton: NSPopUpButton {
    var onShowChoices: (() -> Void)?
    override var acceptsFirstResponder: Bool { isEnabled }
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        showChoices(); return true
    }
    override func accessibilityPerformShowMenu() -> Bool { accessibilityPerformPress() }
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
        if let onShowChoices { onShowChoices(); return }
        let page = GameMenuPage(title: accessibilityLabel() ?? L10n.text("Choose"))
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
            if index == indexOfSelectedItem { page.preferControllerControl(button) }
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
    var onSelectionChanged: (() -> Void)?
    private let tabs = NSTabView()
    private var buttons: [GameButton] = []
    var font: NSFont?
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(L10n.text("Settings sections"))
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
        button.setAccessibilityRole(.radioButton)
        addSubview(button); buttons.append(button)
        updateSelection()
    }
    @objc private func selectTab(_ sender: NSButton) {
        tabs.selectTabViewItem(at: sender.tag); updateSelection()
    }
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) { updateSelection() }
    private func updateSelection() {
        onSelectionChanged?()
        for (index, button) in buttons.enumerated() {
            button.state = tabs.selectedTabViewItem === tabs.tabViewItems[index] ? .on : .off
            button.setAccessibilityValue(button.state == .on ? 1 : 0)
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
    private var bitmapFont: ClassicMacUserInterface.Font? { GameMenuArtwork.renderer()?.font(.small) }
    private var cellWidth: CGFloat { CGFloat(bitmapFont?.cellWidth ?? 6) }
    private var plain: String { MacInterfaceRenderer.menuText(string) }
    private var tamil: Bool { BitmapTamilGlyphs.sequences(in: string).contains(where: BitmapTamilGlyphs.supports) }
    private var vertical: (top: Int, bottom: Int) { bitmapFont?.verticalBounds(of: plain) ?? GamePixelTypography.verticalBounds(of: plain) }
    private var cellHeight: CGFloat { CGFloat(max(14, vertical.bottom - vertical.top)) }
    private var textOrigin: CGPoint {
        let left = bitmapFont?.horizontalBounds(of: plain).left ?? GamePixelTypography.horizontalBounds(of: plain).left
        return CGPoint(x: textContainerOrigin.x - CGFloat(left),
            y: bounds.midY - CGFloat(vertical.bottom - vertical.top) / 2 - CGFloat(vertical.top))
    }

    private var insertionStops: [(index: Int, x: CGFloat)] {
        let characters = Array(string)
        var result: [(index: Int, x: CGFloat)] = [(0, 0)], characterIndex = 0, utf16 = 0, pen: CGFloat = 0
        for sequence in BitmapTamilGlyphs.sequences(in: string) {
            let count = min(sequence.count, characters.count - characterIndex)
            guard count > 0 else { continue }
            let visible = MacInterfaceRenderer.menuText(sequence)
            let advance = bitmapFont.map { $0.layout(visible).reduce(0) { $0 + $1.advance } }
                ?? GamePixelTypography.layout(visible).reduce(0) { $0 + $1.advance }
            for index in 0..<count {
                utf16 += String(characters[characterIndex + index]).utf16.count
                result.append((utf16, pen + CGFloat(advance) * CGFloat(index + 1) / CGFloat(count)))
            }
            pen += CGFloat(advance)
            characterIndex += count
        }
        return result
    }

    func bitmapInsertionX(atUTF16 offset: Int) -> CGFloat {
        let stops = insertionStops
        return stops.min { abs($0.index - offset) < abs($1.index - offset) }?.x ?? 0
    }

    func bitmapInsertionIndex(atX x: CGFloat) -> Int {
        insertionStops.min { abs($0.x - x) < abs($1.x - x) }?.index ?? 0
    }

    override func characterIndexForInsertion(at point: NSPoint) -> Int {
        tamil ? bitmapInsertionIndex(atX: point.x - textOrigin.x) : super.characterIndexForInsertion(at: point)
    }

    override func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard tamil, range.location != NSNotFound else { return super.firstRect(forCharacterRange: range, actualRange: actualRange) }
        let length = (string as NSString).length
        let start = min(length, range.location), end = min(length, range.location + min(range.length, length - start))
        actualRange?.pointee = NSRange(location: start, length: end - start)
        let x = bitmapInsertionX(atUTF16: start), right = bitmapInsertionX(atUTF16: end)
        let rect = CGRect(x: textOrigin.x + x, y: bounds.midY - cellHeight / 2, width: max(1, right - x), height: cellHeight)
        return window?.convertToScreen(convert(rect, to: nil)) ?? rect
    }

    override func mouseDown(with event: NSEvent) {
        guard tamil else { super.mouseDown(with: event); return }
        window?.makeFirstResponder(self)
        let index = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
        let granularity: NSSelectionGranularity = event.clickCount > 2 ? .selectByParagraph : event.clickCount == 2 ? .selectByWord : .selectByCharacter
        let proposed = NSRange(location: index, length: 0)
        let selection = selectedRange()
        let anchor = event.modifierFlags.contains(.shift)
            ? NSRange(location: index < selection.location ? NSMaxRange(selection) : selection.location, length: 0)
            : selectionRange(forProposedRange: proposed, granularity: granularity)
        func select(_ index: Int) {
            let edge = selectionRange(forProposedRange: NSRange(location: index, length: 0), granularity: granularity)
            setSelectedRange(NSUnionRange(anchor, edge))
            needsDisplay = true
            _ = scrollToVisible(CGRect(x: textOrigin.x + bitmapInsertionX(atUTF16: index),
                y: bounds.midY - cellHeight / 2, width: 2, height: cellHeight))
        }
        select(index)
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            select(characterIndexForInsertion(at: convert(next.locationInWindow, from: nil)))
            if next.type == .leftMouseUp { break }
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); bounds.fill()
        let selection = selectedRange()
        if selection.length > 0 {
            NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.12, alpha: 1).setFill()
            let first = bitmapInsertionX(atUTF16: selection.location), last = bitmapInsertionX(atUTF16: NSMaxRange(selection))
            CGRect(x: textOrigin.x + first, y: bounds.midY - cellHeight / 2,
                width: last - first, height: cellHeight).fill()
        }
        GameTypography.annotation(string, at: textOrigin, palette: .blue)
    }
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard flag else { needsDisplay = true; return }
        NSColor.green.setFill()
        CGRect(x: textOrigin.x + bitmapInsertionX(atUTF16: selectedRange().location),
            y: bounds.midY - cellHeight / 2, width: 1, height: cellHeight).fill()
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
        GameControlText.draw(stringValue.isEmpty ? (placeholderString ?? L10n.text("Search")) : stringValue,
            in: bounds.insetBy(dx: 10, dy: 2))
    }
}

@MainActor final class GameTableHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        GameStoneButton.draw(cellFrame, selected: false, pixel: 1)
        GameControlText.draw(stringValue, in: cellFrame.insetBy(dx: 8, dy: 2), role: .heading)
    }
}
#endif
