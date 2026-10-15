import CoreGraphics
import Foundation
import LemmingsMobileCore
import NxlvKit

/// A level portrait, rescue ledger and music sleeve, drawn with the shipped lettering.
public enum MobilePauseArt {
    /// Landscape keeps the action shelf within the viewport at large lettering settings.
    public static func interfaceScale(_ size: ClassicInterfaceSize, width: CGFloat, height: CGFloat,
                                      television: Bool = false) -> CGFloat {
        let preferred = MobileSettingsArt.interfaceScale(size, width: width, television: television)
        if television { return min(preferred, max(1, floor(min(width / 560, height / 240)))) }
        guard width > height else { return preferred }
        return min(preferred, max(1, min(width / 560, height / 240)))
    }

    public static func page(_ summary: MobilePauseSummary, actions: [GameFrontEnd.Action]) -> GameFrontEnd.Page {
        var page = GameFrontEnd.Page(title: summary.isReplay ? L10n.text("Replay") : L10n.text("Paused"), subtitle: summary.level.caption,
            details: [summary.level.title, summary.status, summary.rescueText]
                + summary.fields.map(\.text)
                + [summary.playDetails] + summary.supplies.map { $0.label + " left: " + $0.value }
                + [L10n.text("Soundtrack: \(summary.soundtrack)"), summary.track, summary.audio],
            footer: actions, preview: true, footerColumns: 2)
        page.pause = summary
        return page
    }

