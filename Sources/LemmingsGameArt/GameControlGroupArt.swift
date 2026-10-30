import CoreGraphics
import LemmingsMobileCore

/// Independent display corners, including a foldable's tighter hinge-side corners.
public struct GameControlCornerRadii: Equatable {
    public let topLeft: CGFloat
    public let topRight: CGFloat
    public let bottomLeft: CGFloat
    public let bottomRight: CGFloat

    public init(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        self.topLeft = max(0, topLeft)
        self.topRight = max(0, topRight)
        self.bottomLeft = max(0, bottomLeft)
        self.bottomRight = max(0, bottomRight)
    }

    public func inset(by amount: CGFloat) -> Self {
        Self(topLeft: topLeft - amount, topRight: topRight - amount,
             bottomLeft: bottomLeft - amount, bottomRight: bottomRight - amount)
    }
}

/// One pixel outline, rounded ends and a single divider per joined control.
public enum GameControlGroupArt {
    public static func path(in frame: CGRect, inset: CGFloat = 0,
                            bottomLeft: Bool = false, bottomRight: Bool = false,
                            screenEdges: Bool = false, topLeft: Bool = false, topRight: Bool = false, screenRadius: CGFloat? = nil, cornerRadii: GameControlCornerRadii? = nil) -> CGPath {
        let box = frame.insetBy(dx: inset, dy: inset)
        guard box.width > 0, box.height > 0 else { return CGMutablePath() }
        if screenEdges {
            let fallback = screenRadius ?? min(frame.width, frame.height) / 2
            let corners = cornerRadii ?? GameControlCornerRadii(topLeft: fallback, topRight: fallback,
                bottomLeft: fallback, bottomRight: fallback)
            let topL = topLeft ? max(0, corners.topLeft - inset) : 0
            let topR = topRight ? max(0, corners.topRight - inset) : 0
            let bottomL = bottomLeft ? max(0, corners.bottomLeft - inset) : 0
            let bottomR = bottomRight ? max(0, corners.bottomRight - inset) : 0
            let factor = min(1, box.width / max(1, topL + topR), box.width / max(1, bottomL + bottomR),
                             box.height / max(1, topL + bottomL), box.height / max(1, topR + bottomR))
            let tl = topL * factor, tr = topR * factor
            let bl = bottomL * factor, br = bottomR * factor
            let curve: CGFloat = 0.5522847498
            let path = CGMutablePath()
            path.move(to: CGPoint(x: box.minX + tl, y: box.minY))
            path.addLine(to: CGPoint(x: box.maxX - tr, y: box.minY))
            path.addCurve(to: CGPoint(x: box.maxX, y: box.minY + tr),
                          control1: CGPoint(x: box.maxX - tr * (1 - curve), y: box.minY),
                          control2: CGPoint(x: box.maxX, y: box.minY + tr * (1 - curve)))
            path.addLine(to: CGPoint(x: box.maxX, y: box.maxY - br))
            path.addCurve(to: CGPoint(x: box.maxX - br, y: box.maxY),
                          control1: CGPoint(x: box.maxX, y: box.maxY - br * (1 - curve)),
                          control2: CGPoint(x: box.maxX - br * (1 - curve), y: box.maxY))
            path.addLine(to: CGPoint(x: box.minX + bl, y: box.maxY))
            path.addCurve(to: CGPoint(x: box.minX, y: box.maxY - bl),
                          control1: CGPoint(x: box.minX + bl * (1 - curve), y: box.maxY),
                          control2: CGPoint(x: box.minX, y: box.maxY - bl * (1 - curve)))
            path.addLine(to: CGPoint(x: box.minX, y: box.minY + tl))
            path.addCurve(to: CGPoint(x: box.minX + tl, y: box.minY),
                          control1: CGPoint(x: box.minX, y: box.minY + tl * (1 - curve)),
                          control2: CGPoint(x: box.minX + tl * (1 - curve), y: box.minY))
            path.closeSubpath()
            return path
        }
        let radius = max(0, min(frame.width, frame.height) / 2 - inset)
        guard bottomLeft || bottomRight else {
            return CGPath(roundedRect: box, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
        let bottomY = min(box.height - 1, radius * 1.8)
        let leftBottom = bottomLeft ? bottomY : radius
        let rightBottom = bottomRight ? bottomY : radius
        let leftTop = min(radius, box.height - leftBottom)
        let rightTop = min(radius, box.height - rightBottom)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: box.minX + radius, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX - radius, y: box.minY))
        path.addQuadCurve(to: CGPoint(x: box.maxX, y: box.minY + rightTop),
                          control: CGPoint(x: box.maxX, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.maxY - rightBottom))
        path.addQuadCurve(to: CGPoint(x: box.maxX - radius, y: box.maxY),
                          control: CGPoint(x: box.maxX, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX + radius, y: box.maxY))
        path.addQuadCurve(to: CGPoint(x: box.minX, y: box.maxY - leftBottom),
                          control: CGPoint(x: box.minX, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX, y: box.minY + leftTop))
        path.addQuadCurve(to: CGPoint(x: box.minX + radius, y: box.minY),
                          control: CGPoint(x: box.minX, y: box.minY))
        path.closeSubpath()
        return path
    }

