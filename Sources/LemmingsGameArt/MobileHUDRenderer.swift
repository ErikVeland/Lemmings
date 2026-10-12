import CoreGraphics
import Foundation
import NxlvKit
import LemmingsMobileCore

public enum MobileHUDAction: Equatable, Sendable {
    case releaseRate(Int)
    case skill(Int)
    case pause
    case endRun
    case speed
    case speedStep(Int)
    case rewind
    case stepBackward
    case step
    case menu
}

/// UIKit and the audit tool draw the same pixels and route the same input rectangles.
@MainActor public final class MobileHUDRenderer {
    public struct Item {
        public let action: MobileHUDAction
        public let frame: CGRect
        public let sourceCell: Int?
        public let accessibilityLabel: String
        public var inputFrame: CGRect {
            if case .speed = action { return speedInputFrame ?? frame }
            return frame
        }
        let speedInputFrame: CGRect?
    }

    private let layout: MobileHUDLayout
    private let snapshot: MobileGameSnapshot
    private let selectedSkill: Int
    private let paused: Bool
    private let speed: Double
    private let endRunArmed: Bool
    private let counterStyle: ClassicCounterStyle
    private let panelImage: CGImage?
    private let typography: GameMenuTypography?
    private let items: [Item]

    public init(layout: MobileHUDLayout, snapshot: MobileGameSnapshot, selectedSkill: Int,
                paused: Bool, speed: Double, endRunArmed: Bool, panelImage: CGImage?, typography: GameMenuTypography?, counterStyle: ClassicCounterStyle = .game) {
        self.layout = layout; self.snapshot = snapshot; self.selectedSkill = selectedSkill
        self.paused = paused; self.speed = speed; self.endRunArmed = endRunArmed
        self.counterStyle = counterStyle
        self.panelImage = panelImage; self.typography = typography
        items = Self.targets(layout: layout, snapshot: snapshot, selectedSkill: selectedSkill,
                             paused: paused, speed: speed, endRunArmed: endRunArmed)
    }

    public static func targets(layout: MobileHUDLayout, snapshot: MobileGameSnapshot, selectedSkill: Int,
                               paused: Bool, speed: Double, endRunArmed: Bool) -> [Item] {
        var descriptors: [(MobileHUDAction, Int?, String)] = []
        if let rate = snapshot.releaseRate {
            descriptors.append((.releaseRate(-1), 0, "Decrease release rate, currently \(rate)"))
            descriptors.append((.releaseRate(1), 1, "Increase release rate, currently \(rate)"))
        }
        for (index, skill) in snapshot.skills.enumerated() {
            let amount = skill.isUnlimited ? "unlimited" : "\(skill.count) remaining"
            let selected = index == selectedSkill ? ", selected" : ""
            descriptors.append((.skill(index), index + 2, "\(skill.name), \(amount)\(selected)"))
        }
        descriptors.append((.pause, 10, paused ? "Resume" : "Pause"))
        let endRunLabel = snapshot.isEndingRun
            ? "Undo end run"
            : (endRunArmed ? "Confirm end run" : "End run")
        descriptors.append((.endRun, 11, endRunLabel))
        descriptors.append((.speed, nil, "Game speed \(Self.speedLabel(speed))"))
        if layout.supportsRewind {
            descriptors.append((.rewind, nil, "Rewind two seconds"))
            descriptors.append((.stepBackward, nil, "Step backward one tick"))
        }
        descriptors.append((.step, nil, "Advance one tick"))
        descriptors.append((.menu, nil, "Menu"))

        var items = zip(descriptors, layout.interface.controlFrames).map { descriptor, frame in
            Item(
                action: descriptor.0,
                frame: Self.cgRect(frame),
                sourceCell: descriptor.1,
                accessibilityLabel: descriptor.2,
                speedInputFrame: descriptor.0 == .speed && layout.speedArrows.count == 2
                    ? CGRect(x: layout.speedArrows[0].maxX, y: frame.y,
                             width: layout.speedArrows[1].minX - layout.speedArrows[0].maxX, height: frame.height) : nil
            )
        }
        if layout.speedArrows.count == 2 {
            items.append(Item(action: .speedStep(-1), frame: layout.speedArrows[0], sourceCell: nil,
                              accessibilityLabel: "Slower", speedInputFrame: nil))
            items.append(Item(action: .speedStep(1), frame: layout.speedArrows[1], sourceCell: nil,
                              accessibilityLabel: "Faster", speedInputFrame: nil))
        }
        return items
    }

