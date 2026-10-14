import CoreGraphics
import Foundation
import LemmingsMobileCore
import LemmingsTVCore

/// The shipping TV playfield renderer also supplies offscreen acceptance captures.
@MainActor public final class TVPlayfieldArt {
    public var ownerName = ""
    public var ownerPortrait = 0
    public var cameraAdjustment = false
    private let typography: GameMenuTypography?
    private let portraits: GamePortraitArt?
    private var bounds = CGRect.zero
    private var image: CGImage?
    private var skillImage: CGImage?
    private let countdown = BombCountdownRenderer()
    public init(typography: GameMenuTypography? = nil, portraits: GamePortraitArt? = nil) {
        self.typography = typography; self.portraits = portraits
    }
    public static func playBounds(in bounds: CGRect) -> CGRect {
        CGRect(x: 0, y: 44, width: bounds.width, height: max(1, bounds.height - 184))
    }
    public func draw(game: TVGameExperience, image: CGImage?, skillImage: CGImage?, bounds: CGRect, in context: CGContext) {
        self.bounds = bounds; self.image = image; self.skillImage = skillImage
        context.saveGState(); defer { context.restoreGState() }
        context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(bounds)
        let playBounds = Self.playBounds(in: bounds)
        context.saveGState(); context.translateBy(x: playBounds.minX, y: playBounds.minY)
        context.clip(to: CGRect(origin: .zero, size: playBounds.size))
        if let image { MobileBitmapRenderer.draw(image, viewport: game.viewport, in: context) }
        for fuse in game.session.bombCountdowns {
            let anchor = game.viewport.viewPoint(fromLevel: fuse.anchor)
            countdown.draw(seconds: fuse.seconds, above: CGPoint(x: anchor.x, y: anchor.y), zoom: game.viewport.zoom, in: context)
        }
        drawTarget(game, context: context)
        if let number = game.startNumber {
            let box = CGRect(x: playBounds.width / 2 - 60, y: playBounds.height / 2 - 60, width: 120, height: 120)
            GameStoneArt.draw(in: context, frame: box, selected: false, pixel: 2)
            TVMenuArt.text(String(number), box: box.insetBy(dx: 8, dy: 8), title: true, green: true,
                           typography: typography, textScale: 1.25, context: context)
        }
        context.restoreGState()
        drawHUD(game, context: context)
    }
    private func drawTarget(_ game: TVGameExperience, context: CGContext) {
        guard game.play.canEdit else { return }
        let pointer = game.pointer
        let point = CGPoint(x: pointer.x, y: pointer.y)
        Self.drawAimPointer(at: point, eligible: game.target?.state == .eligible,
                            occupied: game.target != nil, context: context)
        if game.session.snapshot.skills.indices.contains(game.selectedControl) {
            let skill = game.session.snapshot.skills[game.selectedControl]
            let remaining = game.session.skillCursorRemaining(control: game.selectedControl, target: game.target?.id)
            SkillPointerBadge.draw(icon: skillImage, name: skill.name,
                count: remaining.map(String.init) ?? (skill.isUnlimited && game.session.engineIdentifier != "lemmings3" ? "*" : nil), at: point,
                within: CGRect(x: 0, y: 0, width: game.viewport.viewSize.width, height: game.viewport.viewSize.height),
                scale: 2, context: context)
        }
        if let target = game.target {
            let projected = game.viewport.viewPoint(fromLevel: target.point)
            context.setStrokeColor(CGColor(gray: 1, alpha: 1)); context.setLineWidth(2)
            context.stroke(CGRect(x: projected.x - 15, y: projected.y - 20, width: 30, height: 38))
        }
    }
    /// The TV pointer stays visible over both terrain and HUD targets.
    public static func drawAimPointer(at point: CGPoint, eligible: Bool, occupied: Bool, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        let colour = eligible ? CGColor(srgbRed: 0.55, green: 1, blue: 0.4, alpha: 1)
            : occupied ? CGColor(srgbRed: 1, green: 0.8, blue: 0.15, alpha: 1)
            : CGColor(gray: 0.85, alpha: 1)
        let frame = CGRect(x: floor(point.x) - 11, y: floor(point.y) - 11, width: 22, height: 22)
        for left in [true, false] { for top in [true, false] {
            let horizontal = CGRect(x: left ? frame.minX : frame.maxX - 7,
                                    y: top ? frame.minY : frame.maxY - 2, width: 7, height: 2)
            let vertical = CGRect(x: left ? frame.minX : frame.maxX - 2,
                                  y: top ? frame.minY : frame.maxY - 7, width: 2, height: 7)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(horizontal.insetBy(dx: -1, dy: -1)); context.fill(vertical.insetBy(dx: -1, dy: -1))
            context.setFillColor(colour)
            context.fill(horizontal); context.fill(vertical)
        } }
    }

