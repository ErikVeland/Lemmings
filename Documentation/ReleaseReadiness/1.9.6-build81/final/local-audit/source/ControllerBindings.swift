/// Default extended-gamepad bindings. Actions fire once per button press.
public struct ControllerBindings {
    public enum Button: String, CaseIterable, Codable, Hashable, Sendable { case a, b, x, y, leftShoulder, rightShoulder, leftTrigger, rightTrigger, up, down, left, right, menu, options, leftStick, rightStick }
    public enum Action: Equatable, Sendable {
        case assign, repeatAssignment, cancel, pause, help, focusLast, focusUnassigned(Int), cycle(Int)
        case rate(Int), centre(Bool), speedStep(Int), speedReset, boost(Bool)
        case hints, settings, retry, rewind, step(Int), endRun
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
        case .a: return "Assign selected skill"
        case .b: return "Reset speed / cancel / pause menu"
        case .x: return "Repeat last assignment"
        case .y: return "Focus last assignment"
        case .leftShoulder: return "Previous skill"
        case .rightShoulder: return "Next skill"
        case .leftTrigger: return "Modifier for extra actions"
        case .rightTrigger: return "Tap: toggle fast-forward; hold: temporary boost"
        case .up: return "Increase release rate"
        case .down: return "Decrease release rate"
        case .left: return "Previous unassigned lemming"
        case .right: return "Next unassigned lemming"
        case .menu: return "Pause / resume"
        case .options: return "Controls help"
        case .leftStick: return "Centre on entrance"
        case .rightStick: return "Centre on exit"
        }
    }
    private var previous: Set<Button> = []
    private var primed = false
    public init() {}
    public mutating func reset() { previous = []; primed = false }
    public mutating func update(pressed: Set<Button>, inMenu: Bool = false) -> [Action] {
        defer { previous = pressed; primed = true }
        guard primed else { return [] }
        var actions: [Action] = []
        if previous.contains(.rightTrigger) && !pressed.contains(.rightTrigger) { actions.append(.boost(false)) }
        let extra = pressed.contains(.leftTrigger)
        // Fixed order makes simultaneous presses reproducible.
        for button in [Button.b, .menu, .options, .leftShoulder, .rightShoulder, .left, .right, .up, .down, .leftStick, .rightStick, .y, .x, .a, .rightTrigger] where pressed.contains(button) && !previous.contains(button) {
            switch button {
            case .a: actions.append(extra && !inMenu ? .endRun : .assign)
            case .b: actions.append(extra && !inMenu ? .rewind : .cancel)
            case .x: actions.append(extra ? .speedReset : .repeatAssignment)
            case .y: actions.append(extra ? .hints : .focusLast)
            case .menu: actions.append(extra && !inMenu ? .retry : .pause)
            case .options: actions.append(extra ? .settings : .help)
            case .leftShoulder: actions.append(extra && !inMenu ? .step(-1) : .cycle(-1))
            case .rightShoulder: actions.append(extra && !inMenu ? .step(1) : .cycle(1))
            case .left: actions.append(extra && !inMenu ? .speedStep(-1) : .focusUnassigned(-1))
            case .right: actions.append(extra && !inMenu ? .speedStep(1) : .focusUnassigned(1))
            case .up: actions.append(extra && !inMenu ? .centre(true) : .rate(1))
            case .down: actions.append(extra && !inMenu ? .centre(false) : .rate(-1))
            case .leftStick: actions.append(.centre(true))
            case .rightStick: actions.append(.centre(false))
            case .rightTrigger: actions.append(.boost(true))
            case .leftTrigger: break
            }
        }
        return actions
    }
    public static let help = """
    Controller (Xbox-style button names)
    Left stick: aim • Right stick: pan camera
    A: assign selected skill • B: return to 1×, then cancel / pause menu
    X: repeat last skill • Y: focus last assignment
    LB / RB: previous / next available skill
    D-pad left / right: previous / next unassigned lemming
    D-pad up / down: increase / decrease release rate (where supported)
    Tap RT: toggle fast-forward • Hold RT: ramp up; release: previous speed
    B: immediately return to 1× • Menu: pause / resume
    L3 / R3: entrance / exit • View / Options: help
    Hold LT + D-pad left / right: decrease / increase speed
    Hold LT + D-pad up / down: entrance / exit
    Hold LT + X: reset speed • Hold LT + Y: level hints
    Hold LT + LB / RB: step back / forward where supported
    Hold LT + B: rewind where supported • LT + Menu: retry
    Hold LT + A: end run / undo nuke • LT + View / Options: settings
    Menus: D-pad selects or adjusts, A confirms, B returns, LB / RB changes tabs
    Right stick scrolls long pages. Release buttons before using a new page.
    """
}
