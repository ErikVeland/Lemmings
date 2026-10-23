import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

struct DeskClockArtTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let artwork = root.appendingPathComponent(".build/mac-artwork/export/lemmings")
    private static let hasArtwork = FileManager.default.fileExists(atPath: artwork.appendingPathComponent("manifest.json").path)
    private static let renders = root.appendingPathComponent(".build/desk-clock/renders")
    private static let width = 832, height = 596

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }

    @Test(.enabled(if: hasArtwork, "The Macintosh artwork export is absent; run the Mac artwork export first."))
    func loadsShippedArtwork() {
        #expect(GameDeskClockArt(directory: Self.artwork) != nil)
    }

    @Test(.enabled(if: hasArtwork, "The Macintosh artwork export is absent; run the Mac artwork export first."))
    func loadsPrunedArtwork() throws {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: destination) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", Self.root.appendingPathComponent("Tools/DeskClock/prune_artwork.py").path,
                             "--source", Self.artwork.path, "--destination", destination.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(GameDeskClockArt(directory: destination) != nil)
        let pruned = try Self.size(of: destination), source = try Self.size(of: Self.artwork)
        #expect(pruned * 10 < source)
        #expect(pruned < 2_000_000)
        // Every frame the app scene and the widgets can request survives, in both directions and at every tick.
        let frames = try ClassicMacArtwork(directory: destination)
        for pose in [ClassicLemmingPose.walking, .falling, .digging, .building, .blocking, .umbrellaOpening,
                     .floating, .exiting, .ohNo, .explosion] {
            for left in [false, true] {
                for tick in 0..<32 { #expect(frames.lemming(pose: pose, left: left, tick: tick) != nil, "\(pose) \(tick)") }
            }
        }
        for index in [3, 9, 10, 36, 37, 38, 39] { #expect(frames.frame(1500, index) != nil) }
        for index in 0...16 { #expect(frames.frame(1600, index) != nil) }
    }

    @Test(.enabled(if: hasArtwork, "The Macintosh artwork export is absent; run the Mac artwork export first."))
    func rendersWidgets() throws {
        let art = try #require(GameDeskClockArt(directory: Self.artwork))
        let now = Date(timeIntervalSince1970: 1_792_150_200)
        let event = DeskClockEvent(start: now.addingTimeInterval(300), title: "Design review with everyone", nuke: false)
        for (family, size, compact) in [
            ("small", CGSize(width: 158, height: 158), true),
            ("medium", CGSize(width: 338, height: 158), false),
            ("large", CGSize(width: 338, height: 354), false),
            ("mac-small", CGSize(width: 164, height: 164), true),
            ("mac-medium", CGSize(width: 344, height: 164), false),
            ("mac-large", CGSize(width: 344, height: 344), false)
        ] {
            for (state, candidate) in [
                ("calm", Optional<DeskClockEvent>.none), ("soon", event),
                ("start", DeskClockEvent(start: now, title: "Design review with everyone", nuke: false)),
                ("nuke", DeskClockEvent(start: now, title: "Design review with everyone", nuke: true))
            ] {
                let sim = DeskClockSimulation.still(at: now, event: candidate, uses24Hour: true, calendar: Self.calendar)
                let pixels = try Self.renderWidget(art, sim, event: candidate, now: now, size: size, compact: compact,
                    name: "widget-\(family)-\(state)")
                let width = Int(size.width) * 2, height = Int(size.height) * 2
                // The scene covers the whole rectangular canvas before the system rounds its corners.
                #expect(stride(from: 3, to: pixels.count, by: 4).allSatisfy { pixels[$0] == 255 })
                for x in [0, 1, width - 2, width - 1] {
                    #expect(Self.isLit(pixels, width: width, x: x, y: height - 2))
                }
                // Terrain digits occupy most of the width, instead of a centred scene with side gutters.
                var left = width, right = 0
                for y in 0..<(height * 2 / 3) {
                    for x in 0..<width {
                        let offset = (y * width + x) * 4
                        let red = Int(pixels[offset]), green = Int(pixels[offset + 1]), blue = Int(pixels[offset + 2])
                        if red > 80, red > green * 3 / 2, green > blue {
                            left = min(left, x)
                            right = max(right, x)
                        }
                    }
                }
                #expect(right - left > width * 2 / 3)
            }
        }
    }

    @Test(.enabled(if: hasArtwork, "The Macintosh artwork export is absent; run the Mac artwork export first."))
    func rendersExitTop() throws {
        let art = try #require(GameDeskClockArt(directory: Self.artwork))
        let now = Date(timeIntervalSince1970: 1_792_150_230)
        let event = DeskClockEvent(start: now.addingTimeInterval(3 * 3600), title: "Design review", nuke: false)
        let sim = DeskClockSimulation.still(at: now, event: event, uses24Hour: true, calendar: Self.calendar)
        let pixels = try Self.render(art, sim, event: event, now: now, name: "calm")
        // The arch's top edge is classic row 111, canvas row 444. The torches stand on its brackets.
        var lit = 0
        for y in (444 - 24)...(444 - 2) {
            for x in (170 * 4)..<(200 * 4) where Self.isLit(pixels, x: x, y: y) { lit += 1 }
        }
        #expect(lit > 100)
    }

    @Test(.enabled(if: hasArtwork, "The Macintosh artwork export is absent; run the Mac artwork export first."))
    func rendersWithoutEvent() throws {
        let art = try #require(GameDeskClockArt(directory: Self.artwork))
        let now = Date(timeIntervalSince1970: 1_792_150_230)
        let sim = DeskClockSimulation.still(at: now, event: nil, uses24Hour: true, calendar: Self.calendar)
        let empty = try Self.render(art, sim, event: nil, now: now, name: "no-event")
        let event = DeskClockEvent(start: now.addingTimeInterval(300), title: "Stand-up", nuke: false)
        let soon = DeskClockSimulation.still(at: now, event: event, uses24Hour: true, calendar: Self.calendar)
        let shown = try Self.render(art, soon, event: event, now: now, name: "soon")
        // Stars may twinkle behind the text rows: at most 40 dots of 2 x 2 canvas pixels.
        #expect(Self.litCount(empty, rows: 296...400) <= 160)
        #expect(Self.litCount(shown, rows: 296...400) > 1000)
        // The fourth render: a nuke in its start minute, with the first walker saying "Oh no!".
        let nuke = DeskClockEvent(start: now.addingTimeInterval(-30), title: "Quarterly planning with the whole team", nuke: true)
        let start = DeskClockSimulation.still(at: now, event: nuke, uses24Hour: true, calendar: Self.calendar)
        _ = try Self.render(art, start, event: nuke, now: now, name: "start-nuke", nightDim: false)
        _ = try Self.render(art, sim, event: nil, now: now, name: "night", nightDim: true)
    }

    @Test func hatchOpensThroughEveryFrame() {
        #expect(GameDeskClockArt.hatchFrame(age: -1) == 1)
        #expect(GameDeskClockArt.hatchFrame(age: 0.05) == 1)
        #expect((0..<9).map { GameDeskClockArt.hatchFrame(age: Double($0) / 10 + 0.05) } == Array(1...9))
        #expect(GameDeskClockArt.hatchFrame(age: 0.85) == 9)
        #expect(GameDeskClockArt.hatchFrame(age: 0.95) == 0)
        #expect(GameDeskClockArt.hatchFrame(age: 1.0) == 0)
        #expect(GameDeskClockArt.hatchFrame(age: 60) == 0)
    }

    // MARK: - Helpers

    private static func render(_ art: GameDeskClockArt, _ sim: DeskClockSimulation, event: DeskClockEvent?,
                               now: Date, name: String, nightDim: Bool = false) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let image: CGImage = try pixels.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            art.draw(sim, event: event, now: now, time: 0.25, in: context,
                     rect: CGRect(x: 0, y: 0, width: width, height: height), nightDim: nightDim)
            return try #require(context.makeImage())
        }
        try FileManager.default.createDirectory(at: renders, withIntermediateDirectories: true)
        let destination = try #require(CGImageDestinationCreateWithURL(
            renders.appendingPathComponent(name + ".png") as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return pixels
    }

    private static func isLit(_ pixels: [UInt8], x: Int, y: Int) -> Bool {
        let offset = (y * width + x) * 4
        return pixels[offset + 3] > 0 && Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2]) > 0
    }

    private static func litCount(_ pixels: [UInt8], rows: ClosedRange<Int>) -> Int {
        var count = 0
        for y in rows { for x in 0..<width where isLit(pixels, x: x, y: y) { count += 1 } }
        return count
    }

    private static func renderWidget(_ art: GameDeskClockArt, _ sim: DeskClockSimulation, event: DeskClockEvent?,
                                     now: Date, size: CGSize, compact: Bool, name: String) throws -> [UInt8] {
        let width = Int(size.width) * 2, height = Int(size.height) * 2
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let image: CGImage = try pixels.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            // The widget's own transform: flipped, two pixels per point.
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 2, y: -2)
            art.drawWidget(sim, event: event, now: now, in: context, rect: CGRect(origin: .zero, size: size), compact: compact)
            return try #require(context.makeImage())
        }
        try FileManager.default.createDirectory(at: renders, withIntermediateDirectories: true)
        let destination = try #require(CGImageDestinationCreateWithURL(
            renders.appendingPathComponent(name + ".png") as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return pixels
    }

    private static func isLit(_ pixels: [UInt8], width: Int, x: Int, y: Int) -> Bool {
        let offset = (y * width + x) * 4
        return pixels[offset + 3] > 0 && Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2]) > 0
    }

    private static func size(of directory: URL) throws -> Int {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
            .reduce(0) { $0 + (try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
    }
}
