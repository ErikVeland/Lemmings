#if os(iOS) || os(tvOS)
import UIKit

extension UIControl.Event {
    static var gameActivation: UIControl.Event {
        #if os(tvOS)
        .primaryActionTriggered
        #else
        .touchUpInside
        #endif
    }
}

#if os(tvOS)
/// Focus decorates the exact bitmap target without stretching the shipped artwork.
@MainActor final class MobileFocusButton: UIButton {
    var onSelectBegan: (() -> Void)?
    var onHold: (() -> Void)?
    private var holdTask: Task<Void, Never>?
    private var trackingSelect = false
    private var heldSelect = false

    override func accessibilityActivate() -> Bool {
        guard isEnabled else { return false }
        onSelectBegan?()
        sendActions(for: .primaryActionTriggered)
        return true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if isEnabled, presses.contains(where: { $0.type == .select }) { onSelectBegan?() }
        guard onHold != nil, isEnabled, presses.contains(where: { $0.type == .select }) else {
            super.pressesBegan(presses, with: event); return
        }
        trackingSelect = true; heldSelect = false
        holdTask?.cancel()
        holdTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            guard let self, self.trackingSelect, self.isFocused, self.isEnabled else { return }
            self.heldSelect = true
            self.onHold?()
        }
        super.pressesBegan(presses.filter { $0.type != .select }, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard trackingSelect, presses.contains(where: { $0.type == .select }) else {
            super.pressesEnded(presses, with: event); return
        }
        holdTask?.cancel(); holdTask = nil; trackingSelect = false
        if !heldSelect, isFocused, isEnabled { sendActions(for: .primaryActionTriggered) }
        heldSelect = false
        super.pressesEnded(presses.filter { $0.type != .select }, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        holdTask?.cancel(); holdTask = nil; trackingSelect = false; heldSelect = false
        super.pressesCancelled(presses, with: event)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if !isFocused { holdTask?.cancel(); holdTask = nil; heldSelect = true }
        layer.borderWidth = isFocused ? 2 : 0
        layer.borderColor = UIColor.white.cgColor
        transform = .identity
    }
}
#else
typealias MobileFocusButton = UIButton
#endif
#endif
