import CoreGraphics

public enum Lemmings3PanelArt {
    public static func skillGlyph(in panel: CGImage, index: Int) -> CGImage? {
        guard (0..<5).contains(index) else { return nil }
        let scaleX = CGFloat(panel.width) / 320
        let scaleY = CGFloat(panel.height) / 40
        return panel.cropping(to: CGRect(x: CGFloat(index * 35 + 3) * scaleX, y: 3 * scaleY,
                                         width: 29 * scaleX, height: 34 * scaleY))
    }
}
