import NxlvKit
import Foundation

/**
 * Decodes Lix's authored interface icons and reproduces its default button backing.
 * Source: Lix f1e805048fe439a4a0e9cc650c613713ababac8b, CC0, doc/copying.txt.
 * Socket geometry and colours follow gui/draw3d.d, gui/button/button.d and graphic/color.d.
 */
public struct LixInterfaceArtwork: Sendable {
    public enum State: String, CaseIterable, Sendable {
        case normal, selected, pressed, disabled
    }

    public enum Control: String, CaseIterable, Sendable {
        case play, pause, stepBackward, stepForward, rewind, fastForward, turbo
        case restart, nuke, save, load, help, undo, rewindPrevious, rateDecrease, rateIncrease, menu
    }

    public struct Frame: Sendable {
        public let width: Int
        public let height: Int
        public let rgba: Data
    }

    enum Sheet: String, CaseIterable {
        case skills = "skillsinpanel.png"
        case big = "gamebigbuttons/1.png"
        case small = "gamesmallbuttons/1.png"
        case pause = "gamepause/1.png"
        case arrows = "guinumpick/1.png"
        case checkbox = "checkbox/1.png"
        case previous = "rewindprevply/1.png"
    }

    private struct Grid: Sendable {
        let width: Int, height: Int, columns: Int, rows: Int
        let frames: [LixSceneArtwork.Pixels]
    }

    private let sheets: [Sheet: Grid]
    private let playerColours: [UInt32: [UInt8]]
    private static let skills: [LixArtwork.Activity] = [
        .walker, .runner, .climber, .floater, .imploder, .exploder, .blocker, .builder,
        .platformer, .basher, .miner, .digger, .jumper, .batter, .cuber,
    ]

    public init(directory: URL) throws {
        let root = directory.standardizedFileURL
        try self.init(read: { name in
            let url = root.appendingPathComponent("assets/data/images/" + name)
            var current = url
            while true {
                let values = try current.resourceValues(forKeys: [.isSymbolicLinkKey])
                guard values.isSymbolicLink != true else { throw LixSceneArtwork.DecodeError.unsafeFile }
                if current.path == root.path { break }
                current.deleteLastPathComponent()
            }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true, let bytes = values.fileSize,
                  bytes > 0, bytes <= 2_000_000 else { throw LixSceneArtwork.DecodeError.unsafeFile }
            return try Data(contentsOf: url)
        })
    }

    init(read: (String) throws -> Data) throws {
        let expected: [Sheet: [Int]] = [
            .skills: [32, 32, 15, 2], .big: [40, 30, 11, 2], .small: [34, 20, 7, 2],
            .pause: [34, 60, 1, 2], .arrows: [20, 20, 12, 2],
            .checkbox: [20, 20, 7, 3], .previous: [40, 30, 1, 2],
        ]
        var grids: [Sheet: Grid] = [:]
        for sheet in Sheet.allCases {
            let geometry = expected[sheet]!
            let image = try LixSceneArtwork.decode(read(sheet.rawValue))
            let width = geometry[0], height = geometry[1], columns = geometry[2], rows = geometry[3]
            guard image.width == columns * (width + 1) + 1,
                  image.height == rows * (height + 1) + 1 else { throw LixSceneArtwork.DecodeError.invalidImage }
            var frames: [LixSceneArtwork.Pixels] = []
            for row in 0..<rows { for column in 0..<columns {
                frames.append(try image.crop(x: 1 + column * (width + 1), y: 1 + row * (height + 1),
                    width: width, height: height))
            } }
            grids[sheet] = Grid(width: width, height: height, columns: columns, rows: rows, frames: frames)
        }
        let palette = try LixSceneArtwork.decode(read("lixrecol.png"))
        guard palette.width == 15, palette.height == 12 else { throw LixSceneArtwork.DecodeError.invalidImage }
        var colours: [UInt32: [UInt8]] = [:]
        for column in 0..<palette.width {
            let source = column * 4, target = (palette.width + column) * 4
            colours[Self.key(palette.rgba, source)] = Array(palette.rgba[target..<(target + 4)])
        }
        sheets = grids
        playerColours = colours
    }

    /**
     * Returns an authored skill icon. Missing Lix skills stay explicit.
     */
    public func skill(_ activity: LixArtwork.Activity, enabled: Bool = true) -> Frame? {
        guard let column = Self.skills.firstIndex(of: activity) else { return nil }
        return image(.skills, column: column, row: enabled ? 0 : 1, state: .normal)
    }

