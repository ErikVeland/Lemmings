import AppKit

/// The real paused level remains visible beneath these annotations.
@MainActor final class KeyboardOverlayView: NSView {
    var anchors: () -> [(String, CGRect)] = { [] }
    var onClose: () -> Void = {}
    var onCommands: () -> Void = {}
    var onHints: () -> Void = {}
    private var cards: [(NSView, String)] = []
    private var buttons: [NSButton] = []
    override var acceptsFirstResponder: Bool { true }

    init(commands: [KeyboardCommand], modern: Bool, hints: Bool) {
        super.init(frame: .zero)
        setAccessibilityLabel("Keyboard overlay. The level is paused. Escape closes the overlay.")
        func card(_ title: String, _ text: String, _ position: String) {
            let box = NSView()
            box.wantsLayer = true
            box.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.82).cgColor
            box.layer?.cornerRadius = 0
            box.layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.7).cgColor
            box.layer?.borderWidth = 1
            let heading = GameLabel(labelWithString: title)
            heading.font = .systemFont(ofSize: 15 * GameAccessibility.scale, weight: .bold)
            heading.textColor = .systemGreen
            let label = GameLabel(wrappingLabelWithString: text)
            label.font = .monospacedSystemFont(ofSize: 13 * GameAccessibility.scale, weight: .medium)
            label.textColor = .white
            for view in [heading, label] { view.translatesAutoresizingMaskIntoConstraints = false; box.addSubview(view) }
            NSLayoutConstraint.activate([
                heading.topAnchor.constraint(equalTo: box.topAnchor, constant: 12), heading.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14), heading.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
                label.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 7), label.leadingAnchor.constraint(equalTo: heading.leadingAnchor), label.trailingAnchor.constraint(equalTo: heading.trailingAnchor), label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12)
            ])
            addSubview(box); cards.append((box, position))
        }
        card("KEYBOARD", "ESC / ?  CLOSE", "title")
        let camera = commands.filter { $0.group == "Camera" }.map { "\($0.keys)  \($0.action)" }.joined(separator: "\n")
        card("LOOK AROUND", camera, "camera")
        let variable = commands.contains { $0.keys.contains("Shift +") }
        card("TIME & SPEED", "Space  Pause / resume\nF      Fast-forward / normal speed" + (variable ? "\nHold F  Ramp to 10×; release to keep\nHold Shift  Temporary boost\nShift+[ / ]  Decrease / increase speed\nShift+\\     Immediately return to 1×" : ""), "speed")
        let skillRows = commands.filter { $0.group == "Skills" && $0.action.hasPrefix("Select ") }
        let skills = skillRows.map { "\($0.keys)  \($0.action.replacingOccurrences(of: "Select ", with: "").components(separatedBy: " (")[0])" }.joined(separator: "   •   ")
        card("SELECT A SKILL → CLICK A LEMMING", skills.isEmpty ? "Skill bindings appear when a level is loaded." : skills, "skills")
        let focus = modern ? "[ / ]  Focus unassigned lemmings\n\\      Focus last assignment\nReturn Repeat last skill" : "Number keys select skills.\nModern letter and focus shortcuts are off."
        card("ASSIGN & FOCUS", focus, "focus")
        let actions = commands.filter { $0.group != "Controller" && ["R", "Z", ", / .", "X", "− / +"].contains($0.keys) }.map { "\($0.keys)  \($0.action)" }.joined(separator: "\n")
        card("LEVEL CONTROLS", actions + "\nEsc  Save run and return to main menu\n     (after closing this overlay)", "actions")
        for (title, action) in [("Close (Esc)", #selector(closeOverlay)), ("All commands", #selector(allCommands))] + (hints ? [("Level hints", #selector(levelHints))] : []) {
            let button = GameButton(title: title, target: self, action: action)
            button.bezelStyle = .rounded
            if action == #selector(closeOverlay) { button.keyEquivalent = "\u{1b}" }
            addSubview(button); buttons.append(button)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func layout() {
        super.layout()
        let inset: CGFloat = 18
        let width = bounds.width
        let height = bounds.height
        let side = min(350 * GameAccessibility.scale, (width - 3 * inset) / 2)
        func measured(_ card: NSView, width: CGFloat) -> CGFloat {
            let labels = card.subviews.compactMap { $0 as? NSTextField }
            return labels.reduce(CGFloat(43)) { total, label in
                if let renderer = GameMenuArtwork.renderer(), let font = renderer.font(.small) {
                    return total + CGFloat(MacInterfaceRenderer.menuLines(label.stringValue, columns: max(1, Int(width - 28) / font.cellWidth)).count * (font.cellHeight + 6))
                }
                return total + label.intrinsicContentSize.height
            }
        }
        let title = cards.first { $0.1 == "title" }!.0
        let titleWidth = min(width - 2 * inset, 800 * GameAccessibility.scale)
        title.frame = NSRect(x: inset, y: height - inset - measured(title, width: titleWidth), width: titleWidth, height: measured(title, width: titleWidth))
        var x = inset
        let buttonY = title.frame.minY - 40
        for button in buttons { button.frame = NSRect(x: x, y: buttonY, width: 174, height: 30); x += 184 }
        let skills = cards.first { $0.1 == "skills" }!.0
        let floor = max(90, (anchors().map { $0.1.maxY }.max() ?? 54) + 36)
        skills.frame = NSRect(x: inset, y: floor, width: width - 2 * inset, height: measured(skills, width: width - 2 * inset))
        var upperBottom = buttonY - 14
        for (card, position) in cards where ["camera", "speed"].contains(position) {
            let h = measured(card, width: side)
            card.frame = NSRect(x: position == "camera" ? inset : width - side - inset, y: buttonY - 14 - h, width: side, height: h)
            upperBottom = min(upperBottom, card.frame.minY)
        }
        for (card, position) in cards where ["focus", "actions"].contains(position) {
            let h = measured(card, width: side)
            card.frame = NSRect(x: position == "focus" ? inset : width - side - inset, y: skills.frame.maxY + 14, width: side, height: h)
            card.isHidden = card.frame.maxY + 24 > upperBottom
        }
        let compact = skills.frame.maxY + 24 > upperBottom
        for (card, position) in cards where ["camera", "speed", "focus", "actions"].contains(position) {
            if compact { card.isHidden = true }
            else if position == "camera" || position == "speed" { card.isHidden = false }
        }
        skills.isHidden = skills.frame.maxY + 14 > buttonY
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.22).setFill(); bounds.fill()
        for (key, rect) in anchors() where !rect.isEmpty {
            NSColor.systemGreen.setStroke()
            let outline = NSBezierPath(rect: rect.insetBy(dx: -2, dy: -2))
            outline.lineWidth = 2; outline.stroke()
            let badgeWidth = CGFloat(MacInterfaceRenderer.menuText(key).count * 8 + 16)
            let badge = NSRect(x: max(2, min(bounds.width - badgeWidth - 2, rect.midX - badgeWidth / 2)),
                y: max(2, min(bounds.height - 26, rect.maxY + 4)), width: badgeWidth, height: 24)
            GameStoneButton.draw(badge, selected: true, pixel: 1)
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: 0, yBy: badge.midY * 2); transform.scaleX(by: 1, yBy: -1); transform.concat()
            if let context = NSGraphicsContext.current?.cgContext {
                NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            }
            GameControlText.draw(key, in: badge.insetBy(dx: 4, dy: 2), alignment: .center)
            NSGraphicsContext.restoreGraphicsState()
        }
    }
    override func mouseDown(with event: NSEvent) { }
    override func scrollWheel(with event: NSEvent) { }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 || event.characters == "?" { if !event.isARepeat { onClose() }; return }
        if event.keyCode == 48 { super.keyDown(with: event); return }
        // Gameplay keys cannot act through the overlay.
    }
    @objc private func closeOverlay() { onClose() }
    @objc private func allCommands() { onCommands() }
    @objc private func levelHints() { onHints() }
}
