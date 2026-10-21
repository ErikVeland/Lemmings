@MainActor private func testLemmingsTypography() throws {
    guard let renderer = GameMenuArtwork.renderer() else {
        throw IntegrationFailure(message: "Missing Lemmings character sets")
    }
    let typography = GameMenuTypography(interface: renderer.interface)
    let output = URL(fileURLWithPath: ".build/lemmings-typography")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    func canvas(_ size: CGSize) -> CGContext {
        let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
        return context
    }
    func bytes(_ context: CGContext) -> Data {
        Data(bytes: context.data!, count: context.bytesPerRow * context.height)
    }
    func shot(_ context: CGContext, _ name: String) throws {
        try NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
            .write(to: output.appendingPathComponent(name + ".png"))
    }
    for face in GameMenuTypography.Face.allCases {
        let font = typography.font(face)!
        for scale in (face == .large ? [1, 2, 4] : [1, 2]) {
            let text = scale == 4 ? "0123456789" : "LEMMINGS 0123456789 ÅÉÑŒẞ"
            let size = CGSize(width: font.width(of: text, scale: scale), height: font.height(of: text, scale: scale))
            let authored = canvas(size), fitted = canvas(size), nearest = canvas(size)
            let vertical = font.verticalBounds(of: text), horizontal = font.horizontalBounds(of: text)
            typography.draw(text, face: face,
                at: CGPoint(x: -horizontal.left * scale, y: -vertical.top * scale), scale: scale, in: authored)
            for item in font.layout(text) {
                guard let glyph = item.glyph, let provider = CGDataProvider(data: glyph.rgba as CFData),
                    let image = CGImage(width: glyph.width, height: glyph.height, bitsPerComponent: 8, bitsPerPixel: 32,
                        bytesPerRow: glyph.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                        decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { continue }
                nearest.interpolationQuality = .none
                GameStoneArt.drawImage(image, in: CGRect(x: (item.x + glyph.x - horizontal.left) * scale,
                    y: (glyph.y - vertical.top) * scale, width: glyph.width * scale, height: glyph.height * scale), context: nearest)
            }
            try check(GameLemmingsTypography.draw(text, in: CGRect(origin: .zero, size: size),
                height: CGFloat(font.cellHeight * scale), interface: typography.interface, face: face,
                context: fitted), "Lemmings face failed at its authored size")
            try check(bytes(authored) == bytes(fitted), "The shared renderers disagree on a font cut")
            try check((bytes(authored) == bytes(nearest)) == (scale == 1),
                "The original 1× artwork changed, or a display cut is only a stretched copy")
        }
    }
    let atlasFolder = output.appendingPathComponent("display2x")
    try FileManager.default.createDirectory(at: atlasFolder, withIntermediateDirectories: true)
    let characters = (32...126).map { String(Unicode.Scalar($0)!) }
        + BitmapLatinGlyphs.characters.map { String($0) } + ["💀"]
    for face in GameMenuTypography.Face.allCases {
        let font = typography.font(face)!
        let entries = try characters.compactMap { text -> (String, GameLemmingsDisplayFace.Glyph)? in
            guard let glyph = font.glyph(forSequence: text) else { return nil }
            let cut = GameLemmingsDisplayFace.frame(glyph, sequence: text, cellWidth: font.cellWidth, cellHeight: font.cellHeight)
            try check(cut.width == glyph.width * 2 && cut.height == glyph.height * 2
                && cut.x == glyph.x * 2 && cut.y == glyph.y * 2, "Display glyph changed its doubled bounds")
            return (text, cut)
        }
        let cellWidth = (entries.map { $0.1.width }.max() ?? 32) + 8
        let cellHeight = (entries.map { $0.1.height }.max() ?? 40) + 8
        let columns = 16, rows = (entries.count + columns - 1) / columns
        var metrics: [[String: Any]] = []
        if !entries.contains(where: { $0.0 == " " }) {
            metrics.append(["text": " ", "x": 0, "y": 0, "width": 0, "height": 0,
                "offsetX": 0, "offsetY": 0, "advance": font.cellWidth * 2])
        }
        for green in [false, true] {
            let context = canvas(CGSize(width: cellWidth * columns, height: cellHeight * rows))
            for (index, entry) in entries.enumerated() {
                let (text, glyph) = entry
                var rgba = glyph.rgba
                if green {
                    rgba.withUnsafeMutableBytes { raw in
                        let bytes = raw.bindMemory(to: UInt8.self)
                        for i in stride(from: 0, to: bytes.count, by: 4) {
                            let red = bytes[i], green = bytes[i + 1], blue = bytes[i + 2]
                            bytes[i] = green; bytes[i + 1] = blue; bytes[i + 2] = red
                        }
                    }
                }
                let provider = CGDataProvider(data: rgba as CFData)!
                let image = CGImage(width: glyph.width, height: glyph.height, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: glyph.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                    decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
                let x = index % columns * cellWidth + 4, y = index / columns * cellHeight + 4
                GameStoneArt.drawImage(image, in: CGRect(x: x, y: y, width: glyph.width, height: glyph.height), context: context)
                if !green {
                    metrics.append(["text": text, "x": x, "y": y, "width": glyph.width, "height": glyph.height,
                        "offsetX": glyph.x, "offsetY": glyph.y, "advance": font.advance(forSequence: text) * 2])
                }
            }
            try shot(context, "display2x/\(face == .large ? "large" : "small")-\(green ? "green" : "blue")")
        }
        let metadata: [String: Any] = ["version": 1, "scale": 2, "face": face.rawValue,
            "cellWidth": font.cellWidth * 2, "cellHeight": font.cellHeight * 2, "glyphs": metrics]
        try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            .write(to: atlasFolder.appendingPathComponent("\(face == .large ? "large" : "small")-metrics.json"))
    }
    let display = canvas(CGSize(width: 1060, height: 400))
    display.setFillColor(CGColor(gray: 0, alpha: 1)); display.fill(CGRect(x: 0, y: 0, width: 1060, height: 400))
    for (index, text) in ["ABCDEFGHIJKLMNOPQRSTUVWXYZ", "0123456789  !?&%+-*/", "ÅÉÑŒÆØẞ  ÇŽŠ  ÀÈÌÒÙ", "ULTIMATE LEMMINGS"].enumerated() {
        typography.menuLine(text, in: CGRect(x: 40, y: 24 + CGFloat(index) * 84, width: 980, height: 56),
            context: display, face: .large, scale: 2, palette: index == 1 ? .blue : .green)
    }
    try shot(display, "display2x-preview")
    let countdownFolder = output.appendingPathComponent("countdown4x")
    try FileManager.default.createDirectory(at: countdownFolder, withIntermediateDirectories: true)
    let large = typography.font(.large)!
    var countdownMetrics: [[String: Any]] = []
    for green in [false, true] {
        let atlas = canvas(CGSize(width: 360, height: 176))
        for number in 0...9 {
            let text = String(number), source = large.glyph(forSequence: text)!
            let glyph = GameLemmingsCountdownFace.frame(source, sequence: text)!
            try check(glyph.x == source.x * 4 && glyph.y == source.y * 4
                && glyph.width == source.width * 4 && glyph.height == source.height * 4,
                "A countdown digit changed its 4× metrics")
            var rgba = [UInt8](glyph.rgba)
            let two = GameLemmingsDisplayFace.frame(source, sequence: text, cellWidth: 16, cellHeight: 20)
            let doubled = [UInt8](two.rgba)
            try check((0..<glyph.height).contains { y in (0..<glyph.width).contains { x in
                rgba[(y * glyph.width + x) * 4 + 3] != doubled[((y / 2) * two.width + x / 2) * 4 + 3]
            } }, "A countdown contour was only enlarged from 2×")
            if green { for i in stride(from: 0, to: rgba.count, by: 4) {
                let r = rgba[i]; rgba[i] = rgba[i + 1]; rgba[i + 1] = rgba[i + 2]; rgba[i + 2] = r
            } }
            let image = CGImage(width: glyph.width, height: glyph.height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: glyph.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: CGDataProvider(data: Data(rgba) as CFData)!, decode: nil,
                shouldInterpolate: false, intent: .defaultIntent)!
            let x = number % 5 * 72 + 4, y = number / 5 * 88 + 4
            GameStoneArt.drawImage(image, in: CGRect(x: x, y: y, width: glyph.width, height: glyph.height), context: atlas)
            if !green { countdownMetrics.append(["text": text, "x": x, "y": y, "width": glyph.width,
                "height": glyph.height, "offsetX": glyph.x, "offsetY": glyph.y,
                "advance": large.advance(forSequence: text) * 4]) }
        }
        try shot(atlas, "countdown4x/\(green ? "green" : "blue")")
    }
    let countdownMetadata: [String: Any] = ["version": 1, "scale": 4, "cellWidth": 64,
        "cellHeight": 80, "baseline": 80, "sampling": "nearest", "glyphs": countdownMetrics]
    try JSONSerialization.data(withJSONObject: countdownMetadata, options: [.prettyPrinted, .sortedKeys])
        .write(to: countdownFolder.appendingPathComponent("metrics.json"))
    let countdownPreview = canvas(CGSize(width: 760, height: 300))
    countdownPreview.setFillColor(CGColor(gray: 0, alpha: 1))
    countdownPreview.fill(CGRect(x: 0, y: 0, width: 760, height: 300))
    for (index, palette) in [GameMenuTypography.Palette.blue, .green].enumerated() {
        typography.draw("0123456789", face: .large, at: CGPoint(x: 60, y: 16 + index * 96), scale: 4,
            in: countdownPreview, palette: palette)
    }
    typography.draw("3  2  1", face: .large, at: CGPoint(x: 156, y: 208), scale: 4,
        in: countdownPreview, palette: .green)
    try shot(countdownPreview, "countdown4x-preview")
    let sample = canvas(CGSize(width: 1400, height: 1280))
    sample.setFillColor(CGColor(gray: 0, alpha: 1)); sample.fill(CGRect(x: 0, y: 0, width: 1400, height: 1280))
    var y: CGFloat = 12
    for height: CGFloat in [12, 14, 18, 21, 24, 28, 32, 40, 56, 64, 88, 104] {
        _ = GameLemmingsTypography.draw(String(Int(height)), in: CGRect(x: 0, y: y, width: 90, height: height + 8),
            height: 18, interface: typography.interface, alignment: .right, context: sample)
        try check(GameLemmingsTypography.draw("LEMMINGS 3  0123456789", in: CGRect(x: 110, y: y, width: 1280, height: height + 8),
            height: height, interface: typography.interface, palette: .green, alignment: .left, context: sample),
            "An intermediate Lemmings size fell back to the tiny face")
        y += height + 20
    }
    for text in ["ÅÉÑŒẞ  ŽIVOT  FRANÇAIS", "தமிழ்  உயிர்கள் 123"] {
        try check(!GameMenuTypography.menuText(text).contains("?"), "Extended font characters became question marks")
        try check(GameLemmingsTypography.draw(text, in: CGRect(x: 110, y: y, width: 1280, height: 80),
            height: 32, interface: typography.interface, palette: .blue, alignment: .left, context: sample),
            "Extended glyphs could not use the Lemmings face")
        y += 96
    }
    try shot(sample, "lettering-sizes")
    for height: CGFloat in [7, 10, 14, 21, 56, 80, 104] {
        let size = CGSize(width: 160, height: max(16, height))
        let full = canvas(size), half = canvas(size), hidden = canvas(size)
        for (context, alpha) in [(full, CGFloat(1)), (half, CGFloat(0.5)), (hidden, CGFloat(0))] {
            context.setAlpha(alpha)
            let fitted = GameLemmingsTypography.draw("3", in: CGRect(origin: .zero, size: size), height: height,
                interface: typography.interface, palette: .green, context: context)
            try check(fitted == (height >= 12), "Tiny HUD lettering lost its size boundary")
        }
        let f = [UInt8](bytes(full)), h = [UInt8](bytes(half)), z = [UInt8](bytes(hidden))
        try check(z.allSatisfy { $0 == 0 }, "Lemmings lettering ignored its group's hidden state")
        if height >= 12 {
            let visible = stride(from: 3, to: f.count, by: 4).filter { f[$0] > 0 }
            try check(!visible.isEmpty && visible.allSatisfy { abs(Int(h[$0]) * 2 - Int(f[$0])) <= 1 },
                "Lemmings lettering ignored its group's partial opacity")
        }
    }
    for number in [3, 2, 1] {
        let context = canvas(CGSize(width: 560, height: 190))
        context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 560, height: 190))
        for (index, size) in [CGSize(width: 64, height: 80), CGSize(width: 80, height: 96), CGSize(width: 104, height: 104)].enumerated() {
            let box = CGRect(x: CGFloat(index) * 180 + 40, y: 24, width: size.width, height: size.height)
            try check(GameLemmingsTypography.draw(String(number), in: box, height: 80,
                interface: typography.interface, face: .large, palette: .green, context: context),
                "A platform's start countdown lost its Lemmings numeral")
        }
        try shot(context, "countdown-\(number)")
    }
    let hud = canvas(CGSize(width: 900, height: 140))
    hud.setFillColor(CGColor(gray: 0, alpha: 1)); hud.fill(CGRect(x: 0, y: 0, width: 900, height: 140))
    for (index, name) in ["CLIMB", "FLOAT", "BOMB", "BLOCK", "BUILD", "BASH", "MINE", "DIG"].enumerated() {
        typography.menuLine(index < 2 ? "50" : "0", in: CGRect(x: 36 + CGFloat(index) * 100, y: 30, width: 80, height: 36),
            context: hud, scale: 2)
        GamePixelTypography.draw(name, in: CGRect(x: 36 + CGFloat(index) * 100, y: 78, width: 80, height: 10),
            context: hud, typography: typography, maximumScale: 1, bitmapOnly: true)
    }
    try shot(hud, "tiny-hud")
    print("PASS original 1×, retouched 2×, hand-drawn 4× numerals and atlases, 12 sizes, extended Latin/Tamil, tiny HUD, countdowns and inherited fades")
}
