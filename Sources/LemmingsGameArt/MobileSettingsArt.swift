import CoreGraphics
import Foundation
import LemmingsMobileCore
import NxlvKit

/// UIKit and the headless menu audit use the same settings pages and action identifiers.
public enum MobileSettingsArt {
    public static func skillSelectionPauseChoice() -> GameFrontEnd.Page {
        var page = GameFrontEnd.Page(title: L10n.text("Skill selection"), subtitle: L10n.text("Keep pausing?"),
              footer: [.init("1", L10n.text("Keep pausing")), .init("0", L10n.text("Turn off"), primary: true)], footerColumns: 1)
        page.backActionID = "1"
        return page
    }
    /// Compact panes retain a full-width canvas when the requested lettering size cannot fit.
    public static func interfaceScale(_ size: ClassicInterfaceSize, width: CGFloat, television: Bool = false) -> CGFloat {
        if television {
            switch size { case .standard: return 2; case .large: return 3; case .extraLarge: return 4 }
        }
        return min(CGFloat(size.scale), max(1, width / 280))
    }
    public static func groups(inGame: Bool = false, television: Bool = false) -> GameFrontEnd.Page {
        // The Desk Clock is an iPhone and iPad feature.
        let groups = MobileSettingsGroup.allCases.filter { !television || $0 != .deskClock }
        var page = GameFrontEnd.Page(title: L10n.text("Settings"), rows: groups.map {
            .init("settingsGroup." + $0.rawValue, $0.title)
        } + (inGame ? [] : [.init("data", L10n.text("Game Data"))]), footer: [.init("home", L10n.text("Back"))])
        page.televisionGrid = television
        return page
    }

