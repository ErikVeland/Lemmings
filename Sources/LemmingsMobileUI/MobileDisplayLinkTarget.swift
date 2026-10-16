#if os(iOS) || os(tvOS)
import UIKit

/// Display links retain their target. Callers capture their controller weakly.
@MainActor final class MobileDisplayLinkTarget: NSObject {
    let onFrame: (CADisplayLink) -> Void

    init(onFrame: @escaping (CADisplayLink) -> Void) {
        self.onFrame = onFrame
    }

    @objc func frame(_ link: CADisplayLink) { onFrame(link) }
}
#endif
