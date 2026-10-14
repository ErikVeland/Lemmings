import CoreGraphics
import CoreText
import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Native-resolution digits follow the Mac bomb countdown's font and scale.
@MainActor public final class BombCountdownRenderer {
    private var lines: [Int: CTLine] = [:]
    private var cachedSize: CGFloat = 0
    public init() {}

    @discardableResult public func draw(seconds: Int, above anchor: CGPoint, zoom: CGFloat,
        in context: CGContext) -> CGRect {
        guard seconds > 0, zoom.isFinite, zoom > 0,
            anchor.x.isFinite, anchor.y.isFinite else { return .null }
        let size = 10 * zoom / 3
        if size != cachedSize { lines.removeAll(keepingCapacity: true); cachedSize = size }
        let line: CTLine
        if let cached = lines[seconds] { line = cached }
        else {
            #if os(iOS) || os(tvOS)
            let font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
            let colour = UIColor.white
            #else
            let font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
            let colour = NSColor.white
            #endif
            line = CTLineCreateWithAttributedString(NSAttributedString(string: String(seconds),
                attributes: [.font: font, .foregroundColor: colour]))
            if lines.count < 9 { lines[seconds] = line }
        }
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let frame = CGRect(x: anchor.x - width / 2, y: anchor.y - ascent - descent - leading,
            width: width, height: ascent + descent + leading)
        context.saveGState()
        defer { context.restoreGState() }
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setShouldSmoothFonts(false)
        context.translateBy(x: frame.minX, y: frame.minY + ascent)
        context.scaleBy(x: 1, y: -1)
        context.textMatrix = .identity
        context.textPosition = .zero
        CTLineDraw(line, context)
        return frame
    }
}
