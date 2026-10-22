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
    /// The controller supplies the Mac's shared failure decision using live engine counts.
    public struct StatusDetails {
        public let lost: Int
        public let deathCounter: String
        public let accessibility: String
        public let engineIdentifier: String

        public init(lostCount: Int,
                    deathCounter: (visible: String, accessibility: String), engineIdentifier: String = "classic") {
            lost = max(0, lostCount)
            self.deathCounter = deathCounter.visible
            self.engineIdentifier = engineIdentifier
            accessibility = deathCounter.accessibility
        }
    }
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
    private let skillIcons: [CGImage?]
    private let readOnly: Bool
    private let playerName: String?
    private let playerPortrait: CGImage?
    private let counterStyle: ClassicCounterStyle
    private let panelImage: CGImage?
    private let typography: GameMenuTypography?
    private let items: [Item]
    private let statusDetails: StatusDetails?

    public init(layout: MobileHUDLayout, snapshot: MobileGameSnapshot, selectedSkill: Int,
                paused: Bool, speed: Double, endRunArmed: Bool, panelImage: CGImage?, typography: GameMenuTypography?, counterStyle: ClassicCounterStyle = .game, skillIcons: [CGImage?] = [], readOnly: Bool = false, playerName: String? = nil, playerPortrait: CGImage? = nil, statusDetails: StatusDetails? = nil) {
        self.layout = layout; self.snapshot = snapshot; self.selectedSkill = selectedSkill
        self.paused = paused; self.speed = speed; self.endRunArmed = endRunArmed
        self.skillIcons = skillIcons
        self.readOnly = readOnly
        self.playerName = playerName
        self.playerPortrait = playerPortrait
        self.counterStyle = counterStyle
        self.statusDetails = statusDetails
        self.panelImage = panelImage; self.typography = typography
        items = Self.targets(layout: layout, snapshot: snapshot, selectedSkill: selectedSkill,
                             paused: paused, speed: speed, endRunArmed: endRunArmed)
    }

    public static func targets(layout: MobileHUDLayout, snapshot: MobileGameSnapshot, selectedSkill: Int,
                               paused: Bool, speed: Double, endRunArmed: Bool) -> [Item] {
        var descriptors: [(MobileHUDAction, Int?, String)] = []
        if let rate = snapshot.releaseRate {
            descriptors.append((.releaseRate(-1), 0, L10n.text("Decrease release rate, currently \(rate)")))
            descriptors.append((.releaseRate(1), 1, L10n.text("Increase release rate, currently \(rate)")))
        }
        for (index, skill) in snapshot.skills.enumerated() {
            let amount = skill.isUnlimited ? L10n.text("unlimited") : L10n.text("\(skill.count) remaining")
            let selected = index == selectedSkill ? L10n.text(", selected") : ""
            descriptors.append((.skill(index), index + 2, L10n.text("\(SkillVocabulary.title(skill.name)), \(amount)\(selected)")))
        }
        descriptors.append((.pause, 10, paused ? L10n.text("Resume") : L10n.text("Pause")))
        let endRunLabel = snapshot.isEndingRun
            ? L10n.text("Undo end run")
            : (endRunArmed ? L10n.text("Confirm end run") : L10n.text("End run"))
        descriptors.append((.endRun, 11, endRunLabel))
        descriptors.append((.speed, nil, L10n.text("Game speed \(Self.speedLabel(speed)), tap to toggle, hold to accelerate")))
        if layout.supportsRewind {
            descriptors.append((.rewind, nil, L10n.text("Rewind two seconds")))
            descriptors.append((.stepBackward, nil, L10n.text("Step backward one tick")))
        }
        descriptors.append((.step, nil, L10n.text("Advance one tick")))
        if layout.showsMenuButton { descriptors.append((.menu, nil, L10n.text("Menu"))) }

        if layout.portrait != nil {
            descriptors = descriptors.map { action, cell, label in
                (action, cell, action == .pause ? L10n.text("\(label), hold for pause menu") :
                    action == .endRun ? label + (snapshot.isEndingRun ? L10n.text(", tap or hold") : L10n.text(", tap twice or hold")) : label)
            }
        }
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
                              accessibilityLabel: L10n.text("Slower"), speedInputFrame: nil))
            items.append(Item(action: .speedStep(1), frame: layout.speedArrows[1], sourceCell: nil,
                              accessibilityLabel: L10n.text("Faster"), speedInputFrame: nil))
        }
        return items
    }

    private static var shortNames: [String: String] { [
        "walker": L10n.text("WALK"), "jumper": L10n.text("JUMP"), "shimmier": L10n.text("SHIM"), "slider": L10n.text("SLIDE"), "climber": L10n.text("CLIMB"),
        "swimmer": L10n.text("SWIM"), "floater": L10n.text("FLOAT"), "glider": L10n.text("GLIDE"), "disarmer": L10n.text("DISARM"), "bomber": L10n.text("BOMB"),
        "stoner": L10n.text("STONE"), "blocker": L10n.text("BLOCK"), "platformer": L10n.text("PLAT"), "builder": L10n.text("BUILD"), "stacker": L10n.text("STACK"),
        "laserer": L10n.text("LASER"), "basher": L10n.text("BASH"), "fencer": L10n.text("FENCE"), "miner": L10n.text("MINE"), "digger": L10n.text("DIG"), "cloner": L10n.text("CLONE"),
    ] }

    public func draw(in context: CGContext, bounds: CGRect, includeSkills: Bool = true, includeTicks: Bool = true) {
        context.setShouldAntialias(false)
        context.interpolationQuality = .none
        let statusFrame = Self.cgRect(layout.interface.statusFrame)
        if layout.interface.statusFrame.minY == layout.interface.safeFrame.minY {
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: statusFrame.maxY))
        }
        if let panel = layout.panel {
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: panel.frame.minY, width: bounds.width, height: bounds.height - panel.frame.minY))
            drawPanel(panel, context: context)
        } else {
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(statusFrame)
            if layout.portrait != nil {
                context.setFillColor(CGColor(gray: 0.06, alpha: 1))
                context.fill(statusFrame)
                context.setFillColor(CGColor(gray: 0.25, alpha: 1))
                context.fill(CGRect(x: statusFrame.minX, y: statusFrame.maxY - 1, width: statusFrame.width, height: 1))
                context.setFillColor(CGColor(gray: 0, alpha: 1))
                context.fill(Self.cgRect(layout.interface.controlsFrame))
                if let value = layout.portrait?.rateValue {
                    let rate = items.filter { if case .releaseRate = $0.action { return true }; return false }
                        .reduce(value) { $0.union($1.frame) }
                    drawStoneSocket(rate, selected: false, pixel: 1, context: context)
                }
                for item in items {
                    if case .skill = item.action { continue }
                    if !includeTicks && (item.action == .step || item.action == .stepBackward) { continue }
                    drawCell(item, context: context)
                }
                if includeSkills { drawSkills(in: context) }
                if let value = layout.portrait?.rateValue, let rate = snapshot.releaseRate {
                    drawGameLabel("\(rate)", in: value, context: context)
                }
            } else {
                for item in items { drawCell(item, context: context) }
            }
        }
        let frames = Self.statusFrames(layout: layout, hasPlayer: playerName != nil)
        if let playerName, let player = frames.player {
            let identity = Self.playerFrames(in: player, name: playerName, portrait: playerPortrait, typography: typography)
            if let playerPortrait, let icon = identity.portrait {
                GameStoneArt.drawImage(playerPortrait, in: icon, context: context)
            }
            GamePixelTypography.draw(playerName, in: identity.name, context: context,
                typography: typography, palette: .green, maximumScale: 1, alignment: .left)
        }
        drawStatus(in: frames.counters, context: context)
    }

    public func drawSkills(in context: CGContext, clipped: Bool = true) {
        guard let portrait = layout.portrait else { return }
        context.saveGState()
        if clipped { context.clip(to: portrait.skills) }
        for item in items { if case .skill = item.action { drawCell(item, context: context) } }
        context.restoreGState()
    }

    public func drawTicks(in context: CGContext) {
        for item in items where item.action == .step || item.action == .stepBackward { drawCell(item, context: context) }
    }

    // MARK: - Classic panel

    private func drawPanel(_ panel: MobilePanelMetrics, context: CGContext) {
        if panel.style == .lemmings3 {
            drawLemmings3Panel(panel, context: context)
            return
        }
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
            case let .skill(index):
                if let icon = skillIcons[safe: index] ?? nil { drawNativeSkill(item, icon: icon, context: context, pixel: panel.bevel) }
                else if readOnly { context.setFillColor(CGColor(gray: 0, alpha: 0.65)); context.fill(item.frame) }
            case .releaseRate:
                drawRateButton(item, frame: item.frame, pixel: panel.bevel, context: context)
            }
        }
        drawCounts(panel, context: context)
        drawSkillLabels(panel, context: context)
        if let item = items.first(where: { $0.action == .skill(selectedSkill) }) {
            SkillPointerBadge.innerGlow(in: item.frame.insetBy(dx: 3, dy: 3), context: context)
            outline(item.frame, context: context)
        }
    }

    private func drawLemmings3Panel(_ panel: MobilePanelMetrics, context: CGContext) {
        if let panelImage {
            GameStoneArt.drawImage(panelImage, in: panel.frame, context: context)
        }
        for item in items {
            switch item.action {
            case let .skill(index) where index == selectedSkill:
                SkillPointerBadge.innerGlow(in: item.frame.insetBy(dx: 3, dy: 3), context: context)
                outline(item.frame, context: context)
            case .pause where paused:
                outline(item.frame, context: context)
            case .endRun where endRunArmed || snapshot.isEndingRun == true:
                outline(item.frame, context: context)
            case .speed where speed > 1:
                outline(item.frame, context: context)
            case .rewind, .stepBackward, .step, .menu:
                if item.action == .step || item.action == .stepBackward || item.action == .rewind {
                    drawIconButton(item, context: context)
                } else {
                    drawTextButton(item, context: context)
                }
            default:
                break
            }
        }
        if let remaining = snapshot.remainingSeconds {
            let minutes = remaining / 60
            let seconds = remaining % 60
            let time = String(format: "%d:%02d", minutes, seconds)
            let box = CGRect(x: panel.frame.minX + 176 * panel.scale,
                             y: panel.frame.minY + 21 * panel.scale,
                             width: 37 * panel.scale, height: 12 * panel.scale)
            drawGameLabel(time, in: box, context: context)
        }
    }

    private func drawNativeSkill(_ item: Item, icon: CGImage, context: CGContext, pixel: CGFloat) {
        guard case let .skill(index) = item.action else { return }
        drawStoneSocket(item.frame, selected: selectedSkill == index, pixel: pixel, context: context)
        let well = GameStoneArt.well(item.frame, pixel: pixel)
        let fit = min(well.width / CGFloat(icon.width), well.height / CGFloat(icon.height))
        let width = CGFloat(icon.width) * fit, height = CGFloat(icon.height) * fit
        context.saveGState()
        context.setAlpha(readOnly || snapshot.skills[safe: index]?.count == 0 ? 0.35 : 1)
        GameStoneArt.drawImage(icon, in: CGRect(x: floor(well.midX - width / 2), y: well.maxY - height, width: width, height: height), context: context)
        context.restoreGState()
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
        let names = snapshot.skills.map { Self.shortNames[$0.name.lowercased()] ?? SkillVocabulary.title($0.name).uppercased() }
        let compactWidth = names.map { GamePixelTypography.width(of: $0) }.max() ?? 1
        let compactBounds = GamePixelTypography.verticalBounds(of: names.joined())
        for item in items {
            guard case let .skill(index) = item.action, let name = names[safe: index] else { continue }
            let box = CGRect(x: item.frame.minX, y: panel.frame.minY + 10 * panel.scale,
                             width: item.frame.width, height: 5 * panel.scale)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(box)
            let fits = typography.map { typography in
                typography.font(.small).map { font in
                    (names.map { font.width(of: GameMenuTypography.menuText($0)) }.max() ?? 0) <= Int(box.width)
                        && font.height(of: names.joined()) <= Int(box.height)
                } ?? false
            } ?? false
            if fits {
                GamePixelTypography.draw(name, in: box, context: context, typography: typography, maximumScale: 1)
            } else {
                let scale = max(1, min(3, floor(min(box.height / CGFloat(compactBounds.bottom - compactBounds.top), box.width / CGFloat(compactWidth)))))
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
        } else if layout.portrait != nil {
            drawGameLabel(Self.speedLabel(speed), in: CGRect(x: frame.minX + 4, y: frame.minY + 4,
                width: frame.width - 8, height: 22), context: context)
            if frame.height >= 70, let glyph = Self.glyphImage(.fastForward, fitting: CGSize(width: 28, height: 24)) {
                GameStoneArt.drawImage(glyph.image, in: CGRect(x: floor(frame.midX - glyph.size.width / 2),
                    y: floor(frame.midY - glyph.size.height / 2), width: glyph.size.width, height: glyph.size.height), context: context)
            }
            GamePixelTypography.draw(L10n.text("HOLD"), in: CGRect(x: frame.minX + 4, y: frame.maxY - 16,
                width: frame.width - 8, height: 10), context: context, typography: typography,
                palette: active ? .green : .blue, maximumScale: 1, bitmapOnly: true)
            return
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
        case .releaseRate:
            let socket = layout.portrait != nil ? frame : CGRect(x: frame.minX, y: frame.minY + 18, width: frame.width, height: frame.height - 18)
            drawRateButton(item, frame: socket, pixel: 1, context: context)
            if layout.portrait == nil { drawCompactCount(item, in: frame, context: context) }
        case .skill:
            drawStoneSocket(frame, selected: false, pixel: 1, context: context)
            let scale = layout.compactScale
            let well = GameStoneArt.well(frame, pixel: 1)
            context.saveGState()
            context.clip(to: well)
            if readOnly { context.setAlpha(0.35) }
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(well)
            if case let .skill(index) = item.action, let icon = skillIcons[safe: index] ?? nil {
                let art = CGRect(x: well.minX, y: frame.minY + 18, width: well.width, height: max(0, frame.height - 34))
                let available = min(art.width / CGFloat(icon.width), art.height / CGFloat(icon.height))
                let fit = layout.isDiorama && available > 0
                    ? (available >= 1 ? floor(available) : 1 / ceil(1 / available)) : available
                GameStoneArt.drawImage(icon, in: CGRect(x: floor(art.midX - CGFloat(icon.width) * fit / 2), y: art.maxY - CGFloat(icon.height) * fit, width: CGFloat(icon.width) * fit, height: CGFloat(icon.height) * fit), context: context)
            } else if layout.panel?.style != .lemmings3, let cell = item.sourceCell,
               let image = panelImage?.cropping(to: CGRect(x: cell * 16, y: 16, width: 16, height: 24)) {
                let art = CGRect(x: frame.midX - 8 * scale, y: frame.minY + (scale == 1 ? 16 : 18), width: 16 * scale, height: 24 * scale)
                GameStoneArt.drawImage(image, in: art, context: context)
            }
            context.restoreGState()
            drawCompactCount(item, in: frame, context: context)
            if selected {
                SkillPointerBadge.innerGlow(in: well, context: context)
                outline(frame, context: context)
            }
        case .pause, .endRun:
            drawGlyphButton(item, context: context, pixel: 1)
        case .speed:
            drawSpeed(frame, bevel: 1, context: context)
        case .menu:
            if layout.portrait != nil { drawIconButton(item, context: context) }
            else { drawTextButton(item, context: context) }
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
            let name = Self.shortNames[skill.name.lowercased()] ?? SkillVocabulary.title(skill.name).uppercased()
            let label = CGRect(x: frame.minX + 3, y: frame.maxY - 14, width: frame.width - 6, height: 10)
            let bounds = GamePixelTypography.verticalBounds(of: name)
            let scale = max(1, min(2, floor(min(label.height / CGFloat(bounds.bottom - bounds.top), label.width / CGFloat(GamePixelTypography.width(of: name))))))
            GamePixelTypography.draw(name, in: label, context: context, typography: typography, maximumScale: scale, bitmapOnly: true)
        }
    }

    private func drawIconButton(_ item: Item, context: CGContext) {
        let enabled = item.action == .step ? paused : (item.action == .stepBackward || item.action == .rewind ? snapshot.tick > 0 : true)
        GameStoneArt.draw(in: context, frame: item.frame, selected: false, pixel: 1)
        let glyph: PanelGlyphArt
        switch item.action {
        case .menu: glyph = .mobileMenu
        case .rewind: glyph = .rewind
        case .stepBackward: glyph = .stepBackward
        default: glyph = .stepForward
        }
        let well = GameStoneArt.well(item.frame, pixel: 1)
        guard let image = Self.glyphImage(glyph, fitting: CGSize(width: well.width, height: well.height * 0.85)) else { return }
        context.saveGState()
        context.setAlpha(enabled ? 1 : 0.35)
        GameStoneArt.drawImage(image.image, in: CGRect(
            x: floor(well.midX - image.size.width / 2), y: floor(well.midY - image.size.height / 2),
            width: image.size.width, height: image.size.height), context: context)
        context.restoreGState()
    }

    // MARK: - Shared pieces

    private func drawRateButton(_ item: Item, frame: CGRect, pixel: CGFloat, context: CGContext) {
        guard case let .releaseRate(delta) = item.action else { return }
        if layout.portrait == nil { drawStoneSocket(frame, selected: false, pixel: pixel, context: context) }
        context.saveGState()
        context.setAlpha(readOnly ? 0.35 : 1)
        drawGameLabel(delta < 0 ? "-" : "+", in: GameStoneArt.well(frame, pixel: pixel), context: context)
        context.restoreGState()
    }

    private func drawStoneSocket(_ frame: CGRect, selected: Bool, pixel: CGFloat, context: CGContext) {
        GameStoneArt.drawSocket(in: context, frame: frame, selected: selected, pixel: pixel)
        GameStoneArt.drawDetailedRock(in: context, frame: frame, pixel: pixel)
        GameStoneArt.drawAccent(in: context, frame: frame, selected: selected, pixel: pixel)
    }

    private func drawGlyphButton(_ item: Item, context: CGContext, pixel: CGFloat) {
        context.saveGState()
        defer { context.restoreGState() }
        if readOnly && item.action == .endRun { context.setAlpha(0.35) }
        let selected = item.action == .pause ? paused : (snapshot.isEndingRun == true)
        let glyph: PanelGlyphArt
        if item.action == .pause { glyph = paused ? .play : .pause }
        else { glyph = snapshot.isEndingRun == true ? .undo : .nuke }
        drawStoneSocket(item.frame, selected: selected, pixel: pixel, context: context)
        let well = GameStoneArt.well(item.frame, pixel: pixel)
        if glyph.isOriginalTile && layout.portrait == nil {
            if let image = Self.glyphImage(glyph, fitting: item.frame.size) {
                GameStoneArt.drawTile(in: context, image: image.image, logicalSize: image.size,
                                      frame: item.frame, pixel: pixel)
            }
        } else if let image = Self.glyphImage(glyph,
            fitting: item.action == .pause ? well.insetBy(dx: 4 * pixel, dy: 4 * pixel).size
                : glyph.isOriginalTile ? item.frame.insetBy(dx: 2, dy: 2).size : well.size,
            transparentRock: glyph.isOriginalTile) {
            GameStoneArt.drawImage(image.image, in: CGRect(
                x: floor(well.midX - image.size.width / 2), y: floor(well.midY - image.size.height / 2),
                width: image.size.width, height: image.size.height), context: context)
        }
        if item.action == .endRun, endRunArmed, !selected { outline(item.frame, context: context) }
    }

    private func drawTextButton(_ item: Item, context: CGContext) {
        let enabled = item.action != .step || paused
        GameStoneArt.draw(in: context, frame: item.frame, selected: false, pixel: 1)
        let title = item.action == .step ? L10n.text("STEP") : L10n.text("MENU")
        GamePixelTypography.draw(title, in: item.frame.insetBy(dx: 8, dy: 2), context: context, typography: typography, palette: .blue, alpha: enabled ? 1 : 0.45)
    }

    /// Panel text in the game font, falling back to the pixel font when it will not fit.
    private func drawGameLabel(_ text: String, in box: CGRect, context: CGContext) {
        let plain = text.replacingOccurrences(of: "∞", with: "*")
        if let font = typography?.font(.small),
           font.height(of: GameMenuTypography.menuText(plain)) <= Int(box.height), font.width(of: GameMenuTypography.menuText(plain)) <= Int(box.width) {
            GamePixelTypography.draw(plain, in: box, context: context, typography: typography, maximumScale: 1)
        } else {
            let bounds = GamePixelTypography.verticalBounds(of: plain)
            let scale = max(1, min(3, floor(min(box.height / CGFloat(bounds.bottom - bounds.top), box.width / CGFloat(GamePixelTypography.width(of: plain))))))
            GamePixelTypography.draw(plain, in: box, context: context, typography: typography, maximumScale: scale, bitmapOnly: true)
        }
    }

    /// Anchor the profile portrait and name at the leading corner.
    public static func playerFrames(in frame: CGRect, name: String, portrait: CGImage?,
                                    typography: GameMenuTypography?) -> (portrait: CGRect?, name: CGRect) {
        let row = frame.insetBy(dx: 6, dy: 0)
        let iconSize: CGSize
        if let portrait {
            let fit = min(row.height / CGFloat(portrait.height), 20 / CGFloat(portrait.width))
            let scale = fit >= 1 ? floor(fit) : 1 / ceil(1 / fit)
            iconSize = CGSize(width: CGFloat(portrait.width) * scale, height: CGFloat(portrait.height) * scale)
        } else { iconSize = .zero }
        let gap: CGFloat = portrait == nil ? 0 : 6
        let plain = GameMenuTypography.menuText(name)
        let naturalWidth = typography?.width(of: plain, face: .small, scale: 1) ?? CGFloat(GamePixelTypography.width(of: plain))
        let width = min(naturalWidth, max(0, row.width - iconSize.width - gap))
        let x = floor(row.minX)
        let icon = portrait.map { _ in CGRect(x: x, y: floor(row.midY - iconSize.height / 2),
                                              width: iconSize.width, height: iconSize.height) }
        return (icon, CGRect(x: x + iconSize.width + gap, y: row.minY, width: width, height: row.height))
    }

    /// Player identity and counters share the opaque HUD strip, away from gameplay input.
    public static func statusFrames(layout: MobileHUDLayout, hasPlayer: Bool) -> (player: CGRect?, counters: CGRect) {
        var frame = cgRect(layout.interface.statusFrame)
        if layout.panel != nil && !layout.television {
            // The final navigation targets sit to the right of the status strip.
            // Use layout geometry because the actual skill count varies by engine.
            let navigationCount = (layout.supportsRewind ? 3 : 1) + (layout.showsMenuButton ? 1 : 0)
            if let navigation = layout.interface.controlFrames.suffix(navigationCount).first,
               navigation.minY < frame.maxY, navigation.maxY > frame.minY {
                frame.size.width = max(0, navigation.minX - frame.minX - 4)
            }
        }
        let banks = layout.statusBanks.map(cgRect)
        if banks.count > 1, let leading = banks.first, let trailing = banks.last {
            let player = hasPlayer ? CGRect(x: leading.minX, y: leading.minY,
                width: min(200, leading.width), height: leading.height) : nil
            return (player, trailing)
        }
        guard hasPlayer else { return (nil, frame) }
        let playerWidth = min(200, max(90, floor(frame.width * 0.28)))
        return (CGRect(x: frame.minX, y: frame.minY, width: playerWidth, height: frame.height),
                CGRect(x: frame.minX + playerWidth + 8, y: frame.minY,
                       width: max(0, frame.width - playerWidth - 8), height: frame.height))
    }

    public struct StatusField {
        public let id: String
        public let text: String
        public let frame: CGRect
        public let palette: GamePixelTypography.Palette
        public let bitmapOnly: Bool
        public let scale: CGFloat
        public let face: GameMenuTypography.Face
    }

    /// Prioritise rescue progress and the clock. Extra statistics use available horizontal space.
    /// Each statistic owns a fixed slot sized for its widest possible value, and its text stays
    /// centred in that slot. Changing digits, states or speeds never moves another statistic.
    public static func statusFields(in frame: CGRect, snapshot: MobileGameSnapshot, details: StatusDetails?,
                                    engineIdentifier: String, paused: Bool, speed: Double,
                                    typography: GameMenuTypography?) -> [StatusField] {
        guard frame.width >= 24, frame.height >= 8 else { return [] }
        let compact = frame.width < 440
        let gap: CGFloat = compact ? 8 : 20
        let row = frame.insetBy(dx: 6, dy: 2)
        let percent = snapshot.saved * 100 / max(1, snapshot.total)
        let minutes = max(0, snapshot.remainingSeconds ?? 0) / 60
        let time = snapshot.remainingSeconds.map { String(format: "%d:%02d", max(0, $0) / 60, max(0, $0) % 60) } ?? "--:--"
        // Narrow bars abbreviate labels, but retain the regular game lettering.
        let bitmap = typography == nil || row.height < 12
        func width(_ text: String, scale: CGFloat = 1, face: GameMenuTypography.Face = .small) -> CGFloat {
            if bitmap { return CGFloat(GamePixelTypography.width(of: text)) * scale }
            return typography?.width(of: GameMenuTypography.menuText(text), face: face, scale: Int(scale)) ?? 0
        }
        // Slot templates use the widest digit at the largest digit count a value can reach.
        let digit = (0...9).map(String.init).max { width($0) < width($1) } ?? "8"
        func wide(_ bound: Int) -> String { String(repeating: digit, count: String(max(0, bound)).count) }
        let count = wide(max(snapshot.total, snapshot.saved, snapshot.released))
        let clockTemplate = "\(wide(max(10, minutes))):\(digit)\(digit)"
        let clock = compact ? time : L10n.text("TIME \(time)")
        let clockWidth = max(width(clock), width(compact ? clockTemplate : L10n.text("TIME \(clockTemplate)")))
        let scoreScale: CGFloat = bitmap ? 2 : 1
        let scoreFace: GameMenuTypography.Face = !bitmap && frame.width >= 1200 ? .large : .small
        func scoreText(_ saved: String, _ percent: String, full: Bool) -> String {
            guard full else { return "\(saved)/\(snapshot.required)" }
            return compact ? "\(saved)/\(snapshot.required) \(percent)%"
                : L10n.text("HOME \(saved)/\(snapshot.required)") + " (\(percent)%)"
        }
        let full = width(scoreText(count, wide(100), full: true), scale: scoreScale, face: scoreFace) + clockWidth + gap <= row.width
        let score = scoreText("\(snapshot.saved)", "\(percent)", full: full)
        let scoreSlot = min(row.width, width(scoreText(count, wide(100), full: full), scale: scoreScale, face: scoreFace))
        let scoreFrame = CGRect(x: row.maxX - scoreSlot, y: row.minY, width: scoreSlot, height: row.height)
        func centred(_ text: String, in slot: CGRect, scale: CGFloat = 1, face: GameMenuTypography.Face = .small) -> CGRect {
            let extent = min(slot.width, width(text, scale: scale, face: face))
            return CGRect(x: floor(slot.midX - extent / 2), y: slot.minY, width: extent, height: slot.height)
        }
        var fields = [StatusField(id: "score", text: score, frame: centred(score, in: scoreFrame, scale: scoreScale, face: scoreFace),
                                  palette: .green, bitmapOnly: bitmap, scale: scoreScale, face: scoreFace)]
        let available = max(0, scoreFrame.minX - gap - row.minX)
        guard available >= clockWidth else { return fields }
        // The state slot is reserved even while empty so a pause never shifts its neighbours.
        let states = [L10n.text("COMPLETE"), L10n.text("FAILED"), L10n.text("NUKING"), L10n.text("PAUSED")]
        let state = snapshot.isComplete ? (snapshot.didWin ? states[0] : states[1])
            : snapshot.isEndingRun ? states[2] : paused ? states[3] : ""
        let speeds = ["\(digit)\(digit)X", "\(digit).\(digit)X"].map { L10n.text("SPEED \($0)") }
        var candidates: [(id: String, text: String, slot: CGFloat)] = [("time", clock, clockWidth),
            ("state", state, states.map { width($0) }.max() ?? 0)]
        if let details {
            candidates.append(("allowance", details.deathCounter,
                max(width("SAFE"), width("\(count)/\(count) 💀"), width(details.deathCounter))))
        }
        candidates.append(("out", L10n.text("OUT \(snapshot.released)/\(snapshot.total)"),
                           width(L10n.text("OUT \(count)/\(snapshot.total)"))))
        if let details { candidates.append(("lost", L10n.text("LOST \(details.lost)"), width(L10n.text("LOST \(count)")))) }
        if engineIdentifier == "lemmings3" {
            candidates.append(("reserve", L10n.text("LEFT \(max(0, snapshot.total - snapshot.released))"),
                               width(L10n.text("LEFT \(count)"))))
        }
        if let rate = snapshot.releaseRate {
            candidates.append(("rate", L10n.text("RATE \(rate)"), width(L10n.text("RATE \(wide(max(99, rate)))"))))
        }
        let speedText = L10n.text("SPEED \(speedLabel(speed))")
        candidates.append(("speed", speedText, max(width(speedText), speeds.map { width($0) }.max() ?? 0)))
        var selected: [(id: String, text: String, slot: CGFloat)] = []
        var used: CGFloat = 0
        for candidate in candidates {
            let needed = candidate.slot + (selected.isEmpty ? 0 : gap)
            if used + needed <= available { selected.append(candidate); used += needed }
        }
        // Stable groups read left to right, with the clock nearest the rescue score.
        selected = selected.filter { $0.id != "time" } + selected.filter { $0.id == "time" }
        let spacing = selected.count > 1 ? (available - selected.reduce(0) { $0 + $1.slot }) / CGFloat(selected.count - 1) : 0
        var x = selected.count == 1 ? row.minX + available - clockWidth : row.minX
        for candidate in selected {
            let slot = CGRect(x: floor(x), y: row.minY, width: candidate.slot, height: row.height)
            if !candidate.text.isEmpty {
                fields.append(StatusField(id: candidate.id, text: candidate.text, frame: centred(candidate.text, in: slot),
                    palette: .blue, bitmapOnly: bitmap, scale: 1, face: .small))
            }
            x += candidate.slot + spacing
        }
        return fields
    }

    private func drawStatus(in frame: CGRect, context: CGContext) {
        let fields = Self.statusFields(in: frame, snapshot: snapshot, details: statusDetails,
            engineIdentifier: statusDetails?.engineIdentifier ?? (layout.panel?.style == .lemmings3 ? "lemmings3" : "classic"),
            paused: paused, speed: speed, typography: typography)
        for field in fields {
            if field.bitmapOnly {
                GamePixelTypography.draw(field.text, in: field.frame, context: context, typography: nil,
                    palette: field.palette, maximumScale: field.scale, bitmapOnly: true)
            } else { drawStatusLabel(field.text, in: field.frame, palette: field.palette, face: field.face, context: context) }
            if field.id == "score", snapshot.didWin {
                context.setFillColor(CGColor(srgbRed: 0.45, green: 1, blue: 0.10, alpha: 1))
                context.fill(CGRect(x: field.frame.minX, y: field.frame.maxY - 2, width: field.frame.width, height: 2))
            }
        }
    }

    private func drawStatusLabel(_ text: String, in row: CGRect, palette: GamePixelTypography.Palette, face: GameMenuTypography.Face, context: CGContext) {
        guard text.contains("💀"), let typography, let font = typography.font(.small), !font.covers("💀") else {
            GamePixelTypography.draw(text, in: row, context: context, typography: typography,
                palette: palette, maximumScale: 1, alignment: .left, face: face)
            return
        }
        var x = row.minX
        let parts = text.components(separatedBy: "💀")
        for (index, part) in parts.enumerated() {
            let partWidth = typography.width(of: GameMenuTypography.menuText(part), face: .small, scale: 1)
            GamePixelTypography.draw(part, in: CGRect(x: x, y: row.minY, width: partWidth, height: row.height),
                context: context, typography: typography, palette: palette, maximumScale: 1, alignment: .left)
            x += partWidth
            if index < parts.count - 1 {
                GamePixelTypography.draw("💀", in: CGRect(x: x, y: row.minY, width: CGFloat(font.cellWidth), height: row.height),
                    context: context, typography: nil, palette: palette, maximumScale: 2, bitmapOnly: true)
                x += CGFloat(font.cellWidth)
            }
        }
    }

    public static func televisionStatusLines(snapshot: MobileGameSnapshot, details: StatusDetails?,
                                            engineIdentifier: String, paused: Bool, speed: Double) -> [String] {
        let percent = snapshot.saved * 100 / max(1, snapshot.total)
        let time = snapshot.remainingSeconds.map { String(format: "%d:%02d", max(0, $0) / 60, max(0, $0) % 60) } ?? "--:--"
        var counts = [L10n.text("OUT \(snapshot.released)/\(snapshot.total)"),
                      L10n.text("HOME \(snapshot.saved)/\(snapshot.required)") + " (\(percent)%)"]
        if engineIdentifier == "lemmings3" { counts.append(L10n.text("LEFT \(max(0, snapshot.total - snapshot.released))")) }
        counts.append(L10n.text("TIME \(time)"))
        var state: [String] = []
        if let details { state += [L10n.text("LOST \(details.lost)"), details.deathCounter] }
        if let rate = snapshot.releaseRate { state.append(L10n.text("RATE \(rate)")) }
        state.append(L10n.text("SPEED \(speedLabel(speed))"))
        if snapshot.isComplete { state.append(snapshot.didWin ? L10n.text("COMPLETE") : L10n.text("FAILED")) }
        else if paused { state.append(L10n.text("PAUSED")) }
        if snapshot.isEndingRun { state.append(L10n.text("NUKING")) }
        return [counts.joined(separator: "   "), state.joined(separator: "   ")]
    }

    private static func speedLabel(_ speed: Double) -> String {
        speed.rounded() == speed ? "\(Int(speed))X" : String(format: "%.1fX", speed)
    }

    private static func cgRect(_ rect: MobileRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    private static var glyphCache: [String: (image: CGImage, size: CGSize)] = [:]

    private static func glyphImage(_ glyph: PanelGlyphArt, fitting box: CGSize, transparentRock: Bool = false) -> (image: CGImage, size: CGSize)? {
        let steps = glyph.scale(fitting: box)
        guard steps >= 1 else { return nil }
        let key = "\(glyph.rawValue)-\(steps)-\(transparentRock)"
        if let hit = glyphCache[key] { return hit }
        guard let image = glyph.cgImage(scale: steps, transparentRock: transparentRock) else { return nil }
        let size = CGSize(width: CGFloat(image.width) / (glyph.isOriginalTile ? 2 : 1), height: CGFloat(image.height))
        glyphCache[key] = (image, size)
        return (image, size)
    }

}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
