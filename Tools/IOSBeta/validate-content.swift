import CryptoKit
import Foundation
import LemmingsMobileCore
import CoreGraphics
import ImageIO

// This tool exercises real mobile sessions without a window or audio output.
@main struct MobileBetaValidation {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            throw Failure.invalidArguments
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let reportURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let store = MobileContentStore(root: directory.appendingPathComponent("UnusedUserStore"))
        guard let library = try store.loadLibrary(bundledDirectory: directory),
              library.dataSet.title == .lemmings,
              library.levels.count == 120 else { throw Failure.incompleteCampaign }
        var entries: [[String: Any]] = []
        var playfieldRenders: [[String: Any]] = []
        for summary in library.levels {
            let session = try library.loadLevel(at: summary.index).session
            guard session.panelFrame != nil else { throw Failure.missingPanel(summary.index) }
            let initialFrame = try session.render(highlight: nil)
            for _ in 0..<50 { session.tick() }
            let checkpoint = try session.checkpointPayload()
            let snapshot = session.snapshot
            let frame = try session.render(highlight: nil)
            if summary.index == 0 {
                playfieldRenders = try validatePlayfield(initial: initialFrame, advanced: frame,
                                                        session: session, output: reportURL.deletingLastPathComponent())
            }
            let restored = try library.loadLevel(at: summary.index).session
            try restored.restoreCheckpointPayload(checkpoint)
            guard restored.snapshot == snapshot,
                  try restored.render(highlight: nil) == frame else {
                throw Failure.checkpointMismatch(summary.index)
            }
            entries.append([
                "index": summary.index, "rank": summary.rank, "number": summary.number,
                "title": summary.title, "levelIdentifier": session.levelIdentifier,
                "levelFingerprint": session.levelFingerprint, "tick": snapshot.tick,
                "initialFrameSHA256": hash(initialFrame.rgba), "restoredFrameSHA256": hash(frame.rgba),
            ])
        }
        let report: [String: Any] = [
            "schemaVersion": 1, "game": "classic", "levelsValidated": entries.count,
            "ticksPerLevel": 50, "renderAndCheckpointRestore": "passed", "levels": entries,
            "bitmapPlayfieldRenders": playfieldRenders,
            "limitations": ["No touch or UIKit validation", "No music or effects playback", "No L2 or L3 mobile library"],
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: reportURL, options: .atomic)
        print("PASS: 120 Classic mobile levels, bitmap frames, panels and exact checkpoint restoration (6,000 ticks).")
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func validatePlayfield(initial: MobilePixelFrame, advanced: MobilePixelFrame,
                                          session: any MobileGameSession, output: URL) throws -> [[String: Any]] {
        let folder = output.appendingPathComponent("PlayfieldRenders", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var records: [[String: Any]] = []
        for (orientation, size) in [("portrait", MobileSize(width: 834, height: 988)),
                                    ("landscape", MobileSize(width: 1112, height: 670))] {
            var viewport = MobileViewport(levelSize: session.levelSize, viewSize: MobileSize(width: 1, height: 1),
                                          origin: session.initialCameraOrigin, pixelAspect: 1.2)
            viewport.fitGameplay(in: size)
            for state in ["ready", "running", "panned", "zoomed"] {
                if state == "panned" { viewport.pan(viewDelta: MobilePoint(x: -100, y: 0)) }
                if state == "zoomed" {
                    viewport.magnify(by: 1.4, around: MobilePoint(x: size.width / 2, y: size.height / 2))
                }
                let bitmap = try require(MobileBitmapRenderer.image(state == "ready" ? initial : advanced))
                let context = try require(CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                                   bitsPerComponent: 8, bytesPerRow: Int(size.width) * 4,
                                                   space: CGColorSpaceCreateDeviceRGB(),
                                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.setFillColor(CGColor(gray: 0, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
                context.translateBy(x: 0, y: size.height)
                context.scaleBy(x: 1, y: -1)
                MobileBitmapRenderer.draw(bitmap, viewport: viewport, in: context)
                let pixels = try require(context.data).assumingMemoryBound(to: UInt8.self)
                let count = Int(size.width * size.height)
                let coloured = (0..<count).reduce(0) { total, index in
                    total + (pixels[index * 4] > 0 || pixels[index * 4 + 1] > 0 || pixels[index * 4 + 2] > 0 ? 1 : 0)
                }
                guard coloured > 1000 else { throw Failure.blackPlayfield }
                let image = try require(context.makeImage())
                let url = folder.appendingPathComponent("just-dig-\(orientation)-\(state).png")
                let destination = try require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil)
                guard CGImageDestinationFinalize(destination) else { throw Failure.blackPlayfield }
                records.append(["orientation": orientation, "state": state, "width": Int(size.width),
                                "height": Int(size.height), "visibleColouredPixels": coloured,
                                "file": url.lastPathComponent, "sha256": hash(try Data(contentsOf: url))])
            }
        }
        return records
    }

    private static func require<T>(_ value: T?) throws -> T {
        guard let value else { throw Failure.blackPlayfield }
        return value
    }

    enum Failure: Error {
        case invalidArguments, incompleteCampaign
        case missingPanel(Int), checkpointMismatch(Int)
        case blackPlayfield
    }
}
