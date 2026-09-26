import Foundation

public enum MobileInterfaceOrientation: String, Codable, Sendable {
    case portrait
    case landscape
}

public struct MobileInterfaceLayout: Equatable, Sendable {
    public let orientation: MobileInterfaceOrientation
    public let safeFrame: MobileRect
    public let playfieldFrame: MobileRect
    public let statusFrame: MobileRect
    public let controlsFrame: MobileRect
    public let controlFrames: [MobileRect]

    public init(
        orientation: MobileInterfaceOrientation,
        safeFrame: MobileRect,
        playfieldFrame: MobileRect,
        statusFrame: MobileRect,
        controlsFrame: MobileRect,
        controlFrames: [MobileRect]
    ) {
        self.orientation = orientation
        self.safeFrame = safeFrame
        self.playfieldFrame = playfieldFrame
        self.statusFrame = statusFrame
        self.controlsFrame = controlsFrame
        self.controlFrames = controlFrames
    }
}

public enum MobileLayoutEngine {
    public static let minimumControlExtent = 44.0
    public static let controlGap = 2.0
    public static let statusHeight = 26.0

    /// Keeps the playfield and every input target inside the system safe area.
    public static func make(
        container: MobileSize,
        safeArea: MobileInsets,
        controlCount: Int
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
            controlFrames: frames
        )
    }
}
