#if os(macOS)
import AppKit
#if canImport(LemmingsAudio)
import LemmingsAudio
// Preserve the Mac module's names while the implementation is shared with iPad.
typealias FailureMoodDecision = LemmingsAudio.FailureMoodDecision
typealias FailureMoodTransition = LemmingsAudio.FailureMoodTransition
typealias FailureMusicTransition = LemmingsAudio.FailureMusicTransition
typealias NukeMusicSweep = LemmingsAudio.NukeMusicSweep
#endif

@MainActor enum FailureMoodOverlay {
  static func draw(in rect: CGRect, amount: CGFloat) {
    guard amount > 0 else { return }
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.saveGState()
    context.setBlendMode(.color)
    context.setFillColor(NSColor(calibratedWhite: 0.28, alpha: 0.72 * amount).cgColor)
    context.fill(rect)
    context.setBlendMode(.normal)
    context.setFillColor(NSColor.black.withAlphaComponent(0.26 * amount).cgColor)
    context.fill(rect)
    context.restoreGState()
  }
}

#endif
