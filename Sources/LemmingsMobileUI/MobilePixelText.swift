#if os(iOS)
import LemmingsGameArt
import UIKit

/// The Macintosh release's menu lettering, shared with the Mac app. Nil when the bundle lacks it.
@MainActor enum MobileGameArt {
    static let typography: GameMenuTypography? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("MacArtwork/lemmings") else { return nil }
        return GameMenuTypography(directory: url)
    }()
}

@MainActor enum MobilePixelText {
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

    enum Palette {
        case blue
        case green
        case warning

        var menu: GameMenuTypography.Palette { self == .blue ? .blue : .green }

        var colour: UIColor {
            switch self {
            case .blue: return UIColor(red: 0.20, green: 0.50, blue: 1, alpha: 1)
            case .green: return UIColor(red: 0.45, green: 1, blue: 0.10, alpha: 1)
            case .warning: return UIColor(red: 1, green: 0.42, blue: 0.12, alpha: 1)
            }
        }
    }

    static func draw(
        _ text: String,
        in rect: CGRect,
        palette: Palette = .blue,
        maximumScale: CGFloat = 4,
        alignment: NSTextAlignment = .center,
        face: GameMenuTypography.Face = .small,
        alpha: CGFloat = 1,
        bitmapOnly: Bool = false
    ) {
        guard let context = UIGraphicsGetCurrentContext(), rect.width > 0, rect.height > 0 else { return }
        if !bitmapOnly, let typography = MobileGameArt.typography {
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
        let normalized = text.uppercased().replacingOccurrences(of: "×", with: "X")
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
        context.setShouldAntialias(false)
        context.setFillColor(palette.colour.cgColor)
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

@MainActor final class MobilePixelLabel: UIView {
    var text = "" { didSet { setNeedsDisplay() } }
    var palette = MobilePixelText.Palette.blue { didSet { setNeedsDisplay() } }
    var alignment = NSTextAlignment.center { didSet { setNeedsDisplay() } }
    var maximumScale: CGFloat = 4 { didSet { setNeedsDisplay() } }
    var face = GameMenuTypography.Face.small { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ rect: CGRect) {
        MobilePixelText.draw(text, in: bounds, palette: palette,
                             maximumScale: maximumScale, alignment: alignment, face: face)
        accessibilityLabel = text
    }
}

@MainActor final class MobilePixelButton: UIControl {
    var title = "" { didSet { accessibilityLabel = title; setNeedsDisplay() } }
    var isPrimary = false { didSet { setNeedsDisplay() } }
    var isSelectedState = false { didSet { setNeedsDisplay() } }
    var onPress: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .button
        contentMode = .redraw
        addTarget(self, action: #selector(pressed), for: .touchUpInside)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { nil }

    @objc private func pressed() { onPress?() }

    override var isHighlighted: Bool {
        didSet { setNeedsDisplay() }
    }

    override var isEnabled: Bool {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let chosen = isEnabled && (isPrimary || isSelectedState || isHighlighted)
        GameStoneArt.draw(in: context, frame: bounds, selected: chosen, pixel: 1)
        MobilePixelText.draw(title, in: CGRect(x: 12, y: bounds.midY - 10, width: bounds.width - 24, height: 20),
                             palette: chosen ? .green : .blue, alpha: isEnabled ? 1 : 0.45)
    }
}
/// The black page with the stone edging and moss cap the Mac menu pages use.
@MainActor final class MobileMenuBackdrop: UIView {
    var board = CGRect.zero { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), !board.isEmpty else { return }
        GameMenuFrameArt.draw(in: context, board: board)
    }
}
#else
public enum LemmingsMobileUIUnavailable {}
#endif
