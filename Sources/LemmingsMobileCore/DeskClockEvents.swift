import Foundation

/**
 * Calendar data needed to choose an event without exposing EventKit to the simulation.
 */
public struct DeskClockCandidate: Sendable {
    public var identifier: String
    public var start: Date
    public var title: String
    public var allDay: Bool
    public var declined: Bool

    public init(identifier: String, start: Date, title: String, allDay: Bool = false, declined: Bool = false) {
        self.identifier = identifier
        self.start = start
        self.title = title
        self.allDay = allDay
        self.declined = declined
    }
}

public enum DeskClockCalendarAccess: Sendable { case notDetermined, granted, denied }

@MainActor public protocol DeskClockEventSource {
    func authorization() -> DeskClockCalendarAccess
    func requestAccess() async -> Bool
    func nextEvent(now: Date) -> DeskClockEvent?
}

public enum DeskClockEvents {
    public static func next(from candidates: [DeskClockCandidate], now: Date) -> DeskClockEvent? {
        guard let event = candidates.filter({
            !$0.allDay && !$0.declined && $0.start > now.addingTimeInterval(-120)
                && $0.start <= now.addingTimeInterval(86_400)
        }).sorted(by: { $0.start == $1.start ? $0.identifier < $1.identifier : $0.start < $1.start }).first else { return nil }
        return DeskClockEvent(start: event.start, title: event.title,
            nuke: DeskClockFace.isNuke(identifier: event.identifier, start: event.start))
    }
}

/**
 * Whole-minute entries share one timeline on iOS and macOS.
 */
public enum DeskClockTimeline {
    public static func entryDates(from now: Date) -> [Date] {
        let minute = floor(now.timeIntervalSince1970 / 60) * 60
        return (0..<60).map { Date(timeIntervalSince1970: minute + Double($0 * 60)) }
    }
}

#if canImport(EventKit) && (os(iOS) || os(macOS))
import EventKit

@MainActor public final class EventKitDeskClockSource: DeskClockEventSource {
    private let store = EKEventStore()
    public init() {}

    public func authorization() -> DeskClockCalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: .notDetermined
        case .authorized: .granted
        default: .denied
        }
    }

    public func requestAccess() async -> Bool {
        guard authorization() == .notDetermined else { return authorization() == .granted }
        if #available(iOS 17, macOS 14, *) {
            return (try? await store.requestFullAccessToEvents()) == true
        }
        return (try? await store.requestAccess(to: .event)) == true
    }

    public func nextEvent(now: Date) -> DeskClockEvent? {
        DeskClockEvents.next(from: candidates(now: now), now: now)
    }

    public func candidates(now: Date) -> [DeskClockCandidate] {
        guard authorization() == .granted else { return [] }
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-120),
            end: now.addingTimeInterval(86_400), calendars: nil)
        return store.events(matching: predicate).map { event in
            DeskClockCandidate(identifier: event.eventIdentifier ?? "", start: event.startDate,
                title: event.title ?? "", allDay: event.isAllDay,
                declined: event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } == true)
        }
    }
}
#endif
