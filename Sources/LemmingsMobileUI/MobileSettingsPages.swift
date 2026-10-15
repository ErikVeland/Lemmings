#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import LemmingsTVCore
import NxlvKit
import UIKit

extension MobileLibraryViewController {
    var settingsProfileID: String { hotSeat?.turn ?? profiles.activeID }
    var mobileSettings: MobileSettings {
        get { MobileSettings.load(from: .standard, profileID: settingsProfileID) }
        set { newValue.save(to: .standard, profileID: settingsProfileID) }
    }
    var interfaceLanguage: InterfaceLanguage { L10n.currentLanguagePreference }

    func beginLanguageSelection() {
        if languageSelectionOriginal == nil { languageSelectionOriginal = interfaceLanguage }
    }

    func finishLanguageSelection(apply: Bool) {
        guard let original = languageSelectionOriginal else { return }
        if apply { InterfaceLanguagePreference.save(interfaceLanguage, to: .standard) }
        else { L10n.setLanguage(original) }
        languageSelectionOriginal = nil
    }

    func languagePage() -> GameFrontEnd.Page {
        beginLanguageSelection()
        var page = MobileSettingsArt.languages(selection: interfaceLanguage)
        #if os(tvOS)
        page.televisionGrid = true
        #endif
        return page
    }

    func settingsGroupsPage(inGame: Bool = false) -> GameFrontEnd.Page {
        #if os(tvOS)
        MobileSettingsArt.groups(inGame: inGame, television: true)
        #else
        MobileSettingsArt.groups(inGame: inGame)
        #endif
    }
    func controllerMappingsPage() -> GameFrontEnd.Page {
        #if os(tvOS)
        var page = MobileSettingsArt.controllerMappings(mobileSettings, television: true)
        page.rows += page.footer.filter { !$0.isBackNavigation }
        page.footer.removeAll { !$0.isBackNavigation }
        page.televisionGrid = true
        return page
        #else
        MobileSettingsArt.controllerMappings(mobileSettings)
        #endif
    }
    func settingsPage(_ group: MobileSettingsGroup, inGame: Bool = false) -> GameFrontEnd.Page {
        var page = MobileSettingsArt.page(group, settings: mobileSettings,
                               sharing: AnonymousTelemetry.shared.sharesCounts,
                               sharingAvailable: AnonymousTelemetry.shared.sharingAvailable, displayAvailable: true, inGame: inGame,
                               language: interfaceLanguage)
        #if os(tvOS)
        page.televisionGrid = true
        if group == .controller {
            let input = TVPreferences.inputPreferences(from: .standard, profileID: settingsProfileID)
            page.rows += [.init("setting.tvAim", L10n.text("Aim sensitivity: \(Int(input.aimSensitivity * 100))%")),
                          .init("setting.tvDeadZone", L10n.text("Stick dead zone: \(Int(input.deadZone * 100))%")),
                          .init("setting.tvTriggerFeedback", L10n.text("Adaptive triggers"), selected: input.triggerFeedback != false)]
        }
        #endif
        return page
    }
    func soundtrackPage() -> GameFrontEnd.Page {
            let libraries = MobileMusicLibraries.shared
            let packs = libraries.catalogue?.packs ?? []
            let status = libraries.failure ?? (libraries.isDownloading ? L10n.text("Downloading...") : "\(packs.filter { libraries.isBundled($0) || libraries.isInstalled($0) }.count)/\(packs.count)")
            var page = GameFrontEnd.Page(title: L10n.text("Soundtrack"), subtitle: status,
                                rows: packs.map { pack in
                                    let included = libraries.isBundled(pack)
                                    let percent = libraries.progress[pack.id].map { "  \(Int($0 * 100))%" }
                                    return .init("lib." + pack.id,
                                                 pack.title + "  " + (included ? L10n.text("Included") : (percent ?? MobileMusicLibraries.size(pack.bytes))),
                                                 enabled: !included, selected: included || libraries.isInstalled(pack))
                                },
                                footer: [.init("settingsGroup.audio", L10n.text("Back"))])
            #if os(tvOS)
            page.televisionGrid = true
            #endif
            return page
    }

