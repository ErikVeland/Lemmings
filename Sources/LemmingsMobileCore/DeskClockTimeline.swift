import Foundation

/**
 * Supplies one widget entry per whole minute for the next hour.
 */
public enum DeskClockTimeline {
    public static func entryDates(from now: Date) -> [Date] {
        let minute = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970 / 60) * 60)
        return (0..<60).map { minute.addingTimeInterval(TimeInterval($0 * 60)) }
    }
}
