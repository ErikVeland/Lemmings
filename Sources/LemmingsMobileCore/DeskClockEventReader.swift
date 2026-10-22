import Foundation

/**
 * Discards calendar reads after cancellation, replacement or permission revocation.
 */
@MainActor public final class DeskClockEventReader {
    private let source: any DeskClockEventSource
    public private(set) var task: Task<Void, Never>?

    public init(source: any DeskClockEventSource) { self.source = source }

    public func cancel() {
        task?.cancel()
        task = nil
    }

    public func refresh(now: Date, enabled: Bool,
                        onChange: @escaping @MainActor (DeskClockEvent?) -> Void) {
        cancel()
        guard enabled, source.authorization() == .granted else {
            onChange(nil)
            return
        }
        let source = source
        task = Task {
            let next = await Task.detached { await source.nextEvent(now: now) }.value
            guard !Task.isCancelled else { return }
            onChange(source.authorization() == .granted ? next : nil)
        }
    }
}
