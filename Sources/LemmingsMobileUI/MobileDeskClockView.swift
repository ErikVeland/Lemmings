#if os(iOS)
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

/// The idle clock scene. A 30 fps display link advances the simulation and draws it with the Macintosh
/// artwork into a bitmap at two pixels per classic pixel; the layer scales it with whole pixels.
@MainActor final class MobileDeskClockView: UIView {
    private static let artwork: GameDeskClockArt? = Bundle.main.resourceURL.flatMap {
        GameDeskClockArt(directory: $0.appendingPathComponent("MacArtwork/lemmings"))
    }
    private static let density = 2

    var event: DeskClockEvent? {
        didSet {
            guard event != oldValue else { return }
            labelMinute = -1
            tick(now: Date())
        }
    }
    private let scene = CALayer()
    private var simulation: DeskClockSimulation
    private var link: CADisplayLink?
    private let started = CACurrentMediaTime()
    private var labelMinute = -1

    init(now: Date = Date(), settings: MobileSettings = .current(from: .standard)) {
        simulation = DeskClockSimulation(now: now, uses24Hour: DeskClockFace.uses24Hour(locale: .current),
            reduceMotion: UIAccessibility.isReduceMotionEnabled || settings.classic.reduceMotion,
            reduceFlashes: settings.classic.reduceFlashes,
            seed: UInt64(bitPattern: Int64(now.timeIntervalSince1970.rounded(.down))))
        super.init(frame: .zero)
        backgroundColor = .black
        isOpaque = true
        isAccessibilityElement = true
        accessibilityTraits = [.staticText, .updatesFrequently]
        scene.magnificationFilter = .nearest
        scene.minificationFilter = .nearest
        scene.actions = ["position": NSNull(), "bounds": NSNull(), "contents": NSNull()]
        layer.addSublayer(scene)
        refreshAccessibility(now: now)
    }

    required init?(coder: NSCoder) { nil }

    /// Starts or pauses the display link. The controller pauses it while the app is inactive.
    var isRunning: Bool {
        get { link.map { !$0.isPaused } ?? false }
        set {
            if newValue, link == nil {
                let target = MobileDisplayLinkTarget { [weak self] _ in self?.tick(now: Date()) }
                let link = CADisplayLink(target: target, selector: #selector(MobileDisplayLinkTarget.frame(_:)))
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
                link.add(to: .main, forMode: .common)
                self.link = link
            }
            link?.isPaused = !newValue
            if newValue { tick(now: Date()) }
        }
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        tick(now: Date())
    }

    private func tick(now: Date) {
        simulation.advance(to: now, event: event)
        refreshAccessibility(now: now)
        let size = GameDeskClockArt.sceneSize
        let fit = min(bounds.width / size.width, bounds.height / size.height)
        guard fit > 0 else { return }
        let scale = fit >= 1 ? fit.rounded(.down) : fit
        let shift = DeskClockFace.burnInOffset(at: now)
        scene.frame = CGRect(x: ((bounds.width - size.width * scale) / 2).rounded(.down) + CGFloat(shift.x),
                             y: ((bounds.height - size.height * scale) / 2).rounded(.down) + CGFloat(shift.y),
                             width: size.width * scale, height: size.height * scale)
        guard let art = Self.artwork else { return }
        let width = Int(size.width) * Self.density, height = Int(size.height) * Self.density
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        art.draw(simulation, event: event, now: now, time: CACurrentMediaTime() - started, in: context,
                 rect: CGRect(x: 0, y: 0, width: width, height: height),
                 nightDim: DeskClockFace.isNight(now, calendar: simulation.calendar))
        scene.contents = context.makeImage()
    }

    private func refreshAccessibility(now: Date) {
        let minute = Int((now.timeIntervalSince1970 / 60).rounded(.down))
        guard minute != labelMinute else { return }
        labelMinute = minute
        accessibilityLabel = Self.accessibilityLabel(now: now, event: event, locale: .current, calendar: simulation.calendar)
    }

    /// The time, then the next event and its countdown, as one VoiceOver element.
    static func accessibilityLabel(now: Date, event: DeskClockEvent?, locale: Locale, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: now)
        guard let event else { return time }
        let start = formatter.string(from: event.start)
        let countdown = DeskClockFace.countdown(to: event.start, now: now)
        return time + ". " + L10n.text("Next: \(event.title) at \(start), \(countdown)")
    }
}
#endif
