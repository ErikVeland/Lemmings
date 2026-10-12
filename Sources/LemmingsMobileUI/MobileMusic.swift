#if os(iOS)
import LemmingsAudio
import LemmingsMobileCore
import NxlvKit
import UIKit

/// Plays each level's assigned tune, as the Mac does.
///
/// The slim bundle carries the essential tracker modules. Recordings from
/// downloaded libraries are a later layer over the same assignment.
@MainActor final class MobileMusic {
    static let shared = MobileMusic()
    static let enabledKey = "mobile.music"

    static let soundtrackKey = "mobile.soundtrack"

    private let module = ModuleMusicPlayer()
    private let recordings = SoundtrackPlayer()
    private var playing: String?
    private var usingRecording = false

    private var musicRoot: URL? { Bundle.main.resourceURL?.appendingPathComponent("Music") }

    /// "Original" first, then every folder of recordings found in the bundle and installed libraries.
    var soundtrackNames: [String] {
        guard let root = musicRoot else { return ["Original"] }
        return ["Original"] + SoundtrackPlayer.soundtracks(at: root).keys.sorted()
    }

    /// The chosen soundtrack. A folder that is no longer installed falls back to the original modules.
    var soundtrack: String {
        get {
            let saved = UserDefaults.standard.string(forKey: Self.soundtrackKey) ?? "Original"
            return soundtrackNames.contains(saved) ? saved : "Original"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.soundtrackKey)
            stop()
        }
    }

    func cycleSoundtrack() {
        let names = soundtrackNames
        let current = names.firstIndex(of: soundtrack) ?? 0
        soundtrack = names[(current + 1) % names.count]
    }
    // Mechanical tests stay silent without changing the player's saved preference.
    private var isTestAudioMuted: Bool {
        ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted"
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if !newValue { stop() }
        }
    }

    /// Starts the tune for a level. Repeat calls for the same level keep it playing.
    func play(identifier: String, index: Int, title: String) {
        guard isEnabled, !isTestAudioMuted else { return }
        let key = identifier + "|" + soundtrack
        guard playing != key else { return }
        let tune = MobileMusicAssignment.tune(identifier: identifier, index: index, title: title)
        let (folder, track) = (tune.folder, tune.track)
        if playRecording(tune: tune) {
            module.stop()
            playing = key
            usingRecording = true
            return
        }
        recordings.stop()
        usingRecording = false
        guard let root = BundledGameResources.music(folder),
              let url = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil))?
                .first(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == track.lowercased() && $0.pathExtension.lowercased() == "mod" })
        else { return }
        do {
            try module.start()
            module.play(url: url)
            playing = key
        } catch {
            playing = nil
        }
    }

    /// A recording matches only when it is the assigned composition, as on the Mac.
    private func playRecording(tune: MobileMusicAssignment.Tune) -> Bool {
        let name = soundtrack
        guard name != "Original", let root = musicRoot,
              let tracks = SoundtrackPlayer.soundtracks(at: root)[name] else { return false }
        guard let index = tracks.firstIndex(where: {
            SoundtrackPlayer.matches($0, trackID: tune.game + "." + tune.track.lowercased(), root: root)
        }) else { return false }
        recordings.load(tracks)
        return recordings.play(index: index) != nil
    }

    func suspend() { module.suspendOutput() }

    func resume() {
        guard isEnabled, !isTestAudioMuted, playing != nil else { return }
        try? module.resumeOutput()
    }

    func stop() {
        module.stop()
        playing = nil
    }
}
#endif
