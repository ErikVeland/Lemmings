import CoreGraphics

/// The CoverFlow card: its geometry on the stage and its bitmap drawing.
///
/// Rectangles use a top-left origin, as in `GameStoneArt`.
public enum LevelCoverArt {
    /// Measurements for a stage of a given size. The centre card is drawn at 1.5 times its base size.
    public struct Geometry: Equatable, Sendable {
        public let cardSize: CGSize
        public let cameraDistance: CGFloat
        public let nearPitch: CGFloat
        public let outerPitch: CGFloat
        public let stackDepthStep: CGFloat
    }

    /// Where one card sits, for its offset from the centre of the carousel.
    public struct Placement: Equatable, Sendable {
        /// Horizontal distance of the card centre from the stage centre.
        public let x: CGFloat
        public let angle: CGFloat
        public let scale: CGFloat
        public let depth: CGFloat
        public let zPosition: CGFloat
    }

    public static func geometry(for stage: CGSize) -> Geometry {
        let width = min(320, stage.width * 0.33)
        let height = min(260, stage.height * 0.62)
        return Geometry(
            cardSize: CGSize(width: width, height: height),
            cameraDistance: width * 8 / 3,
            nearPitch: width * 1.25 * cos(.pi / 8) + max(8, width * 0.025),
            outerPitch: width * 0.14,
            stackDepthStep: max(8, width * 0.04))
    }

    public static func placement(offset: CGFloat, selected: Bool, geometry: Geometry) -> Placement {
        let distance = abs(offset)
        let direction: CGFloat = offset == 0 ? 0 : offset > 0 ? 1 : -1
        let spacing = min(distance, 1) * geometry.nearPitch + max(0, distance - 1) * geometry.outerPitch
        let side = min(distance, 1)
        let outer = max(0, distance - 1)
        let angle = direction * -.pi / 4 * side
        let scale = 1.5 - side * 0.5
        let width = geometry.cardSize.width
        let halfDepth = width * scale * abs(sin(angle)) / 2
        let front = width / 15 * (1 - side) - geometry.stackDepthStep * (side + outer)
        return Placement(x: direction * spacing, angle: angle, scale: scale,
                         depth: front - halfDepth, zPosition: 0.001 * (10 - distance) + (selected ? 0.0005 : 0))
    }

    /// The part of a card's bounds that holds the cover. The rest is left for the reflection.
    public static func coverBounds(for bounds: CGRect) -> CGRect {
        let gap = max(3, min(7, bounds.height * 0.018))
        let reflection = min(86, bounds.height * 0.21)
        return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: max(1, bounds.height - reflection - gap))
    }

    private static func content(of cover: CGRect, focused: Bool) -> CGRect {
        GameStoneArt.well(cover, pixel: focused ? 2 : 1).insetBy(dx: 10, dy: 8)
    }

    private static func artworkFrame(in content: CGRect) -> CGRect {
        let height = min(content.width / 2, content.height)
        return CGRect(x: content.minX, y: floor(content.midY - height / 2), width: content.width, height: height)
    }

    /// Draws the card and its faded reflection into `bounds`.
    public static func draw(in context: CGContext, bounds: CGRect, title: String, artwork: CGImage?,
                            selected: Bool, typography: GameMenuTypography?) {
        let cover = coverBounds(for: bounds)
        GameDisplayArt.draw(in: context, frame: cover)
        if selected {
            GameDisplayArt.outline(in: context, frame: cover,
                color: CGColor(srgbRed: 0.6755, green: 0.8639, blue: 0.2804, alpha: 1), pixel: 2)
        }
        let content = content(of: cover, focused: selected)
        let frame = artworkFrame(in: content)
        drawArtwork(artwork, in: frame, context: context)
        if let typography {
            if artwork == nil {
                let height = GameTextLayout.height(title, width: content.width)
                if height <= content.height {
                    GameTextLayout.draw(title, in: content, typography: typography, palette: .green, context: context)
                }
            }
        }

        drawReflection(in: context, bounds: bounds, cover: cover, frame: frame, artwork: artwork, selected: selected)
    }

    private static func drawArtwork(_ artwork: CGImage?, in frame: CGRect, context: CGContext) {
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(frame)
        if let artwork {
            let source = CGFloat(artwork.width) / max(1, CGFloat(artwork.height))
            let target = frame.width / max(1, frame.height)
            let size = source > target ? CGSize(width: frame.width, height: frame.width / source)
                                       : CGSize(width: frame.height * source, height: frame.height)
            context.saveGState()
            context.interpolationQuality = .none
            GameStoneArt.drawImage(artwork, in: CGRect(x: floor(frame.midX - size.width / 2), y: floor(frame.midY - size.height / 2),
                                                       width: ceil(size.width), height: ceil(size.height)), context: context)
            context.restoreGState()
        }
        context.setStrokeColor(CGColor(gray: 0.72, alpha: 1))
        context.setLineWidth(1)
        context.stroke(frame.insetBy(dx: 0.5, dy: 0.5))
    }

    private static func drawReflection(in context: CGContext, bounds: CGRect, cover: CGRect, frame: CGRect,
                                       artwork: CGImage?, selected: Bool) {
        let gap = max(3, min(7, bounds.height * 0.018))
        let reflection = CGRect(x: frame.minX, y: cover.maxY + gap, width: frame.width,
                                height: max(0, bounds.maxY - cover.maxY - gap))
        guard reflection.height > 0 else { return }
        context.saveGState()
        context.clip(to: reflection)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        // The cover, mirrored about its lower edge.
        context.saveGState()
        context.translateBy(x: 0, y: reflection.minY + frame.maxY)
        context.scaleBy(x: 1, y: -1)
        drawArtwork(artwork, in: frame, context: context)
        context.restoreGState()
        // Fade it out, brightest at the cover edge.
        context.setBlendMode(.destinationIn)
        let colours = [CGColor(gray: 1, alpha: selected ? 0.42 : 0.32), CGColor(gray: 1, alpha: 0)] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: reflection.midX, y: reflection.minY),
                                       end: CGPoint(x: reflection.midX, y: reflection.maxY), options: [])
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }
}
