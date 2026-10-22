import SwiftUI
import WidgetKit
import LemmingsMobileCore
import LemmingsGameArt
import NxlvKit

struct ClockEntry: TimelineEntry {
    let date: Date
    let event: DeskClockEvent?
}

struct ClockProvider: @preconcurrency TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { ClockEntry(date: .now, event: nil) }

    @MainActor func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        let now = Date()
        completion(ClockEntry(date: now, event: context.isPreview ? nil : EventKitDeskClockSource().nextEvent(now: now)))
    }

    @MainActor func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let now = Date()
        let source = EventKitDeskClockSource()
        let candidates = source.candidates(now: now)
        let dates = DeskClockTimeline.entryDates(from: now)
        let entries = dates.map { date in
            ClockEntry(date: date, event: DeskClockEvents.next(from: candidates, now: date))
        }
        completion(Timeline(entries: entries, policy: .after(dates.last!.addingTimeInterval(60))))
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