    public static func layout(_ page: GameFrontEnd.Page, width: CGFloat, minimumHeight: CGFloat,
                              television: Bool = false) -> GameFrontEnd.Layout {
        let width = max(280, width)
        let boardWidth = min(960, width - 28)
        let x = (width - boardWidth) / 2
        let inner = boardWidth - 32
        let left = x + 16
        let wide = inner >= 560
        let compact = wide && (television || minimumHeight < 520)
        let sideBySide = wide && (television || width > minimumHeight)
        let heading = CGRect(x: left, y: 26, width: inner, height: compact ? 32 : 44)
        let subtitle = CGRect(x: left, y: heading.maxY + 2, width: inner, height: max(compact ? 20 : 24, textHeight(page.subtitle, width: inner, lineHeight: 22)))
        var y = subtitle.maxY + 10
        var details: [CGRect] = []
        let titleHeight = GameTextLayout.height(page.details[0], width: inner, face: .large)
        details.append(CGRect(x: left, y: y, width: inner, height: titleHeight))
        y += titleHeight + 12
        let previewWidth = sideBySide ? floor(inner * 0.44) : inner
        let previewHeight = min(compact ? 92 : wide ? (sideBySide ? 156 : 320) : 132, floor(previewWidth / 2))
        let preview = CGRect(x: left, y: y, width: previewWidth, height: previewHeight)
        let rescueX = sideBySide ? preview.maxX + 20 : left
        let rescueWidth = sideBySide ? inner - previewWidth - 20 : inner
        let statusHeight = textHeight(page.details[1], width: rescueWidth, lineHeight: 22)
        let progressHeight = textHeight(page.details[2], width: rescueWidth, lineHeight: 22) + 18
        let rescueY = sideBySide ? preview.midY - (statusHeight + progressHeight + 4) / 2 : preview.maxY + 12
        details.append(CGRect(x: rescueX, y: rescueY, width: rescueWidth, height: statusHeight))
        details.append(CGRect(x: rescueX, y: rescueY + statusHeight + 4, width: rescueWidth, height: progressHeight))
        y = max(preview.maxY, details.last!.maxY) + 16
        let columns = wide ? 4 : inner < 240 ? 1 : 2
        let gap: CGFloat = 12
        let cellWidth = floor((inner - CGFloat(columns - 1) * gap) / CGFloat(columns))
        let fields = page.pause?.fields ?? []
        let labelHeight = max(18, fields.map { textHeight($0.label, width: cellWidth - 12, lineHeight: 18) }.max() ?? 18)
        let valueHeight = max(22, fields.map { textHeight($0.value, width: cellWidth - 12, lineHeight: 22) }.max() ?? 22)
        let fieldHeight = max(48, labelHeight + valueHeight + 8)
        for index in 0..<8 {
            details.append(CGRect(x: left + CGFloat(index % columns) * (cellWidth + gap),
                y: y + CGFloat(index / columns) * (fieldHeight + 8), width: cellWidth, height: fieldHeight))
        }
        y += CGFloat(8 / columns) * (fieldHeight + 8)
        let playHeight = textHeight(page.details[11], width: inner, lineHeight: 20)
        details.append(CGRect(x: left, y: y, width: inner, height: playHeight))
        y += playHeight + 16
        let supplies = page.pause?.supplies.count ?? 0
        let longestSkill = page.pause?.supplies.map { GameTextLayout.width(of: $0.label) }.max() ?? 0
        let stockValueWidth = max(28, page.pause?.supplies.map { GameTextLayout.width(of: $0.value) }.max() ?? 0)
        let stockColumns = min(wide ? 4 : 2, max(1, Int((inner + 12) / (longestSkill + stockValueWidth + 16))))
        let stockWidth = floor((inner - CGFloat(stockColumns - 1) * 12) / CGFloat(stockColumns))
        let stockHeight = max(24, page.pause?.supplies.map { textHeight($0.label, width: stockWidth - stockValueWidth - 4, lineHeight: 20) }.max() ?? 24)
        for index in 0..<supplies {
            details.append(CGRect(x: left + CGFloat(index % stockColumns) * (stockWidth + 12),
                y: y + CGFloat(index / stockColumns) * (stockHeight + 4), width: stockWidth, height: stockHeight))
        }
        if supplies > 0 { y += CGFloat(Int(ceil(Double(supplies) / Double(stockColumns)))) * (stockHeight + 4) + 16 }
        for index in (12 + supplies)..<(15 + supplies) {
            let height = textHeight(page.details[index], width: inner - 24, lineHeight: 20)
            details.append(CGRect(x: left + 12, y: y, width: inner - 24, height: height))
            y += height + 4
        }
        y += 20
        let desiredColumns = inner < 252 ? 1 : compact && inner >= 640 ? 4 : 2
        let widestAction = page.footer.map { GameTextLayout.width(of: $0.title) + ($0.primary ? 48 : 24) }.max() ?? 44
        let grid = GameFooterGrid(actions: page.orderedFooter,
            columns: min(desiredColumns, max(1, Int((inner + 12) / (widestAction + 12)))),
            spanSingleAction: true, alignTrailing: false)
        let footerColumns = grid.columns
        let rows = grid.rows
        let footerWidth = floor((inner - CGFloat(footerColumns - 1) * 12) / CGFloat(footerColumns))
        let footerHeight = max(48, page.footer.map { GameTextLayout.height($0.title, width: footerWidth - ($0.primary ? 48 : 24)) + 8 }.max() ?? 48)
        let pitch = footerHeight + 8
        let height = max(minimumHeight, y + CGFloat(rows) * pitch + 26)
        y = max(y, height - CGFloat(rows) * pitch - 26)
        var targets: [GameFrontEnd.Target] = []
        for slot in grid.slots {
            targets.append(.init(action: slot.action, frame: CGRect(x: left + CGFloat(slot.column) * (footerWidth + 12),
                y: y + CGFloat(slot.row) * pitch, width: footerWidth * CGFloat(slot.span) + CGFloat(slot.span - 1) * 12, height: footerHeight)))
        }
        return .init(size: CGSize(width: width, height: height),
            board: CGRect(x: x, y: 16, width: boardWidth, height: height - 32),
            heading: heading, subtitle: subtitle, preview: preview, details: details, targets: targets)
    }

    /// The body scrolls behind an opaque action shelf. Resume stays in the same place.
    public static func pinningFooter(_ layout: GameFrontEnd.Layout, viewport: CGRect) -> GameFrontEnd.Layout {
        guard let first = layout.targets.first, let last = layout.targets.last else { return layout }
        let height = last.frame.maxY - first.frame.minY
        let top = max(viewport.minY + 8, viewport.maxY - height - 24)
        let delta = top - first.frame.minY
        let targets = layout.targets.map { GameFrontEnd.Target(action: $0.action, frame: $0.frame.offsetBy(dx: 0, dy: delta)) }
        return .init(size: layout.size, board: layout.board, heading: layout.heading,
            subtitle: layout.subtitle, preview: layout.preview, details: layout.details, targets: targets)
    }

