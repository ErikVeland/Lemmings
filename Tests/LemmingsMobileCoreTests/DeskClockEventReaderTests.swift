import Foundation
import Testing
@testable import LemmingsMobileCore

private actor SuspendedClockQuery {
    private var result: CheckedContinuation<DeskClockEvent?, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func read() async -> DeskClockEvent? {
        await withCheckedContinuation {
            result = $0
            started?.resume()
            started = nil
        }
    }
    func waitUntilStarted() async {
        if result != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish(_ event: DeskClockEvent?) {
        result?.resume(returning: event)
        result = nil
    }
}

private final class ControlledClockEvents: DeskClockEventSource, @unchecked Sendable {
    let query = SuspendedClockQuery()
    private let lock = NSLock()
    private var access = DeskClockCalendarAccess.granted
    func authorization() -> DeskClockCalendarAccess { lock.withLock { access } }
    func revoke() { lock.withLock { access = .denied } }
    func requestAccess() async -> Bool { false }
    func nextEvent(now: Date) async -> DeskClockEvent? { await query.read() }
}

@MainActor struct DeskClockEventReaderTests {
    private let now = Date(timeIntervalSince1970: 1_792_000_000)
    private var event: DeskClockEvent { .init(start: now, title: "Private event", nuke: false) }

    @Test func deliversAnAuthorisedRead() async {
        let source = ControlledClockEvents()
        let reader = DeskClockEventReader(source: source)
        var received: DeskClockEvent?
        reader.refresh(now: now, enabled: true) { received = $0 }
        await source.query.waitUntilStarted()
        await source.query.finish(event)
        await reader.task?.value
        #expect(received == event)
    }

    @Test func disablingClearsTheEventAndDiscardsAnOlderRead() async {
        let source = ControlledClockEvents()
        let reader = DeskClockEventReader(source: source)
        var received: [DeskClockEvent?] = []
        reader.refresh(now: now, enabled: true) { received.append($0) }
        let old = reader.task
        await source.query.waitUntilStarted()
        reader.refresh(now: now, enabled: false) { received.append($0) }
        await source.query.finish(event)
        await old?.value
        #expect(received.count == 1 && received[0] == nil)
        #expect(reader.task == nil)
    }

    @Test func revocationDuringAReadDiscardsPrivateContent() async {
        let source = ControlledClockEvents()
        let reader = DeskClockEventReader(source: source)
        var received: [DeskClockEvent?] = []
        reader.refresh(now: now, enabled: true) { received.append($0) }
        await source.query.waitUntilStarted()
        source.revoke()
        await source.query.finish(event)
        await reader.task?.value
        #expect(received.count == 1 && received[0] == nil)
    }

    @Test func closingDiscardsAReadThatIgnoresCancellation() async {
        let source = ControlledClockEvents()
        let reader = DeskClockEventReader(source: source)
        var deliveries = 0
        reader.refresh(now: now, enabled: true) { _ in deliveries += 1 }
        let old = reader.task
        await source.query.waitUntilStarted()
        reader.cancel()
        await source.query.finish(event)
        await old?.value
        #expect(deliveries == 0)
    }

    @Test func deniedAccessClearsWithoutStartingAQuery() {
        let source = ControlledClockEvents()
        source.revoke()
        let reader = DeskClockEventReader(source: source)
        var received: [DeskClockEvent?] = []
        reader.refresh(now: now, enabled: true) { received.append($0) }
        #expect(received.count == 1 && received[0] == nil)
        #expect(reader.task == nil)
    }
}