    public static func page(_ group: MobileSettingsGroup, settings: MobileSettings,
                            sharing: Bool = false, sharingAvailable: Bool = false,
                            displayAvailable: Bool = false, inGame: Bool = false,
                            language: InterfaceLanguage = .system, respectMuteAvailable: Bool = true,
                            foldable: Bool = false, calendarDenied: Bool = false) -> GameFrontEnd.Page {
        let c = settings.classic
        typealias Action = GameFrontEnd.Action
        func toggle(_ id: String, _ title: String, _ selected: Bool, enabled: Bool = true) -> Action {
            .init("setting." + id, title, enabled: enabled, selected: selected)
        }
        func choice(_ id: String, _ title: String, _ value: String, enabled: Bool = true) -> Action {
            .init("setting." + id, title + ": " + value, enabled: enabled)
        }
        var rows: [Action]
        switch group {
        case .gameplay:
            rows = [choice("language", L10n.text("Language"), language.title),
                    choice("preset", L10n.text("Presentation"), c.experiencePreset.title),
                    toggle("planning", L10n.text("Pause to assign"), settings.pauseToAssign),
                    choice("speed", L10n.text("Fast speed"), "\(settings.fastSpeed)X"),
                    toggle("variableSpeed", L10n.text("Variable speed"), c.variableSpeedEnabled),
                    toggle("ridiculousSpeed", L10n.text("Ridiculous speed (25×)"), c.ridiculousSpeedEnabled, enabled: c.variableSpeedEnabled),
                    toggle("interrupt", L10n.text("Pause on interruption"), c.pauseOnInterruption),
                    toggle("approaching", L10n.text("Target approaching lemmings"), c.favorApproachingLemmings),
                    toggle("bombBlockers", L10n.text("Target blockers for bombs"), c.favorBombBlockers),
                    toggle("builders", L10n.text("Target current builders"), c.favorBuilders),
                    choice("skillIcon", L10n.text("Skill icon size"), c.skillCursorIconSize.title),
                    toggle("reticule", L10n.text("Reticule count"), c.showReticleCount),
                    choice("selection", L10n.text("Selection effect"), c.lemmingSelectionStyle.title),
                    toggle("backpacks", L10n.text("Skill backpacks"), c.showClassicSkillBackpacks),
                    choice("levelAccess", L10n.text("Levels"), c.unlockAllClassicLevels ? L10n.text("All") : L10n.text("Unlocked"))]
        case .controller:
            rows = [toggle("controller", L10n.text("Enable controller"), c.controllerEnabled),
                    toggle("controllerTap", L10n.text("Tap RT for fast-forward"), c.controllerTapSpeed, enabled: c.controllerEnabled),
                    toggle("controllerSwap", L10n.text("Swap sticks"), c.controllerSwapSticks, enabled: c.controllerEnabled),
                    .init("controllerMappings", L10n.text("Remap buttons"), enabled: c.controllerEnabled)]
        case .graphics:
            rows = [choice("machine", L10n.text("Machine preset"), c.graphics.displayName),
                    choice("artwork", L10n.text("Artwork"), c.graphics.displayName),
                    choice("colour", L10n.text("Colour depth"), c.colorDepth.displayName),
                    toggle("shuffleArtwork", L10n.text("Shuffle artwork"), c.shuffleGraphics),
                    choice("counters", L10n.text("Counters"), c.counterStyle == .game ? L10n.text("Game") : L10n.text("Macintosh"))]
        case .display:
            rows = [choice("screen", L10n.text("Screen"), c.display.displayName, enabled: displayAvailable),
                    choice("tube", L10n.text("Tube strength"), "\(Int(c.displayIntensity * 100))%", enabled: displayAvailable && c.display != .flat),
                    toggle("pixels", L10n.text("Whole pixels"), c.integerScaling, enabled: displayAvailable),
                    toggle("hd", L10n.text("HD effects"), c.hdEffectsEnabled, enabled: displayAvailable),
                    toggle("explosions", L10n.text("Cinematic explosions"), c.fullScreenHDRFlashes, enabled: displayAvailable && c.hdEffectsEnabled)]
        case .audio:
            rows = [toggle("music", L10n.text("Music"), settings.musicEnabled),
                    choice("musicStyle", L10n.text("Music style"), c.musicStyle.displayName),
                    choice("musicVolume", L10n.text("Music volume"), "\(Int(c.musicVolume * 100))%"),
                    choice("soundSource", L10n.text("Sound effects"), c.sound.displayName),
                    choice("effectsVolume", L10n.text("Effects volume"), "\(Int(c.soundVolume * 100))%"),
                    toggle("menuMusic", L10n.text("Main menu music"), c.menuMusic),
                    toggle("pauseBeat", L10n.text("Rhythm on pause"), c.pauseMusicBeatOnly),
                    toggle("fall", L10n.text("Fall sounds"), c.bottomFallSounds),
                    choice("soundtrackChoice", L10n.text("Soundtrack"), SoundtrackCatalogue.interfaceTitle(settings.soundtrack)),
                    toggle("djOther", L10n.text("DJ uses other soundtracks"), c.djIncludesOtherSoundtracks),
                    choice("djShuffleScope", L10n.text("DJ shuffle"), settings.djShuffleScope.title),
                    .init("soundtrack", L10n.text("Soundtrack libraries"))]
            if respectMuteAvailable {
                rows.insert(toggle("respectMute", L10n.text("Respect Mute Setting"), settings.respectMuteSetting), at: 0)
            }
        case .accessibility:
            rows = [choice("uiSize", L10n.text("UI size"), c.interfaceSize.title),
                    toggle("songInfo", L10n.text("Show song info"), c.showSongInfo),
                    toggle("staticHome", L10n.text("Static home screen"), c.staticHomeScreen),
                    toggle("motion", L10n.text("Reduce motion"), c.reduceMotion),
                    toggle("flashes", L10n.text("Reduce flashes"), c.reduceFlashes)]
        case .deskClock:
            let clock = settings.deskClock
            rows = foldable ? [toggle("deskClockStacked", L10n.text("Open in Stacked pose when idle"), clock.openWhenStacked),
                               toggle("deskClockCharging", L10n.text("Open when closed and charging"), clock.openWhenCharging)] : []
            // Without calendar access the row stays off and opens iOS Settings.
            rows.append(toggle("deskClockEvents", L10n.text("Show next event"), clock.showNextEvent && !calendarDenied))
        case .privacy:
            rows = [toggle("telemetry", L10n.text("Share counts and records"), sharing, enabled: sharingAvailable),
                    .init("familiarNames", L10n.text("Familiar names")),
                    .init("cloudSaves", L10n.text("Tester sync")),
                    .init("playInsights", L10n.text("Play Insights"))]
        }
        if inGame { rows.removeAll { $0.id == "cloudSaves" || $0.id == "familiarNames" } }
        return .init(title: group.title, rows: rows,
                     footer: [.init("settings", L10n.text("Back"))])
    }

