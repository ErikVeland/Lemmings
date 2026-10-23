import CoreGraphics
import Foundation
import ImageIO
import Testing
import LemmingsGameArt
import LemmingsMobileCore

struct DeskClockFullScreenArtTests {
    private static let root = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    private static let artwork = root.appendingPathComponent(".build/mac-artwork/export/lemmings")

    private static let hasArtwork = FileManager.default.fileExists(atPath: artwork.appendingPathComponent("manifest.json").path)

    @Test(.enabled(if: hasArtwork, "The Macintosh artwork export is absent."))
    func redNightVisionUsesOnlyRedPixels() throws {
        let art = try #require(GameDeskClockArt(directory: Self.artwork))
        let width = 720, height = 495
        let context = try #require(CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        let now = Date(timeIntervalSince1970: 1_792_670_400)
        let simulation = DeskClockSimulation.still(at: now, event: nil, uses24Hour: true)
        art.drawFullScreen(simulation, event: nil, now: now, time: 0, in: context,
                           rect: CGRect(x: 0, y: 0, width: width, height: height), nightDim: false)
        let data = try #require(context.data)
        GameDeskClockArt.applyRedNightVision(to: data, width: width, height: height, bytesPerRow: context.bytesPerRow)
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        #expect(stride(from: 0, to: width * height * 4, by: 4).contains { pixels[$0] > 0 })
        #expect(stride(from: 0, to: width * height * 4, by: 4).allSatisfy {
            pixels[$0 + 1] == 0 && pixels[$0 + 2] == 0
        })
        let output = Self.root.appendingPathComponent(".build/duo-front-tent-renders/red-night-vision.png")
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }

    @Test(.enabled(if: hasArtwork, "The Macintosh artwork export is absent."))
    func fillsPortraitLandscapeAndStackedCanvases() throws {
        let art = try #require(GameDeskClockArt(directory: Self.artwork))
        let output = Self.root.appendingPathComponent(".build/duo-front-tent-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let now = Date(timeIntervalSince1970: 1_792_670_400)
        for (name, size) in [("front-portrait", CGSize(width: 495, height: 720)),
                             ("front-landscape", .init(width: 720, height: 495)),
                             ("front-camera-left", .init(width: 720, height: 495)),
                             ("front-camera-right", .init(width: 720, height: 495)),
                             ("front-duo-tent", .init(width: 2034, height: 1398)),
                             ("unfolded", .init(width: 1194, height: 834)),
                             ("stacked", .init(width: 834, height: 569))] {
            for (state, event) in [("calm", Optional<DeskClockEvent>.none),
                                  ("soon", .init(start: now.addingTimeInterval(300), title: "A meeting about bridges", nuke: false)),
                                  ("nuke", .init(start: now, title: "A meeting about bridges", nuke: true))] {
                let width = Int(size.width), height = Int(size.height)
                let context = try #require(CGContext(data: nil, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0, y: size.height)
                context.scaleBy(x: 1, y: -1)
                let simulation = DeskClockSimulation.still(at: now, event: event, uses24Hour: true)
                let content: CGRect? = name == "front-camera-left"
                    ? CGRect(x: 0, y: 80, width: size.width, height: size.height - 80)
                    : name == "front-camera-right" || name == "front-duo-tent"
                    ? CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.82) : nil
                art.drawFullScreen(simulation, event: event, now: now, time: 0.5, in: context,
                                   rect: CGRect(origin: .zero, size: size), nightDim: false, contentRect: content)
                let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
                #expect(stride(from: 3, to: width * height * 4, by: 4).allSatisfy { pixels[$0] == 255 })
                // Ground reaches both edges. A centred fixed scene leaves transparent side gutters here.
                for x in [0, width - 1] {
                    let bottom = ((height - 2) * width + x) * 4
                    #expect(Int(pixels[bottom]) + Int(pixels[bottom + 1]) + Int(pixels[bottom + 2]) > 0)
                }
                let image = try #require(context.makeImage())
                let destination = try #require(CGImageDestinationCreateWithURL(
                    output.appendingPathComponent("\(name)-\(state).png") as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil)
                #expect(CGImageDestinationFinalize(destination))
            }
        }
    }
}
