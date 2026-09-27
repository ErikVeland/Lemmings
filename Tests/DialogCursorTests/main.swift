import AppKit

@MainActor final class GameMenuPage: NSView {
    var onHorizontalNavigation: ((Int) -> Void)?
    var controllerInitialControl: NSView?
}

private final class FlippedRoot: NSView {
    override var isFlipped: Bool { true }
}

@MainActor private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

@MainActor private func checkOrder(in root: NSView, positions: [CGFloat]) {
    let buttons = ["A", "B", "C"].enumerated().map { index, title in
        let button = NSButton(title: title, target: nil, action: nil)
        button.frame = CGRect(x: [100, 0, -10][index], y: positions[index], width: 70, height: 20)
        root.addSubview(button)
        return button
    }
    let navigation = DialogKeyboardNavigation()
    let ordered = navigation.controls(in: root)
    check(ordered.count == 3 && ordered[0] === buttons[1]
        && ordered[1] === buttons[0] && ordered[2] === buttons[2],
        "Nearby controls did not keep a stable left-to-right row order")
    buttons[1].isEnabled = false
    check(navigation.controls(in: root).count == 2, "A disabled control remained in the focus order")
    buttons[1].isEnabled = true
    buttons[2].isHidden = true
    check(navigation.controls(in: root).count == 2, "A hidden control remained in the focus order")
}

@MainActor private func run() {
    _ = NSApplication.shared
    checkOrder(in: NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 300)),
        positions: [200, 195, 190])
    checkOrder(in: FlippedRoot(frame: CGRect(x: 0, y: 0, width: 300, height: 300)),
        positions: [0, 5, 10])

    let playfield = CGRect(x: 10, y: 10, width: 100, height: 80)
    GameCursor.gameplaySuppressed = false
    check(GameCursor.hidesSystemCursor(at: CGPoint(x: 20, y: 20), inside: playfield),
        "Gameplay did not use the drawn pointer")
    check(!GameCursor.hidesSystemCursor(at: CGPoint(x: 1, y: 1), inside: playfield),
        "A control area hid the system cursor")
    GameCursor.gameplaySuppressed = true
    check(!GameCursor.hidesSystemCursor(at: CGPoint(x: 20, y: 20), inside: playfield),
        "A dialog retained the drawn gameplay pointer")
    GameCursor.gameplaySuppressed = false
    print("PASS dialog focus rows, hidden controls and gameplay cursor policy")
}

MainActor.assumeIsolated { run() }
