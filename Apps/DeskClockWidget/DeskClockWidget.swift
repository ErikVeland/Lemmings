import SwiftUI
import WidgetKit
import LemmingsMobileCore
import LemmingsGameArt
import NxlvKit

struct ClockEntry: TimelineEntry {
    let date: Date
    let event: DeskClockEvent?
}

/// Carries a WidgetKit completion into the task that reads the calendar. WidgetKit accepts it on any thread.
private struct Reply<Value>: @unchecked Sendable {
    let send: (Value) -> Void
}

struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { ClockEntry(date: .now, event: nil) }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        let reply = Reply(send: completion), preview = context.isPreview
        Task.detached {
            let now = Date()
            let event = preview ? nil : await EventKitDeskClockSource().nextEvent(now: now)
            reply.send(ClockEntry(date: now, event: event))
        }
    }

    /// One entry per whole minute for an hour. The blocking EventKit reads run in a detached task.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let reply = Reply(send: completion)
        Task.detached {
            let source = EventKitDeskClockSource()
            let dates = DeskClockTimeline.entryDates(from: Date())
            let events = await DeskClockTimeline.events(for: dates) { await source.nextEvent(now: $0) }
            let entries = zip(dates, events).map { ClockEntry(date: $0, event: $1) }
            reply.send(Timeline(entries: entries, policy: .after(DeskClockTimeline.reloadDate(after: dates))))
        }
    }
}

struct ClockWidgetView: View {
    let entry: ClockEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        GeometryReader { geometry in
            if let image = render(size: geometry.size) {
                Image(decorative: image, scale: 1).resizable().interpolation(.none)
                    .accessibilityLabel(label)
            }
        }
        .privacySensitive()
        .widgetURL(URL(string: "ultimatelemmings://desk-clock"))
        .modifier(ClockBackground())
    }

    private var label: String {
        ([entry.date.formatted(date: .omitted, time: .shortened)]
            + (entry.event.map { [$0.title, DeskClockFace.countdown(to: $0.start, now: entry.date)] } ?? []))
            .joined(separator: ". ")
    }

    private func render(size: CGSize) -> CGImage? {
        let width = max(1, Int(size.width * 2)), height = max(1, Int(size.height * 2))
        guard let root = Bundle.main.resourceURL,
              let art = GameDeskClockArt(directory: root.appendingPathComponent("MacArtwork/lemmings")),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
        context.scaleBy(x: 2, y: 2)
        let bounds = CGRect(origin: .zero, size: size)
        #if os(iOS)
        if family == .accessoryRectangular,
           let type = GameMenuTypography(directory: root.appendingPathComponent("MacArtwork/lemmings")) {
            GameTextLayout.draw(entry.date.formatted(date: .omitted, time: .shortened),
                in: CGRect(x: 0, y: 0, width: size.width, height: size.height / 2), typography: type, palette: .green, context: context)
            if let event = entry.event {
                let title = GameTextLayout.truncated(event.title, width: size.width, font: type.font(.small), preservesCase: true)
                GameTextLayout.draw(title, in: CGRect(x: 0, y: size.height / 2, width: size.width, height: size.height / 2),
                    typography: type, preservesCase: true, context: context)
            }
        } else {
            art.drawWidget(.still(at: entry.date, event: entry.event, uses24Hour: DeskClockFace.uses24Hour(locale: .current)),
                event: entry.event, now: entry.date, in: context, rect: bounds, compact: family == .systemSmall)
        }
        #else
        art.drawWidget(.still(at: entry.date, event: entry.event, uses24Hour: DeskClockFace.uses24Hour(locale: .current)),
            event: entry.event, now: entry.date, in: context, rect: bounds, compact: family == .systemSmall)
        #endif
        return context.makeImage()
    }
}

struct ClockBackground: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 17, macOS 14, *) {
            content.containerBackground(.black, for: .widget)
        } else {
            content.background(.black)
        }
    }
}

@main struct DeskClockWidget: Widget {
    let kind = "DeskClock"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClockProvider()) { ClockWidgetView(entry: $0) }
            .configurationDisplayName(L10n.text("Desk Clock"))
            .description(L10n.text("Lemmings keep the time and watch for your next event."))
            .supportedFamilies(families)
    }
    private var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}
