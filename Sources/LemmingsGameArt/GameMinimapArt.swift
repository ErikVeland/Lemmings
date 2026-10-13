import CoreGraphics

/// The Mac panel's map with its current camera window. Coordinates start at the top left.
public enum GameMinimapArt {
    public static func content(in bounds: CGRect, levelSize: CGSize) -> CGRect {
        guard levelSize.width > 0, levelSize.height > 0 else { return .zero }
        let scale = min(bounds.width / levelSize.width, bounds.height / levelSize.height)
        let size = CGSize(width: levelSize.width * scale, height: levelSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    public static func draw(in context: CGContext, bounds: CGRect, image: CGImage?, visible: CGRect, levelSize: CGSize, overlay: Bool = false) {
        if overlay { GameStoneArt.drawSocket(in: context, frame: bounds, selected: false, pixel: 1) }
        let map = content(in: overlay ? bounds.insetBy(dx: 4, dy: 4) : bounds, levelSize: levelSize)
        guard !map.isEmpty else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.interpolationQuality = .none
        if let image {
            context.setAlpha(0.8)
            GameStoneArt.drawImage(image, in: map, context: context)
            context.setAlpha(1)
        }
        let scale = map.width / levelSize.width
        let window = CGRect(x: map.minX + visible.minX * scale, y: map.minY + visible.minY * scale,
                            width: visible.width * scale, height: visible.height * scale).intersection(map)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.8))
        context.setLineWidth(1)
        context.stroke(window)
    }
}
