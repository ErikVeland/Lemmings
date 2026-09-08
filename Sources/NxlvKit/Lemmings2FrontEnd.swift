import Foundation

/// Original front-end pictures, palettes, strings and GAL sprite banks.
/// These files contain data only; no DOS code is loaded by the player.
public struct Lemmings2FrontEnd: Sendable {
    public struct Bank: Sendable {
        public let sprites: [[Lemmings2SpriteFrame]]
        public let palettes: [[UInt8]]
        public let strings: [String]

        public init(data: Data) throws {
            let graphics = try Lemmings2SpecialGraphics(data: data, addressing: .frontEnd)
            sprites = try (0..<(try graphics.animationCount)).map { try graphics.animation($0) }
            let form = graphics.container
            let entries = try Self.entries(form.requiredSection("L2PD"), index: form.requiredSection("L2PI"))
            palettes = try entries.map { bytes in
                guard bytes.count <= 768, bytes.count.isMultiple(of: 3) else {
                    throw SequelDataError.invalid("Invalid L2 front-end palette.")
                }
                var rgba = [UInt8](repeating: 0, count: 1024)
                for i in 0..<256 { rgba[i * 4 + 3] = 255 }
                // Some shipped palettes contain 64/65. The VGA DAC keeps
                // only the low six bits, as does the original output path.
                for (i, channel) in bytes.enumerated() { rgba[i / 3 * 4 + i % 3] = UInt8(Int(channel & 63) * 255 / 63) }
                return rgba
            }
            strings = try Self.entries(form.requiredSection("L2TM"), index: form.requiredSection("L2TI")).map { bytes in
                guard bytes.last == 0 else { throw SequelDataError.invalid("Unterminated L2 front-end text.") }
                return String(decoding: bytes.dropLast(), as: UTF8.self)
            }
        }

        private static func entries(_ data: Data, index: Data) throws -> [[UInt8]] {
            let r = SequelBinary(data), indices = SequelBinary(index)
            var entries: [Int: [UInt8]] = [:]
            var cursor = 2, logical = 0
            for _ in 0..<(try r.u16(0)) {
                let size = try r.u16(cursor)
                entries[logical] = try r.slice(cursor + 2, size)
                cursor += size + 2; logical += size
            }
            let padded = cursor % 2 == 1 && r.count == cursor + 1 && r.bytes[cursor] == 0
            guard cursor == r.count || padded, indices.count == 2 + (try indices.u16(0)) * 2 else {
                throw SequelDataError.invalid("Invalid L2 front-end entry table.")
            }
            return try (0..<(try indices.u16(0))).map {
                guard let entry = entries[try indices.u16(2 + $0 * 2)] else {
                    throw SequelDataError.invalid("Invalid L2 front-end entry pointer.")
                }
                return entry
            }
        }
    }

    public let banks: [String: Bank]
    public let pictures: [String: [UInt8]]
    public let panel: Lemmings2Panel
    public let font: Lemmings2FrontEndFont
    public let pointers: Lemmings2Pointers

    public init(root: URL) throws {
        var banks: [String: Bank] = [:]
        for name in ["MENU", "MAP", "INFO", "PREFS", "MEDALS", "AWARD", "PRACTICE", "LOAD", "INTRO", "END", "TOUGH"] {
            banks[name] = try Bank(data: Data(contentsOf: root.appendingPathComponent("FRONTEND/GFXIFFS/\(name).IFF")))
        }
        self.banks = banks
        var pictures: [String: [UInt8]] = [:]
        for name in ["MENU", "MAP", "ROCKWALL", "AWARD", "END1", "END2", "END3", "END4", "END5"] {
            let data = try Data(contentsOf: root.appendingPathComponent("FRONTEND/SCREENS/\(name).DAT"))
            pictures[name] = try Self.planar(Lemmings2Compression.decode(data), width: 320, height: 200)
        }
        self.pictures = pictures
        panel = try Lemmings2Panel(root: root)
        font = try Lemmings2FrontEndFont(data: Data(contentsOf: root.appendingPathComponent("FONT.DAT")))
        pointers = try Lemmings2Pointers(data: Data(contentsOf: root.appendingPathComponent("POINTER.DAT")))
    }

