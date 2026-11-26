#if os(macOS)
import AppKit
import LemmingsAppCore
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
        } else {
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            NSGraphicsContext.current?.cgContext.setAlpha(enabled ? 1 : 0.45)
            GamePixelText.draw(MacInterfaceRenderer.menuText(text), in: rect, maxScale: role == .title ? 3 : 2,
                               palette: role.palette, alignment: alignment)
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
    override func accessibilityLabel() -> String? {
        super.accessibilityLabel().map { GamePresentationText.display($0) }
    }
    override func accessibilityTitle() -> String? {
        super.accessibilityTitle().map { GamePresentationText.display($0) }
    }
    override func accessibilityValue() -> Any? {
        let value = super.accessibilityValue()
        return (value as? String).map { GamePresentationText.display($0) } ?? value
    }
    var isCheck: Bool { false }
    override var acceptsFirstResponder: Bool { isEnabled }
    override func becomeFirstResponder() -> Bool { needsDisplay = true; return super.becomeFirstResponder() }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return super.resignFirstResponder() }
    override var intrinsicContentSize: NSSize {
        let plain = MacInterfaceRenderer.menuText(title)
        let width = GameMenuArtwork.renderer()?.width(of: plain, face: .small, scale: 1)
            ?? CGFloat(GamePixelTypography.width(of: plain) + 1) * 2
        let bounds = GamePixelTypography.verticalBounds(of: plain)
        let height = GameMenuArtwork.renderer()?.height(of: title, face: .small, scale: 1) ?? CGFloat(max(18, bounds.bottom - bounds.top + 4))
        return NSSize(width: width + (isCheck ? 32 : 24), height: max(28, height + 4, super.intrinsicContentSize.height))
    }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let selected = state == .on || state == .mixed || isHighlighted
        let socket = isCheck ? CGRect(x: 2, y: floor(bounds.midY) - 8, width: 16, height: 16) : bounds
        let lixCheck = isCheck && GameArtworkSkin.usesLixInterface && NSGraphicsContext.current.map {
            GameLixInterfaceArt.drawCheckbox(checked: state != .off, in: socket, context: $0.cgContext,
                selected: isHighlighted, enabled: isEnabled)
        } == true
        if isCheck, !lixCheck, let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.setAlpha(isEnabled ? 1 : 0.45)
            context.setFillColor(CGColor(gray: 0.08, alpha: 1))
            context.fill(socket)
            context.setStrokeColor(CGColor(gray: isHighlighted ? 0.95 : 0.60, alpha: 1))
            context.setLineWidth(1)
            context.stroke(socket.insetBy(dx: 0.5, dy: 0.5))
            context.setFillColor(CGColor(srgbRed: 0.72, green: 0.86, blue: 0.45, alpha: 1))
            if state == .mixed {
                context.fill(CGRect(x: socket.minX + 4, y: socket.midY - 1, width: 8, height: 2))
            } else if state == .on {
                for step in 0..<9 {
                    let y = step < 3 ? 7 + step : 12 - step
                    context.fill(CGRect(x: socket.minX + 4 + CGFloat(step), y: socket.minY + CGFloat(y), width: 1, height: 2))
                }
            }
            context.restoreGState()
        } else if !isCheck {
            GameStoneButton.draw(socket, selected: selected, pixel: 1)
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
        focusRingType = .none
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

@MainActor final class GameLabel: NSTextField {
    override func accessibilityLabel() -> String? {
        super.accessibilityLabel().map { GamePresentationText.display($0) }
    }
    override func accessibilityTitle() -> String? {
        super.accessibilityTitle().map { GamePresentationText.display($0) }
    }
    override func accessibilityValue() -> String? {
        super.accessibilityValue().map { GamePresentationText.display($0) }
    }
    var role: GameTypography.Role = .body {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }
    private var measuredWidth: CGFloat = 0
    /// Wrapped body text reads in its authored case. Titles, headings and actions stay in capitals.
    private var reading: Bool { cell?.wraps == true && role == .body }
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
        let lines = cell?.wraps == true ? GameTextLayout.lines(stringValue, width: width, face: role.face, font: face,
            preservesCase: reading).count : 1
        let spacing = max(face.cellHeight + 6, face.height(of: MacInterfaceRenderer.menuText(stringValue)) + 2)
        return NSSize(width: natural, height: CGFloat(max(1, lines) * spacing))
    }
    override func layout() {
        super.layout()
        if bounds.width != measuredWidth { measuredWidth = bounds.width; invalidateIntrinsicContentSize() }
    }
    override func draw(_ dirtyRect: NSRect) {
        if cell?.wraps == true, let renderer = GameMenuArtwork.renderer(), bounds.height >= 32 {
            renderer.menuParagraph(stringValue, in: bounds, alignment: reading ? .left : alignment, face: role.face,
                palette: role.palette, alpha: isEnabled ? 1 : 0.45, preservesCase: reading)
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
        setAccessibilityLabel(L10n.text("Add favourite"))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    @objc private func invoke() { onPress?() }
    override var intrinsicContentSize: NSSize { NSSize(width: 44, height: 44) }
    override func draw(_ dirtyRect: NSRect) {
        GameStoneButton.draw(bounds, selected: isHighlighted, pixel: 1)
        if let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.setAlpha(isEnabled ? 1 : 0.45)
            GameStarArt.draw(in: bounds, earned: state == .on, context: context)
            context.restoreGState()
        }
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
            renderer.menuParagraph(string, in: bounds.insetBy(dx: 5, dy: 5), alignment: .left, preservesCase: true)
        } else { GamePixelText.draw(string, in: bounds) }
    }
}

