import CoreGraphics
import CryptoKit
import Foundation
import LemmingsGameArt
import LemmingsMobileCore

/**
 * Checks the widget boundary with isolated storage and the native clock renderer.
 */
@main struct DeskClockResourceTests {
    private struct Failure: Error, CustomStringConvertible { let description: String }
    private static func check(_ value: Bool, _ message: String) throws {
        if !value { throw Failure(description: message) }
    }

    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 4 else { throw Failure(description: "Supply the owned resource root, clean bundle root and isolated test folder.") }
        let source = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let bundled = URL(fileURLWithPath: arguments[2], isDirectory: true)
        let folder = URL(fileURLWithPath: arguments[3], isDirectory: true).standardizedFileURL
        let build = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/").path
        try check(folder.path.hasPrefix(build), "Test storage must be inside the checkout's .build folder.")
        let group = folder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        let originalDirectory = source.appendingPathComponent("MacArtwork/lemmings", isDirectory: true)
        let fallbackDirectory = bundled.appendingPathComponent("MacArtwork/lemmings", isDirectory: true)
        try check(GameDeskClockResources.artworkDirectory(containerURL: group, bundledResourceURL: bundled) == fallbackDirectory,
                  "A clean widget must use its licensed bundle.")
        try check(try !GameDeskClockResources.publish(resourceURL: source, containerURL: nil), "A missing group must be a no-op.")
        try check(try GameDeskClockResources.publish(resourceURL: source, containerURL: group), "The first owned selection must publish.")
        let published = GameDeskClockResources.artworkDirectory(containerURL: group, bundledResourceURL: bundled)!
        try check(published.path.hasPrefix(group.path + "/Library/Application Support/UltimateLemmix/"), "Owned art must stay in its namespaced group folder.")
        try check(published != originalDirectory, "The extension must use an independent shared copy.")
        try check(try !GameDeskClockResources.publish(resourceURL: source, containerURL: group), "An unchanged selection must avoid another copy.")
        let sourceFiles = try FileManager.default.contentsOfDirectory(atPath: originalDirectory.path).sorted()
        let sharedFiles = try FileManager.default.contentsOfDirectory(atPath: published.path).sorted()
        try check(sourceFiles == sharedFiles, "The widget copy must keep every Mac art file, including fonts.")
        var copiedBytes = 0
        for file in sourceFiles {
            let original = try Data(contentsOf: originalDirectory.appendingPathComponent(file))
            let shared = try Data(contentsOf: published.appendingPathComponent(file))
            try check(original == shared, "The shared file differs: " + file)
            copiedBytes += shared.count
        }
        let snapshots = published.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        try check(try FileManager.default.contentsOfDirectory(atPath: snapshots.path).sorted() == [published.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, "selection.json"].sorted(),
                  "Only the selected Mac art tree and selection manifest may be published.")

        let original = try requiredArt(originalDirectory)
        let imported = try requiredArt(published)
        let fallback = try requiredArt(fallbackDirectory)
        let now = Date(timeIntervalSince1970: 1_792_150_230)
        let event = DeskClockEvent(start: now.addingTimeInterval(300), title: "Design review", nuke: false)
        var comparisons = 0
        var hashes: [String: String] = [:]
        for (name, size, compact) in [
            ("ios-small", CGSize(width: 158, height: 158), true),
            ("ios-medium", CGSize(width: 338, height: 158), false),
            ("ios-large", CGSize(width: 338, height: 354), false),
            ("mac-small", CGSize(width: 164, height: 164), true),
            ("mac-medium", CGSize(width: 344, height: 164), false),
            ("mac-large", CGSize(width: 344, height: 344), false)
        ] {
            for (state, candidate) in [("calm", Optional<DeskClockEvent>.none), ("soon", event),
                ("nuke", DeskClockEvent(start: now, title: "Design review", nuke: true))] {
                let reference = try pixels(original, now: now, event: candidate, size: size, compact: compact)
                let actual = try pixels(imported, now: now, event: candidate, size: size, compact: compact)
                try check(reference == actual, "Native owned widget pixels differ: " + name + "-" + state)
                hashes[name + "-" + state] = digest(actual)
                comparisons += 1
            }
        }
        let baselinePixels = try pixels(fallback, now: now, event: nil, size: CGSize(width: 164, height: 164), compact: true)
        let originalPixels = try pixels(original, now: now, event: nil, size: CGSize(width: 164, height: 164), compact: true)
        try check(baselinePixels != originalPixels, "The clean Lix clock must differ from the owned original clock.")

