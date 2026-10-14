import NxlvKit

/// TV keeps the timeline on the triggers. Create/View supplies the extra-action layer.
public struct TVControllerBindings {
    private var bindings = ControllerBindings()
    private var previous: Set<ControllerBindings.Button> = []
    private var modifierUsed = false
    private var rewindArmed = false
    private var optionsArmed = false
    public private(set) var rewindHeld = false
    public private(set) var menuRequested = false
    public private(set) var shuffleRequested = false
    public init() {}
    public mutating func reset() {
        bindings.reset(); previous = []; modifierUsed = false
        rewindArmed = false; rewindHeld = false; optionsArmed = false; menuRequested = false; shuffleRequested = false
    }
    public mutating func update(pressed: Set<ControllerBindings.Button>) -> [ControllerBindings.Action] {
        menuRequested = false
        shuffleRequested = false
        if !pressed.contains(.leftTrigger) { rewindArmed = true }
        // Forward takes over from a held rewind until L2 is released and pressed again.
        if pressed.contains(.rightTrigger), !previous.contains(.rightTrigger) { rewindArmed = false }
        rewindHeld = rewindArmed && pressed.contains(.leftTrigger)
        if pressed.contains(.options), !pressed.subtracting([.options, .leftTrigger]).isEmpty { modifierUsed = true }
        var roles = pressed
        roles.remove(.leftTrigger)
        roles.remove(.options)
        if pressed.contains(.options) { roles.insert(.leftTrigger) }
        var actions = bindings.update(pressed: roles)
        if !pressed.contains(.options) {
            actions = actions.compactMap { action in
                switch action {
                case .repeatAssignment: return .pause
                case .focusLast: return .endRun
                case .focusUnassigned(let direction): return .rate(direction < 0 ? -99 : 99)
                case .pause: menuRequested = true; return nil
                default: return action
                }
            }
        } else {
            actions = actions.map { action in
                switch action {
                case .endRun: .repeatAssignment
                case .rewind: .focusLast
                case .centre(let entrance) where pressed.contains(entrance ? .up : .down): .focusUnassigned(entrance ? -1 : 1)
                default: action
                }
            }
        }
        if pressed.contains(.options), pressed.contains(.rightStick), !previous.contains(.rightStick) {
            actions.removeAll { $0 == .centre(false) }
            actions.append(.settings)
        }
        if optionsArmed, pressed.contains(.options), pressed.contains(.leftStick), !previous.contains(.leftStick) {
            actions.removeAll { $0 == .centre(true) }
            shuffleRequested = true
        }
        if previous.contains(.options), !pressed.contains(.options) {
            if optionsArmed && !modifierUsed { actions.append(.help) }
            modifierUsed = false
        }
        if !pressed.contains(.options) { optionsArmed = true }
        previous = pressed
        return actions
    }
    public static let help = """
    Left stick: aim • Right stick: pan
    Cross / A: assign • Circle / B: reset speed, then pause
    Square / X: pause / play • Triangle / Y: nuke / undo, where supported
    L1 / R1: previous / next skill
    L2 / LT: hold to rewind • R2 / RT: resume, tap fast-forward, hold boost
    Options / Menu: menu • DualSense touchpad click: DJ shuffle
    D-pad left / right: minimum / maximum release rate, where supported
    D-pad up / down: release rate, where supported
    L3 / R3: entrance / exit
    Create / View: controls help
    Hold Create / View + L1 / R1: step back / forward
    Hold Create / View + D-pad left / right: speed down / up
    Hold Create / View + D-pad up / down: previous / next unassigned lemming
    Hold Create / View + Triangle / Y: hints
    Hold Create / View + Options / Menu: retry
    Hold Create / View + Cross / A: repeat last assignment
    Hold Create / View + Circle / B: focus last assignment
    Hold Create / View + Square / X: reset speed
    Hold Create / View + R3: settings
    Hold Create / View + L3: DJ shuffle
    Menus: D-pad moves, Cross / A selects, Circle / B returns
    Siri Remote: centre assigns, Play/Pause pauses or plays, Back opens pause
    """
}