    private func drawHUD(_ game: TVGameExperience, context: CGContext) {
        let snapshot = game.session.snapshot
        let y = bounds.height - 142
        let skillCount = min(8, snapshot.skills.count)
        let start = max(0, min(game.selectedControl - 3, snapshot.skills.count - skillCount))
        let mapWidth: CGFloat = 230
        let cell = (bounds.width - mapWidth - 28) / CGFloat(max(1, skillCount))
        let widestName = snapshot.skills.map { typography?.width(of: $0.name, face: .small, scale: 2) ?? 0 }.max() ?? 0
        let labelScale: CGFloat = widestName <= cell - 12 ? 1.25 : 1
        for index in start..<(start + skillCount) {
            let skill = snapshot.skills[index]
            let box = CGRect(x: CGFloat(index - start) * cell, y: y, width: cell - 8, height: 132)
            GameStoneArt.draw(in: context, frame: box, selected: index == game.selectedControl, pixel: 2)
            if index == game.selectedControl { SkillPointerBadge.innerGlow(in: box.insetBy(dx: 4, dy: 4), context: context) }
            if let icon = game.session.skillCursorFrame(control: index).flatMap(MobileBitmapRenderer.image) {
                let iconScale = max(1, floor(min(44 / CGFloat(icon.width), 44 / CGFloat(icon.height))))
                let size = CGSize(width: CGFloat(icon.width) * iconScale, height: CGFloat(icon.height) * iconScale)
                GameStoneArt.drawImage(icon, in: CGRect(x: floor(box.midX - size.width / 2), y: floor(box.minY + 10 + (44 - size.height) / 2), width: size.width, height: size.height), context: context)
            }
            TVMenuArt.text(skill.isUnlimited ? "*" : String(skill.count), box: CGRect(x: box.minX + 8, y: box.minY + 56, width: box.width - 16, height: 32),
                green: index == game.selectedControl, typography: typography, textScale: 1.25, context: context)
            TVMenuArt.text(skill.name, box: CGRect(x: box.minX + 2, y: box.maxY - 42, width: box.width - 4, height: 38),
                green: index == game.selectedControl, enabled: skill.count > 0 || skill.isUnlimited, typography: typography, textScale: labelScale, context: context)
        }
        let visible = game.viewport.visibleLevelRect
        GameMinimapArt.draw(in: context, bounds: CGRect(x: bounds.width - mapWidth, y: y + 24, width: mapWidth, height: 64),
            image: image, visible: CGRect(x: visible.x, y: visible.y, width: visible.width, height: visible.height),
            levelSize: CGSize(width: game.session.levelSize.width, height: game.session.levelSize.height), overlay: true)
        let time = snapshot.remainingSeconds.map { "\($0 / 60):\(String(format: "%02d", $0 % 60))" } ?? ""
        let status = "\(snapshot.saved)/\(snapshot.required)  \(time)  \(Int(game.speed))X"
        TVMenuArt.text(status, box: CGRect(x: bounds.width / 2 - 260, y: 2, width: 520, height: 34), typography: typography, textScale: 1.25, context: context)
        portraits?.draw(ownerPortrait, in: CGRect(x: 0, y: 0, width: 38, height: 38), context: context)
        TVMenuArt.text(ownerName, box: CGRect(x: 44, y: 2, width: bounds.width / 2 - 320, height: 34), green: true, typography: typography, textScale: 1.25, context: context)
        if snapshot.skills.indices.contains(game.selectedControl) {
            TVMenuArt.text(snapshot.skills[game.selectedControl].name, box: CGRect(x: bounds.width - 440, y: 2, width: 370, height: 34),
                           green: true, typography: typography, textScale: 1.25, context: context)
        }
        if game.play.isPaused {
            if let glyph = (cameraAdjustment ? PanelGlyphArt.menu : PanelGlyphArt.play).cgImage(scale: 2) {
                GameStoneArt.drawImage(glyph, in: CGRect(x: bounds.width - 52, y: 6, width: 36, height: 28), context: context)
            }
        }
    }
}
