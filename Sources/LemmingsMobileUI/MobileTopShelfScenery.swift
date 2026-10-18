#if os(tvOS)
@preconcurrency import AVFoundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import TVServices
import UIKit

/// The Top Shelf extension previews the Home camera pan from a clip in the shared container.
/// Keep the group, folder and manifest fields in step with `TopShelf/ContentProvider.swift`.
enum MobileTopShelfScenery {
    struct Manifest: Codable {
        var key: String
        var title: String?
        var image: String
        var video: String?
    }

    static let group = "group.academy.glasscode.lemmings"
    private static let size = CGSize(width: 1920, height: 1080)
    private static let framesPerSecond: Int32 = 30
    /// The clip runs faster than Home so the system preview shows the whole route.
    private static let longestLeg: TimeInterval = 20

    static var folder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("Library/Caches/TopShelf", isDirectory: true)
    }

    /// Holiday Top Shelf runs from 1 December to 6 January.
    static func isHolidaySeason(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return parts.month == 12 || (parts.month == 1 && (parts.day ?? 0) <= 6)
    }

    /// The season is part of the key, so the logo changes on the first visit to Home in a new season.
    static func seasonalKey(_ key: String) -> String { key + (isHolidaySeason() ? ":holiday" : "") }

    static func needsExport(key: String) -> Bool {
        guard let folder, let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return folder != nil }
        let files = [manifest.image] + (manifest.video.map { [$0] } ?? [])
        return manifest.key != key || !files.allSatisfy {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
        }
    }

    /// Writes a still and a seamless out-and-back clip, then swaps the manifest and removes older files.
    static func export(_ scenery: MobileHomeBackdrop, key: String) async throws {
        guard let folder, let image = MobileBitmapRenderer.image(scenery.frame) else { return }
        let logo = logo(holiday: isHolidaySeason())
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = UUID().uuidString
        let start = CGPoint(x: scenery.start.x, y: scenery.start.y)
        let goal = CGPoint(x: scenery.goal.x, y: scenery.goal.y)
        let imageSize = CGSize(width: image.width, height: image.height)
        let first = GameHomeBackdropArt.source(imageSize: imageSize, viewSize: size, start: start, goal: goal, elapsed: 0)
        let menuLeg = GameHomeBackdropArt.legDuration(imageSize: imageSize, viewSize: size, start: start, goal: goal)
        let moves = first != GameHomeBackdropArt.source(imageSize: imageSize, viewSize: size,
            start: start, goal: goal, elapsed: menuLeg)

        let still = "scenery-\(stamp).png"
        guard let frame = render(image, source: first, logo: logo),
              let png = UIImage(cgImage: frame).pngData() else { return }
        try png.write(to: folder.appendingPathComponent(still), options: .atomic)

        var video: String?
        if moves {
            let name = "scenery-\(stamp).mp4"
            let leg = min(menuLeg, longestLeg)
            try await writeClip(to: folder.appendingPathComponent(name), seconds: leg * 2) { context, time in
                draw(image, source: GameHomeBackdropArt.source(imageSize: imageSize, viewSize: size,
                    start: start, goal: goal, elapsed: time * menuLeg / leg), logo: logo, in: context)
            }
            video = name
        }
        try Task.checkCancellation()

        let manifest = Manifest(key: key, title: scenery.title, image: still, video: video)
        try JSONEncoder().encode(manifest).write(to: folder.appendingPathComponent("manifest.json"), options: .atomic)
        let keep = Set(["manifest.json", still] + (video.map { [$0] } ?? []))
        for old in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where !keep.contains(old) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(old))
        }
        TVTopShelfContentProvider.topShelfContentDidChange()
    }

    private static func render(_ image: CGImage, source: CGRect, logo: Logo?) -> CGImage? {
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        draw(image, source: source, logo: logo, in: context)
        return context.makeImage()
    }

    /// Shared artwork expects a top-left origin, as in the Home view.
    private static func draw(_ image: CGImage, source: CGRect, logo: Logo?, in context: CGContext) {
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        GameHomeBackdropArt.draw(image: image, source: source, in: CGRect(origin: .zero, size: size), context: context)
        guard let logo else { return }
        // The mark is stored at twice its pixel size; an exact half keeps doubled pixels whole.
        context.interpolationQuality = .high
        GameStoneArt.drawImage(logo.image, in: logo.frame, context: context)
    }

    /// The Home menu's Ultimate mark. In the holidays, Xmas Lemmings, or one time in five Holiday Lemmings 1994.
    private struct Logo { let image: CGImage; let frame: CGRect }
    private static func logo(holiday: Bool) -> Logo? {
        let family = !holiday ? "lemmings" : Int.random(in: 0..<5) == 0 ? "holiday" : "xmas"
        guard let directory = Bundle.main.resourceURL?.appendingPathComponent("MacArtwork/" + family),
              let artwork = try? ClassicMacArtwork(directory: directory),
              let original = ClassicMacUserInterface(artwork: artwork)?.logo,
              let image = GameMenuLogo.image(for: original) else { return nil }
        // The system carousel draws its title and buttons along the bottom, so the mark sits above the scenery.
        let frame = GameMenuLogo.frame(canvasSize: GameMenuLogo.logicalSize(of: image), originalWidth: CGFloat(original.width),
                                       in: CGRect(x: 460, y: 72, width: 1000, height: 340))
        return Logo(image: image, frame: frame)
    }

    private static func writeClip(to url: URL, seconds: TimeInterval,
                                  paint: (CGContext, TimeInterval) -> Void) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000,
                AVVideoMaxKeyFrameIntervalKey: Int(framesPerSecond) * 2]])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height)])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)
        defer { if writer.status == .writing { writer.cancelWriting() } }

        let count = Int(seconds * Double(framesPerSecond))
        for index in 0..<count {
            try Task.checkCancellation()
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }
            guard let pool = adaptor.pixelBufferPool else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
            guard let buffer else { throw CocoaError(.fileWriteUnknown) }
            CVPixelBufferLockBaseAddress(buffer, [])
            let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width),
                height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            if let context { paint(context, Double(index) / Double(framesPerSecond)) }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard context != nil, adaptor.append(buffer, withPresentationTime:
                CMTime(value: CMTimeValue(index), timescale: framesPerSecond)) else {
                throw writer.error ?? CocoaError(.fileWriteUnknown)
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
    }
}
#endif