    /// Four VGA byte planes, not Amiga bit planes.
    static func planar(_ data: Data, width: Int, height: Int) throws -> [UInt8] {
        guard width > 0, width.isMultiple(of: 4), height > 0, width * height == data.count else {
            throw SequelDataError.invalid("Invalid L2 planar picture size.")
        }
        let bytes = [UInt8](data), planeSize = width * height / 4
        var pixels = [UInt8](repeating: 0, count: bytes.count)
        for i in bytes.indices { pixels[(i % planeSize) * 4 + i / planeSize] = bytes[i] }
        return pixels
    }
}

public struct Lemmings2FrontEndFont: Sendable {
    public let glyphs: [[UInt8]]
    // Proportional advances used by the original GAL text layout.
    public let advances = [6,5,8,8,7,8,8,3,5,5,8,7,3,7,3,8,9,5,8,8,9,8,9,9,9,9,3,3,6,7,6,8,
        8,9,9,8,10,9,8,8,9,5,7,9,8,10,10,9,9,9,9,7,7,9,9,10,8,9,8,5,8,5,6,7,
        3,9,8,8,8,8,6,8,8,4,5,8,5,9,8,8,8,9,8,8,6,8,8,9,8,8,8]
    public init(data: Data) throws {
        guard data.count == 17952 else { throw SequelDataError.invalid("Invalid L2 front-end font size.") }
        let r = SequelBinary(data)
        glyphs = try (0..<102).map { try Lemmings2FrontEnd.planar(Data(r.slice($0 * 176, 176)), width: 16, height: 11) }
    }
    public func width(_ text: String) -> Int {
        text.utf8.reduce(0) { $0 + ((32..<123).contains($1) ? advances[Int($1) - 32] : 6) }
    }
}

/// The original 320×40 skill panel, including its icons and bitmap font.
public struct Lemmings2Panel: Sendable {
    public static let backgroundIndex: UInt8 = 143

    /// VGA.RKO 3397: common panel colours and its cycling yellow/red outline.
    public static func palette(over palette: [UInt8], phase: Int = 0) -> [UInt8] {
        guard palette.count == 1024 else { return palette }
        let colours = [0,0,0, 56,48,0, 16,8,44, 24,12,52, 52,4,4, 60,24,4, 0,32,0, 0,44,0,
            48,48,52, 36,24,32, 32,20,28, 28,16,24, 24,12,20, 20,8,16, 16,4,12, 12,0,0,
            0,0,0, 63,63,0, 63,0,0, 63,0,0]
        var result = palette
        for i in 0..<20 {
            let source = i < 17 ? i : 17 + (i - 17 + max(0, phase) % 3) % 3
            for c in 0..<3 { result[(128 + i) * 4 + c] = UInt8(colours[source * 3 + c] * 255 / 63) }
            result[(128 + i) * 4 + 3] = 255
        }
        return result
    }
    public let skillTile: [UInt8]
    public let controlTile: [UInt8]
    public let numberTile: [UInt8]
    public let glyphs: [[UInt8]]
    public let controls: [Lemmings2SpriteFrame]
    public let skills: [Lemmings2SpriteFrame]

    public init(root: URL) throws {
        try self.init(panel: Data(contentsOf: root.appendingPathComponent("PANEL.DAT")),
                      icons: Data(contentsOf: root.appendingPathComponent("ICONS.DAT")))
    }

    public init(panel: Data, icons: Data) throws {
        let r = SequelBinary(try Lemmings2Compression.decode(panel))
        skillTile = try Lemmings2FrontEnd.planar(Data(r.slice(0, 960)), width: 32, height: 30)
        controlTile = try Lemmings2FrontEnd.planar(Data(r.slice(960, 640)), width: 32, height: 20)
        glyphs = try (0..<59).map {
            try Lemmings2FrontEnd.planar(Data(r.slice(1600 + $0 * 64, 64)), width: 8, height: 8)
        }
        numberTile = try Lemmings2FrontEnd.planar(Data(r.slice(0x1500, 144)), width: 16, height: 9)
        controls = try Self.rawSprites(Data(r.slice(0x1590, r.count - 0x1590)), count: 26)
        skills = try Self.rawSprites(Lemmings2Compression.decode(icons), count: 54)
    }