    private static let shortNames = [
        "walker": "WALK", "jumper": "JUMP", "shimmier": "SHIM", "slider": "SLIDE", "climber": "CLIMB",
        "swimmer": "SWIM", "floater": "FLOAT", "glider": "GLIDE", "disarmer": "DISARM", "bomber": "BOMB",
        "stoner": "STONE", "blocker": "BLOCK", "platformer": "PLAT", "builder": "BUILD", "stacker": "STACK",
        "laserer": "LASER", "basher": "BASH", "fencer": "FENCE", "miner": "MINE", "digger": "DIG", "cloner": "CLONE",
    ]

    public func draw(in context: CGContext, bounds: CGRect) {
        context.setShouldAntialias(false)
        context.interpolationQuality = .none
        let statusFrame = Self.cgRect(layout.interface.statusFrame)
        if let panel = layout.panel {
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: panel.frame.minY, width: bounds.width, height: bounds.height - panel.frame.minY))
            drawPanel(panel, context: context)
        } else {
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(statusFrame)
            for item in items { drawCell(item, context: context) }
        }
        drawStatus(in: statusFrame, panelMode: layout.panel != nil, context: context)
    }

    // MARK: - Classic panel

    private func drawPanel(_ panel: MobilePanelMetrics, context: CGContext) {
        if let panelImage {
            GameStoneArt.drawImage(panelImage, in: panel.frame, context: context)
        }
        for item in items {
            switch item.action {
            case .pause, .endRun:
                drawGlyphButton(item, context: context, pixel: panel.bevel)
            case .speed:
                drawSpeed(item.frame, bevel: panel.bevel, context: context)
            case .rewind, .stepBackward, .step:
                drawIconButton(item, context: context)
            case .menu:
                drawTextButton(item, context: context)
            case .speedStep:
                break
            case .releaseRate, .skill:
                break
            }
        }
        drawCounts(panel, context: context)
        drawSkillLabels(panel, context: context)
        if let item = items.first(where: { $0.action == .skill(selectedSkill) }) {
            outline(item.frame, context: context)
        }
    }

    private func drawCounts(_ panel: MobilePanelMetrics, context: CGContext) {
        for item in items {
            let value: String
            switch item.action {
            case .releaseRate:
                guard let rate = snapshot.releaseRate else { continue }
                value = "\(rate)"
            case let .skill(index):
                guard let skill = snapshot.skills[safe: index] else { continue }
                value = skill.isUnlimited ? "∞" : "\(skill.count)"
            default:
                continue
            }
            // Quantities sit in their own strip above the skill artwork.
            let box = CGRect(x: item.frame.minX, y: panel.frame.minY + panel.scale,
                             width: item.frame.width, height: 9 * panel.scale)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(box)
            if counterStyle != .macintosh || typography?.drawCounter(value, in: box, panelScale: panel.scale, context: context) != true {
                drawGameLabel(value, in: box, context: context)
            }
        }
    }

    private func drawSkillLabels(_ panel: MobilePanelMetrics, context: CGContext) {
        let names = snapshot.skills.map { Self.shortNames[$0.name.lowercased()] ?? $0.name.uppercased() }
        let longest = names.map(\.count).max() ?? 1
        for item in items {
            guard case let .skill(index) = item.action, let name = names[safe: index] else { continue }
            let box = CGRect(x: item.frame.minX, y: panel.frame.minY + 10 * panel.scale,
                             width: item.frame.width, height: 5 * panel.scale)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(box)
            let fits = typography.map { typography in
                typography.font(.small).map {
                    $0.cellWidth * longest <= Int(box.width) && $0.cellHeight <= Int(box.height)
                } ?? false
            } ?? false
            if fits {
                GamePixelTypography.draw(name, in: box, context: context, typography: typography, maximumScale: 1)
            } else {
                let scale = max(1, min(3, floor(min(box.height / 7, box.width / CGFloat(longest * 6)))))
                GamePixelTypography.draw(name, in: box, context: context, typography: typography, maximumScale: scale, bitmapOnly: true)
            }
        }
    }

    private func drawSpeed(_ frame: CGRect, bevel: CGFloat, context: CGContext) {
        let active = speed > 1
        drawStoneSocket(frame, selected: active, pixel: bevel, context: context)
        let pixel = SpeedPanelArt.pixel(forHeight: frame.height)
        let boxes: [CGRect]
        if layout.speedArrows.count == 2 {
            let left = layout.speedArrows[0], right = layout.speedArrows[1]
            boxes = [left, CGRect(x: left.maxX, y: frame.minY, width: right.minX - left.maxX, height: frame.height), right]
        } else { boxes = SpeedPanelArt.boxes(in: frame) }
        SpeedPanelArt.drawArrow(in: context, box: boxes[0], pointsRight: false)
        SpeedPanelArt.drawArrow(in: context, box: boxes[2], pointsRight: true)
        let label = boxes[1].insetBy(dx: frame.height >= 60 ? 4 * pixel : pixel, dy: 6 * pixel)
        drawGameLabel(Self.speedLabel(speed), in: label, context: context)
    }

    private func outline(_ frame: CGRect, context: CGContext) {
        context.setStrokeColor(CGColor(gray: 1, alpha: 1))
        context.setLineWidth(2)
        context.stroke(frame.insetBy(dx: 2, dy: 2))
    }

    // MARK: - Compact cells

    private func drawCell(_ item: Item, context: CGContext) {
        let frame = item.frame
        let selected: Bool
        if case let .skill(index) = item.action { selected = index == selectedSkill }
        else if item.action == .pause { selected = paused }
        else if item.action == .endRun { selected = snapshot.isEndingRun == true }
        else if item.action == .speed { selected = speed > 1 }
        else { selected = false }

        switch item.action {
        case .releaseRate, .skill:
            drawStoneSocket(frame, selected: false, pixel: 1, context: context)
            let scale = layout.compactScale
            let well = GameStoneArt.well(frame, pixel: 1)
            context.saveGState()
            context.clip(to: well)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(well)
            if let cell = item.sourceCell,
               let image = panelImage?.cropping(to: CGRect(x: cell * 16, y: 16, width: 16, height: 24)) {
                let art = CGRect(x: frame.midX - 8 * scale, y: frame.minY + (scale == 1 ? 16 : 18), width: 16 * scale, height: 24 * scale)
                GameStoneArt.drawImage(image, in: art, context: context)
            }
            context.restoreGState()
            drawCompactCount(item, in: frame, context: context)
            if selected { outline(frame, context: context) }
        case .pause, .endRun:
            drawGlyphButton(item, context: context, pixel: 1)
        case .speed:
            drawSpeed(frame, bevel: 1, context: context)
        case .menu:
            drawTextButton(item, context: context)
        case .rewind, .stepBackward, .step:
            drawIconButton(item, context: context)
        case .speedStep:
            break
        }
    }

    private func drawCompactCount(_ item: Item, in frame: CGRect, context: CGContext) {
        let value: String
        switch item.action {
        case .releaseRate:
            guard let rate = snapshot.releaseRate else { return }
            value = "\(rate)"
        case let .skill(index):
            guard let skill = snapshot.skills[safe: index] else { return }
            value = skill.isUnlimited ? "∞" : "\(skill.count)"
        default:
            return
        }
        drawGameLabel(value, in: CGRect(x: frame.minX + 4, y: frame.minY + 4, width: frame.width - 8, height: 14), context: context)
        if case let .skill(index) = item.action, let skill = snapshot.skills[safe: index] {
            let name = Self.shortNames[skill.name.lowercased()] ?? skill.name.uppercased()
            let label = CGRect(x: frame.minX + 3, y: frame.maxY - 14, width: frame.width - 6, height: 10)
            let scale = max(1, min(2, floor(min(label.height / 7, label.width / CGFloat(max(1, name.count * 6))))))
            GamePixelTypography.draw(name, in: label, context: context, typography: typography, maximumScale: scale, bitmapOnly: true)
        }
    }

    private func drawIconButton(_ item: Item, context: CGContext) {
        let enabled = item.action == .step ? paused : (item.action == .stepBackward || item.action == .rewind ? snapshot.tick > 0 : true)
        GameStoneArt.draw(in: context, frame: item.frame, selected: false, pixel: 1)
        let glyph: PanelGlyphArt = item.action == .rewind ? .rewind : item.action == .stepBackward ? .stepBackward : .stepForward
        let well = GameStoneArt.well(item.frame, pixel: 1)
        guard let image = Self.glyphImage(glyph, fitting: CGSize(width: well.width, height: well.height / 2)) else { return }
        context.saveGState()
        context.setAlpha(enabled ? 1 : 0.35)
        GameStoneArt.drawImage(image.image, in: CGRect(
            x: floor(well.midX - image.size.width / 2), y: floor(well.midY - image.size.height / 2),
            width: image.size.width, height: image.size.height), context: context)
        context.restoreGState()
    }

    // MARK: - Shared pieces

    private func drawStoneSocket(_ frame: CGRect, selected: Bool, pixel: CGFloat, context: CGContext) {
        GameStoneArt.drawSocket(in: context, frame: frame, selected: selected, pixel: pixel)
        if let rock = Self.glyphImage(.rock, fitting: frame.size) {
            GameStoneArt.drawTile(in: context, image: rock.image, logicalSize: rock.size, frame: frame, pixel: pixel)
        }
        GameStoneArt.drawAccent(in: context, frame: frame, selected: selected, pixel: pixel)
    }

    private func drawGlyphButton(_ item: Item, context: CGContext, pixel: CGFloat) {
        let selected = item.action == .pause ? paused : (snapshot.isEndingRun == true)
        let glyph: PanelGlyphArt
        if item.action == .pause { glyph = paused ? .play : .pause }
        else { glyph = snapshot.isEndingRun == true ? .undo : .nuke }
        drawStoneSocket(item.frame, selected: selected, pixel: pixel, context: context)
        let well = GameStoneArt.well(item.frame, pixel: pixel)
        if glyph.isOriginalTile {
            if let image = Self.glyphImage(glyph, fitting: item.frame.size) {
                GameStoneArt.drawTile(in: context, image: image.image, logicalSize: image.size,
                                      frame: item.frame, pixel: pixel)
            }
        } else if let image = Self.glyphImage(glyph, fitting: well.size) {
            GameStoneArt.drawImage(image.image, in: CGRect(
                x: floor(well.midX - image.size.width / 2), y: floor(well.midY - image.size.height / 2),
                width: image.size.width, height: image.size.height), context: context)
        }
        if item.action == .endRun, endRunArmed, !selected { outline(item.frame, context: context) }
    }

    private func drawTextButton(_ item: Item, context: CGContext) {
        let enabled = item.action != .step || paused
        GameStoneArt.draw(in: context, frame: item.frame, selected: false, pixel: 1)
        let title = item.action == .step ? "STEP" : "MENU"
        GamePixelTypography.draw(title, in: item.frame.insetBy(dx: 8, dy: 2), context: context, typography: typography, palette: .blue, alpha: enabled ? 1 : 0.45)
    }

    /// Panel text in the game font, falling back to the pixel font when it will not fit.
    private func drawGameLabel(_ text: String, in box: CGRect, context: CGContext) {
        let plain = text.replacingOccurrences(of: "∞", with: "*")
        if let font = typography?.font(.small),
           font.cellHeight <= Int(box.height), font.cellWidth * plain.count <= Int(box.width) {
            GamePixelTypography.draw(plain, in: box, context: context, typography: typography, maximumScale: 1)
        } else {
            let scale = max(1, min(3, floor(min(box.height / 7, box.width / CGFloat(max(1, plain.count * 6))))))
            GamePixelTypography.draw(plain, in: box, context: context, typography: typography, maximumScale: scale, bitmapOnly: true)
        }
    }

    private func drawStatus(in frame: CGRect, panelMode: Bool, context: CGContext) {
        let time: String
        if let remaining = snapshot.remainingSeconds {
            time = String(format: "%d:%02d", remaining / 60, remaining % 60)
        } else {
            time = "--:--"
        }
        let status = "OUT \(snapshot.released)  HOME \(snapshot.saved)/\(snapshot.required)  \(time)"
        let available = panelMode
            ? CGRect(x: frame.minX, y: frame.minY,
                     width: max(0, (items.first { $0.action == .rewind || $0.action == .step }?.frame.minX ?? frame.maxX) - frame.minX - 4), height: frame.height)
            : frame
        let inset = panelMode ? CGFloat(8) : 6
        GamePixelTypography.draw(status, in: available.insetBy(dx: inset, dy: 2), context: context, typography: typography,
                             palette: snapshot.didWin ? .green : .blue, maximumScale: 1,
                             alignment: panelMode ? .left : .center)
    }

    private static func speedLabel(_ speed: Double) -> String {
        speed.rounded() == speed ? "\(Int(speed))X" : String(format: "%.1fX", speed)
    }

    private static func cgRect(_ rect: MobileRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    private static var glyphCache: [String: (image: CGImage, size: CGSize)] = [:]

    private static func glyphImage(_ glyph: PanelGlyphArt, fitting box: CGSize) -> (image: CGImage, size: CGSize)? {
        let steps = glyph.scale(fitting: box)
        guard steps >= 1 else { return nil }
        let key = "\(glyph.rawValue)-\(steps)"
        if let hit = glyphCache[key] { return hit }
        guard let image = glyph.cgImage(scale: steps) else { return nil }
        let size = CGSize(width: CGFloat(image.width) / (glyph.isOriginalTile ? 2 : 1), height: CGFloat(image.height))
        glyphCache[key] = (image, size)
        return (image, size)
    }

}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
