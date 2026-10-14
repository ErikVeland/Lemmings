#if os(tvOS)
import LemmingsGameArt
import LemmingsMobileCore
import LemmingsTVCore
import UIKit

@MainActor final class TVPlayfieldView: UIView {
    var experience: TVGameExperience?
    var image: CGImage?
    var actorSprite: CGImage?
    var skillImage: CGImage?
    var renderError: String?
    var ownerName = ""
    var ownerPortrait = 0
    var cameraAdjustment = false
    var onAssign: (() -> Void)?
    var onCycle: ((Int) -> Void)?
    var onPause: (() -> Void)?
    var onRenderFailure: ((String) -> Void)?
    private var sourceTick = -1
    private var sourceTarget: Int?
    private var sourceControl = -1
    override var canBecomeFocused: Bool { false }

    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = .black; isOpaque = true
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityLabel = "Level playfield"
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Assign selected skill", actionHandler: { [weak self] _ in self?.onAssign?(); return true }),
            UIAccessibilityCustomAction(name: "Next eligible lemming", actionHandler: { [weak self] _ in self?.onCycle?(1); return true }),
            UIAccessibilityCustomAction(name: "Previous eligible lemming", actionHandler: { [weak self] _ in self?.onCycle?(-1); return true }),
            UIAccessibilityCustomAction(name: "Pause and open controls", actionHandler: { [weak self] _ in self?.onPause?(); return true })
        ]
    }
    required init?(coder: NSCoder) { nil }

    var playBounds: CGRect { TVPlayfieldArt.playBounds(in: bounds) }

    override func layoutSubviews() {
        super.layoutSubviews()
        experience?.resize(.init(width: playBounds.width, height: playBounds.height))
    }

    func refresh(force: Bool = false) {
        guard let game = experience else { return }
        if force || sourceTick != game.session.snapshot.tick || sourceTarget != game.target?.id || sourceControl != game.selectedControl {
            do {
                let frame = try game.session.render(highlight: game.target)
                image = MobileBitmapRenderer.image(frame)
                sourceTick = game.session.snapshot.tick; sourceTarget = game.target?.id; sourceControl = game.selectedControl
                skillImage = game.session.skillCursorFrame(control: game.selectedControl).flatMap(MobileBitmapRenderer.image)
                actorSprite = game.target.flatMap { game.session.spriteHighlight(for: $0.id) }.flatMap { MobileBitmapRenderer.image($0.frame) }
                renderError = nil
            } catch {
                let message = error.localizedDescription
                if renderError != message { renderError = message; onRenderFailure?(message) }
            }
        }
        let skill = game.session.snapshot.skills.indices.contains(game.selectedControl) ? game.session.snapshot.skills[game.selectedControl].name : "No skill"
        let status = game.target.map { "Lemming \($0.id), \($0.state == .eligible ? "eligible" : "unavailable")" } ?? "No target"
        accessibilityValue = "\(ownerName). \(skill). \(status). \(game.session.snapshot.saved) rescued, \(game.session.snapshot.required) required. \(game.play.isPaused ? "Paused" : "Playing")."
        setNeedsDisplay()
    }

    private let renderer = TVPlayfieldArt(typography: TVArtwork.typography, portraits: TVArtwork.portraits)
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let game = experience else { return }
        renderer.ownerName = ownerName; renderer.ownerPortrait = ownerPortrait; renderer.cameraAdjustment = cameraAdjustment
        renderer.draw(game: game, image: image, skillImage: skillImage, bounds: bounds, in: context)
        if let renderError { TVMenuArt.text(renderError, box: playBounds.insetBy(dx: 30, dy: 30), context: context) }
    }
}
#endif
