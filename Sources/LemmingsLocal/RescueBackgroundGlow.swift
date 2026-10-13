#if os(macOS)
import AppKit
import LemmingsGameArt

extension RescueBackgroundGlow {
    func draw(_ image: NSImage, in rect: CGRect, amount: CGFloat, slot: String? = nil) {
        guard amount > 0, let context = NSGraphicsContext.current?.cgContext,
              let pixels = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        draw(pixels, in: rect, amount: amount, context: context, slot: slot)
    }

}
#endif
