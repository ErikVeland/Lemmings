#if os(iOS)
import UIKit

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
        alignment: NSTextAlignment = .center
    ) {
        guard let context = UIGraphicsGetCurrentContext(), rect.width > 0, rect.height > 0 else { return }
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ rect: CGRect) {
        MobilePixelText.draw(text, in: bounds, palette: palette,
                             maximumScale: maximumScale, alignment: alignment)
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
        addTarget(self, action: #selector(pressed), for: .touchUpInside)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { nil }

    @objc private func pressed() { onPress?() }

    override var isHighlighted: Bool {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let selected = isHighlighted || isSelectedState
        context.setShouldAntialias(false)
        context.setFillColor(UIColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1).cgColor)
        context.fill(bounds)
        let pixel = max(1, floor(min(bounds.width, bounds.height) / 24))
        let top = selected ? UIColor(white: 0.22, alpha: 1) : UIColor(white: 0.42, alpha: 1)
        let bottom = selected ? UIColor(white: 0.52, alpha: 1) : UIColor(white: 0.18, alpha: 1)
        context.setFillColor(top.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: pixel * 2))
        context.fill(CGRect(x: 0, y: 0, width: pixel * 2, height: bounds.height))
        context.setFillColor(bottom.cgColor)
        context.fill(CGRect(x: 0, y: bounds.height - pixel * 2, width: bounds.width, height: pixel * 2))
        context.fill(CGRect(x: bounds.width - pixel * 2, y: 0, width: pixel * 2, height: bounds.height))
        if isPrimary || isSelectedState {
            context.setStrokeColor(MobilePixelText.Palette.green.colour.cgColor)
            context.setLineWidth(pixel)
            context.stroke(bounds.insetBy(dx: pixel * 3, dy: pixel * 3))
        }
        MobilePixelText.draw(title, in: bounds.insetBy(dx: 8, dy: 8),
                             palette: isPrimary || isSelectedState ? .green : .blue)
    }
}
#else
public enum LemmingsMobileUIUnavailable {}
#endif
