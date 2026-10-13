import CoreGraphics
import Foundation
import NxlvKit

/// Shared bitmap pages. UIKit supplies input over these exact drawing rectangles.
public struct GameFrontEnd {
    public struct Action: Equatable, Sendable {
        public var id: String
        public var title: String
        public var enabled: Bool
        public var primary: Bool
        public var selected: Bool
        public var portrait: Int?
        public init(_ id: String, _ title: String, enabled: Bool = true,
                    primary: Bool = false, selected: Bool = false, portrait: Int? = nil) {
            self.id = id; self.title = title; self.enabled = enabled
            self.primary = primary; self.selected = selected
            self.portrait = portrait
        }
    }
    public struct Page: Equatable, Sendable {
        public var title: String
        public var subtitle: String
        public var home: Bool
        public var homeInitials: String
        public var rows: [Action]
        public var details: [String]
        public var footer: [Action]
        public var preview: Bool
        public var footerColumns: Int?
        public init(title: String, subtitle: String = "", home: Bool = false,
                    rows: [Action] = [], details: [String] = [], footer: [Action] = [], preview: Bool = false,
                    footerColumns: Int? = nil, homeInitials: String = "") {
            self.title = title; self.subtitle = subtitle; self.home = home
            self.rows = rows; self.details = details; self.footer = footer; self.preview = preview
            self.footerColumns = footerColumns
            self.homeInitials = homeInitials
        }
    }
    public struct Target: Equatable {
        public let action: Action
        public let frame: CGRect
    }
    public struct Layout {
        public let size: CGSize
        public let board: CGRect
        public let heading: CGRect
        public let subtitle: CGRect
        public let preview: CGRect
        public let details: [CGRect]
        public let targets: [Target]
        public var initials: CGRect = .zero
        public func action(at point: CGPoint) -> String? {
            targets.first { $0.action.enabled && $0.frame.contains(point) }?.action.id
        }
    }

    public static func layout(_ page: Page, width: CGFloat, minimumHeight: CGFloat) -> Layout {
        if page.home { return homeLayout(page, width: width, minimumHeight: minimumHeight) }
        let width = max(280, width)
        let inset: CGFloat = width < 600 ? 14 : 32
        let boardWidth = min(1032, width - inset * 2)
        let x = (width - boardWidth) / 2
        // A short, wide screen puts the preview beside its details so the actions stay in view.
        let compact = page.preview && minimumHeight < 520 && width > minimumHeight * 1.3
        let headingHeight: CGFloat = compact ? 40 : page.home ? min(160, boardWidth * 0.28) : 64
        let heading = CGRect(x: x + 20, y: compact ? 28 : 32, width: boardWidth - 40, height: headingHeight)
        let subtitle = CGRect(x: x + 20, y: heading.maxY + (compact ? 2 : 8), width: boardWidth - 40, height: compact ? 24 : 28)
        var y = subtitle.maxY + (compact ? 8 : 16)
        var targets: [Target] = []
        for row in page.rows {
            targets.append(Target(action: row, frame: CGRect(x: x + 20, y: y, width: boardWidth - 40, height: 52)))
            y += 60
        }
        var preview = CGRect.zero
        var details: [CGRect] = []
        if compact {
            let footerRows = Int(ceil(Double(page.footer.count) / Double(max(1, min(page.footerColumns ?? 3, max(1, page.footer.count))))))
            let room = max(80, minimumHeight - y - CGFloat(footerRows) * 60 - 36)
            let previewWidth = min((boardWidth - 40) * 0.55, room * 2)
            preview = CGRect(x: x + 20, y: y, width: previewWidth, height: previewWidth / 2)
            let side = boardWidth - 40 - previewWidth - 16
            let block = CGFloat(page.details.count) * 32
            var detailY = preview.midY - block / 2
            for _ in page.details {
                details.append(CGRect(x: preview.maxX + 16, y: detailY, width: side, height: 28))
                detailY += 32
            }
            y = preview.maxY + 12
        } else {
            if page.preview {
                let previewWidth = boardWidth - 40
                preview = CGRect(x: x + 20, y: y, width: previewWidth, height: min(360, previewWidth / 2))
                y = preview.maxY + 16
            }
            for _ in page.details {
                details.append(CGRect(x: x + 20, y: y, width: boardWidth - 40, height: 28))
                y += 32
            }
        }
        let columns = max(1, min(page.footerColumns ?? (boardWidth >= 620 ? 3 : 2), max(1, page.footer.count)))
        let rows = Int(ceil(Double(page.footer.count) / Double(columns)))
        let height = max(minimumHeight, y + CGFloat(rows) * 60 + 36)
        y = max(y + 12, height - CGFloat(rows) * 60 - 24)
        let cell = (boardWidth - 40 - CGFloat(columns - 1) * 12) / CGFloat(columns)
        for (index, action) in page.footer.enumerated() {
            // A lone action in the last row takes the whole row.
            let alone = columns > 1 && index == page.footer.count - 1 && index % columns == 0
            targets.append(Target(action: action, frame: CGRect(x: x + 20 + CGFloat(index % columns) * (cell + 12),
                y: y + CGFloat(index / columns) * 60, width: alone ? boardWidth - 40 : cell, height: 48)))
        }
        return Layout(size: CGSize(width: width, height: height),
                      board: CGRect(x: x, y: 16, width: boardWidth, height: height - 32),
                      heading: heading, subtitle: subtitle, preview: preview,
                      details: details, targets: targets)
    }

