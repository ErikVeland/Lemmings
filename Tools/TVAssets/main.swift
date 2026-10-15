import CoreGraphics
import Foundation
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

/// Export native pixel artwork as Apple's layered icon and static Top Shelf assets.
@main struct TVAssets {
    enum Failure: Error { case artwork, image }
    static var info: [String: Any] { ["author": "academy.glasscode.lemmings.tvos", "version": 1] }
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let artwork = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        guard let interface = ClassicMacUserInterface(artwork: artwork) else { throw Failure.artwork }
        guard let logoFrame = interface.logo else { throw Failure.artwork }
        guard let logo = GameMenuLogo.image(for: logoFrame,
            letteringURL: root.appendingPathComponent("Resources/MenuArtwork/ultimate.png"), layer: .lemmings),
              let ultimate = GameMenuLogo.image(for: logoFrame,
            letteringURL: root.appendingPathComponent("Resources/MenuArtwork/ultimate.png"), layer: .ultimate),
              let stride = artwork.lemming(pose: .walking, left: false, tick: 2) else { throw Failure.artwork }
        // The Macintosh bank contains the authored 2× artwork, rather than doubled DOS pixels.
        let sprite = try MobilePixelFrame(width: stride.width, height: stride.height,
                                         rgba: stride.rgba)
        guard let spriteImage = MobileBitmapRenderer.image(sprite) else { throw Failure.artwork }
        let actor = try trimmed(spriteImage)
        let catalogue = root.appendingPathComponent("Apps/UltimateLemmingsTV/Assets.xcassets")
        try json(["info": info], at: catalogue.appendingPathComponent("Contents.json"))
        let brand = catalogue.appendingPathComponent("AppIcon.brandassets")
        var assets: [[String: Any]] = []
        for (name, width, height) in [("App Icon", 400, 240), ("App Icon Large", 1280, 768)] {
            let stack = brand.appendingPathComponent(name + ".imagestack")
            // Image stacks list the nearest surface first.
            let names = ["Lemming", "Ultimate", "Lemmings", "Depth", "Background"]
            try json(["info": info, "layers": names.map { ["filename": $0 + ".imagestacklayer"] }], at: stack.appendingPathComponent("Contents.json"))
            for layer in names {
                let folder = stack.appendingPathComponent(layer + ".imagestacklayer/Content.imageset")
                var images: [[String: String]] = []
                for scale in name == "App Icon" ? [1, 2] : [1] {
                    let canvas = try context(width: width * scale, height: height * scale)
                    draw(layer: layer, logo: logo, ultimate: ultimate, actor: actor, bounds: CGRect(x: 0, y: 0, width: width * scale, height: height * scale), in: canvas)
                    let filename = "\(layer)-\(scale)x.png"
                    try png(canvas, at: folder.appendingPathComponent(filename))
                    images.append(["idiom": "tv", "filename": filename, "scale": "\(scale)x"])
                }
                try json(["info": info, "images": images], at: folder.appendingPathComponent("Contents.json"))
            }
            assets.append(["idiom": "tv", "filename": name + ".imagestack", "role": "primary-app-icon", "size": "\(width)x\(height)"])
            let preview = try context(width: width, height: height)
            for layer in names.reversed() {
                draw(layer: layer, logo: logo, ultimate: ultimate, actor: actor,
                     bounds: CGRect(x: 0, y: 0, width: width, height: height), in: preview)
            }
            try png(preview, at: root.appendingPathComponent(".build/tv-icon/\(name).png"))
        }
        for (name, width, role) in [("Top Shelf", 1920, "top-shelf-image"), ("Top Shelf Wide", 2320, "top-shelf-image-wide")] {
            let folder = brand.appendingPathComponent(name + ".imageset")
            var images: [[String: String]] = []
            for scale in [1, 2] {
                let canvas = try context(width: width * scale, height: 720 * scale)
                for layer in ["Background", "Depth", "Lemmings", "Ultimate", "Lemming"] { draw(layer: layer, logo: logo, ultimate: ultimate, actor: actor, bounds: CGRect(x: 0, y: 0, width: width * scale, height: 720 * scale), in: canvas) }
                let filename = "shelf-\(scale)x.png"
                try png(canvas, at: folder.appendingPathComponent(filename))
                images.append(["idiom": "tv", "filename": filename, "scale": "\(scale)x"])
            }
            try json(["info": info, "images": images], at: folder.appendingPathComponent("Contents.json"))
            assets.append(["idiom": "tv", "filename": name + ".imageset", "role": role, "size": "\(width)x720"])
        }
        try json(["info": info, "assets": assets], at: brand.appendingPathComponent("Contents.json"))
        print("PASS five-layer TV icons: separate Ultimate, Lemmings and Macintosh 2× walker")
    }
    static func draw(layer: String, logo: CGImage, ultimate: CGImage, actor: CGImage, bounds: CGRect, in context: CGContext) {
        context.interpolationQuality = .none; context.setShouldAntialias(false)
        // Use the icon's aspect ratio on Top Shelf too, so the mark stays beneath the walker.
        let width = min(bounds.width, bounds.height * 5 / 3)
        let scene = CGRect(x: floor(bounds.midX - width / 2), y: 0, width: width, height: bounds.height)
        let logoRect = fitted(logo, in: CGRect(x: scene.minX + width * 0.12, y: bounds.height * 0.56,
                                             width: width * 0.76, height: bounds.height * 0.31))
        let actorRect = fitted(actor, in: CGRect(x: scene.minX + width * 0.35, y: 0,
                                               width: width * 0.30, height: bounds.height * 0.42), wholePixels: true)
        // Match the lettering beneath the feet, including the gap between a walking stride.
        let footing = feet(actor).map { foot in
            let x = actorRect.minX + foot * actorRect.width
            return logoRect.minY + logoRect.height * skyline(logo, at: (x - logoRect.minX) / logoRect.width)
        }.min() ?? logoRect.minY
        let walkingRect = CGRect(x: actorRect.minX, y: floor(footing - actorRect.height),
                                 width: actorRect.width, height: actorRect.height)
        let depth = max(1, (bounds.height / 96).rounded())
        if layer == "Background" {
            context.setFillColor(CGColor(srgbRed: 0.025, green: 0.035, blue: 0.07, alpha: 1)); context.fill(bounds)
        } else if layer == "Depth" {
            context.saveGState()
            context.setShadow(offset: CGSize(width: depth, height: -depth), blur: depth,
                              color: CGColor(gray: 0, alpha: 0.5))
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            for step in stride(from: Int(depth * 2), through: 1, by: -1) {
                surface(logo, in: logoRect.offsetBy(dx: CGFloat(step), dy: CGFloat(step)),
                        tint: CGColor(srgbRed: 0.025, green: 0.18, blue: 0.09, alpha: 1), context: context)
            }
            context.endTransparencyLayer()
            context.restoreGState()
        } else if layer == "Ultimate" {
            context.saveGState()
            context.setShadow(offset: CGSize(width: depth, height: -depth), blur: depth,
                              color: CGColor(gray: 0, alpha: 0.5))
            surface(ultimate, in: logoRect.offsetBy(dx: depth, dy: depth),
                    tint: CGColor(srgbRed: 0.25, green: 0.22, blue: 0.02, alpha: 1), context: context)
            context.restoreGState()
            surface(ultimate, in: logoRect, context: context)
        } else if layer == "Lemmings" {
            surface(logo, in: logoRect.offsetBy(dx: -depth / 2, dy: -depth / 2),
                    tint: CGColor(srgbRed: 0.87, green: 1, blue: 0.55, alpha: 0.85), context: context)
            surface(logo, in: logoRect, context: context)
        } else {
            context.saveGState()
            context.setShadow(offset: CGSize(width: depth, height: -depth), blur: depth,
                              color: CGColor(gray: 0, alpha: 0.65))
            surface(actor, in: walkingRect.offsetBy(dx: -depth / 2, dy: -depth / 2),
                    tint: CGColor(srgbRed: 0.7, green: 0.95, blue: 1, alpha: 0.8), context: context)
            context.restoreGState()
            surface(actor, in: walkingRect, context: context)
        }
    }
    /// Animation frames include padding, which must not shrink the visible walker.
    static func trimmed(_ image: CGImage) throws -> CGImage {
        let canvas = try context(width: image.width, height: image.height)
        guard let data = canvas.data else { throw Failure.image }
        GameStoneArt.drawImage(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height), context: canvas)
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var left = image.width, top = image.height, right = 0, bottom = 0
        for y in 0..<image.height {
            for x in 0..<image.width where pixels[y * canvas.bytesPerRow + x * 4 + 3] > 0 {
                left = min(left, x); right = max(right, x + 1)
                top = min(top, y); bottom = max(bottom, y + 1)
            }
        }
        guard right > left, bottom > top,
              let result = image.cropping(to: CGRect(x: left, y: top, width: right - left, height: bottom - top))
        else { throw Failure.image }
        return result
    }
    static func fitted(_ image: CGImage, in box: CGRect, wholePixels: Bool = false) -> CGRect {
        let fit = min(box.width / CGFloat(image.width), box.height / CGFloat(image.height))
        let scale = wholePixels && fit >= 1 ? floor(fit) : fit
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        return CGRect(x: floor(box.midX - size.width / 2), y: floor(box.midY - size.height / 2), width: size.width, height: size.height)
    }
    static func feet(_ image: CGImage) -> [CGFloat] {
        guard let canvas = try? context(width: image.width, height: image.height),
              let data = canvas.data else { return [0.5] }
        GameStoneArt.drawImage(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height), context: canvas)
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var centres: [CGFloat] = [], start: Int?
        for x in 0...image.width {
            let opaque = x < image.width && pixels[(image.height - 1) * canvas.bytesPerRow + x * 4 + 3] > 192
            if opaque, start == nil { start = x }
            if !opaque, let left = start {
                centres.append(CGFloat(left + x) / (2 * CGFloat(image.width)))
                start = nil
            }
        }
        return centres.isEmpty ? [0.5] : centres
    }
    /// Read the top of the lettering directly beneath one foot.
    static func skyline(_ image: CGImage, at fraction: CGFloat) -> CGFloat {
        guard let canvas = try? context(width: image.width, height: image.height),
              let data = canvas.data else { return 0.3 }
        GameStoneArt.drawImage(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height), context: canvas)
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var tops: [Int] = []
        let centre = Int(CGFloat(image.width) * fraction)
        let radius = max(1, image.width / 200)
        for x in max(0, min(image.width - 1, centre - radius))...max(0, min(image.width - 1, centre + radius)) {
            if let y = (0..<image.height).first(where: { pixels[$0 * canvas.bytesPerRow + x * 4 + 3] > 192 }) {
                tops.append(y)
            }
        }
        tops.sort()
        return tops.isEmpty ? 0.3 : CGFloat(tops[tops.count / 2]) / CGFloat(image.height)
    }
    /// Preserve the original pixels and alpha while lighting each independent surface.
    static func surface(_ image: CGImage, in rect: CGRect, tint: CGColor? = nil, context: CGContext) {
        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        GameStoneArt.drawImage(image, in: rect, context: context)
        if let tint {
            context.setBlendMode(.sourceIn)
            context.setFillColor(tint)
            context.fill(rect)
        } else if let shine = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [CGColor(gray: 1, alpha: 0.02), CGColor(gray: 1, alpha: 0.32),
                     CGColor(gray: 1, alpha: 0.04), CGColor(gray: 1, alpha: 0)] as CFArray,
            locations: [0, 0.24, 0.28, 1]) {
            context.setBlendMode(.sourceAtop)
            context.drawLinearGradient(shine, start: CGPoint(x: rect.minX, y: rect.minY),
                end: CGPoint(x: rect.maxX, y: rect.maxY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        context.endTransparencyLayer()
        context.restoreGState()
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
