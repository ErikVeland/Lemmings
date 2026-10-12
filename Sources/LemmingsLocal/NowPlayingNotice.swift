#if os(macOS)
import AppKit
import LemmingsAudio
import NxlvKit

struct PlayingTrack: Equatable {
    let url: URL
    let title: String
    let soundtrack: String
}

@MainActor enum PlayingTrackMetadata {
    private static var cached: [URL: PlayingTrack] = [:]
    private static let root = Bundle.main.resourceURL?.appendingPathComponent("Music")
    private static let catalogue = root.flatMap { SoundtrackCatalogue.load(at: $0) }
    private static let libraries = MusicLibrary.catalogue(at: root)

    static func track(url: URL, fallbackTitle: String? = nil) -> PlayingTrack {
        if let value = cached[url] { return value }
        if let macRoot = Bundle.main.resourceURL?.appendingPathComponent("MacMusic"),
           let relative = SoundtrackPlayer.relativePath(url, under: macRoot), ClassicMacMusicLibrary.requiredPaths.contains(relative) {
            let family = relative.split(separator: "/").first.map(String.init) ?? "classic"
            let gameID = family == "xmas" ? "holiday" : family
            let name = url.deletingPathExtension().lastPathComponent
            let title = catalogue?.track(id: gameID + "." + name)?.title ?? name.capitalized
            let game = family == "ohno" ? "Oh No! More Lemmings" : family == "xmas" ? "Holiday Lemmings" : "Lemmings"
            let value = PlayingTrack(url: url, title: title, soundtrack: game + " - Macintosh (original)")
            cached[url] = value
            return value
        }
        let path = root.flatMap { SoundtrackPlayer.cataloguePath(url, root: $0) }
        let entry = path.flatMap { catalogue?.entry(path: $0) }
        let title = entry?.track.title ?? fallbackTitle ?? url.deletingPathExtension().lastPathComponent
        let library = path.flatMap { path in libraries?.packs.first { pack in
            pack.files.contains { $0.path == "Music/" + path }
        }?.title }
        let games = ["classic": "Lemmings", "lemmings": "Lemmings", "lemmings2": "Lemmings 2", "lemmings3": "Lemmings 3",
                     "ohno": "Oh No! More Lemmings", "holiday": "Holiday Lemmings"]
        let game = entry.map { games[$0.track.game] ?? $0.track.game.capitalized }
        let source = library ?? entry.map { $0.variant.port == "amiga" ? "Amiga" : $0.variant.port.uppercased() }
            ?? url.deletingLastPathComponent().lastPathComponent.replacingOccurrences(of: "_", with: " ")
        let value = PlayingTrack(url: url, title: title, soundtrack: game.map { $0 + " - " + source } ?? source)
        cached[url] = value
        return value
    }
}

/// A brief bitmap notice. Pointer input passes through to the game.
@MainActor final class NowPlayingNotice: NSView {
    private(set) var track: PlayingTrack?
    private var shownAt: TimeInterval = 0
    private var currentURL: URL?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(track next: PlayingTrack?, at now: TimeInterval, visible: Bool, reduceMotion: Bool) {
        guard visible, let next else {
            isHidden = true
            if next == nil { currentURL = nil; track = nil }
            return
        }
        if currentURL != next.url {
            currentURL = next.url; track = next; shownAt = now
            setAccessibilityElement(true); setAccessibilityRole(.group)
            setAccessibilityLabel(next.title + ". " + next.soundtrack)
        }
        let elapsed = now - shownAt
        isHidden = elapsed >= 4.5
        alphaValue = reduceMotion ? 1 : CGFloat(min(1, max(0, (4.5 - elapsed) / 0.5)))
        needsDisplay = !isHidden
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let track else { return }
        GameStoneButton.draw(bounds, selected: false, pixel: 1)
        GameControlText.draw(track.title, in: CGRect(x: 12, y: 5, width: bounds.width - 24, height: 24), role: .heading)
        GameControlText.draw(track.soundtrack, in: CGRect(x: 12, y: 30, width: bounds.width - 24, height: 24))
    }
}
#endif
