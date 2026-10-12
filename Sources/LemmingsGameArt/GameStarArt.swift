import CoreGraphics

/// The rescue star uses the same filled and outlined pixels on each platform.
public enum GameStarArt {
    public static func draw(at origin: CGPoint, earned: Bool, size: CGFloat, context: CGContext) {
        let pixels = [".....#.....", "....###....", "....###....", "###########", ".#########.",
                      "..#######..", "..#######..", ".####.####.", ".##.....##."].map(Array.init)
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.setFillColor(earned ? CGColor(srgbRed: 1, green: 0.76, blue: 0.30, alpha: 1) : CGColor(gray: 0.62, alpha: 1))
        for (y, row) in pixels.enumerated() {
            for (x, pixel) in row.enumerated() where pixel == "#" {
                let interior = x > 0 && x + 1 < row.count && y > 0 && y + 1 < pixels.count
                    && row[x - 1] == "#" && row[x + 1] == "#" && pixels[y - 1][x] == "#" && pixels[y + 1][x] == "#"
                if !earned && interior { continue }
                context.fill(CGRect(x: origin.x + CGFloat(x) * size, y: origin.y + CGFloat(y) * size, width: size, height: size))
            }
        }
    }
}