    private static func homeLayout(_ page: Page, width: CGFloat, minimumHeight: CGFloat) -> Layout {
        let width = max(280, width)
        let boardWidth = min(900, width - 28)
        let x = (width - boardWidth) / 2
        let inset: CGFloat = width < 600 ? 12 : 18
        let headerHeight: CGFloat = width < 600 ? 106 : 116
        let rowHeight: CGFloat = 44
        let headerIDs: Set<String> = ["settings", "whatsNew"]
        let footer = page.footer.filter { !headerIDs.contains($0.id) }
        let wide = boardWidth >= 600
        let columns = wide ? max(1, footer.count) : min(width >= 380 ? 2 : 1, max(1, footer.count))
        let footerRows = Int(ceil(Double(footer.count) / Double(columns)))
        let noticeHeight: CGFloat = page.subtitle.isEmpty ? 0 : 32
        let initialsHeight: CGFloat = wide || page.homeInitials.isEmpty ? 0 : 32
        let boardHeight = headerHeight + noticeHeight + CGFloat(page.rows.count) * (rowHeight + 5)
            + initialsHeight + CGFloat(footerRows) * 52 + 48
        let height = max(minimumHeight, boardHeight + 24)
        let board = CGRect(x: x, y: max(12, (height - boardHeight) / 2), width: boardWidth, height: boardHeight)
        let heading = CGRect(x: x + 62, y: board.minY + 18, width: boardWidth - 124, height: headerHeight - 24)
        let subtitle = CGRect(x: x + inset, y: board.minY + headerHeight, width: boardWidth - inset * 2, height: noticeHeight)
        var y = subtitle.maxY + 12
        var targets: [Target] = page.rows.map { action in
            defer { y += rowHeight + 5 }
            return Target(action: action, frame: CGRect(x: x + inset, y: y, width: boardWidth - inset * 2, height: rowHeight))
        }
        y += 12
        let initialsWidth: CGFloat = page.homeInitials.isEmpty ? 0 : wide ? min(200, max(64, CGFloat(page.homeInitials.count) * 8 + 12)) : boardWidth - inset * 2
        let initials = CGRect(x: x + inset, y: y, width: initialsWidth, height: wide ? 44 : initialsHeight)
        if !wide { y += initialsHeight }
        let gap: CGFloat = 12
        let start = x + inset + (wide && initialsWidth > 0 ? initialsWidth + gap : 0)
        let cell = (x + boardWidth - inset - start - CGFloat(columns - 1) * gap) / CGFloat(columns)
        // Keep the target order equal to Page.rows + Page.footer for UIKit and keyboard input.
        for action in page.footer {
            let frame: CGRect
            if headerIDs.contains(action.id) {
                frame = CGRect(x: action.id == "settings" ? board.maxX - inset - 44 : board.minX + inset,
                               y: board.minY + 18, width: 44, height: 44)
            } else {
                let index = footer.firstIndex(where: { $0.id == action.id })!
                let alone = !wide && index == footer.count - 1 && index % columns == 0
                frame = CGRect(x: start + CGFloat(index % columns) * (cell + gap),
                               y: y + CGFloat(index / columns) * 52,
                               width: alone ? boardWidth - inset * 2 : cell, height: 44)
            }
            targets.append(Target(action: action, frame: frame))
        }
        return Layout(size: CGSize(width: width, height: height), board: board, heading: heading,
                      subtitle: subtitle, preview: .zero, details: [], targets: targets, initials: initials)
    }

