/// Default extended-gamepad bindings. Actions fire once per button press.
public struct ControllerBindings {
    public enum Button: String, CaseIterable, Codable, Hashable, Sendable { case a, b, x, y, leftShoulder, rightShoulder, leftTrigger, rightTrigger, up, down, left, right, menu, options, leftStick, rightStick }
    public enum Action: Equatable, Sendable {
        case assign, repeatAssignment, cancel, pause, help, focusLast, focusUnassigned(Int), cycle(Int)
        case rate(Int), centre(Bool), speedStep(Int), speedReset, boost(Bool)
        case hints, settings, retry, rewind, step(Int), endRun, djShuffle
    }
    /// Only permutations are accepted, so no action becomes unreachable.
    public static func validatedMapping(_ value: [String: String]) -> [String: String] {
        guard value.allSatisfy({ Button(rawValue: $0.key) != nil && Button(rawValue: $0.value) != nil }) else { return [:] }
        let targets = Button.allCases.map { value[$0.rawValue] ?? $0.rawValue }
        guard Set(targets).count == Button.allCases.count else { return [:] }
        return value.filter { $0.key != $0.value }
    }
    public static func remap(_ pressed: Set<Button>, using mapping: [String: String]) -> Set<Button> {
        let mapping = validatedMapping(mapping)
        return Set(pressed.map { mapping[$0.rawValue].flatMap(Button.init(rawValue:)) ?? $0 })
    }
    public static func swapping(_ mapping: [String: String], physical: Button, role: Button) -> [String: String] {
        var value = validatedMapping(mapping)
        let old = value[physical.rawValue] ?? physical.rawValue
        let displaced = Button.allCases.first { (value[$0.rawValue] ?? $0.rawValue) == role.rawValue }!
        value[physical.rawValue] = role.rawValue
        value[displaced.rawValue] = old
        return validatedMapping(value)
    }
    public static func roleName(_ button: Button) -> String {
        switch button {
        case .a: return L10n.text("Assign selected skill")
        case .b: return L10n.text("Reset fast speed / pause / resume")
        case .x: return L10n.text("Reset speed")
        case .y: return L10n.text("End run / undo")
        case .leftShoulder: return L10n.text("Previous skill")
        case .rightShoulder: return L10n.text("Next skill")
        case .leftTrigger: return L10n.text("Modifier for extra actions")
        case .rightTrigger: return L10n.text("Tap: toggle fast-forward; hold: temporary boost")
        case .up: return L10n.text("Increase release rate")
        case .down: return L10n.text("Decrease release rate")
        case .left: return L10n.text("Previous unassigned lemming")
        case .right: return L10n.text("Next unassigned lemming")
        case .menu: return L10n.text("Game menu")
        case .options: return L10n.text("Controls help")
        case .leftStick: return L10n.text("Centre on entrance")
        case .rightStick: return L10n.text("Centre on exit")
        }
    }
    /// Timing for a held D-pad up / down. Each platform passes the timing of
    /// its own held rate button, so a controller hold feels the same as a
    /// mouse or finger hold.
    public struct RateRepeat: Sendable {
        public var delay: Double
        public var interval: Double
        public init(delay: Double, interval: Double) { self.delay = delay; self.interval = interval }
        /// The Mac skill panel's held rate button.
        public static let mac = RateRepeat(delay: 0.3, interval: 0.02)
        /// The iPad, iPhone and Apple TV held rate button.
        public static let touch = RateRepeat(delay: 0.35, interval: 0.08)
    }
    private var previous: Set<Button> = []
    private var primed = false
    private let rateRepeat: RateRepeat
    private var heldRate: (button: Button, direction: Int, next: Double)?
    public init(rateRepeat: RateRepeat = .touch) { self.rateRepeat = rateRepeat }
    public mutating func reset() { previous = []; primed = false; heldRate = nil }
    /// Pass `now` to repeat a held release-rate step. Without it, every action fires once per press.
    public mutating func update(pressed: Set<Button>, inMenu: Bool = false, at now: Double? = nil) -> [Action] {
        defer { previous = pressed; primed = true }
        guard primed else { return [] }
        var actions: [Action] = []
        // The release rate is held rather than tapped. A changed modifier or a
        // menu ends the hold, so the step never turns into another action.
        if let held = heldRate, let now, !inMenu, pressed.contains(held.button), !pressed.contains(.leftTrigger) {
            // A stalled frame catches up a few steps, not the whole stall.
            var next = held.next, steps = 0
            while next <= now, steps < 4 { actions.append(.rate(held.direction)); next += rateRepeat.interval; steps += 1 }
            heldRate?.next = max(next, now - rateRepeat.interval)
        } else { heldRate = nil }
        if previous.contains(.rightTrigger) && !pressed.contains(.rightTrigger) { actions.append(.boost(false)) }
        let extra = pressed.contains(.leftTrigger)
        // Fixed order makes simultaneous presses reproducible.
        for button in [Button.b, .menu, .options, .leftShoulder, .rightShoulder, .left, .right, .up, .down, .leftStick, .rightStick, .y, .x, .a, .rightTrigger] where pressed.contains(button) && !previous.contains(button) {
            switch button {
            case .a: actions.append(extra && !inMenu ? .repeatAssignment : .assign)
            case .b: actions.append(extra && !inMenu ? .rewind : (inMenu ? .cancel : .pause))
            case .x: actions.append(.speedReset)
            case .y: actions.append(extra ? .hints : .endRun)
            case .menu: actions.append(extra && !inMenu ? .retry : .cancel)
            case .options: actions.append(extra ? .settings : .help)
            case .leftShoulder: actions.append(extra && !inMenu ? .step(-1) : .cycle(-1))
            case .rightShoulder: actions.append(extra && !inMenu ? .step(1) : .cycle(1))
            case .left: actions.append(extra && !inMenu ? .speedStep(-1) : .focusUnassigned(-1))
            case .right: actions.append(extra && !inMenu ? .speedStep(1) : .focusUnassigned(1))
            case .up, .down:
                let direction = button == .up ? 1 : -1
                if extra && !inMenu { actions.append(.centre(direction > 0)); break }
                actions.append(.rate(direction))
                if let now, !inMenu { heldRate = (button, direction, now + rateRepeat.delay) }
            case .leftStick: actions.append(extra && !inMenu ? .djShuffle : .centre(true))
            case .rightStick: actions.append(extra && !inMenu ? .focusLast : .centre(false))
            case .rightTrigger: actions.append(.boost(true))
            case .leftTrigger: break
            }
        }
        return actions
    }
    public static var help: String { L10n.text("""
    Controller (Xbox-style button names)
    Left stick: aim • Right stick: pan camera
    A: assign selected skill • B: reset fast speed, then pause / resume
    X: reset speed • Y: end run / undo
    LB / RB: previous / next available skill
    D-pad left / right: previous / next unassigned lemming
    D-pad up / down: increase / decrease release rate (where supported)
    At fast speed, RT resets to 1×. Release before pressing it again.
    Tap RT at 1×: toggle fast-forward • Hold RT: ramp up; release: previous speed
    X: immediately return to 1× • Menu: game menu
    L3 / R3: entrance / exit • View / Options: help
    Hold LT + D-pad left / right: decrease / increase speed
    Hold LT + D-pad up / down: entrance / exit
    Hold LT + X: reset speed • Hold LT + Y: level hints
    Hold LT + LB / RB: step back / forward where supported
    Hold LT + B: rewind where supported • LT + Menu: retry
    Hold LT + A: repeat last assignment • LT + View / Options: settings
    Hold LT + R3: focus last assignment
    Hold LT + L3: DJ shuffle • DualSense touchpad click: DJ shuffle
    Menus: D-pad selects or adjusts, A confirms, B returns, LB / RB changes tabs
    Right stick scrolls long pages. Release buttons before using a new page.
    """) }
}