    /**
     * Each installed language remains selectable independently of system language support.
     */
    public static func languages(selection: InterfaceLanguage) -> GameFrontEnd.Page {
        .init(title: L10n.text("Language"),
              rows: L10n.languageOptions.map { .init("language." + $0.rawValue, $0.title, selected: $0 == selection) },
              footer: [.init("language.cancel", L10n.text("Back"), backNavigation: true),
                       .init("language.apply", L10n.text("Apply"), primary: true)])
    }

    public static func controllerMappings(_ settings: MobileSettings, television: Bool = false) -> GameFrontEnd.Page {
        .init(title: L10n.text("Remap buttons"), rows: ControllerBindings.Button.allCases.map { button in
            let role = settings.classic.controllerMappings[button.rawValue].flatMap(ControllerBindings.Button.init(rawValue:)) ?? button
            return .init("mapping." + button.rawValue, buttonTitle(button, television: television) + ": " + roleTitle(role, television: television))
        }, footer: [.init("mappingReset", L10n.text("Reset")), .init("settingsGroup.controller", L10n.text("Back"))])
    }

    private static func buttonTitle(_ button: ControllerBindings.Button, television: Bool = false) -> String {
        if television {
            switch button {
            case .a: return L10n.text("Cross / A")
            case .b: return L10n.text("Circle / B")
            case .x: return L10n.text("Square / X")
            case .y: return L10n.text("Triangle / Y")
            case .leftShoulder: return L10n.text("L1 / LB")
            case .rightShoulder: return L10n.text("R1 / RB")
            case .leftTrigger: return L10n.text("L2 / LT")
            case .rightTrigger: return L10n.text("R2 / RT")
            case .menu: return L10n.text("Options / Menu")
            case .options: return L10n.text("Create / View")
            default: break
            }
        }
        return switch button {
        case .a, .b, .x, .y: button.rawValue.uppercased()
        case .leftShoulder: "LB"
        case .rightShoulder: "RB"
        case .leftTrigger: "LT"
        case .rightTrigger: "RT"
        case .up: "Up"
        case .down: L10n.text("Down")
        case .left: L10n.text("Left")
        case .right: L10n.text("Right")
        case .menu: L10n.text("Menu")
        case .options: L10n.text("Options")
        case .leftStick: "L3"
        case .rightStick: "R3"
        }
    }
    private static func roleTitle(_ button: ControllerBindings.Button, television: Bool = false) -> String {
        if television && button == .leftTrigger { return L10n.text("Rewind") }
        if television && button == .rightTrigger { return L10n.text("Fast-forward") }
        if television && button == .options { return L10n.text("Help / extra actions") }
        if television && button == .b { return L10n.text("Pause / play") }
        if television && button == .x { return L10n.text("Reset speed") }
        if television && button == .y { return L10n.text("Nuke / undo") }
        if television && button == .left { return L10n.text("Minimum release rate") }
        if television && button == .right { return L10n.text("Maximum release rate") }
        if television && button == .menu { return L10n.text("Menu") }
        return switch button {
        case .a: L10n.text("Assign")
        case .b: L10n.text("Pause / play")
        case .x: L10n.text("Reset speed")
        case .y: L10n.text("Nuke / undo")
        case .leftShoulder: L10n.text("Previous skill")
        case .rightShoulder: L10n.text("Next skill")
        case .leftTrigger: L10n.text("Extra actions")
        case .rightTrigger: L10n.text("Fast-forward")
        case .up: L10n.text("Increase release rate")
        case .down: L10n.text("Decrease release rate")
        case .left: L10n.text("Previous unassigned")
        case .right: L10n.text("Next unassigned")
        case .menu: L10n.text("Menu")
        case .options: L10n.text("Controls help")
        case .leftStick: L10n.text("Entrance")
        case .rightStick: L10n.text("Goal")
        }
    }
}