/// A flat frame groups related options without adding another input target.
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
        setAccessibilityLabel(GamePresentationText.display(label))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        GameDisplayPanel.draw(bounds)
    }
}

@MainActor final class GameSliderCell: NSSliderCell {
    var trackMarks: [Double]?
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        if !isEnabled { NSGraphicsContext.current?.cgContext.setAlpha(0.45) }
        GameStoneButton.draw(CGRect(x: rect.minX, y: rect.midY - 3, width: rect.width, height: 6), selected: true, pixel: 1)
        if let trackMarks, let context = NSGraphicsContext.current?.cgContext, maxValue > minValue {
            let progress = (doubleValue - minValue) / (maxValue - minValue)
            context.setFillColor(CGColor(srgbRed: 0.48, green: 0.80, blue: 0.24, alpha: 1))
            context.fill(CGRect(x: rect.minX + 1, y: floor(rect.midY) - 1,
                width: floor(max(0, rect.width - 2) * progress), height: 2))
            let knob = knobRect(flipped: flipped)
            let travel = rect.insetBy(dx: knob.width / 2, dy: 0)
            let direction: CGFloat = flipped ? 1 : -1
            let tip = floor(flipped ? knob.maxY : knob.minY) + 3 * direction
            context.setFillColor(CGColor(srgbRed: 1, green: 0.76, blue: 0.28, alpha: 1))
            for mark in trackMarks {
                let center = floor(travel.minX + travel.width * mark)
                for row in 0..<9 {
                    let halfWidth = 4 - abs(4 - row)
                    let y = tip + CGFloat(flipped ? row : -row - 1)
                    context.fill(CGRect(x: center - CGFloat(halfWidth), y: y, width: CGFloat(2 * halfWidth + 1), height: 1))
                }
            }
        }
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
    override func accessibilityTitle() -> String? {
        super.accessibilityTitle().map { GamePresentationText.display($0) }
    }
    override func accessibilityValue() -> Any? {
        let value = super.accessibilityValue()
        return (value as? String).map { GamePresentationText.display($0) } ?? value
    }
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
        GameControlText.draw(titleOfSelectedItem ?? "", in: CGRect(x: 10, y: 2,
            width: max(1, bounds.width - 36), height: bounds.height - 4), enabled: isEnabled)
        if let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.setFillColor(CGColor(gray: 0.80, alpha: isEnabled ? 1 : 0.45))
            let x = floor(bounds.maxX - 13), y = floor(bounds.midY - 3)
            for step in 0..<5 {
                let offset = CGFloat(4 - step)
                let row = y + CGFloat(step)
                context.fill([CGRect(x: x - offset, y: row, width: 1, height: 2),
                    CGRect(x: x + offset, y: row, width: 1, height: 2)])
            }
            context.restoreGState()
        }
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

@MainActor final class GameTabButton: GameButton {
    var inSidebar = false
    override func draw(_ dirtyRect: NSRect) {
        guard inSidebar else { super.draw(dirtyRect); return }
        GameStoneButton.draw(bounds, selected: state == .on || isHighlighted, pixel: 1)
        GameControlText.draw(title, in: bounds.insetBy(dx: 12, dy: 4), enabled: isEnabled,
            role: state == .on ? .heading : .body)
        if state == .on {
            GameStyle.fill(CGRect(x: 12, y: bounds.maxY - 7, width: bounds.width - 24, height: 2), GameStyle.accent)
        }
        GameControlText.focus(self)
    }
}

@MainActor final class GameTabs: NSView, NSTabViewDelegate {
    var onSelectionChanged: (() -> Void)?
    private let tabs = NSTabView()
    private var buttons: [GameButton] = []
    var font: NSFont?
    var sidebarBreaks: Set<Int>?
    private(set) var sidebarFooterFrame: CGRect = .zero
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
    @discardableResult func addTabViewItem(_ item: NSTabViewItem) -> GameTabButton {
        tabs.addTabViewItem(item)
        let button = GameTabButton(title: item.label, target: self, action: #selector(selectTab))
        button.inSidebar = sidebarBreaks != nil
        button.tag = buttons.count
        button.setButtonType(.pushOnPushOff)
        button.setAccessibilityLabel(item.label)
        button.setAccessibilityRole(.radioButton)
        addSubview(button); buttons.append(button)
        updateSelection()
        return button
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
        let widths = buttons.map { $0.intrinsicContentSize.width }
        if let sidebarBreaks {
            let width = min(floor(bounds.width / 3), max(220, widths.max() ?? 0))
            let detailsX = width + 24
            tabs.frame = CGRect(x: detailsX, y: 0, width: max(0, bounds.width - detailsX), height: bounds.height)
            var y = bounds.height
            for (index, button) in buttons.enumerated() {
                if sidebarBreaks.contains(index) { y -= 12 }
                button.frame = CGRect(x: 0, y: y - 38, width: width, height: 38)
                y -= 44
            }
            sidebarFooterFrame = CGRect(x: 0, y: y - 14, width: width, height: 0)
            return
        }
        tabs.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - 42))
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
        GameStyle.fill(bounds, NSColor(calibratedWhite: 0.045, alpha: 1))
        let focused = window?.firstResponder === currentEditor()
        (focused ? NSColor.white : NSColor(calibratedWhite: 0.48, alpha: 1)).setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()
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
