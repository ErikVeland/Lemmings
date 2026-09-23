import AppKit

/// Captures a held full-stop only while a sequel has a rewind branch to scrub.
@MainActor final class RewindForwardKeyTransport {
  private var monitor: Any?
  private var held = false

  init(
    window: NSWindow,
    canStart: @escaping () -> Bool,
    begin: @escaping () -> Bool,
    end: @escaping () -> Void
  ) {
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
      guard let self, event.window === window,
            event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
            event.charactersIgnoringModifiers == "." else { return event }
      if event.type == .keyDown, !event.isARepeat, !self.held, canStart(), begin() {
        self.held = true
        return nil
      }
      if event.type == .keyUp, self.held {
        self.held = false
        end()
        return nil
      }
      return event
    }
  }

  isolated deinit {
    if let monitor { NSEvent.removeMonitor(monitor) }
  }
}
