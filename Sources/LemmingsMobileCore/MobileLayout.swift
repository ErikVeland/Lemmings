import Foundation

public enum MobileInterfaceOrientation: String, Codable, Sendable {
    case portrait
    case landscape
}

public enum MobileLayoutDirection: Equatable, Sendable {
    case leftToRight
    case rightToLeft
}

public enum MobileControlsPlacement: Equatable, Sendable {
    case bottom
    case trailingRail
}

public struct MobileInterfaceLayout: Equatable, Sendable {
    public let orientation: MobileInterfaceOrientation
    public let safeFrame: MobileRect
    public let playfieldFrame: MobileRect
    public let statusFrame: MobileRect
    public let controlsFrame: MobileRect
    public let controlFrames: [MobileRect]
    public let controlsPlacement: MobileControlsPlacement

    public init(
        orientation: MobileInterfaceOrientation,
        safeFrame: MobileRect,
        playfieldFrame: MobileRect,
        statusFrame: MobileRect,
        controlsFrame: MobileRect,
        controlFrames: [MobileRect],
        controlsPlacement: MobileControlsPlacement = .bottom
    ) {
        self.orientation = orientation
        self.safeFrame = safeFrame
        self.playfieldFrame = playfieldFrame
        self.statusFrame = statusFrame
        self.controlsFrame = controlsFrame
        self.controlFrames = controlFrames
        self.controlsPlacement = controlsPlacement
    }
}

public enum MobileLayoutEngine {
    public static let minimumControlExtent = 44.0
    public static let controlGap = 2.0
    public static let statusHeight = 26.0
    public static let edgeRailAspectThreshold = 0.62

    /// Keeps the playfield and every input target inside the system safe area.
    public static func make(
        container: MobileSize,
        safeArea: MobileInsets,
        controlCount: Int,
        direction: MobileLayoutDirection = .leftToRight
    ) -> MobileInterfaceLayout {
        let bounds = MobileRect(
            x: 0,
            y: 0,
            width: max(0, container.width.mobileFiniteOrZero),
            height: max(0, container.height.mobileFiniteOrZero)
        )
        let safe = bounds.inset(by: MobileInsets(
            top: max(0, safeArea.top.mobileFiniteOrZero),
            left: max(0, safeArea.left.mobileFiniteOrZero),
            bottom: max(0, safeArea.bottom.mobileFiniteOrZero),
            right: max(0, safeArea.right.mobileFiniteOrZero)
        ))
        let orientation: MobileInterfaceOrientation = safe.width > safe.height ? .landscape : .portrait
        let count = max(0, controlCount)

        if count > 0,
           safe.width / max(1, safe.height) >= edgeRailAspectThreshold,
           let railLayout = makeTrailingRail(
            safe: safe,
            orientation: orientation,
            controlCount: count,
            direction: direction
           ) {
            return railLayout
        }

        let idealColumns = max(1, Int((safe.width + controlGap) / (minimumControlExtent + controlGap)))
        let columns = min(max(1, count), idealColumns)
        let rows = count == 0 ? 0 : Int(ceil(Double(count) / Double(columns)))
        let controlsHeight = rows == 0 ? 0 : Double(rows) * minimumControlExtent + Double(rows - 1) * controlGap
        let statusHeight = min(Self.statusHeight, max(0, safe.height - controlsHeight))
        let controls = MobileRect(
            x: safe.minX,
            y: safe.maxY - controlsHeight,
            width: safe.width,
            height: controlsHeight
        )
        let status = MobileRect(
            x: safe.minX,
            y: controls.minY - statusHeight,
            width: safe.width,
            height: statusHeight
        )
        let playfield = MobileRect(
            x: safe.minX,
            y: safe.minY,
            width: safe.width,
            height: max(0, status.minY - safe.minY)
        )

        let cellWidth = columns > 0
            ? (controls.width - Double(columns - 1) * controlGap) / Double(columns)
            : 0
        var frames: [MobileRect] = []
        frames.reserveCapacity(count)
        for index in 0..<count {
            let row = index / columns
            let column = index % columns
            let originX = controls.minX + Double(column) * (cellWidth + controlGap)
            frames.append(MobileRect(
                x: originX,
                y: controls.minY + Double(row) * (minimumControlExtent + controlGap),
                width: column == columns - 1 ? max(0, controls.maxX - originX) : cellWidth,
                height: minimumControlExtent
            ))
        }

        return MobileInterfaceLayout(
            orientation: orientation,
            safeFrame: safe,
            playfieldFrame: playfield,
            statusFrame: status,
            controlsFrame: controls,
            controlFrames: frames,
            controlsPlacement: .bottom
        )
    }

    private static func makeTrailingRail(
        safe: MobileRect,
        orientation: MobileInterfaceOrientation,
        controlCount: Int,
        direction: MobileLayoutDirection
    ) -> MobileInterfaceLayout? {
        let rowCapacity = max(1, Int((safe.height + controlGap) / (minimumControlExtent + controlGap)))
        let columns = Int(ceil(Double(controlCount) / Double(rowCapacity)))
        let railWidth = Double(columns) * minimumControlExtent + Double(columns - 1) * controlGap
        let playfieldWidth = safe.width - railWidth
        guard playfieldWidth >= max(160, safe.width * 0.48) else { return nil }

        let railIsLeading = direction == .rightToLeft
        let railX = railIsLeading ? safe.minX : safe.maxX - railWidth
        let playfieldX = railIsLeading ? safe.minX + railWidth : safe.minX
        let statusHeight = min(statusHeight, safe.height)
        let contentWidth = max(0, playfieldWidth)
        let status = MobileRect(
            x: playfieldX,
            y: safe.minY,
            width: contentWidth,
            height: statusHeight
        )
        let playfield = MobileRect(
            x: playfieldX,
            y: status.maxY,
            width: contentWidth,
            height: max(0, safe.maxY - status.maxY)
        )
        let controls = MobileRect(x: railX, y: safe.minY, width: railWidth, height: safe.height)
        let rows = Int(ceil(Double(controlCount) / Double(columns)))
        let controlsHeight = Double(rows) * minimumControlExtent + Double(rows - 1) * controlGap
        let controlsY = safe.minY + (safe.height - controlsHeight) / 2
        var frames: [MobileRect] = []
        frames.reserveCapacity(controlCount)

        for index in 0..<controlCount {
            let column = index / rows
            let row = index % rows
            let x: Double
            if railIsLeading {
                x = controls.minX + Double(column) * (minimumControlExtent + controlGap)
            } else {
                x = controls.maxX - Double(column + 1) * minimumControlExtent
                    - Double(column) * controlGap
            }
            frames.append(MobileRect(
                x: x,
                y: controlsY + Double(row) * (minimumControlExtent + controlGap),
                width: minimumControlExtent,
                height: minimumControlExtent
            ))
        }

        return MobileInterfaceLayout(
            orientation: orientation,
            safeFrame: safe,
            playfieldFrame: playfield,
            statusFrame: status,
            controlsFrame: controls,
            controlFrames: frames,
            controlsPlacement: .trailingRail
        )
    }
}
