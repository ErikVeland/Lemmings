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

/// The shared widget timeline for iOS and macOS: one entry per whole minute for an hour.
public enum DeskClockTimeline {
    public static let entryCount = 60

    /// Whole minutes from the current minute. UTC flooring is exact for whole-minute time zone offsets.
    public static func entryDates(from now: Date) -> [Date] {
        let minute = (now.timeIntervalSince1970 / 60).rounded(.down) * 60
        return (0..<entryCount).map { Date(timeIntervalSince1970: minute + Double($0 * 60)) }
    }

    /// WidgetKit reloads when the last entry's minute ends, one hour after the first entry.
    public static func reloadDate(after dates: [Date]) -> Date {
        (dates.last ?? Date()).addingTimeInterval(60)
    }

    /// The next event for each date. The source is asked again only when the current event leaves the
    /// two-minute start window, so an hour costs one read for each event that ends in it.
    public static func events(for dates: [Date], next: (Date) async -> DeskClockEvent?) async -> [DeskClockEvent?] {
        var events: [DeskClockEvent?] = []
        var current: DeskClockEvent?
        var read = false
        for date in dates {
            if !read || current.map({ $0.start < date.addingTimeInterval(-DeskClockEvents.lookBack) }) == true {
                current = await next(date)
                read = true
            }
            events.append(current)
        }
        return events
    }
}

#if canImport(EventKit) && (os(iOS) || os(macOS))
/// Reads the calendar with EventKit. Every `nextEvent(now:)` runs a fresh predicate query, so a
/// `.EKEventStoreChanged` notification needs no observer: the next call already sees the change.
/// `EKEventStore` is not `Sendable`, but the store is a `let` and EventKit documents it as thread safe.
public final class EventKitDeskClockSource: DeskClockEventSource, @unchecked Sendable {
    private let store = EKEventStore()

    public init() {}

    public func authorization() -> DeskClockCalendarAccess { Self.authorization() }

    /// The current access without creating an event store, for Settings.
    public static func authorization() -> DeskClockCalendarAccess {
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
