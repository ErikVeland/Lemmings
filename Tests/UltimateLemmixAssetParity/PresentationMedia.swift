import Foundation

/**
 * Records only the existing soundtrack setter boundary, without an audio engine.
 */
@MainActor final class MobileMusic {
    static let shared = MobileMusic()
    private(set) var savedSoundtrack = "Original"
    private(set) var writes = 0
    var soundtrack: String {
        get { savedSoundtrack == "Lix" ? "Original" : savedSoundtrack }
        set { savedSoundtrack = newValue; writes += 1 }
    }
    func seed(_ value: String) { self.savedSoundtrack = value; writes = 0 }
}

struct PresentationSettings { let soundtrack: String }
@MainActor var mobileSettings: PresentationSettings {
    PresentationSettings(soundtrack: MobileMusic.shared.savedSoundtrack)
}

@main struct PresentationMediaSelection {
    @MainActor static func main() {
        for (before, after, writes) in [("Lix", "Original", 1), ("Original", "Original", 0),
                                         ("Macintosh", "Macintosh", 0), ("Custom", "Custom", 0)] {
            MobileMusic.shared.seed(before)
            restoreImportedMedia()
            guard MobileMusic.shared.savedSoundtrack == after && MobileMusic.shared.writes == writes else {
                print("FAIL full import soundtrack: \(before) -> \(MobileMusic.shared.savedSoundtrack)")
                exit(1)
            }
        }
        print("PASS full-import soundtrack selection in four states")
    }
}
