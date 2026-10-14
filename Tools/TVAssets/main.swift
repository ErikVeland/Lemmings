import CoreGraphics
import Foundation
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore

/// Export native pixel artwork as Apple's layered icon and static Top Shelf assets.
@main struct TVAssets {
    enum Failure: Error { case artwork, image }
    static var info: [String: Any] { ["author": "academy.glasscode.lemmings.tvos", "version": 1] }
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        guard let typography = GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")),
              let logoFrame = typography.interface.logo else { throw Failure.artwork }
        let logo = try image(width: logoFrame.width, height: logoFrame.height, rgba: logoFrame.rgba)
        let library = try ClassicMobileLibrary(directory: root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30"))
        let session = try library.loadLevel(at: 0).session
        session.applySettings(.init())
        for _ in 0..<140 { session.tick() }
        guard let sprite = session.spriteHighlight(for: 1)?.frame,
              let actor = MobileBitmapRenderer.image(sprite) else { throw Failure.artwork }
        let catalogue = root.appendingPathComponent("Apps/UltimateLemmingsTV/Assets.xcassets")
        try json(["info": info], at: catalogue.appendingPathComponent("Contents.json"))
        let brand = catalogue.appendingPathComponent("AppIcon.brandassets")
        var assets: [[String: Any]] = []
        for (name, width, height) in [("App Icon", 400, 240), ("App Icon Large", 1280, 768)] {
            let stack = brand.appendingPathComponent(name + ".imagestack")
            let names = ["Logo", "Lemming", "Background"]
            try json(["info": info, "layers": names.map { ["filename": $0 + ".imagestacklayer"] }], at: stack.appendingPathComponent("Contents.json"))
            for layer in names {
                let folder = stack.appendingPathComponent(layer + ".imagestacklayer/Content.imageset")
                var images: [[String: String]] = []
                for scale in name == "App Icon" ? [1, 2] : [1] {
                    let canvas = try context(width: width * scale, height: height * scale)
                    draw(layer: layer, logo: logo, actor: actor, bounds: CGRect(x: 0, y: 0, width: width * scale, height: height * scale), in: canvas)
                    let filename = "\(layer)-\(scale)x.png"
                    try png(canvas, at: folder.appendingPathComponent(filename))
                    images.append(["idiom": "tv", "filename": filename, "scale": "\(scale)x"])
                }
                try json(["info": info, "images": images], at: folder.appendingPathComponent("Contents.json"))
            }
            assets.append(["idiom": "tv", "filename": name + ".imagestack", "role": "primary-app-icon", "size": "\(width)x\(height)"])
        }
        for (name, width, role) in [("Top Shelf", 1920, "top-shelf-image"), ("Top Shelf Wide", 2320, "top-shelf-image-wide")] {
            let folder = brand.appendingPathComponent(name + ".imageset")
            var images: [[String: String]] = []
            for scale in [1, 2] {
                let canvas = try context(width: width * scale, height: 720 * scale)
                for layer in ["Background", "Lemming", "Logo"] { draw(layer: layer, logo: logo, actor: actor, bounds: CGRect(x: 0, y: 0, width: width * scale, height: 720 * scale), in: canvas) }
                let filename = "shelf-\(scale)x.png"
                try png(canvas, at: folder.appendingPathComponent(filename))
                images.append(["idiom": "tv", "filename": filename, "scale": "\(scale)x"])
            }
            try json(["info": info, "images": images], at: folder.appendingPathComponent("Contents.json"))
            assets.append(["idiom": "tv", "filename": name + ".imageset", "role": role, "size": "\(width)x720"])
        }
        try json(["info": info, "assets": assets], at: brand.appendingPathComponent("Contents.json"))
        print("PASS layered TV app icons and static Top Shelf assets exported from native artwork")
    }
    static func draw(layer: String, logo: CGImage, actor: CGImage, bounds: CGRect, in context: CGContext) {
        context.interpolationQuality = .none; context.setShouldAntialias(false)
        if layer == "Background" {
            context.setFillColor(CGColor(srgbRed: 0.025, green: 0.035, blue: 0.07, alpha: 1)); context.fill(bounds)
        } else if layer == "Logo" {
            fit(logo, in: CGRect(x: bounds.width * 0.16, y: bounds.height * 0.15, width: bounds.width * 0.68, height: bounds.height * 0.22), context: context)
        } else {
            fit(actor, in: CGRect(x: bounds.width * 0.35, y: bounds.height * 0.40, width: bounds.width * 0.30, height: bounds.height * 0.42), context: context)
        }
    }
    static func fit(_ image: CGImage, in box: CGRect, context: CGContext) {
        let scale = max(1, floor(min(box.width / CGFloat(image.width), box.height / CGFloat(image.height))))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        GameStoneArt.drawImage(image, in: CGRect(x: floor(box.midX - size.width / 2), y: floor(box.midY - size.height / 2), width: size.width, height: size.height), context: context)
    }
    static func image(width: Int, height: Int, rgba: Data) throws -> CGImage {
        guard let image = MobileBitmapRenderer.image(try MobilePixelFrame(width: width, height: height, rgba: rgba)) else { throw Failure.image }
        return image
    }
    static func context(width: Int, height: Int) throws -> CGContext {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.image }
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1); return context
    }
    static func json(_ value: [String: Any], at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
    }
    static func png(_ context: CGContext, at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let image = context.makeImage(), let output = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { throw Failure.image }
        CGImageDestinationAddImage(output, image, nil)
        guard CGImageDestinationFinalize(output) else { throw Failure.image }
    }
}
