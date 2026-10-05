import AppKit
import Foundation

func require(_ value: @autoclosure () -> Bool, _ message: String) {
    if !value() { fatalError(message) }
}

func colours(_ frame: SequelEffectArtwork.Frame) -> Set<[UInt8]> {
    Set(stride(from: 0, to: frame.rgba.count, by: 4).compactMap { offset in
        frame.rgba[offset + 3] == 0 ? nil : Array(frame.rgba[offset..<offset + 3])
    })
}

@MainActor func run() throws {
    let rope = SequelEffectArtwork.mark(red: 160, green: 112, blue: 48, kind: .rope)
    let particle = SequelEffectArtwork.mark(red: 160, green: 112, blue: 48, kind: .particle)
    let pole = SequelEffectArtwork.mark(red: 160, green: 112, blue: 48, kind: .pole)
    for (name, mark) in [("rope", rope), ("particle", particle), ("pole", pole)] {
        require(mark.width == 2 && mark.height == 2, "\(name) changed its game footprint")
        require(mark.rgba.count == 16, "\(name) has invalid pixel data")
        require(stride(from: 3, to: 16, by: 4).allSatisfy { mark.rgba[$0] == 255 },
            "\(name) changed source opacity")
        require(colours(mark).count > 1, "\(name) has no recreated detail")
    }
    let ring = SequelEffectArtwork.blastRing()
    let fireball = SequelEffectArtwork.fireball()
    for (name, frame) in [("ring", ring), ("fireball", fireball)] {
        require(stride(from: 3, to: frame.rgba.count, by: 4).allSatisfy {
            frame.rgba[$0] == 0 || frame.rgba[$0] == 255
        }, "\(name) has translucent pixels")
    }
    require(ring.width == 80 && ring.height == 80, "Blast ring changed its 40×40 game footprint")
    require(fireball.width == 12 && fireball.height == 8, "Fireball changed its 6×4 game footprint")
    require(ring.rgba[(40 * ring.width + 40) * 4 + 3] == 0, "Blast ring filled its centre")
    require(colours(ring).count >= 3 && colours(fireball).count >= 4,
        "Effect artwork lost its highlight and shadow colours")
    var occupiedArcs = [Bool](repeating: false, count: 64)
    var highlightArcs = occupiedArcs, shadowArcs = occupiedArcs
    for y in 0..<ring.height { for x in 0..<ring.width {
        let offset = (y * ring.width + x) * 4
        guard ring.rgba[offset + 3] > 0 else { continue }
        let sector = Int((atan2(Double(y * 2 - 79), Double(x * 2 - 79))
            + Double.pi) * 64 / (2 * Double.pi)) % 64
        occupiedArcs[sector] = true
        let rgb = Array(ring.rgba[offset..<offset + 3])
        if rgb == [255, 209, 85] { highlightArcs[sector] = true }
        if rgb == [165, 55, 24] { shadowArcs[sector] = true }
    } }
    func arcRuns(_ flags: [Bool]) -> Int {
        flags.indices.filter { flags[$0] && !flags[($0 + flags.count - 1) % flags.count] }.count
    }
    let gapRuns = arcRuns(occupiedArcs.map { !$0 }), brightRuns = arcRuns(highlightArcs)
    let darkRuns = arcRuns(shadowArcs)
    require(gapRuns >= 3 && brightRuns >= 3 && darkRuns >= 3,
        "Blast ring lost its separated pixel clusters")
    print("Blast ring arcs: gaps=\(gapRuns), highlights=\(brightRuns), shadows=\(darkRuns)")
    var sourcePalette = [UInt8](repeating: 0, count: 1024)
    sourcePalette[16..<20] = [160, 112, 48, 255]
    require(SequelEffectArtwork.markImage(palette: sourcePalette, colourIndex: 4,
        kind: .rope)?.size == NSSize(width: 1, height: 1),
        "Rope mark has the wrong logical size")
    require(SequelEffectArtwork.blastRingImage?.size == NSSize(width: 40, height: 40),
        "Blast ring has the wrong logical size")
    require(SequelEffectArtwork.fireballImage?.size == NSSize(width: 6, height: 4),
        "Fireball has the wrong logical size")

    let width = 720, height = 400
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for offset in stride(from: 0, to: pixels.count, by: 4) {
        pixels[offset..<offset + 4] = [24, 28, 34, 255]
    }
    func blit(_ frame: SequelEffectArtwork.Frame, x: Int, y: Int, scale: Int) {
        for sourceY in 0..<frame.height { for sourceX in 0..<frame.width {
            let source = (sourceY * frame.width + sourceX) * 4
            guard frame.rgba[source + 3] != 0 else { continue }
            for dy in 0..<scale { for dx in 0..<scale {
                let targetX = x + sourceX * scale + dx, targetY = y + sourceY * scale + dy
                let target = (targetY * width + targetX) * 4
                pixels[target..<target + 4] = frame.rgba[source..<source + 4]
            } }
        } }
    }
    blit(ring, x: 18, y: 40, scale: 4)
    blit(fireball, x: 385, y: 84, scale: 16)
    for (index, mark) in [rope, particle, pole].enumerated() {
        blit(mark, x: 404 + index * 100, y: 290, scale: 24)
    }
    guard let provider = CGDataProvider(data: Data(pixels) as CFData),
          let image = CGImage(width: width, height: height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { fatalError("Could not render effect proof") }
    let path = URL(fileURLWithPath: ".build/sequel-effect-artwork/proof.png")
    try png.write(to: path, options: .atomic)
    print("PASS sequel effects keep their game footprints and add 2× detail: \(path.path)")
}

try run()
