import CoreGraphics
import Foundation

public enum GameLoadingIntroArt {
    public static let visualDelay: UInt64 = 550_000_000
    public static func frameElapsed(_ elapsed: TimeInterval, reduceMotion: Bool, reduceFlashes: Bool) -> TimeInterval {
        reduceMotion || reduceFlashes ? 0 : elapsed
    }

    private static func colour(_ rgb: UInt32) -> CGColor {
        CGColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
            blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }

    private static let sky = [0x080719, 0x100a2a, 0x20123c, 0x341b4c, 0x522756, 0x7a3861].map {
        colour(UInt32($0))
    }
    private static let stars = [colour(0x8776ba), colour(0x4d518e)]
    private static let copper = [0x53326d, 0x764581, 0xad6494, 0xe59ea9, 0xf6cfb1, 0xd175a0, 0x713f86].map {
        colour(UInt32($0))
    }
    private static let tiles = [colour(0x241442), colour(0x140e2d)]

    public static func draw(in frame: CGRect, title: String, message: String,
                            elapsed: TimeInterval, context: CGContext) {
        guard frame.width > 0, frame.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: frame)
        context.setFillColor(colour(0x080719))
        context.fill(frame)

        let scale = min(frame.width / 320, frame.height / 200)
        context.translateBy(x: frame.midX - 160 * scale, y: frame.midY - 100 * scale)
        context.scaleBy(x: scale, y: scale)
        context.setShouldAntialias(false)
        context.clip(to: CGRect(x: 0, y: 0, width: 320, height: 200))

        for (index, band) in sky.enumerated() {
            context.setFillColor(band)
            context.fill(CGRect(x: 0, y: index * 20, width: 320, height: 20))
        }
        let drift = Int(elapsed.truncatingRemainder(dividingBy: 80) * 4)
        for index in 0..<38 {
            let size = 1 + index % 2
            let x = (index * 67 + drift * size) % 320
            let y = (index * 41 + 11) % 111
            context.setFillColor(stars[index % 2])
            context.fill(CGRect(x: x, y: y, width: size, height: size))
        }
        let wave = Int((sin(elapsed * 3) * 5).rounded())
        for (index, band) in copper.enumerated() {
            let inset = 4 * abs(index - 3)
            context.setFillColor(band)
            context.fill(CGRect(x: 44 + inset, y: 90 + wave + index * 3,
                                width: 232 - 2 * inset, height: 3))
        }
        context.setFillColor(tiles[1])
        context.fill(CGRect(x: 0, y: 121, width: 320, height: 79))
        let rows: [CGFloat] = [121, 126, 133, 143, 157, 176, 200]
        for row in rows.indices.dropLast() {
            let top = rows[row], bottom = rows[row + 1]
            let topWidth = (top - 106) * 0.54, bottomWidth = (bottom - 106) * 0.54
            for column in -20..<20 where (column + row).isMultiple(of: 2) {
                let left = CGFloat(column), right = left + 1
                guard 160 + left * bottomWidth < 320, 160 + right * bottomWidth > 0 else { continue }
                context.beginPath()
                context.move(to: CGPoint(x: 160 + left * topWidth, y: top))
                context.addLine(to: CGPoint(x: 160 + right * topWidth, y: top))
                context.addLine(to: CGPoint(x: 160 + right * bottomWidth, y: bottom))
                context.addLine(to: CGPoint(x: 160 + left * bottomWidth, y: bottom))
                context.closePath()
                context.setFillColor(tiles[0])
                context.fillPath()
            }
        }

        let wordmark = CGRect(x: 20, y: 54 + CGFloat(wave), width: 280, height: 31)
        GamePixelTypography.draw(title, in: wordmark.offsetBy(dx: 2, dy: 3), context: context,
            typography: nil, maximumScale: 4, bitmapOnly: true, color: colour(0x2d225d))
        GamePixelTypography.draw(title, in: wordmark, context: context,
            typography: nil, maximumScale: 4, bitmapOnly: true, color: colour(0xd8e8ff))
        GamePixelTypography.draw(message, in: CGRect(x: 20, y: 150, width: 280, height: 28), context: context,
            typography: nil, maximumScale: 2, bitmapOnly: true, color: colour(0xf8daca))
    }
}
