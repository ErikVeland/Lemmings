import AppKit

/// Provides adjacent punctuation keys for precise and continuous timeline transport.
@MainActor final class TimelineKeyTransport {
  private enum Direction { case backward, forward }

  private var monitor: Any?
  private var held: Direction?
  private var continuous = false
  private var startTimer: Timer?

  private let canStartBackward: () -> Bool
  private let stepBackward: () -> Bool
  private let beginBackward: () -> Bool
  private let endBackward: () -> Void
  private let canStartForward: () -> Bool
  private let stepForward: () -> Bool
  private let beginForward: () -> Bool
  private let endForward: () -> Void

  init(
    window: NSWindow,
    canStartBackward: @escaping () -> Bool,
    stepBackward: @escaping () -> Bool,
    beginBackward: @escaping () -> Bool,
    endBackward: @escaping () -> Void,
    canStartForward: @escaping () -> Bool,
    stepForward: @escaping () -> Bool,
    beginForward: @escaping () -> Bool,
    endForward: @escaping () -> Void
  ) {
    self.canStartBackward = canStartBackward
    self.stepBackward = stepBackward
    self.beginBackward = beginBackward
    self.endBackward = endBackward
    self.canStartForward = canStartForward
    self.stepForward = stepForward
    self.beginForward = beginForward
    self.endForward = endForward
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
      guard let self, event.window === window,
            event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return event }
      let direction: Direction
      switch event.charactersIgnoringModifiers {
      case ",": direction = .backward
      case ".": direction = .forward
      default: return event
      }
      if event.type == .keyDown {
        guard !event.isARepeat else { return self.held == direction ? nil : event }
        guard self.held == nil else { return nil }
        let canStart = direction == .backward ? self.canStartBackward() : self.canStartForward()
        guard canStart else { return event }
        let stepped = direction == .backward ? self.stepBackward() : self.stepForward()
        guard stepped else { return nil }
        self.held = direction
        self.startTimer?.invalidate()
        self.startTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: false) { [weak self] _ in
          MainActor.assumeIsolated {
            guard let self, self.held == direction else { return }
            let started = direction == .backward ? self.beginBackward() : self.beginForward()
            self.continuous = started
          }
        }
        return nil
      }
      guard self.held == direction else { return event }
      self.startTimer?.invalidate()
      self.startTimer = nil
      if self.continuous {
        if direction == .backward { self.endBackward() } else { self.endForward() }
      }
      self.continuous = false
      self.held = nil
      return nil
    }
  }

  isolated deinit {
    startTimer?.invalidate()
    if let monitor { NSEvent.removeMonitor(monitor) }
  }
}
