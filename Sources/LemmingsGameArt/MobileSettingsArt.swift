import CoreGraphics
import Foundation
import LemmingsMobileCore
import NxlvKit

/// UIKit and the headless menu audit use the same settings pages and action identifiers.
public enum MobileSettingsArt {
    /// Compact panes retain a full-width canvas when the requested lettering size cannot fit.
    public static func interfaceScale(_ size: ClassicInterfaceSize, width: CGFloat) -> CGFloat {
        min(CGFloat(size.scale), max(1, width / 280))
    }
    public static func groups() -> GameFrontEnd.Page {
        .init(title: "Settings", rows: MobileSettingsGroup.allCases.map {
            .init("settingsGroup." + $0.rawValue, $0.title)
        }, footer: [.init("home", "Back")])
    }

    public static func page(_ group: MobileSettingsGroup, settings: MobileSettings,
                            sharing: Bool = false, sharingAvailable: Bool = false,
                            displayAvailable: Bool = false) -> GameFrontEnd.Page {
        let c = settings.classic
        typealias Action = GameFrontEnd.Action
        func toggle(_ id: String, _ title: String, _ selected: Bool, enabled: Bool = true) -> Action {
            .init("setting." + id, title, enabled: enabled, selected: selected)
        }
        func choice(_ id: String, _ title: String, _ value: String, enabled: Bool = true) -> Action {
            .init("setting." + id, title + ": " + value, enabled: enabled)
        }
        let rows: [Action]
        switch group {
        case .gameplay:
            rows = [choice("preset", "Preset", c.experiencePreset.title),
                    toggle("planning", "Pause to assign", settings.pauseToAssign),
                    choice("speed", "Fast speed", "\(settings.fastSpeed)X"),
                    toggle("variableSpeed", "Variable speed", c.variableSpeedEnabled),
                    toggle("interrupt", "Pause on interruption", c.pauseOnInterruption),
                    toggle("approaching", "Target approaching lemmings", c.favorApproachingLemmings),
                    toggle("bombBlockers", "Target blockers for bombs", c.favorBombBlockers),
                    toggle("builders", "Target current builders", c.favorBuilders),
                    choice("skillIcon", "Skill icon size", c.skillCursorIconSize.title),
                    toggle("reticule", "Reticule count", c.showReticleCount),
                    choice("selection", "Selection effect", c.lemmingSelectionStyle.title),
                    toggle("backpacks", "Skill backpacks", c.showClassicSkillBackpacks),
                    choice("levelAccess", "Level selection", c.unlockAllClassicLevels ? "All" : "Player unlocked")]
        case .controller:
            rows = [toggle("controller", "Enable controller", c.controllerEnabled),
                    toggle("controllerTap", "Tap RT for fast-forward", c.controllerTapSpeed, enabled: c.controllerEnabled),
                    toggle("controllerSwap", "Swap sticks", c.controllerSwapSticks, enabled: c.controllerEnabled),
                    .init("controllerMappings", "Remap buttons", enabled: c.controllerEnabled)]
        case .graphics:
            rows = [choice("machine", "Machine preset", c.graphics.displayName),
                    choice("artwork", "Artwork", c.graphics.displayName),
                    choice("colour", "Colour depth", c.colorDepth.displayName),
                    toggle("shuffleArtwork", "Shuffle artwork", c.shuffleGraphics),
                    choice("counters", "Counters", c.counterStyle == .game ? "Game" : "Macintosh")]
        case .display:
            rows = [choice("screen", "Screen", c.display.displayName, enabled: displayAvailable),
                    choice("tube", "Tube strength", "\(Int(c.displayIntensity * 100))%", enabled: displayAvailable && c.display != .flat),
                    toggle("pixels", "Whole pixels", c.integerScaling, enabled: displayAvailable),
                    toggle("hd", "HD effects", c.hdEffectsEnabled, enabled: displayAvailable),
                    toggle("explosions", "Cinematic explosions", c.fullScreenHDRFlashes, enabled: displayAvailable && c.hdEffectsEnabled)]
        case .audio:
            rows = [toggle("music", "Music", settings.musicEnabled),
                    choice("musicStyle", "Music style", c.musicStyle.displayName),
                    choice("musicVolume", "Music volume", "\(Int(c.musicVolume * 100))%"),
                    choice("soundSource", "Sound effects", c.sound.displayName),
                    choice("effectsVolume", "Effects volume", "\(Int(c.soundVolume * 100))%"),
                    toggle("pauseBeat", "Rhythm on pause", c.pauseMusicBeatOnly),
                    toggle("fall", "Fall sounds", c.bottomFallSounds),
                    choice("soundtrackChoice", "Soundtrack", settings.soundtrack),
                    toggle("djOther", "DJ uses other soundtracks", c.djIncludesOtherSoundtracks),
                    .init("soundtrack", "Soundtrack libraries")]
        case .accessibility:
            rows = [choice("uiSize", "UI size", c.interfaceSize.title),
                    toggle("songInfo", "Show song info", c.showSongInfo),
                    toggle("motion", "Reduce motion", c.reduceMotion),
                    toggle("flashes", "Reduce flashes", c.reduceFlashes)]
        case .privacy:
            rows = [toggle("telemetry", "Anonymous telemetry", sharing, enabled: sharingAvailable),
                    .init("playInsights", "Play Insights")]
        }
        return .init(title: group.title, rows: rows, footer: [.init("settings", "Back")])
    }

    public static func controllerMappings(_ settings: MobileSettings) -> GameFrontEnd.Page {
        .init(title: "Remap buttons", rows: ControllerBindings.Button.allCases.map { button in
            let role = settings.classic.controllerMappings[button.rawValue].flatMap(ControllerBindings.Button.init(rawValue:)) ?? button
            return .init("mapping." + button.rawValue, buttonTitle(button) + ": " + roleTitle(role))
        }, footer: [.init("mappingReset", "Reset"), .init("settingsGroup.controller", "Back")])
    }

    private static func buttonTitle(_ button: ControllerBindings.Button) -> String {
        switch button {
        case .a, .b, .x, .y: button.rawValue.uppercased()
        case .leftShoulder: "LB"
        case .rightShoulder: "RB"
        case .leftTrigger: "LT"
        case .rightTrigger: "RT"
        case .up: "Up"
        case .down: "Down"
        case .left: "Left"
        case .right: "Right"
        case .menu: "Menu"
        case .options: "Options"
        case .leftStick: "L3"
        case .rightStick: "R3"
        }
    }
    private static func roleTitle(_ button: ControllerBindings.Button) -> String {
        switch button {
        case .a: "Assign"
        case .b: "Cancel"
        case .x: "Repeat skill"
        case .y: "Last assignment"
        case .leftShoulder: "Previous skill"
        case .rightShoulder: "Next skill"
        case .leftTrigger: "Extra actions"
        case .rightTrigger: "Fast-forward"
        case .up: "Increase release rate"
        case .down: "Decrease release rate"
        case .left: "Previous unassigned"
        case .right: "Next unassigned"
        case .menu: "Pause"
        case .options: "Controls help"
        case .leftStick: "Entrance"
        case .rightStick: "Goal"
        }
    }
}
