#if os(macOS)
import AppKit
import LemmingsAudio
import LemmingsGameArt
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
            let value = PlayingTrack(url: url, title: title, soundtrack: game + L10n.text(" - Macintosh (original)"))
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
                     "ohno": L10n.text("Oh No! More Lemmings"), "holiday": "Holiday Lemmings"]
        let game = entry.map { games[$0.track.game] ?? $0.track.game.capitalized }
        let source = library ?? entry.map { $0.variant.port == "amiga" ? L10n.text("Amiga") : $0.variant.port.uppercased() }
            ?? url.deletingLastPathComponent().lastPathComponent.replacingOccurrences(of: "_", with: " ")
        let value = PlayingTrack(url: url, title: title, soundtrack: game.map { $0 + " - " + source } ?? source)
        cached[url] = value
        return value
    }
}

/// A brief bitmap notice. Pointer input passes through to the game.
@MainActor final class NowPlayingNotice: NSView {
    private(set) var track: PlayingTrack?
    private(set) var artworkOpacity: CGFloat = 1
    private var shownAt: TimeInterval = 0
    private var currentURL: URL?
    private var expired = false
    private var card: MusicTitleCard.Layout?
    private var cardConstraint = CGSize.zero
    private var elapsed: TimeInterval = 0
    private weak var fontRenderer: MacInterfaceRenderer?
    private var typography: GameMenuTypography?
    var displayDuration: TimeInterval { card?.duration ?? 4.5 }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(track next: PlayingTrack?, at now: TimeInterval, visible: Bool, reduceMotion: Bool, enabled: Bool = true,
                area: CGRect? = nil, flipped: Bool = true) {
        guard enabled else {
            currentURL = nil; track = nil; isHidden = true; artworkOpacity = 0
            setAccessibilityElement(false)
            return
        }
        guard visible, let next else {
            isHidden = true
            if next == nil { currentURL = nil; track = nil }
            return
        }
        if let area {
            let constraint = CGSize(width: max(0, area.width - 24), height: max(0, min(area.height - 24, area.height * 0.45)))
            if track != next || cardConstraint != constraint {
                card = MusicTitleCard.layout(title: next.title, soundtrack: next.soundtrack,
                    maximumWidth: constraint.width, maximumHeight: constraint.height)
                cardConstraint = constraint
            }
            frame = MusicTitleCard.frame(size: card?.size ?? .zero, in: area, flipped: flipped)
        } else if track != next || card == nil {
            card = MusicTitleCard.layout(title: next.title, soundtrack: next.soundtrack,
                maximumWidth: bounds.width, maximumHeight: max(54, bounds.height))
        }
        if currentURL != next.url {
            currentURL = next.url; track = next; shownAt = now; expired = false
            setAccessibilityElement(true); setAccessibilityRole(.group)
            setAccessibilityLabel(next.title + ". " + next.soundtrack)
        }
        elapsed = now - shownAt
        if elapsed >= displayDuration { expired = true }
        isHidden = expired || card?.pages.isEmpty != false
        let fadeIn = min(1, max(0, elapsed / 0.35))
        let fadeOut = min(1, max(0, (displayDuration - elapsed) / 0.5))
        let progress = min(fadeIn, fadeOut)
        artworkOpacity = reduceMotion ? 1 : CGFloat(progress * progress * (3 - 2 * progress))
        needsDisplay = !isHidden
        superview?.setNeedsDisplay(frame)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let card, artworkOpacity > 0, let context = NSGraphicsContext.current?.cgContext else { return }
        let renderer = GameMenuArtwork.renderer()
        if fontRenderer !== renderer {
            fontRenderer = renderer
            typography = renderer.map { GameMenuTypography(interface: $0.interface) }
        }
        context.saveGState()
        context.setAlpha(artworkOpacity)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        MusicTitleCard.draw(card, elapsed: elapsed, typography: typography, in: context)
        context.endTransparencyLayer()
        context.restoreGState()
    }
}
#endif