    /**
     * Returns an upstream control symbol. Lix uses text for Menu.
     */
    public func control(_ control: Control, state: State = .normal) -> Frame? {
        let sheet: Sheet, column: Int
        switch control {
        case .play: sheet = .arrows; column = 3
        case .pause: sheet = .pause; column = 0
        case .stepBackward: sheet = .big; column = 10
        case .stepForward: sheet = .big; column = 3
        case .rewind: sheet = .arrows; column = 1
        case .fastForward: sheet = .big; column = 4
        case .turbo: sheet = .big; column = 5
        case .restart: sheet = .big; column = 8
        case .nuke: sheet = .small; column = 0
        case .save: sheet = .big; column = 6
        case .load: sheet = .big; column = 7
        case .help: sheet = .big; column = 1
        case .undo, .rewindPrevious: sheet = .previous; column = 0
        case .rateDecrease: sheet = .arrows; column = 2
        case .rateIncrease: sheet = .arrows; column = 3
        case .menu: return nil
        }
        return image(sheet, column: column, row: state == .selected ? 1 : 0, state: state)
    }

    public func checkbox(checked: Bool, state: State = .normal) -> Frame? {
        image(.checkbox, column: checked ? 2 : 0, row: state == .selected ? 1 : 0, state: state)
    }

    /**
     * Reproduces Lix's raised or inset backing. It contains no text or invented icons.
     */
    public func button(width: Int, height: Int, state: State = .normal, border: Int = 2) -> Frame? {
        guard (1...2_048).contains(width), (1...2_048).contains(height),
              width * height <= 1_048_576, (0...64).contains(border) else { return nil }
        let thickness = min(border, width / 2, height / 2)
        let brightness = state == .selected ? 11.0 / 16 : state == .pressed ? 8.75 / 16 : 7.75 / 16
        let contrast = state == .normal || state == .disabled ? 1.2 : 1.1
        let middle = Self.sepia(brightness)
        let light = Self.sepia(brightness * contrast), dark = Self.sepia(brightness / contrast)
        let inset = state == .selected || state == .pressed
        let top = inset ? dark : light, bottom = inset ? light : dark
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            let depth = min(x, y, width - 1 - x, height - 1 - y)
            let colour: [UInt8]
            if depth >= thickness { colour = middle }
            else if x == depth && y == height - 1 - depth
                || x == width - 1 - depth && y == depth { colour = middle }
            else if x == depth || y == depth { colour = top }
            else { colour = bottom }
            let offset = (y * width + x) * 4
            pixels.replaceSubrange(offset..<(offset + 4), with: colour)
            if state == .disabled { pixels[offset + 3] = 112 }
        } }
        return Frame(width: width, height: height, rgba: Data(pixels))
    }

    private func image(_ sheet: Sheet, column: Int, row: Int, state: State) -> Frame? {
        guard let grid = sheets[sheet], (0..<grid.columns).contains(column), (0..<grid.rows).contains(row) else { return nil }
        let source = grid.frames[row * grid.columns + column]
        var pixels = source.rgba
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let sourceColour = Self.key(pixels, offset)
            if sheet == .skills && row == 0, let replacement = playerColours[sourceColour] {
                pixels.replaceSubrange(offset..<(offset + 4), with: replacement)
            }
            if pixels[offset + 3] == 0 { continue }
            let rgb = Array(pixels[offset..<(offset + 3)])
            var replacement: [UInt8]?
            if rgb == [0, 0, 0] { replacement = [0, 0, 0, 0] }
            else if rgb == [64, 64, 64] { replacement = Self.sepia(3.0 / 16) }
            else if sheet != .skills || row != 0 {
                let bright = row > 0 && sheet != .skills
                if rgb == [128, 128, 128] { replacement = Self.sepia((bright ? 14.0 : 11.0) / 16 / 1.2) }
                if rgb == [192, 192, 192] { replacement = Self.sepia((bright ? 14.0 : 11.0) / 16) }
                if rgb == [255, 255, 255] { replacement = Self.sepia(bright ? 1 : 11.0 / 16 * 1.2) }
            }
            if let replacement { pixels.replaceSubrange(offset..<(offset + 4), with: replacement) }
            if state == .disabled { pixels[offset + 3] = UInt8(Int(pixels[offset + 3]) * 112 / 255) }
        }
        return Frame(width: source.width, height: source.height, rgba: Data(pixels))
    }

    private static func key(_ rgba: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(rgba[offset]) << 24 | UInt32(rgba[offset + 1]) << 16
            | UInt32(rgba[offset + 2]) << 8 | UInt32(rgba[offset + 3])
    }

    private static func sepia(_ brightness: Double) -> [UInt8] {
        let light = min(1, max(0, brightness))
        var result: [UInt8] = []
        for component in [96.0, 128.0, 176.0] {
            let value: Double
            if light < 0.5 { value = component * 2 * light }
            else { value = component + (255 - component) * 2 * (light - 0.5) }
            result.append(UInt8(value.rounded()))
        }
        result.append(255)
        return result
    }
}
