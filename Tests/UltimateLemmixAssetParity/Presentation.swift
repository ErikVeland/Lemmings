import AppKit
import CryptoKit
import Foundation
import LemmingsAppCore
import LemmingsGameArt
import NxlvKit

enum PanelButton: Equatable {
    case nuke, pause, fastForward, rateDown, rateUp, skill(Int)
}

@MainActor enum GamePixelText {
    static func draw(_ text: String, in rect: CGRect, maxScale: CGFloat) {}
}

@main struct PresentationParity {
    @MainActor static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else { throw CocoaError(.fileReadInvalidFileName) }
        UserDefaults.standard.setVolatileDomain([GameArtworkSkin.key: false], forName: UserDefaults.argumentDomain)
        try GameResources.activate(bundleURL: URL(fileURLWithPath: arguments[1]))
        #if OWNED_PANEL_RECOVERY
        guard OwnedClassicPanelArt.decode(Data(repeating: 0, count: 12_799)) == nil,
              OwnedClassicPanelArt.decode(Data(repeating: 0, count: 12_801)) == nil,
              OwnedClassicPanelArt.decode(Data(repeating: 0, count: 12_800)) == nil else {
            throw CocoaError(.fileReadCorruptFile)
        }
        #endif
        var results: [String: String] = [:]
        func record(_ name: String, _ image: CGImage?) throws {
            guard let image else { results[name] = "MISSING"; return }
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            guard let context = CGContext(data: &bytes, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.coderInvalidValue) }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            results[name] = "\(image.width)x\(image.height):" + SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
        }
        func raster(_ name: String, width: Int = 480, height: Int = 120,
                    draw: (CGContext) -> Void) throws {
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.coderInvalidValue) }
            draw(context)
            try record(name, context.makeImage())
        }
        for glyph in [PanelGlyph.rock, .pause, .nuke] {
            for scale in 1...3 {
                let box = CGSize(width: 14 * scale, height: 22 * scale)
                for transparent in [false, true] {
                    let image = glyph.image(fitting: box, transparentRock: transparent)
                    try record("mac-shell/\(glyph.rawValue)/\(scale)/colour/\(transparent)", image?.cgImage(forProposedRect: nil, context: nil, hints: nil))
                    let mac = glyph.macImage(fitting: box, transparentRock: transparent)
                    try record("mac-shell/\(glyph.rawValue)/\(scale)/mac/\(transparent)", mac?.cgImage(forProposedRect: nil, context: nil, hints: nil))
                }
                let mono = glyph.monochromeImage(fitting: box)
                try record("mac-shell/\(glyph.rawValue)/\(scale)/mono", mono?.cgImage(forProposedRect: nil, context: nil, hints: nil))
                try record("shared/\(glyph.rawValue)/\(scale)", PanelGlyphArt(rawValue: glyph.rawValue)!.cgImage(scale: scale))
                try record("shared/\(glyph.rawValue)/\(scale)/transparent", PanelGlyphArt(rawValue: glyph.rawValue)!.cgImage(scale: scale, transparentRock: true))
            }
        }
        try raster("stone") { context in
            GameStoneArt.drawSocket(in: context, frame: CGRect(x: 0, y: 0, width: 160, height: 80), selected: false, pixel: 2)
            GameStoneArt.drawSocket(in: context, frame: CGRect(x: 170, y: 0, width: 160, height: 80), selected: true, pixel: 2)
        }
        for height in [20, 40] {
            try raster("font/\(height)") { context in
                _ = GameLemmingsTypography.draw("Ready 0123", in: CGRect(x: 0, y: 0, width: 480, height: 120), height: CGFloat(height), context: context)
            }
        }
        try record("logo", GameArtworkResources.interface?.logo.flatMap { GameMenuLogo.image(for: $0) })
        let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: arguments[2]))
        print("Captured \(results.count) offscreen presentation states")
    }
}