    // PANEL and ICONS have an absolute-pointer table and four command streams,
    // without the dimensions present in VLEMMS. The panel bounds are fixed.
    private static func rawSprites(_ data: Data, count: Int) throws -> [Lemmings2SpriteFrame] {
        let r = SequelBinary(data)
        let starts = try (0..<count).map { try r.u16($0 * 2) }
        guard starts.first == count * 2, zip(starts, starts.dropFirst()).allSatisfy({ $0 < $1 }) else {
            throw SequelDataError.invalid("Invalid L2 panel sprite table.")
        }
        return try starts.enumerated().map { index, start in
            let end = index + 1 < count ? starts[index + 1] : r.count
            let planes = try (0..<4).map { try r.u16(start + 4 + $0 * 2) }
            let decoded = try Lemmings2SpriteCommands.decode(r, width: 32, height: 40,
                planes: planes, within: (start + 12)..<end)
            return Lemmings2SpriteFrame(x: 0, y: 0, width: 32, height: 40,
                                       pixels: decoded.pixels, opaque: decoded.opaque)
        }
    }

    public func render(skills identifiers: [Int], supplies: [Int], selected: Int,
                       saved: Int, remaining: Int, seconds: Int, label: String, palette: [UInt8],
                       highlightedControls: Set<Lemmings2Control> = []) throws -> SequelIndexedImage {
        guard identifiers.count == 8, supplies.count == 8, (0..<12).contains(selected), palette.count == 1024,
              identifiers.allSatisfy({ (0...51).contains($0) }), supplies.allSatisfy({ (0...99).contains($0) }) else {
            throw SequelDataError.invalid("Invalid L2 panel state.")
        }
        var pixels = [UInt8](repeating: Self.backgroundIndex, count: 320 * 40)
        func put(_ source: [UInt8], width: Int, x: Int, y: Int, mask: [Bool]? = nil) {
            for i in source.indices where mask?[i] ?? true {
                let px = x + i % width, py = y + i / width
                if (0..<320).contains(px), (0..<40).contains(py) { pixels[py * 320 + px] = source[i] }
            }
        }
        func sprite(_ frame: Lemmings2SpriteFrame, _ x: Int, _ y: Int) {
            put(frame.pixels, width: frame.width, x: x, y: y, mask: frame.opaque)
        }
        func text(_ string: String, _ x: Int, _ y: Int) {
            for (i, byte) in string.uppercased().utf8.enumerated() where (32...90).contains(byte) {
                put(glyphs[Int(byte) - 32], width: 8, x: x + i * 8, y: y)
            }
        }
        for i in 0..<8 {
            put(skillTile, width: 32, x: i * 32, y: 9)
            if identifiers[i] > 0 { sprite(skills[identifiers[i] - 1], i * 32, 15) }
            put(numberTile, width: 16, x: i * 32, y: 13)
            sprite(controls[6 + supplies[i] / 10], i * 32, 13)
            sprite(controls[16 + supplies[i] % 10], i * 32, 13)
        }
        for i in 0..<4 {
            let x = 256 + i % 2 * 32, y = i / 2 * 20
            put(controlTile, width: 32, x: x, y: y)
            sprite(controls[i], x, y)
        }
        sprite(controls[selected < 8 ? 5 : 4], selected < 8 ? selected * 32 : 256 + (selected - 8) % 2 * 32,
               selected < 8 ? 9 : (selected - 8) / 2 * 20)
        for control in highlightedControls {
            let slot = control.rawValue - 8
            sprite(controls[4], 256 + slot % 2 * 32, slot / 2 * 20)
        }
        text(String(label.prefix(13)), 0, 1)
        sprite(skills[51], 120, 1)
        sprite(skills[52], 160, 1)
        sprite(skills[53], 208, 1)
        text(String(format: "%02d", min(99, max(0, saved))), 136, 1)
        text(String(format: "%02d", min(99, max(0, remaining))), 184, 1)
        text(String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60), 224, 1)
        return SequelIndexedImage(width: 320, height: 40, pixels: pixels, palette: palette)
    }
}
