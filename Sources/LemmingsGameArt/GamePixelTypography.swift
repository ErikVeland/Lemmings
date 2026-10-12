import CoreGraphics
import Foundation
import NxlvKit

/// Bitmap lettering shared by mobile drawing and headless captures.
public enum GamePixelTypography {
    private static let columns: [Character: [UInt8]] = [
        "A":[126,9,9,9,126], "B":[127,73,73,73,54], "C":[62,65,65,65,34],
        "D":[127,65,65,34,28], "E":[127,73,73,73,65], "F":[127,9,9,9,1],
        "G":[62,65,73,73,122], "H":[127,8,8,8,127], "I":[0,65,127,65,0],
        "J":[32,64,65,63,1], "K":[127,8,20,34,65], "L":[127,64,64,64,64],
        "M":[127,2,12,2,127], "N":[127,4,8,16,127], "O":[62,65,65,65,62],
        "P":[127,9,9,9,6], "Q":[62,65,81,33,94], "R":[127,9,25,41,70],
        "S":[70,73,73,73,49], "T":[1,1,127,1,1], "U":[63,64,64,64,63],
        "V":[31,32,64,32,31], "W":[63,64,56,64,63], "X":[99,20,8,20,99],
        "Y":[3,4,120,4,3], "Z":[97,81,73,69,67],
        "0":[62,81,73,69,62], "1":[0,66,127,64,0], "2":[98,81,73,73,70],
        "3":[34,65,73,73,54], "4":[24,20,18,127,16], "5":[39,69,69,69,57],
        "6":[60,74,73,73,48], "7":[1,113,9,5,3], "8":[54,73,73,73,54],
        "9":[6,73,73,41,30], ":":[0,54,54,0,0], ".":[0,96,96,0,0],
        "-":[8,8,8,8,8], "+":[8,8,62,8,8], "/":[32,16,8,4,2],
        "*":[20,8,62,8,20], "%":[99,19,8,100,99], "(":[0,28,34,65,0],
        ")":[0,65,34,28,0], "'":[0,3,0,0,0], "!":[0,0,95,0,0],
        ",":[0,64,48,0,0], "<":[8,20,34,65,0], ">":[0,65,34,20,8],
        "?":[2,1,81,9,6], "=":[20,20,20,20,20]
    ]

    public enum Palette {
        case blue
        case green
        case warning

        var menu: GameMenuTypography.Palette { self == .blue ? .blue : .green }

        var colour: CGColor {
            switch self {
            case .blue: return CGColor(srgbRed: 0.20, green: 0.50, blue: 1, alpha: 1)
            case .green: return CGColor(srgbRed: 0.45, green: 1, blue: 0.10, alpha: 1)
            case .warning: return CGColor(srgbRed: 1, green: 0.42, blue: 0.12, alpha: 1)
            }
        }
    }

    public static func draw(
        _ text: String,
        in rect: CGRect,
        context: CGContext, typography: GameMenuTypography?,
        palette: Palette = .blue,
        maximumScale: CGFloat = 4,
        alignment: GameMenuTypography.Alignment = .center,
        face: GameMenuTypography.Face = .small,
        alpha: CGFloat = 1,
        bitmapOnly: Bool = false
    ) {
        guard rect.width > 0, rect.height > 0 else { return }
        if !bitmapOnly, let typography {
            // Lettering keeps one size by purpose. Titles take 2× when they fit, as on the Mac pages.
            let plain = GameMenuTypography.menuText(text)
            let doubled = face == .large
                && typography.width(of: plain, face: face, scale: 2) <= rect.width
                && typography.height(face: face, scale: 2) <= rect.height
            let scale = doubled ? 2 : 1
            let height = typography.height(face: face, scale: scale)
            typography.menuLine(
                text,
                in: CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height),
                context: context,
                face: face,
                scale: scale,
                alignment: alignment == .left ? .left : alignment == .right ? .right : .center,
                alpha: alpha,
                palette: palette.menu
            )
            return
        }
        let plain = text.uppercased().replacingOccurrences(of: "×", with: "X")
        let fittingColumns = max(0, Int((rect.width + 1) / 6))
        guard fittingColumns > 0 else { return }
        let normalized = plain.count <= fittingColumns ? plain
            : String(plain.prefix(max(0, fittingColumns - 3))) + String(repeating: ".", count: min(3, fittingColumns))
        let naturalWidth = max(1, normalized.count * 6 - 1)
        let scale = max(1, min(maximumScale, floor(min(rect.height / 7, rect.width / CGFloat(naturalWidth)))))
        let drawnWidth = CGFloat(naturalWidth) * scale
        let start: CGFloat
        switch alignment {
        case .left: start = rect.minX
        case .right: start = rect.maxX - drawnWidth
        default: start = rect.midX - drawnWidth / 2
        }
        let top = floor(rect.midY - 3.5 * scale)
        context.saveGState()
        context.clip(to: rect)
        context.setShouldAntialias(false)
        context.setFillColor(palette.colour)
        context.setAlpha(alpha)
        for (index, character) in normalized.enumerated() {
            guard let glyph = columns[character] else { continue }
            for (x, column) in glyph.enumerated() {
                for y in 0..<7 where column & (1 << y) != 0 {
                    context.fill(CGRect(
                        x: start + CGFloat(index * 6 + x) * scale,
                        y: top + CGFloat(y) * scale,
                        width: scale,
                        height: scale
                    ))
                }
            }
        }
        context.restoreGState()
    }
}
