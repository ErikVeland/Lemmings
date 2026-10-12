#if os(macOS)
import AppKit
@_exported import LemmingsGameArt

extension LemmingSelectionRenderer {
    static func draw(_ effect: LemmingSelectionEffect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        draw(effect, in: context)
    }
}
#endif
