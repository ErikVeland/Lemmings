import Foundation

public struct MobileViewport: Codable, Equatable, Sendable {
    public var levelSize: MobileSize
    public var viewSize: MobileSize
    public var origin: MobilePoint
    public var zoom: Double
    public var pixelAspect: Double
    public var maximumZoom: Double

    public init(
        levelSize: MobileSize,
        viewSize: MobileSize,
        origin: MobilePoint = MobilePoint(x: 0, y: 0),
        zoom: Double? = nil,
        pixelAspect: Double = 1,
        maximumZoom: Double = 12
    ) {
        self.levelSize = MobileSize(width: max(1, levelSize.width), height: max(1, levelSize.height))
        self.viewSize = MobileSize(width: max(1, viewSize.width), height: max(1, viewSize.height))
        self.origin = origin
        self.pixelAspect = max(0.1, pixelAspect.mobileFiniteOrZero)
        self.maximumZoom = max(1, maximumZoom.mobileFiniteOrZero)
        self.zoom = zoom ?? 1
        if zoom == nil { self.zoom = fittedGameplayZoom }
        clamp()
    }

    public var minimumZoom: Double {
        max(0.1, min(
            viewSize.width / (levelSize.width * pixelAspect),
            viewSize.height / levelSize.height
        ))
    }

    public var visibleLevelSize: MobileSize {
        MobileSize(
            width: viewSize.width / max(0.1, zoom * pixelAspect),
            height: viewSize.height / max(0.1, zoom)
        )
    }

    public var visibleLevelRect: MobileRect {
        MobileRect(
            x: origin.x,
            y: origin.y,
            width: min(levelSize.width, visibleLevelSize.width),
            height: min(levelSize.height, visibleLevelSize.height)
        )
    }

    public var contentFrame: MobileRect {
        let size = MobileSize(
            width: min(viewSize.width, levelSize.width * zoom * pixelAspect),
            height: min(viewSize.height, levelSize.height * zoom)
        )
        return MobileRect(
            x: (viewSize.width - size.width) / 2,
            y: (viewSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    public mutating func resize(_ size: MobileSize) {
        let centre = MobilePoint(
            x: origin.x + visibleLevelSize.width / 2,
            y: origin.y + visibleLevelSize.height / 2
        )
        viewSize = MobileSize(width: max(1, size.width), height: max(1, size.height))
        origin = MobilePoint(
            x: centre.x - visibleLevelSize.width / 2,
            y: centre.y - visibleLevelSize.height / 2
        )
        clamp()
    }

    /// Fits the original gameplay window when a view receives its first size.
    public mutating func fitGameplay(in size: MobileSize) {
        viewSize = MobileSize(width: max(1, size.width), height: max(1, size.height))
        zoom = fittedGameplayZoom
        clamp()
    }

    /// Moves the level with the finger. The camera moves in the opposite direction.
    public mutating func pan(viewDelta: MobilePoint) {
        origin.x -= viewDelta.x / max(0.1, zoom * pixelAspect)
        origin.y -= viewDelta.y / max(0.1, zoom)
        clamp()
    }

    /// Changes scale without moving the level pixel below the gesture anchor.
    public mutating func magnify(by factor: Double, around anchor: MobilePoint) {
        guard factor.isFinite, factor > 0 else { return }
        let levelAnchor = levelPoint(fromView: anchor)
        zoom = min(maximumZoom, max(minimumZoom, zoom * factor))
        let frame = contentFrame
        origin = MobilePoint(
            x: levelAnchor.x - (anchor.x - frame.minX) / (zoom * pixelAspect),
            y: levelAnchor.y - (anchor.y - frame.minY) / zoom
        )
        clamp()
    }

    public func levelPoint(fromView point: MobilePoint) -> MobilePoint {
        let frame = contentFrame
        return MobilePoint(
            x: origin.x + (point.x - frame.minX) / (zoom * pixelAspect),
            y: origin.y + (point.y - frame.minY) / zoom
        )
    }

    public func viewPoint(fromLevel point: MobilePoint) -> MobilePoint {
        let frame = contentFrame
        return MobilePoint(
            x: frame.minX + (point.x - origin.x) * zoom * pixelAspect,
            y: frame.minY + (point.y - origin.y) * zoom
        )
    }

    public mutating func clamp() {
        zoom = min(maximumZoom, max(minimumZoom, zoom.mobileFiniteOrZero))
        let visible = visibleLevelSize
        origin.x = min(max(0, origin.x.mobileFiniteOrZero), max(0, levelSize.width - visible.width))
        origin.y = min(max(0, origin.y.mobileFiniteOrZero), max(0, levelSize.height - visible.height))
    }

    private var fittedGameplayZoom: Double {
        let fitHeight = viewSize.height / levelSize.height
        let gameplayWidth = min(320, levelSize.width)
        let fitGameplayWidth = viewSize.width / (gameplayWidth * pixelAspect)
        return max(1, min(maximumZoom, min(fitHeight, fitGameplayWidth)))
    }
}
