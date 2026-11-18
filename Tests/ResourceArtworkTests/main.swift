import AppKit
import NxlvKit

@MainActor enum AppDistribution { static let isStore = true }
@MainActor enum CharacterArtworkPreference { static var lixEnabled = false }
@MainActor enum GamePixelText {
    static func draw(_ value: String, in rect: CGRect, maxScale: CGFloat = 3,
                     palette: MacInterfaceRenderer.Palette = .blue, alignment: NSTextAlignment = .center) {}
}

private func check(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { FileHandle.standardError.write(Data(("FAIL " + message + "\n").utf8)); exit(1) }
}

@MainActor private func cursorGreenPixels() -> Int {
    let context = CGContext(data: nil, width: 192, height: 192, bitsPerComponent: 8, bytesPerRow: 768,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: 192); context.scaleBy(x: 2, y: -2)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    GameCursor.drawPlayfieldPointer(at: CGPoint(x: 48, y: 48), scale: 2, tint: .white,
                                    original: true, occupied: true)
    NSGraphicsContext.restoreGraphicsState()
    let image = NSBitmapImageRep(cgImage: context.makeImage()!)
    var green = 0
    for y in 0..<192 { for x in 0..<192 {
        if let colour = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), colour.greenComponent > 0.5,
           colour.redComponent < 0.05, colour.blueComponent < 0.05 { green += 1 }
    } }
    return green
}

MainActor.assumeIsolated {
    _ = NSApplication.shared
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("ResourceArtwork-\(UUID())")
    defer { try? GameResources.activate(bundleURL: nil); try? FileManager.default.removeItem(at: root) }
    func fixtureBundle(_ name: String, original: Bool) throws -> URL {
        let bundle = root.appendingPathComponent(name + ".bundle")
        let resources = bundle.appendingPathComponent("Contents/Resources")
        let mouse = resources.appendingPathComponent("AlternativeAssets/Lix/assets/data/images")
        try FileManager.default.createDirectory(at: mouse, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: project.appendingPathComponent(".build/alternative-assets/lix/assets/data/images/mouse.png"),
                                        to: mouse.appendingPathComponent("mouse.png"))
        let info: [String: Any] = ["CFBundleIdentifier": "academy.glasscode.tests.resources." + name,
            "CFBundlePackageType": "BNDL", "CFBundleName": name]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: bundle.appendingPathComponent("Contents/Info.plist"))
        if original {
            let fonts = resources.appendingPathComponent("Fonts")
            try FileManager.default.createDirectory(at: fonts, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: project.appendingPathComponent(".build/personal-preview-assets/Fonts/OriginalLemmings"),
                                            to: fonts.appendingPathComponent("OriginalLemmings"))
            let cursors = resources.appendingPathComponent("Cursors")
            try FileManager.default.createDirectory(at: cursors, withIntermediateDirectories: true)
            for (source, destination) in [("amiga-cursor.png", "original-cross.png"), ("amiga-reticule.png", "original-reticule.png")] {
                try FileManager.default.copyItem(at: project.appendingPathComponent("Tests/DialogCursorTests/Fixtures/" + source),
                                                to: cursors.appendingPathComponent(destination))
            }
        }
        return bundle
    }
    do {
        let clean = try fixtureBundle("clean", original: false)
        let originalBundle = try fixtureBundle("original", original: true)
        try GameResources.activate(bundleURL: clean)
        check(GameMenuArtwork.renderer() == nil && cursorGreenPixels() == 0,
              "The clean resource layer exposed original font/cursor pixels")
        try GameResources.activate(bundleURL: originalBundle)
        guard let original = GameMenuArtwork.renderer() else {
            FileHandle.standardError.write(Data("FAIL An imported original font is still blocked by the build profile.\n".utf8)); exit(1)
        }
        check(original.font(.small)?.cellWidth == 12 && original.font(.small)?.cellHeight == 18,
              "The imported original font has incorrect metrics")
        check(cursorGreenPixels() > 0, "The imported original cursor did not replace the licensed Lix cursor")
        let lix = LixInterfaceRenderer(directory: project.appendingPathComponent(".build/alternative-assets/lix"))
        check(lix.isAvailable && !lix.isEnabled, "The Store build still forces Lix after original interface restoration")
        CharacterArtworkPreference.lixEnabled = true
        check(lix.isEnabled, "An explicit Lix choice was ignored after restoration")
        CharacterArtworkPreference.lixEnabled = false
        try GameResources.activate(bundleURL: clean)
        check(GameMenuArtwork.renderer() == nil && cursorGreenPixels() == 0,
              "Removing an imported interface retained original font/cursor caches")
        check(lix.isEnabled, "Missing original resources did not fall back to available Lix controls")
        try GameResources.activate(bundleURL: originalBundle)
        check(GameMenuArtwork.renderer() != nil && cursorGreenPixels() > 0,
              "Reimport retained missing original font/cursor caches")
        print("PASS actual resource activation: original fonts/cursors, removal/reimport invalidation, original/Lix preference and missing-original fallback")
    } catch {
        FileHandle.standardError.write(Data("FAIL \(error)\n".utf8)); exit(1)
    }
}
