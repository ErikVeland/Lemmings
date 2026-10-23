import AppKit
import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

// PanelGlyphs also supplies the native socket adapter. These types belong to its host app.
enum PanelButton: Equatable { case nuke, pause, fastForward, rateDown, rateUp, skill(Int) }
@MainActor enum GamePixelText {
    static func draw(_ text: String, in rect: CGRect, maxScale: CGFloat) {}
}

enum Failure: Error { case invalid(String) }
func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw Failure.invalid(message) }
}
func surface(_ size: CGSize) throws -> CGContext {
    guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
        bitsPerComponent: 8, bytesPerRow: Int(size.width) * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.invalid("Bitmap") }
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1, y: -1)
    return context
}
func bytes(_ context: CGContext) -> [UInt8] {
    Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self),
        count: context.bytesPerRow * context.height))
}
func save(_ context: CGContext, _ name: String, to output: URL) throws {
    guard let image = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { throw Failure.invalid("PNG") }
    try png.write(to: output.appendingPathComponent(name + ".png"))
}

@main struct StoneButtonAudit {
    @MainActor static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let artwork = Bundle.main.resourceURL!.appendingPathComponent("MacArtwork/lemmings")
        guard let typography = GameMenuTypography(directory: artwork) else { throw Failure.invalid("Mac artwork") }
        let gameplayIcons = try checkGameplayButtons(typography: typography, artwork: artwork, output: output)

        // NSImage materialisation requires application registration on this host.
        // Check the shared source colours without opening an AppKit image context.
        for glyph in [PanelGlyphArt.pause, .nuke] {
            for mark in glyph.rows.flatMap(Array.init) {
                let colour = glyph.colour(for: mark, transparentRock: true)
                if "9abcde".contains(mark) { try check(colour == nil, "Old rock remains around symbol") }
                if glyph == .pause && mark == "0" {
                    try check((colour?.0 ?? 0) >= 190 && (colour?.1 ?? 0) >= 220, "Pause is lost against dark rock")
                }
            }
        }

        // Resizing may expose more rock, but must never magnify its grain or change its contrast.
        for selected in [false, true] {
            for pixel: CGFloat in [1, 2] {
                let narrow = try surface(CGSize(width: 44, height: 44))
                GameStoneArt.drawSocket(in: narrow, frame: CGRect(x: 0, y: 0, width: 44, height: 44),
                    selected: selected, pixel: pixel)
                let reference = bytes(narrow)
                for size in [CGSize(width: 128, height: 44), .init(width: 320, height: 44),
                             .init(width: 656, height: 44), .init(width: 1200, height: 180)] {
                    let wide = try surface(size)
                    GameStoneArt.drawSocket(in: wide, frame: CGRect(origin: .zero, size: size),
                        selected: selected, pixel: pixel)
                    let result = bytes(wide)
                    let inset = Int(4 * pixel)
                    for y in inset..<44 - inset {
                        for x in inset..<44 - inset {
                            let a = (y * narrow.width + x) * 4
                            let b = (y * wide.width + x) * 4
                            if reference[a..<a + 4] != result[b..<b + 4] {
                                throw Failure.invalid("Button size changed grain at \(x),\(y), bevel \(pixel), selected \(selected), \(size): \(Array(reference[a..<a + 4])) vs \(Array(result[b..<b + 4]))")
                            }
                            let idle = selected ? (56, 80, 34) : (22, 30, 19)
                            try check(abs(Int(result[b]) - idle.0) <= 24
                                && abs(Int(result[b + 1]) - idle.1) <= 24
                                && abs(Int(result[b + 2]) - idle.2) <= 24, "Rock contrast overwhelms the socket")
                        }
                    }
                }
            }
        }