    public static func draw(_ page: Page, layout: Layout, typography: GameMenuTypography,
                            preview: CGImage? = nil, previewSource: CGRect? = nil,
                            highlighted: String? = nil, portraits: GamePortraitArt? = nil, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: layout.size))
        GameMenuFrameArt.draw(in: context, board: layout.board)
        if page.home, let logo = typography.interface.logo,
           let image = image(logo) {
            drawImage(image, fittedIn: layout.heading, context: context)
        } else {
            heading(page.title, box: layout.heading, typography: typography, context: context)
        }
        line(page.subtitle, box: layout.subtitle, typography: typography, context: context)
        if page.home, !page.homeInitials.isEmpty {
            line(page.homeInitials, box: layout.initials, typography: typography, palette: .green, context: context)
        }
        if page.preview {
            GameStoneArt.draw(in: context, frame: layout.preview, selected: true, pixel: 2)
            if let preview {
                let image = previewSource.flatMap { preview.cropping(to: $0.integral) } ?? preview
                drawImage(image, fittedIn: GameStoneArt.well(layout.preview, pixel: 2).insetBy(dx: 4, dy: 4), context: context)
            }
        }
        for (value, box) in zip(page.details, layout.details) {
            line(value, box: box, typography: typography, context: context)
        }
        let rowIDs = Set(page.rows.map(\.id))
        for target in layout.targets {
            let action = target.action
            let chosen = action.enabled && (action.primary || action.selected || highlighted == action.id)
            if page.home, rowIDs.contains(action.id) {
                // The home screen uses the same dark rows and green selection as the Mac title overlay.
                context.setFillColor(chosen ? CGColor(srgbRed: 0.18, green: 0.27, blue: 0.12, alpha: 1)
                    : CGColor(gray: 0.07, alpha: 1))
                context.fill(target.frame)
                context.setStrokeColor(chosen ? CGColor(srgbRed: 0.70, green: 0.84, blue: 0.29, alpha: 1)
                    : CGColor(gray: 0.29, alpha: 1))
                context.setLineWidth(chosen ? 2 : 1)
                context.stroke(target.frame.insetBy(dx: 1, dy: 1))
            } else if page.home, ["settings", "whatsNew"].contains(action.id) {
                GameStoneArt.draw(in: context, frame: target.frame, selected: chosen, pixel: 1)
                let glyph: PanelGlyphArt = action.id == "settings" ? .settings : .download
                let well = GameStoneArt.well(target.frame, pixel: 1).insetBy(dx: 2, dy: 2)
                let scale = glyph.scale(fitting: well.size)
                if let image = glyph.cgImage(scale: scale) {
                    drawImage(image, fittedIn: well, context: context)
                }
                continue
            } else if page.home {
                context.setFillColor(chosen ? CGColor(srgbRed: 0.06, green: 0.16, blue: 0.035, alpha: 1) : CGColor(gray: 0.025, alpha: 1))
                context.fill(target.frame)
                context.setStrokeColor(chosen ? CGColor(srgbRed: 0.48, green: 0.80, blue: 0.24, alpha: 1) : CGColor(gray: 0.35, alpha: 1))
                context.setLineWidth(1)
                context.stroke(target.frame.insetBy(dx: 0.5, dy: 0.5))
            } else {
                GameStoneArt.draw(in: context, frame: target.frame, selected: chosen, pixel: 1)
            }
            if action.selected {
                context.setFillColor(CGColor(srgbRed: 0.48, green: 0.80, blue: 0.24, alpha: action.enabled ? 1 : 0.45))
                context.fill(CGRect(x: target.frame.minX + 8, y: target.frame.maxY - 6,
                                    width: target.frame.width - 16, height: 3))
            }
            if action.primary, action.enabled, !page.home {
                context.setFillColor(CGColor(srgbRed: 0.48, green: 0.80, blue: 0.24, alpha: 1))
                context.beginPath()
                context.move(to: CGPoint(x: target.frame.minX + 10, y: target.frame.midY - 5))
                context.addLine(to: CGPoint(x: target.frame.minX + 17, y: target.frame.midY))
                context.addLine(to: CGPoint(x: target.frame.minX + 10, y: target.frame.midY + 5))
                context.closePath(); context.fillPath()
            }
            if let portrait = action.portrait {
                portraits?.draw(portrait, in: CGRect(x: target.frame.minX + 12,
                    y: target.frame.minY + 7, width: 30, height: 36), context: context)
            }
            var caption = target.frame.insetBy(dx: action.primary ? 24 : 12, dy: 2)
            if action.portrait != nil { caption.origin.x += 36; caption.size.width -= 36 }
            actionLabel(action.title, box: caption, typography: typography,
                        palette: chosen ? .green : .blue, alpha: action.enabled ? 1 : 0.45, context: context)
        }
    }

    private static func actionLabel(_ text: String, box: CGRect, typography: GameMenuTypography,
                                    palette: GameMenuTypography.Palette, alpha: CGFloat, context: CGContext) {
        let lines = wrapped(GameMenuTypography.menuText(text), face: .small, width: box.width, typography: typography)
        let height = max(1, typography.height(face: .small, scale: 1))
        let count = min(lines.count, Int(box.height / height))
        let top = box.midY - CGFloat(count) * height / 2
        for (index, value) in lines.prefix(count).enumerated() {
            line(value, box: CGRect(x: box.minX, y: top + CGFloat(index) * height, width: box.width, height: height),
                 typography: typography, palette: palette, alpha: alpha, context: context)
        }
    }

    private static func heading(_ text: String, box: CGRect, typography: GameMenuTypography, context: CGContext) {
        let plain = GameMenuTypography.menuText(text)
        if typography.width(of: plain, face: .large, scale: 1) <= box.width {
            line(text, box: box, typography: typography, face: .large, palette: .green, context: context)
            return
        }
        var face: GameMenuTypography.Face = .large
        var lines = wrapped(plain, face: face, width: box.width, typography: typography)
        if lines.count > 2 {
            face = .small
            lines = wrapped(plain, face: face, width: box.width, typography: typography)
        }
        let height = max(1, typography.height(face: face, scale: 1))
        let count = min(lines.count, Int(box.height / height))
        let top = box.midY - CGFloat(count) * height / 2
        for (index, value) in lines.prefix(count).enumerated() {
            line(value, box: CGRect(x: box.minX, y: top + CGFloat(index) * height, width: box.width, height: height),
                 typography: typography, face: face, palette: .green, scale: 1, context: context)
        }
    }

    private static func wrapped(_ text: String, face: GameMenuTypography.Face, width: CGFloat,
                                typography: GameMenuTypography) -> [String] {
        var lines: [String] = []
        var line = ""
        for word in text.split(separator: " ") {
            let next = line.isEmpty ? String(word) : line + " " + word
            if !line.isEmpty && typography.width(of: next, face: face, scale: 1) > width {
                lines.append(line); line = String(word)
            } else { line = next }
        }
        if !line.isEmpty { lines.append(line) }
        return lines
    }

    private static func line(_ text: String, box: CGRect, typography: GameMenuTypography,
                             face: GameMenuTypography.Face = .small, palette: GameMenuTypography.Palette = .blue,
                             alpha: CGFloat = 1, scale fixed: Int? = nil, context: CGContext) {
        let scale = fixed ?? (face == .large && typography.width(of: GameMenuTypography.menuText(text), face: face, scale: 2) <= box.width ? 2 : 1)
        let height = typography.height(face: face, scale: scale)
        typography.menuLine(text, in: CGRect(x: box.minX, y: box.midY - height / 2, width: box.width, height: height),
                            context: context, face: face, scale: scale, alpha: alpha, palette: palette)
    }
    private static func image(_ frame: ClassicMacArtwork.Frame) -> CGImage? {
        guard let provider = CGDataProvider(data: frame.rgba as CFData) else { return nil }
        return CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8,
                       bitsPerPixel: 32, bytesPerRow: frame.width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    private static func drawImage(_ image: CGImage, fittedIn box: CGRect, context: CGContext) {
        let fit = min(box.width / CGFloat(image.width), box.height / CGFloat(image.height))
        let factor = fit >= 1 ? floor(fit) : fit
        let size = CGSize(width: CGFloat(image.width) * factor, height: CGFloat(image.height) * factor)
        let frame = CGRect(x: floor(box.midX - size.width / 2), y: floor(box.midY - size.height / 2), width: size.width, height: size.height)
        GameStoneArt.drawImage(image, in: frame, context: context)
    }
}