        let broken = group.appendingPathComponent("broken/MacArtwork/lemmings", isDirectory: true)
        try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
        try Data("invalid".utf8).write(to: broken.appendingPathComponent("manifest.json"))
        do {
            try GameDeskClockResources.publish(resourceURL: group.appendingPathComponent("broken"), containerURL: group)
            throw Failure(description: "Invalid artwork must not publish.")
        } catch is Failure { throw Failure(description: "Invalid artwork must not publish.") }
        catch { }
        try check(GameDeskClockResources.artworkDirectory(containerURL: group, bundledResourceURL: bundled) == published,
                  "A failed import must preserve the previous published selection.")
        let linked = group.appendingPathComponent("linked/MacArtwork", isDirectory: true)
        try FileManager.default.createDirectory(at: linked, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linked.appendingPathComponent("lemmings"), withDestinationURL: originalDirectory)
        do {
            try GameDeskClockResources.publish(resourceURL: group.appendingPathComponent("linked"), containerURL: group)
            throw Failure(description: "A symbolic artwork directory must not publish.")
        } catch is Failure { throw Failure(description: "A symbolic artwork directory must not publish.") }
        catch { }
        try check(try GameDeskClockResources.publish(resourceURL: nil, containerURL: group), "Selecting Lix must clear the owned selection.")
        let selectedFallback = GameDeskClockResources.artworkDirectory(containerURL: group, bundledResourceURL: bundled)!
        try check(selectedFallback == fallbackDirectory, "Clearing must restore the bundle root.")
        try check(try pixels(requiredArt(selectedFallback), now: now, event: nil, size: CGSize(width: 164, height: 164), compact: true) == baselinePixels,
                  "Lix fallback pixels must match the clean bundle.")
        let selection = snapshots.appendingPathComponent("selection.json")
        try Data("{\"version\":1,\"artwork\":\"../../other\"}".utf8).write(to: selection, options: .atomic)
        try check(GameDeskClockResources.artworkDirectory(containerURL: group, bundledResourceURL: bundled) == fallbackDirectory,
                  "An invalid selection path must fall back to the bundle.")
        try Data("invalid".utf8).write(to: selection, options: .atomic)
        try check(GameDeskClockResources.artworkDirectory(containerURL: group, bundledResourceURL: bundled) == fallbackDirectory,
                  "A corrupt selection must fall back to the bundle.")
        let evidence: [String: Any] = ["copiedFiles": sourceFiles.count, "copiedBytes": copiedBytes,
            "nativePixelComparisons": comparisons, "pixelSHA256": hashes, "fallbackSHA256": digest(baselinePixels),
            "group": group.path, "productionContainerAccessed": false]
        let output = try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
        try output.write(to: folder.appendingPathComponent("results.json"), options: .atomic)
        print("PASS widget owned-resource publication: \(comparisons) native frame matches, clean Lix fallback, atomic selection and isolated storage.")
    }

    private static func requiredArt(_ directory: URL) throws -> GameDeskClockArt {
        guard let art = GameDeskClockArt(directory: directory) else { throw Failure(description: "Clock artwork cannot load: " + directory.path) }
        return art
    }

    private static func digest(_ pixels: [UInt8]) -> String {
        SHA256.hash(data: Data(pixels)).map { String(format: "%02x", $0) }.joined()
    }

    private static func pixels(_ art: GameDeskClockArt, now: Date, event: DeskClockEvent?, size: CGSize, compact: Bool) throws -> [UInt8] {
        let width = Int(size.width * 2), height = Int(size.height * 2)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_GB")
        let simulation = DeskClockSimulation.still(at: now, event: event, uses24Hour: true, calendar: calendar)
        try pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                else { throw Failure(description: "The clock bitmap context could not be created.") }
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 2, y: -2)
            art.drawWidget(simulation, event: event, now: now, in: context, rect: CGRect(origin: .zero, size: size), compact: compact)
        }
        return pixels
    }
}