    func insightsPage() -> GameFrontEnd.Page {
        let summary = AnonymousTelemetry.shared.localSummary()
        return .init(title: L10n.text("Play Insights"), details: [L10n.text("Started: \(summary.total(.levelStart))"),
            L10n.text("Won: \(summary.total(.levelWin))"), L10n.text("Saved: \(summary.total(.lemmingsSaved))")],
                     footer: [.init("settingsGroup.privacy", L10n.text("Back"))])
    }

    /// Each row changes one choice. Individual gameplay edits retain the Custom preset.
    func handleSettings(_ id: String) -> Bool {
        #if os(tvOS)
        if id == "setting.tvAim" || id == "setting.tvDeadZone" || id == "setting.tvTriggerFeedback" {
            var input = TVPreferences.inputPreferences(from: .standard, profileID: settingsProfileID)
            if id == "setting.tvAim" { input.aimSensitivity = input.aimSensitivity >= 2 ? 0.5 : input.aimSensitivity + 0.25 }
            else if id == "setting.tvDeadZone" { input.deadZone = input.deadZone >= 0.349 ? 0.05 : input.deadZone + 0.05 }
            else { input.triggerFeedback = !(input.triggerFeedback ?? true) }
            input.saveInputPreferences(to: .standard, profileID: settingsProfileID)
            rebuild(); return true
        }
        #endif
        if id.hasPrefix("settingsGroup."), let group = MobileSettingsGroup(rawValue: String(id.dropFirst(14))) {
            navigate(.settingsGroup(group)); return true
        }
        if id == "controllerMappings" { navigate(.controllerMappings); return true }
        if id == "playInsights" { navigate(.playInsights); return true }
        if id == "setting.language" { beginLanguageSelection(); navigate(.language); return true }
        if id == "language.cancel" || id == "language.apply" {
            finishLanguageSelection(apply: id == "language.apply")
            navigate(.settingsGroup(.gameplay)); return true
        }
        if id.hasPrefix("language."), let language = InterfaceLanguage(rawValue: String(id.dropFirst(9))),
           L10n.languageOptions.contains(language) {
            beginLanguageSelection()
            L10n.setLanguage(language)
            rebuild(); return true
        }
        var settings = mobileSettings
        if id == "mappingReset" { settings.classic.controllerMappings = [:] }
        else if id.hasPrefix("mapping."), let physical = ControllerBindings.Button(rawValue: String(id.dropFirst(8))) {
            let buttons = ControllerBindings.Button.allCases
            let current = settings.classic.controllerMappings[physical.rawValue].flatMap(ControllerBindings.Button.init(rawValue:)) ?? physical
            let index = buttons.firstIndex(of: current) ?? 0
            settings.classic.controllerMappings = ControllerBindings.swapping(settings.classic.controllerMappings,
                physical: physical, role: buttons[(index + 1) % buttons.count])
        } else if id.hasPrefix("setting.") {
            let key = String(id.dropFirst(8))
            switch key {
            case "preset": settings.applyExperiencePreset(modern: settings.classic.experiencePreset != .modern)
            case "planning": settings.chooseSkillSelectionPause(!settings.pauseToAssign)
            case "speed": settings.fastSpeed = cycle(settings.fastSpeed, MobileSettings.fastSpeeds)
            case "variableSpeed": settings.classic.variableSpeedEnabled.toggle()
            case "interrupt": settings.classic.pauseOnInterruption.toggle()
            case "approaching": settings.classic.favorApproachingLemmings.toggle()
            case "bombBlockers": settings.classic.favorBombBlockers.toggle()
            case "builders": settings.classic.favorBuilders.toggle()
            case "skillIcon": settings.classic.skillCursorIconSize = cycle(settings.classic.skillCursorIconSize, SkillCursorIconSize.allCases)
            case "reticule": settings.classic.showReticleCount.toggle()
            case "selection": settings.classic.lemmingSelectionStyle = cycle(settings.classic.lemmingSelectionStyle, LemmingSelectionStyle.allCases)
            case "backpacks": settings.classic.showClassicSkillBackpacks.toggle()
            case "levelAccess": settings.classic.unlockAllClassicLevels.toggle()
            case "controller": settings.classic.controllerEnabled.toggle()
            case "controllerTap": settings.classic.controllerTapSpeed.toggle()
            case "controllerSwap": settings.classic.controllerSwapSticks.toggle()
            case "machine", "artwork":
                settings.classic.graphics = cycle(settings.classic.graphics, [.dosVGA, .amiga, .macintosh, .macintoshMonochrome])
                if key == "machine" {
                    settings.classic.colorDepth = settings.classic.graphics == .amiga ? .amigaOCS : .full
                    settings.classic.musicStyle = settings.classic.graphics == .amiga ? .faithful : .modern
                    settings.classic.sound = settings.classic.graphics == .amiga ? .amigaVoices : .macintoshResources
                }
            case "colour": settings.classic.colorDepth = cycle(settings.classic.colorDepth, ClassicColorDepth.allCases)
            case "shuffleArtwork": settings.classic.shuffleGraphics.toggle()
            case "counters": settings.classic.counterStyle = cycle(settings.classic.counterStyle, ClassicCounterStyle.allCases)
            case "screen": settings.classic.display = cycle(settings.classic.display, ClassicDisplayMode.allCases)
            case "tube": settings.classic.displayIntensity = nextVolume(settings.classic.displayIntensity)
            case "pixels": settings.classic.integerScaling.toggle()
            case "hd": settings.classic.hdEffectsEnabled.toggle()
            case "explosions": settings.classic.fullScreenHDRFlashes.toggle()
            case "music": settings.musicEnabled.toggle()
            case "musicStyle": settings.classic.musicStyle = cycle(settings.classic.musicStyle, ClassicMusicStyle.allCases)
            case "musicVolume": settings.classic.musicVolume = nextVolume(settings.classic.musicVolume)
            case "effectsVolume": settings.classic.soundVolume = nextVolume(settings.classic.soundVolume)
            case "soundSource": settings.classic.sound = cycle(settings.classic.sound, ClassicSettingsOptions.playableSound)
            case "pauseBeat": settings.classic.pauseMusicBeatOnly.toggle()
            case "fall": settings.classic.bottomFallSounds.toggle()
            case "soundtrackChoice":
                settings.soundtrack = cycle(settings.soundtrack, MobileMusic.shared.soundtrackNames)
                settings.classic.music = settings.soundtrack == "Adaptive DJ" ? .adaptiveDJ : .amigaModules
            case "djOther": settings.classic.djIncludesOtherSoundtracks.toggle()
            case "djShuffleScope": settings.djShuffleScope = cycle(settings.djShuffleScope, SoundtrackCatalogue.ShuffleScope.allCases)
            case "uiSize": settings.classic.interfaceSize = cycle(settings.classic.interfaceSize, ClassicInterfaceSize.allCases)
            case "songInfo": settings.classic.showSongInfo.toggle()
            case "staticHome": settings.classic.staticHomeScreen.toggle()
            case "motion": settings.classic.reduceMotion.toggle()
            case "flashes": settings.classic.reduceFlashes.toggle()
            case "telemetry": AnonymousTelemetry.shared.setSharing(!AnonymousTelemetry.shared.sharesCounts)
            default: return false
            }
            if ["variableSpeed", "interrupt", "approaching", "bombBlockers", "builders", "skillIcon", "reticule", "selection", "backpacks"].contains(key) {
                settings.classic.experiencePreset = .custom
            }
        } else { return false }
        mobileSettings = settings
        MobileMusic.shared.applySettings(profileID: settingsProfileID)
        rebuild()
        return true
    }

    private func cycle<T: Equatable>(_ value: T, _ values: [T]) -> T {
        values[((values.firstIndex(of: value) ?? -1) + 1) % values.count]
    }
    private func nextVolume(_ value: Double) -> Double { value >= 0.999 ? 0 : min(1, (Double(Int((value * 10).rounded())) + 1) / 10) }
}
#endif
