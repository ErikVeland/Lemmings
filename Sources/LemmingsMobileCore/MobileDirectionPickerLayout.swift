import Foundation
import NxlvKit

/** Places the native 3-by-3 Lemmings 3 direction pad inside the playfield. */
public enum MobileDirectionPickerLayout {
    public static let cellExtent = 44.0

    /** Directions in row-major order, with the centre reserved for cancel. */
    public static let gridDirections: [Lemmings3Runtime.Direction?] = [
        .upLeft, .up, .upRight,
        .left, nil, .right,
        .downLeft, .down, .downRight
    ]

    /** Returns the matching frame in the native Chronicles arrow bank. */
    public static func frameIndex(for direction: Lemmings3Runtime.Direction) -> Int {
        switch direction {
        case .up: 0
        case .upRight: 1
        case .right: 2
        case .downRight: 3
        case .down: 4
        case .downLeft: 5
        case .left: 6
        case .upLeft: 7
        }
    }

    public static func frame(centredAt point: MobilePoint, within bounds: MobileRect) -> MobileRect? {
        let extent = cellExtent * 3
        guard point.x.isFinite, point.y.isFinite,
              bounds.x.isFinite, bounds.y.isFinite,
              bounds.width.isFinite, bounds.height.isFinite,
              bounds.width >= extent, bounds.height >= extent else { return nil }
        return MobileRect(
            x: min(max(bounds.minX, point.x - extent / 2), bounds.maxX - extent),
            y: min(max(bounds.minY, point.y - extent / 2), bounds.maxY - extent),
            width: extent,
            height: extent
        )
    }
}