    public static func draw(_ page: GameFrontEnd.Page, layout: GameFrontEnd.Layout, typography: GameMenuTypography,
                            preview: CGImage?, previewSource: CGRect?, in context: CGContext) {
        guard let summary = page.pause, layout.details.count == 15 + summary.supplies.count else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        let boxes = layout.details
        text(page.subtitle, box: layout.subtitle, typography: typography, context: context)
        GameTextLayout.draw(summary.level.title, in: boxes[0], typography: typography, face: .large, palette: .green, context: context)
        GameStoneArt.draw(in: context, frame: layout.preview, selected: false, pixel: 2)
        if let preview {
            let image = previewSource.flatMap { preview.cropping(to: $0.integral) } ?? preview
            let well = GameStoneArt.well(layout.preview, pixel: 2).insetBy(dx: 2, dy: 2)
            let fit = min(well.width / CGFloat(image.width), well.height / CGFloat(image.height))
            let frame = CGRect(x: floor(well.midX - CGFloat(image.width) * fit / 2),
                y: floor(well.midY - CGFloat(image.height) * fit / 2),
                width: floor(CGFloat(image.width) * fit), height: floor(CGFloat(image.height) * fit))
            context.interpolationQuality = .none
            GameStoneArt.drawImage(image, in: frame, context: context)
        }
        text(summary.status, box: boxes[1], palette: .blue, typography: typography, context: context)
        let progress = boxes[2]
        text(summary.rescueText, box: CGRect(x: progress.minX, y: progress.minY, width: progress.width, height: progress.height - 18),
             typography: typography, context: context)
        let rail = CGRect(x: progress.minX, y: progress.maxY - 12, width: progress.width, height: 10)
        GameStoneArt.draw(in: context, frame: rail, selected: false, pixel: 1)
        let well = rail.insetBy(dx: 4, dy: 3)
        let fraction = summary.required > 0 ? min(1, CGFloat(summary.saved) / CGFloat(summary.required)) : 1
        context.setFillColor(CGColor(srgbRed: 0.48, green: 0.80, blue: 0.24, alpha: 1))
        context.fill(CGRect(x: well.minX, y: well.minY, width: floor(well.width * fraction), height: well.height))
        let labelHeight = max(18, summary.fields.map { textHeight($0.label, width: boxes[3].width - 12, lineHeight: 18) }.max() ?? 18)
        for (index, field) in summary.fields.enumerated() {
            let box = boxes[index + 3]
            context.setFillColor(CGColor(srgbRed: 0.035, green: 0.065, blue: 0.045, alpha: 1))
            context.fill(box)
            text(field.label, box: CGRect(x: box.minX + 6, y: box.minY + 3, width: box.width - 12, height: labelHeight),
                 typography: typography, context: context)
            text(field.value, box: CGRect(x: box.minX + 6, y: box.minY + labelHeight + 5, width: box.width - 12, height: box.height - labelHeight - 8),
                 palette: .blue, typography: typography, context: context)
        }
        text(summary.playDetails, box: boxes[11], typography: typography, context: context)
        let stockValueWidth = max(28, summary.supplies.map { GameTextLayout.width(of: $0.value) }.max() ?? 0)
        for (index, stock) in summary.supplies.enumerated() {
            let box = boxes[12 + index]
            text(stock.label, box: CGRect(x: box.minX, y: box.minY, width: box.width - stockValueWidth - 4, height: box.height),
                 typography: typography, context: context)
            text(stock.value, box: CGRect(x: box.maxX - stockValueWidth, y: box.minY, width: stockValueWidth, height: box.height),
                 palette: .blue, typography: typography, context: context)
        }
        let musicStart = 12 + summary.supplies.count
        let music = boxes[musicStart].union(boxes[musicStart + 2]).insetBy(dx: -12, dy: -8)
        GameStoneArt.draw(in: context, frame: music, selected: false, pixel: 1)
        for index in musicStart..<(musicStart + 3) {
            text(page.details[index], box: boxes[index], palette: index == musicStart + 1 ? .green : .blue,
                 typography: typography, context: context)
        }
    }

    // The small shipped font has twelve-point cells. Keep whole words and a fixed face size.
    private static func lines(_ text: String, width: CGFloat) -> [String] {
        GameTextLayout.lines(text, width: width)
    }

    private static func textHeight(_ text: String, width: CGFloat, lineHeight: CGFloat) -> CGFloat {
        CGFloat(max(1, lines(text, width: width).count)) * max(lineHeight, GameTextLayout.glyphHeight(of: text))
    }
    private static func text(_ text: String, box: CGRect, palette: GamePixelTypography.Palette = .blue,
                             typography: GameMenuTypography, context: CGContext) {
        let lines = lines(text, width: box.width)
        let height = box.height / CGFloat(max(1, lines.count))
        for (index, line) in lines.enumerated() {
            GamePixelTypography.draw(line, in: CGRect(x: box.minX, y: box.minY + CGFloat(index) * height,
                width: box.width, height: height), context: context, typography: typography, palette: palette)
        }
    }
}