    public static func draw(in context: CGContext, frame: CGRect, group: CGRect,
                            selected: Bool, face: GamePlayButtonArt.Face? = nil,
                            monochrome: Bool = false,
                            bottomLeft: Bool = false, bottomRight: Bool = false,
                            screenEdges: Bool = false, topLeft: Bool = false, topRight: Bool = false, screenRadius: CGFloat? = nil, cornerRadii: GameControlCornerRadii? = nil) {
        let pixel = GameHUDControlGroup.border
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.clip(to: frame)
        let brightSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        let bright = CGColor(colorSpace: brightSpace, components: [1.6, 2.0, 1.4, 1])!
        context.setFillColor(monochrome ? CGColor(gray: 1, alpha: 1)
            : selected ? bright : CGColor(srgbRed: 0.56, green: 0.59, blue: 0.49, alpha: 1))
        context.addPath(path(in: group, bottomLeft: bottomLeft, bottomRight: bottomRight, screenEdges: screenEdges, topLeft: topLeft, topRight: topRight, screenRadius: screenRadius, cornerRadii: cornerRadii)); context.fillPath()
        context.addPath(path(in: group, inset: pixel, bottomLeft: bottomLeft, bottomRight: bottomRight, screenEdges: screenEdges, topLeft: topLeft, topRight: topRight, screenRadius: screenRadius, cornerRadii: cornerRadii)); context.clip()
        context.setFillColor(monochrome ? CGColor(gray: 0, alpha: 1)
            : CGColor(srgbRed: 0.09, green: 0.12, blue: 0.07, alpha: 1))
        context.fill(group)
        if !monochrome, let face {
            GamePlayButtonArt.drawFace(in: context, frame: frame.insetBy(dx: -3, dy: -3),
                selected: false, pixel: pixel, face: face)
        }
        if selected && !monochrome {
            context.setFillColor(CGColor(gray: 0, alpha: 0.42))
            context.fill(frame)
            context.setFillColor(CGColor(gray: 0, alpha: 0.45))
            context.fill(CGRect(x: frame.minX, y: frame.minY + pixel, width: frame.width, height: pixel))
            context.fill(CGRect(x: frame.minX + pixel, y: frame.minY, width: pixel, height: frame.height))
        }
        if selected && monochrome {
            context.setFillColor(monochrome ? CGColor(gray: 0, alpha: 1)
                : CGColor(srgbRed: 0.28, green: 0.50, blue: 0.10, alpha: 0.4))
            context.fill(frame)
            context.setFillColor(monochrome ? CGColor(gray: 1, alpha: 1)
                : CGColor(srgbRed: 0.68, green: 0.86, blue: 0.28, alpha: 1))
            context.fill(CGRect(x: frame.minX + 5, y: frame.maxY - 4,
                width: max(0, frame.width - 10), height: 2))
        }
        context.setFillColor(monochrome ? CGColor(gray: 1, alpha: 1)
            : selected ? bright : CGColor(srgbRed: 0.56, green: 0.59, blue: 0.49, alpha: 1))
        if frame.minX > group.minX + 0.01 {
            context.fill(CGRect(x: frame.minX, y: group.minY, width: pixel, height: group.height))
        }
        if frame.minY > group.minY + 0.01 {
            context.fill(CGRect(x: group.minX, y: frame.minY, width: group.width, height: pixel))
        }
    }
}

/// Shared count contrast and sprite feedback for selected skill controls.
public enum GameSkillSelectionArt {
    public static func drawSprite(_ image: CGImage, in frame: CGRect, selected: Bool, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.interpolationQuality = .none
        if selected {
            context.saveGState()
            context.setShadow(offset: .zero, blur: 5, color: CGColor(srgbRed: 0.28, green: 1, blue: 0.18, alpha: 0.9))
            GameStoneArt.drawImage(image, in: frame, context: context)
            context.restoreGState()
            context.saveGState()
            context.setShadow(offset: .zero, blur: 2, color: CGColor(gray: 1, alpha: 0.95))
            GameStoneArt.drawImage(image, in: frame, context: context)
            context.restoreGState()
        }
        GameStoneArt.drawImage(image, in: frame, context: context)
        if selected {
            context.setBlendMode(.plusLighter)
            context.setAlpha(0.45)
            GameStoneArt.drawImage(image, in: frame, context: context)
        }
    }
}
