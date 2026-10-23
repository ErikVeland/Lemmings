import AppKit
import CoreGraphics
import Foundation
import LemmingsGameArt
import NxlvKit

private func imageBytes(_ image: CGImage) throws -> [UInt8] {
    guard image.bytesPerRow == image.width * 4, let data = image.dataProvider?.data else {
        throw Failure.invalid("Gameplay face pixels")
    }
    return Array(data as Data)
}

@MainActor func checkGameplayButtons(typography: GameMenuTypography, artwork: URL, output: URL) throws -> [CGImage?] {
    typealias Face = GamePlayButtonArt.Face
    let originalFaces: [Face] = [.rateDown, .rateUp] + (0..<8).map { .skill($0) } + [.pause, .endRun]
    let faces = originalFaces + [.speed, .rewind, .stepBackward, .stepForward, .hints, .rate]
    let palette: Set<UInt32> = [0x220000, 0x442222, 0x662222, 0x884444, 0xaa4444, 0xcc6666]
    guard let panel = typography.interface.counterPanel, panel.width == 640 else { throw Failure.invalid("Original Mac panel") }
    let original = Array(panel.rgba)
    var identities = Set<Data>(), preserved = 0
    for (index, face) in faces.enumerated() {
        guard let image = GamePlayButtonArt.image(for: face, width: 96, height: 80),
              let wider = GamePlayButtonArt.image(for: face, width: 320, height: 120) else { throw Failure.invalid("Gameplay rock") }
        let pixels = try imageBytes(image), widePixels = try imageBytes(wider)
        try check(identities.insert(Data(pixels)).inserted, "Gameplay buttons share a repeated face")
        for y in 0..<80 {
            for x in 0..<96 {
                let p = (y * 96 + x) * 4, q = (y * 320 + x) * 4
                if pixels[p..<p + 4] != widePixels[q..<q + 4] {
                    throw Failure.invalid("Gameplay face \(index) changes on resize at \(x),\(y): \(Array(pixels[p..<p + 4])) vs \(Array(widePixels[q..<q + 4]))")
                }
                let colour = UInt32(pixels[p]) << 16 | UInt32(pixels[p + 1]) << 8 | UInt32(pixels[p + 2])
                try check(palette.contains(colour) && pixels[p + 3] == 255, "Foreign pixels remain in gameplay rock")
            }
        }
        if index < 12 {
            var kept = 0
            for y in 0..<44 {
                for x in 0..<28 {
                    let sx = x + 2, sy = y + 2
                    if index < 10 && sx >= 3 && sx < 30 && sy < 21 { continue }
                    let p = (sy * 640 + 32 + index * 32 + sx) * 4
                    let colour = UInt32(original[p]) << 16 | UInt32(original[p + 1]) << 8 | UInt32(original[p + 2])
                    guard palette.contains(colour), original[p + 3] == 255 else { continue }
                    let q = (y * 96 + x) * 4
                    try check(original[p..<p + 4] == pixels[q..<q + 4], "Authored Macintosh rock was replaced")
                    kept += 1
                }
            }
            try check(kept > 40, "Missing original face \(index)")
            preserved += kept
        }
        for period in [16, 20, 26, 28, 32, 64] {
            let repeated = (64..<96).allSatisfy { y in
                (48..<256 - period).allSatisfy { x in
                    let a = (y * 320 + x) * 4, b = a + period * 4
                    return widePixels[a..<a + 4] == widePixels[b..<b + 4]
                }
            }
            try check(!repeated, "Gameplay face repeats a \(period)-pixel tile")
        }
        for selected in [false, true] {
            for monochrome in [false, true] {
                let size = CGSize(width: 64, height: 72), frame = CGRect(origin: .zero, size: size)
                let shared = try surface(size), native = try surface(size)
                if monochrome {
                    GameStoneArt.drawSocket(in: shared, frame: frame, selected: selected, pixel: 1, monochrome: true)
                    GameStoneArt.drawAccent(in: shared, frame: frame, selected: selected, pixel: 1, monochrome: true)
                } else {
                    GamePlayButtonArt.draw(in: shared, frame: frame, selected: selected, pixel: 1, face: face)
                }
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: native, flipped: true)
                GameStoneButton.draw(frame, selected: selected, pixel: 1, monochrome: monochrome, playFace: face)
                NSGraphicsContext.restoreGraphicsState()
                try check(bytes(shared) == bytes(native), "Native gameplay face differs from shared artwork")
            }
        }
    }

    let mac = try ClassicMacArtwork(directory: artwork)
    let poses: [ClassicLemmingPose] = [.climbing, .floating, .ohNo, .blocking, .building, .bashing, .mining, .digging]
    let icons: [CGImage?] = poses.enumerated().map { index, pose in
        guard let frame = mac.lemming(pose: pose, left: false, tick: index == 2 ? 12 : 0),
              let provider = CGDataProvider(data: frame.rgba as CFData),
              let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: frame.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        let pixels = Array(frame.rgba)
        var left = frame.width, top = frame.height, right = 0, bottom = 0
        for y in 0..<frame.height {
            for x in 0..<frame.width where pixels[(y * frame.width + x) * 4 + 3] != 0 {
                left = min(left, x); top = min(top, y); right = max(right, x + 1); bottom = max(bottom, y + 1)
            }
        }
        return image.cropping(to: CGRect(x: left, y: top, width: right - left, height: bottom - top))
    }
    let proof = try surface(CGSize(width: 1024, height: 300))
    proof.setFillColor(CGColor(gray: 0.025, alpha: 1)); proof.fill(CGRect(x: 0, y: 0, width: 1024, height: 300))
    let labels = ["-", "+", "CLIMB", "FLOAT", "BOMB", "BLOCK", "BUILD", "BASH", "MINE", "DIG", "PAUSE", "NUKE"]
    let largestWidth = CGFloat(icons.compactMap { $0?.width }.max() ?? 1)
    let largestHeight = CGFloat(icons.compactMap { $0?.height }.max() ?? 1)
    let spriteScale = max(1, floor(min(54 / largestWidth, 48 / largestHeight)))
    for row in 0..<2 {
        for (index, face) in originalFaces.enumerated() {
            let frame = CGRect(x: 16 + CGFloat(index) * 82, y: 18 + CGFloat(row) * 132, width: 74, height: 112)
            GamePlayButtonArt.draw(in: proof, frame: frame, selected: row == 1 && index == 6, pixel: 1, face: face)
            if row == 1 {
                let image: CGImage?
                if (2..<10).contains(index) { image = icons[index - 2] }
                else if index == 10 || index == 11 { image = isolatedSymbol(index == 10 ? .pause : .nuke) }
                else { image = nil }
                if let image {
                    let fit = (2..<10).contains(index) ? spriteScale
                        : max(1, floor(min(54 / CGFloat(image.width), 48 / CGFloat(image.height))))
                    let size = CGSize(width: CGFloat(image.width) * fit, height: CGFloat(image.height) * fit)
                    GameStoneArt.drawImage(image, in: CGRect(x: floor(frame.midX - size.width / 2), y: frame.minY + 24,
                        width: size.width, height: size.height), context: proof)
                }
                if index < 10 {
                    GameTextLayout.draw(index < 2 ? labels[index] : "5", in: CGRect(x: frame.minX + 4, y: frame.minY + 5,
                        width: frame.width - 8, height: 16), typography: typography, context: proof)
                }
            }
            GamePixelTypography.draw(labels[index], in: CGRect(x: frame.minX + 3, y: frame.maxY - 18,
                width: frame.width - 6, height: 12), context: proof, typography: typography,
                palette: .blue, maximumScale: 1, bitmapOnly: true)
        }
    }
    try save(proof, "gameplay-mac-rock", to: output)
    print("PASS 18 distinct gameplay faces, 72 native/state/monochrome comparisons, fixed grain, no periodic tiles and \(preserved) original Macintosh rock pixels preserved")
    return icons
}

private func isolatedSymbol(_ glyph: PanelGlyphArt) -> CGImage? {
    let rows = glyph.rows, width = rows[0].count
    var pixels = [UInt8](repeating: 0, count: width * rows.count * 4)
    for (y, row) in rows.enumerated() {
        for (x, mark) in row.enumerated() {
            guard let colour = glyph.colour(for: mark, transparentRock: true) else { continue }
            let p = (y * width + x) * 4
            pixels[p..<p + 4] = [colour.0, colour.1, colour.2, 255]
        }
    }
    guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
    return CGImage(width: width, height: rows.count, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
        decode: nil, shouldInterpolate: false, intent: .defaultIntent)
}
