import AppKit
import NxlvKit

extension PrecisionZoomLens {
    func applyToCurrentGraphicsContext() {
        guard active else { return }
        var elements = NSAffineTransformStruct()
        elements.m11 = 2; elements.m22 = 2
        elements.tX = -anchor.x; elements.tY = -anchor.y
        let transform = NSAffineTransform()
        transform.transformStruct = elements
        transform.concat()
    }
}
