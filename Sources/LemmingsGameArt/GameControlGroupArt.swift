import CoreGraphics
import LemmingsMobileCore

/// One pixel outline, rounded ends and a single divider per joined control.
public enum GameControlGroupArt {
    public static func path(in frame: CGRect, inset: CGFloat = 0,
                            bottomLeft: Bool = false, bottomRight: Bool = false) -> CGPath {
        let box = frame.insetBy(dx: inset, dy: inset)
        guard box.width > 0, box.height > 0 else { return CGMutablePath() }
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
                            bottomLeft: Bool = false, bottomRight: Bool = false) {
        let pixel = GameHUDControlGroup.border
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.clip(to: frame)
        let skillSelected: Bool
        if case .skill = face { skillSelected = selected } else { skillSelected = false }
        let brightSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        let bright = CGColor(colorSpace: brightSpace, components: [1.6, 2.0, 1.4, 1])!
        context.setFillColor(monochrome ? CGColor(gray: 1, alpha: 1)
            : skillSelected ? bright : CGColor(srgbRed: 0.56, green: 0.59, blue: 0.49, alpha: 1))
        context.addPath(path(in: group, bottomLeft: bottomLeft, bottomRight: bottomRight)); context.fillPath()
        context.addPath(path(in: group, inset: pixel, bottomLeft: bottomLeft, bottomRight: bottomRight)); context.clip()
        context.setFillColor(monochrome ? CGColor(gray: 0, alpha: 1)
            : CGColor(srgbRed: 0.09, green: 0.12, blue: 0.07, alpha: 1))
        context.fill(group)
        if !monochrome, let face {
            GamePlayButtonArt.drawFace(in: context, frame: frame.insetBy(dx: -3, dy: -3),
                selected: selected && !skillSelected, pixel: pixel, face: face)
        }
        if skillSelected && !monochrome {
            context.setFillColor(CGColor(gray: 0, alpha: 0.42))
            context.fill(frame)
            context.setFillColor(CGColor(gray: 0, alpha: 0.45))
            context.fill(CGRect(x: frame.minX, y: frame.minY + pixel, width: frame.width, height: pixel))
            context.fill(CGRect(x: frame.minX + pixel, y: frame.minY, width: pixel, height: frame.height))
        }
        if selected && !skillSelected {
            context.setFillColor(monochrome ? CGColor(gray: 0, alpha: 1)
                : CGColor(srgbRed: 0.28, green: 0.50, blue: 0.10, alpha: 0.4))
            context.fill(frame)
            context.setFillColor(monochrome ? CGColor(gray: 1, alpha: 1)
                : CGColor(srgbRed: 0.68, green: 0.86, blue: 0.28, alpha: 1))
            context.fill(CGRect(x: frame.minX + 5, y: frame.maxY - 4,
                width: max(0, frame.width - 10), height: 2))
        }
        context.setFillColor(monochrome ? CGColor(gray: 1, alpha: 1)
            : skillSelected ? bright : CGColor(srgbRed: 0.56, green: 0.59, blue: 0.49, alpha: 1))
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