        // The native adapter must use exactly the same surface, including Retina-sized bevels.
        for size in [CGSize(width: 44, height: 44), .init(width: 128, height: 48),
                     .init(width: 320, height: 56), .init(width: 656, height: 46)] {
            for pixel: CGFloat in [1, 2] {
                for selected in [false, true] {
                    for monochrome in [false, true] {
                        let frame = CGRect(origin: .zero, size: size)
                        let shared = try surface(size), native = try surface(size)
                        GameStoneArt.drawSocket(in: shared, frame: frame, selected: selected, pixel: pixel, monochrome: monochrome)
                        GameStoneArt.drawAccent(in: shared, frame: frame, selected: selected, pixel: pixel, monochrome: monochrome)
                        NSGraphicsContext.saveGraphicsState()
                        NSGraphicsContext.current = NSGraphicsContext(cgContext: native, flipped: true)
                        GameStoneButton.draw(frame, selected: selected, pixel: pixel, monochrome: monochrome)
                        NSGraphicsContext.restoreGraphicsState()
                        let rgba = bytes(shared)
                        try check(rgba == bytes(native), "Native/shared socket mismatch")
                        var colours = Set<UInt32>()
                        let well = GameStoneArt.well(frame, pixel: pixel).insetBy(dx: 2, dy: 3 * pixel)
                        for y in Int(well.minY)..<Int(well.maxY) {
                            for x in Int(well.minX)..<Int(well.maxX) {
                                let i = ((shared.height - 1 - y) * shared.width + x) * 4
                                colours.insert(UInt32(rgba[i]) << 16 | UInt32(rgba[i + 1]) << 8 | UInt32(rgba[i + 2]))
                            }
                        }
                        try check(monochrome ? colours.count == 1 : colours.count >= 4,
                            "Missing original rock or changed monochrome face: \(size), bevel \(pixel), selected \(selected), mono \(monochrome), \(colours.count) colours")
                        // The former reconstructed stamp repeated every 26 pixels.
                        if size.width >= 128 && !monochrome {
                            let y = shared.height / 2
                            let matches = (12..<100).allSatisfy { x in
                                let a = (y * shared.width + x) * 4, b = a + 26 * 4
                                return rgba[a..<a + 4] == rgba[b..<b + 4]
                            }
                            try check(!matches, "Repeated panel stamp")
                        }
                        try check(stride(from: 3, to: rgba.count, by: 4).allSatisfy {
                            let p = $0 / 4, x = p % shared.width, y = p / shared.width
                            return (x > 0 && x < shared.width - 1 && y > 0 && y < shared.height - 1) || rgba[$0] == 0
                        }, "Stone escaped its input bounds")
                    }
                }
            }
        }

