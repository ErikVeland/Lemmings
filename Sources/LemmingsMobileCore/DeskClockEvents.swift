import Foundation
#if canImport(EventKit) && (os(iOS) || os(macOS))
import EventKit
#endif

/// One calendar entry before the Desk Clock filters it.
public struct DeskClockCandidate: Sendable {
    public var identifier: String
    public var start: Date
    public var title: String
    public var allDay: Bool
    public var declined: Bool

    public init(identifier: String, start: Date, title: String, allDay: Bool, declined: Bool) {
        self.identifier = identifier
        self.start = start
        self.title = title
        self.allDay = allDay
        self.declined = declined
    }
}

public enum DeskClockCalendarAccess: Sendable {
    case notDetermined, granted, denied
}

/// Supplies the next event. Reading never asks for access; only `requestAccess()` does.
public protocol DeskClockEventSource: Sendable {
    func authorization() -> DeskClockCalendarAccess
    func requestAccess() async -> Bool
    func nextEvent(now: Date) async -> DeskClockEvent?
}

public enum DeskClockEvents {
    /// Events that started this long ago still count as the current event.
    static let lookBack: TimeInterval = 120
    static let lookAhead: TimeInterval = 24 * 60 * 60

    /// The earliest timed, accepted event from two minutes ago to 24 hours ahead.
    public static func next(from candidates: [DeskClockCandidate], now: Date) -> DeskClockEvent? {
        let earliest = now.addingTimeInterval(-lookBack)
        let latest = now.addingTimeInterval(lookAhead)
        let pick = candidates
            .filter { !$0.allDay && !$0.declined && $0.start >= earliest && $0.start <= latest }
            .min { $0.start < $1.start }
        guard let pick else { return nil }
        return DeskClockEvent(
            start: pick.start,
            title: pick.title,
            nuke: DeskClockFace.isNuke(identifier: pick.identifier, start: pick.start)
        )
    }
}

#if canImport(EventKit) && (os(iOS) || os(macOS))
/// Reads the calendar with EventKit. Every `nextEvent(now:)` runs a fresh predicate query, so a
/// `.EKEventStoreChanged` notification needs no observer: the next call already sees the change.
/// `EKEventStore` is not `Sendable`, but the store is a `let` and EventKit documents it as thread safe.
public final class EventKitDeskClockSource: DeskClockEventSource, @unchecked Sendable {
    private let store = EKEventStore()

    public init() {}

    public func authorization() -> DeskClockCalendarAccess {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined { return .notDetermined }
        if #available(iOS 17, macOS 14, *) {
            return status == .fullAccess ? .granted : .denied
        }
        return status == .authorized ? .granted : .denied
    }

    public func requestAccess() async -> Bool {
        if #available(iOS 17, macOS 14, *) {
            return (try? await store.requestFullAccessToEvents()) ?? false
        }
        return await withCheckedContinuation { continuation in
            store.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    public func nextEvent(now: Date) async -> DeskClockEvent? {
        guard authorization() == .granted else { return nil }
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-DeskClockEvents.lookBack),
            end: now.addingTimeInterval(DeskClockEvents.lookAhead),
            calendars: nil
        )
        let candidates = store.events(matching: predicate).map { event in
            DeskClockCandidate(
                identifier: event.eventIdentifier ?? event.title ?? "",
                start: event.startDate,
                title: event.title ?? "",
                allDay: event.isAllDay,
                declined: event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
            )
        }
        return DeskClockEvents.next(from: candidates, now: now)
    }
}
#endif
