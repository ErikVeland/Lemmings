import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import WidgetKit

/// Compile with the shared widget source and LEMMINGS_WIDGET_AUDIT. Run through UITestRunner.
@main @MainActor struct DeskClockWidgetViewAudit {
    static func main() {
        do { try run() }
        catch {
            FileHandle.standardError.write(Data("FAIL widget appearance audit: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run() throws {
        let input = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var captures = 0
        for family in ["small", "medium", "large"] {
            let url = input.appendingPathComponent("widget-mac-\(family)-soon.png")
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw Failure.image }
            for (name, mode) in [("full-color", WidgetRenderingMode.fullColor),
                                 ("accented", .accented), ("vibrant", .vibrant)] {
                let content = ClockArtworkImage(image: image)
                    .frame(width: CGFloat(image.width) / 2, height: CGFloat(image.height) / 2)
                    .environment(\.widgetRenderingMode, mode)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                guard let rendered = renderer.cgImage,
                      rendered.width == image.width, rendered.height == image.height else { throw Failure.image }
                let pixels = try rgba(rendered)
                let alphas = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
                if mode == .vibrant {
                    // Desktop tinting needs the clock silhouette, rather than an opaque rectangular mask.
                    guard alphas.contains(0), alphas.contains(where: { $0 > 0 }),
                          alphas.filter({ $0 == 0 }).count > alphas.count / 4 else { throw Failure.opaqueVibrancy }
                    let visible = stride(from: 0, to: pixels.count, by: 4).filter { pixels[$0] > 0 }.count
                    guard visible > alphas.count / 20 else { throw Failure.image }
                } else {
                    guard alphas.allSatisfy({ $0 == 255 }) else { throw Failure.image }
                    let colours = stride(from: 0, to: pixels.count, by: 4).filter {
                        abs(Int(pixels[$0]) - Int(pixels[$0 + 1])) > 20
                    }.count
                    guard colours > alphas.count / 20 else { throw Failure.image }
                }
                let destination = output.appendingPathComponent("\(family)-\(name).png")
                guard let writer = CGImageDestinationCreateWithURL(destination as CFURL, "public.png" as CFString, 1, nil)
                else { throw Failure.image }
                CGImageDestinationAddImage(writer, rendered, nil)
                guard CGImageDestinationFinalize(writer) else { throw Failure.image }
                captures += 1
            }
        }
        print("PASS \(captures) SwiftUI widget appearance renders. No windows or audio.")
    }

    private static func rgba(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.image }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }

    private enum Failure: Error { case image, opaqueVibrancy }
}