        let page = GameFrontEnd.Page(title: "Stone controls", rows: [
            .init("normal", "Normal"), .init("selected", "Selected", selected: true),
            .init("disabled", "Unavailable", enabled: false)], footer: [
                .init("back", "Back"), .init("retry", "Retry", primary: true)])
        for (name, size) in [("iphone", CGSize(width: 390, height: 763)),
                             ("narrow-phone", .init(width: 320, height: 548)),
                             ("ipad", .init(width: 834, height: 1092)),
                             ("mac", .init(width: 720, height: 520))] {
            let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
            let context = try surface(layout.size)
            GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "normal", in: context)
            for target in layout.targets {
                try check(target.frame.height >= 44, "Short menu input target")
                try check(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY))
                    == (target.action.enabled ? target.action.id : nil), "Incorrect menu target")
            }
            try save(context, name, to: output)
        }
        let tv = try surface(TVMenuArt.size)
        TVMenuArt.draw(page, focused: "normal", typography: typography, in: tv)
        try save(tv, "tv", to: output)
        for target in TVMenuArt.layout(page).targets {
            try check(target.frame.height >= 44, "Short TV input target")
        }

        for engine in ["classic", "lemmings2", "lemmings3"] {
            let names = engine == "lemmings3" ? ["Walker", "Builder", "Blocker"]
                : ["Climber", "Floater", "Bomber", "Blocker", "Builder", "Basher", "Miner", "Digger"]
            let snapshot = MobileGameSnapshot(tick: 120, released: 10, total: 20, saved: 4, required: 10,
                remainingSeconds: 120, releaseRate: engine == "classic" ? 50 : nil, isComplete: false,
                didWin: false, isEndingRun: false, skills: names.map { .init(name: $0, count: 5) })
            for (name, size) in [("phone", MobileSize(width: 390, height: 763)),
                                 ("landscape", .init(width: 844, height: 390)),
                                 ("tablet", .init(width: 1112, height: 814)),
                                 ("tv", .init(width: 1920, height: 1080))] {
                let layout = MobileHUDLayout.make(container: size, safeArea: .init(), hasRate: snapshot.releaseRate != nil,
                    skillCount: names.count, supportsRewind: true, engineIdentifier: engine, television: name == "tv")
                let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot, selectedSkill: 0,
                    paused: true, speed: 1, endRunArmed: false)
                for target in targets {
                    try check(target.inputFrame.width >= 44 && target.inputFrame.height >= 44, "Short HUD input target")
                    try check(!target.accessibilityLabel.isEmpty, "Unnamed HUD input target")
                }
                for paused in [false, true] {
                    let context = try surface(CGSize(width: size.width, height: size.height))
                    context.setFillColor(CGColor(gray: 0.025, alpha: 1))
                    context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    let renderer = MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: 0,
                        paused: paused, speed: 1, endRunArmed: false, panelImage: nil, typography: typography,
                        skillIcons: engine == "classic" ? gameplayIcons : [])
                    renderer.draw(in: context, bounds: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    try save(context, "hud-\(engine)-\(name)-\(paused ? "paused" : "playing")", to: output)
                }
            }
        }

        let proof = try surface(CGSize(width: 720, height: 300))
        proof.setFillColor(CGColor(gray: 0.025, alpha: 1)); proof.fill(CGRect(x: 0, y: 0, width: 720, height: 300))
        for (row, label) in ["NORMAL", "SELECTED", "DISABLED"].enumerated() {
            for (column, width) in [CGFloat(44), 128, 320].enumerated() {
                let frame = CGRect(x: [CGFloat(20), 84, 232][column], y: CGFloat(20 + row * 88), width: width, height: 64)
                proof.saveGState()
                proof.setAlpha(row == 2 ? 0.45 : 1)
                GameStoneArt.draw(in: proof, frame: frame, selected: row == 1, pixel: 1)
                if column == 0, let image = PanelGlyphArt.settings.cgImage(scale: 1) {
                    GameStoneArt.drawImage(image, in: CGRect(x: frame.midX - 7.5, y: frame.midY - 7.5, width: 15, height: 15), context: proof)
                } else if column > 0 {
                    GameTextLayout.draw(label, in: frame.insetBy(dx: 8, dy: 4), typography: typography,
                        palette: row == 1 ? .green : .blue, context: proof)
                }
                proof.restoreGState()
            }
        }
        try save(proof, "button-states", to: output)
        let grainProof = try surface(CGSize(width: 720, height: 290))
        grainProof.setFillColor(CGColor(gray: 0.025, alpha: 1))
        grainProof.fill(CGRect(x: 0, y: 0, width: 720, height: 290))
        for (index, width) in [CGFloat(44), 128, 320, 656].enumerated() {
            let frame = CGRect(x: 20, y: 16 + CGFloat(index) * 66, width: width, height: 44)
            GameStoneArt.draw(in: grainProof, frame: frame, selected: false, pixel: 1)
        }
        try save(grainProof, "fixed-rock-grain", to: output)
        print("PASS 32 native/shared socket comparisons, 16 fixed-grain resize comparisons, subtle contrast, original rock, monochrome, clipping, 5 menu renders and 24 HUD renders across all three engines, with input targets")
    }
}
