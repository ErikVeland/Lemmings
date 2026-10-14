#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

extension MobileLibraryViewController {
    private var mobileBuild: Int { Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0 }
    private var mobileVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0" }

    func beginWelcomeIfNeeded() {
        guard game == nil else { return }
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "mobile.effectsChoice.v1") { navigate(.effectsWelcome) }
        else if mobileBuild > defaults.integer(forKey: "mobile.whatsNew.seenBuild") { navigate(.whatsNew) }
        else if AnonymousTelemetry.shared.sharingAvailable, !AnonymousTelemetry.shared.consentDecided { navigate(.telemetryConsent) }
    }
    func effectsWelcomePage() -> GameFrontEnd.Page { MobileInformationArt.effectsWelcome() }
    func whatsNewPage() -> GameFrontEnd.Page { MobileInformationArt.whatsNew(version: mobileVersion) }
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
            navigate(.home); beginWelcomeIfNeeded()
        case "welcomeContinue":
            UserDefaults.standard.set(mobileBuild, forKey: "mobile.whatsNew.seenBuild")
            navigate(.home); beginWelcomeIfNeeded()
        case "telemetryYes", "telemetryNo":
            AnonymousTelemetry.shared.setSharing(id == "telemetryYes")
            navigate(.home)
        default: return false
        }
        return true
    }
}
#endif
