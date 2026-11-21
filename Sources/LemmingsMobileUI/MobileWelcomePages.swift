#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import LemmingsTVCore
import NxlvKit
import UIKit

extension MobileLibraryViewController {
    private var mobileBuild: Int { Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0 }
    private var mobileVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0" }

    static let firstPlayerCompleteKey = "FirstLaunchProfileCompleteV1"

    func beginFirstLaunch() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.firstPlayerCompleteKey) == nil {
            let saved = MobileStorage.standard(profile: "_players").load(MobileProfiles.self, name: "players")
            var returning = saved != nil || defaults.object(forKey: "mobile.effectsChoice.v1") != nil
                || defaults.object(forKey: "mobile.whatsNew.seenBuild") != nil
                || defaults.object(forKey: "mobile.completed.Lemmings") != nil
                || defaults.object(forKey: "mobile.completed.release/lemmings") != nil
            #if os(tvOS)
            returning = returning || TVMobileMigration.hasLegacyPlayer(in: defaults)
            #endif
            defaults.set(returning, forKey: Self.firstPlayerCompleteKey)
        }
        guard !defaults.bool(forKey: Self.firstPlayerCompleteKey) else { return }
        route = .firstPlayer
        nameDraft = profiles.active.name == "Player 1" ? "" : ArcadeProfile(initials: profiles.active.name).initials
        draftPortrait = profiles.active.portrait
        searchField.text = nameDraft
        Task { [weak self] in
            let total = try? await AnonymousTelemetry.shared.publicSavedTotal()
            guard let self, route == .firstPlayer else { return }
            firstPlayerSavedTotal = total
            rebuild()
        }
    }

    var firstPlayerPack: MobileContentPack? {
        let id = configuration == .ultimateLemmix ? "authored/" + GameStarterContent.identifier : "release/lemmings"
        return catalogue?.pack(id: id) ?? catalogue?.packs(in: .classic).first
    }

    func startFirstLevel() {
        guard let initials = nameDraft, !initials.isEmpty else { return }
        searchField.resignFirstResponder()
        let previous = profiles
        profiles.rename(profiles.activeID, to: initials)
        profiles.setPortrait(profiles.activeID, to: draftPortrait)
        guard saveProfiles() else { profiles = previous; rebuild(); return }
        UserDefaults.standard.set(true, forKey: Self.firstPlayerCompleteKey)
        if let pack = firstPlayerPack {
            openPack(pack, back: .home, play: 0)
        } else if library?.levels.isEmpty == false {
            startLevel(0, checkpoint: nil)
        } else {
            navigate(.data)
            dataBackRoute = .home
        }
    }

    func effectsWelcomePage() -> GameFrontEnd.Page { MobileInformationArt.effectsWelcome() }
    func whatsNewPage() -> GameFrontEnd.Page {
        #if os(tvOS)
        MobileInformationArt.whatsNew(build: tvBuildInfo)
        #else
        MobileInformationArt.whatsNew(version: mobileVersion)
        #endif
    }
    func telemetryConsentPage() -> GameFrontEnd.Page { MobileInformationArt.telemetryConsent() }
    func handleWelcome(_ id: String) -> Bool {
        switch id {
        case "whatsNew": navigate(.whatsNew)
        case "welcomeOriginal", "welcomeModern":
            var saved = mobileSettings
            saved.applyExperiencePreset(modern: id == "welcomeModern")
            mobileSettings = saved
            UserDefaults.standard.set(true, forKey: "mobile.effectsChoice.v1")
            UserDefaults.standard.set(mobileBuild, forKey: "mobile.whatsNew.seenBuild")
            navigate(.home)
        case "welcomeContinue":
            #if os(tvOS)
            tvBuildInfo.acknowledge(in: .standard)
            #endif
            UserDefaults.standard.set(mobileBuild, forKey: "mobile.whatsNew.seenBuild")
            navigate(.home)
        case "telemetryYes", "telemetryNo":
            AnonymousTelemetry.shared.setSharing(id == "telemetryYes")
            navigate(.home)
        default: return false
        }
        return true
    }
}
#endif
