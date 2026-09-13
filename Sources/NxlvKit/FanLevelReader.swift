import Foundation

public enum FanLevelError: Error, Equatable, CustomStringConvertible {
    case wrongSize(bytes: Int)
    case missingField(String)
    case invalidField(String)
    case tooMuchTerrain(count: Int)
    case tooManyObjects(count: Int)

    public var description: String {
        switch self {
        case let .wrongSize(bytes):
            return "A .lvl level is 2048 bytes. This one is \(bytes)."
        case let .missingField(name):
            return "The level description has no \(name) field."
        case let .invalidField(name):
            return "The level description has an invalid \(name) field."
        case let .tooMuchTerrain(count):
            return "A level holds at most 400 terrain pieces. This one lists \(count)."
        case let .tooManyObjects(count):
            return "A level holds at most 32 objects. This one lists \(count)."
        }
    }
}

/// Reads the level formats used by the fan level packs.
///
/// Two formats turn up. A `.lvl` file is the classic 2048 byte record exactly as
/// the original game stored it. A `.ini` file is the same level written as text
/// by a level editor, with one line per object and per terrain piece.
///
/// Both end up as a `ClassicLevel`. The text form is turned back into a 2048
/// byte record and handed to the same parser the binary form uses, so there is
/// one implementation of the layout rather than two that can drift apart.
public enum FanLevelReader {
    // MARK: - Binary levels

    /// Reads a `.lvl` file, which is the classic record with nothing around it.
    public static func level(fromLVL data: Data) throws -> ClassicLevel {
        guard data.count == ClassicLevel.recordSize else {
            throw FanLevelError.wrongSize(bytes: data.count)
        }
        return try ClassicLevel(data: data)
    }

    // MARK: - Text levels

    /// The fields a text level carries, before it becomes a record.
    public struct Fields {
        public var values: [String: String] = [:]
        public var objects: [[Int]] = []
        public var terrain: [[Int]] = []
        public var steel: [[Int]] = []
        fileprivate var invalidFields: [String] = []

        public func integer(_ name: String, default fallback: Int? = nil) throws -> Int {
            if let text = values[name] {
                guard let value = Int(text) else { throw FanLevelError.invalidField(name) }
                return value
            }
            if let fallback { return fallback }
            throw FanLevelError.missingField(name)
        }
    }

    /// Splits a text level into its fields, ignoring comments and blank lines.
    public static func parse(_ text: String) -> Fields {
        var fields = Fields()
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.prefix { $0 != "#" }.trimmingCharacters(in: .whitespaces)
            guard let split = line.firstIndex(of: "=") else { continue }
            let key = line[line.startIndex..<split].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: split)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }

            let components = value.split(separator: ",", omittingEmptySubsequences: false)
            let numbers = components.compactMap {
                Int($0.trimmingCharacters(in: .whitespaces))
            }
            if key.hasPrefix("object_") || key.hasPrefix("terrain_") || key.hasPrefix("steel_") {
                let minimum = key.hasPrefix("steel_") ? 4 : 3
                if numbers.count != components.count || numbers.count < minimum {
                    fields.invalidFields.append(key)
                }
            }
            if key.hasPrefix("object_") {
                fields.objects.append(numbers)
            } else if key.hasPrefix("terrain_") {
                fields.terrain.append(numbers)
            } else if key.hasPrefix("steel_") {
                fields.steel.append(numbers)
            } else {
                fields.values[key] = value
            }
        }
        return fields
    }

    /// The eight skills, in the order the record stores them.
    private static let skillFields = [
        "numClimbers", "numFloaters", "numBombers", "numBlockers",
        "numBuilders", "numBashers", "numMiners", "numDiggers",
    ]

    /// Turns a text level into the 2048 byte record the game uses.
    ///
    /// Steel must fit the DOS grid and size limits exactly. Use `level(fromINI:)`
    /// to load text rectangles that cannot be represented by a DOS record.
    public static func record(fromINI text: String) throws -> Data {
        try record(fromINI: text, encodeSteel: true)
    }

    private static func steelAreas(_ fields: Fields) throws -> [ClassicSteelArea] {
        guard fields.steel.count <= 4096 else { throw FanLevelError.invalidField("steel") }
        return try fields.steel.enumerated().map { index, values in
            guard values.count == 4, values[2] > 0, values[3] > 0,
                  !values[0].addingReportingOverflow(values[2]).overflow,
                  !values[1].addingReportingOverflow(values[3]).overflow else {
                throw FanLevelError.invalidField("steel_\(index)")
            }
            return ClassicSteelArea(x: values[0], y: values[1], width: values[2], height: values[3])
        }
    }

    private static func record(fromINI text: String, encodeSteel: Bool) throws -> Data {
        let fields = parse(text)
        if let invalid = fields.invalidFields.first { throw FanLevelError.invalidField(invalid) }
        guard fields.terrain.count <= 400 else {
            throw FanLevelError.tooMuchTerrain(count: fields.terrain.count)
        }
        guard fields.objects.count <= 32 else {
            throw FanLevelError.tooManyObjects(count: fields.objects.count)
        }

        var bytes = [UInt8](repeating: 0, count: ClassicLevel.recordSize)
        func putWord(_ value: Int, at offset: Int) {
            let word = UInt16(truncatingIfNeeded: value)
            bytes[offset] = UInt8(word >> 8)
            bytes[offset + 1] = UInt8(word & 0xFF)
        }
        func checkedOffset(_ value: Int, by amount: Int, field: String) throws -> Int {
            let result = value.addingReportingOverflow(amount)
            guard !result.overflow else { throw FanLevelError.invalidField(field) }
            return result.partialValue
        }

        putWord(try fields.integer("releaseRate"), at: 0x0000)
        putWord(try fields.integer("numLemmings"), at: 0x0002)
        putWord(try fields.integer("numToRescue"), at: 0x0004)
        // Editors disagree on this one field. The NeoLemmix and SuperLemmini
        // editors write whole seconds; the older ones write whole minutes. The
        // record stores minutes, so seconds are converted, rounding up so a
        // level never loses time it was given.
        let minutes: Int
        if fields.values["timeLimit"] != nil {
            minutes = try fields.integer("timeLimit")
        } else {
            let seconds = try fields.integer("timeLimitSeconds")
            minutes = try checkedOffset(seconds, by: 59, field: "timeLimitSeconds") / 60
        }
        putWord(minutes, at: 0x0006)
        for (index, name) in skillFields.enumerated() {
            putWord(try fields.integer(name, default: 0), at: 0x0008 + index * 2)
        }
        putWord(try fields.integer("xPos", default: 0), at: 0x0018)
        putWord(try fields.integer("groundStyle", default: 0), at: 0x001A)
        putWord(try fields.integer("specialStyle", default: 0), at: 0x001C)

        // Objects: id, x, y, paint mode, upside down.
        // Paint mode 8 draws only over terrain, 4 never overwrites terrain.
        for (index, values) in fields.objects.enumerated() where values.count >= 3 {
            let offset = 0x0020 + index * 8
            putWord(try checkedOffset(values[1], by: 16, field: "object_\(index)"), at: offset)
            putWord(values[2], at: offset + 2)
            bytes[offset + 5] = UInt8(values[0] & 0x0F)
            let mode = values.count > 3 ? values[3] : 0
            var flags = 0
            if mode == 4 { flags |= 0x8000 }
            if mode == 8 { flags |= 0x4000 }
            putWord(flags, at: offset + 6)
            if values.count > 4, values[4] == 1 { bytes[offset + 7] = 0x8F }
        }

        // Terrain: id, x, y, modifier. The modifier bits are one place higher
        // than the record's, so 8, 4 and 2 become 4, 2 and 1.
        for (index, values) in fields.terrain.enumerated() where values.count >= 3 {
            let offset = 0x0120 + index * 4
            let modifier = values.count > 3 ? values[3] : 0
            let flags = UInt32((modifier >> 1) & 0x07)
            let x = UInt32(truncatingIfNeeded: try checkedOffset(values[1], by: 16, field: "terrain_\(index)")) & 0x0FFF
            let y = UInt32(truncatingIfNeeded: try checkedOffset(values[2], by: 4, field: "terrain_\(index)")) & 0x01FF
            let id = UInt32(truncatingIfNeeded: values[0]) & 0x003F
            let word = (flags << 29) | (x << 16) | (y << 7) | id
            bytes[offset] = UInt8((word >> 24) & 0xFF)
            bytes[offset + 1] = UInt8((word >> 16) & 0xFF)
            bytes[offset + 2] = UInt8((word >> 8) & 0xFF)
            bytes[offset + 3] = UInt8(word & 0xFF)
        }
        // Unused terrain slots are all ones, which is what marks them empty.
        for index in fields.terrain.count..<400 {
            let offset = 0x0120 + index * 4
            for byte in 0..<4 { bytes[offset + byte] = 0xFF }
        }

        if encodeSteel {
            let areas = try steelAreas(fields)
            guard areas.count <= 32 else { throw FanLevelError.invalidField("steel") }
            for (index, area) in areas.enumerated() {
                // DOS stores four-pixel units. Refuse an export that changes the protection area.
                guard (-16...2028).contains(area.x), (0...508).contains(area.y),
                      (4...64).contains(area.width), (4...64).contains(area.height),
                      [area.x, area.y, area.width, area.height].allSatisfy({ $0 % 4 == 0 }) else {
                    throw FanLevelError.invalidField("steel_\(index)")
                }
                let position = (((area.x + 16) / 4) << 7) | (area.y / 4)
                let size = ((area.width / 4 - 1) << 4) | (area.height / 4 - 1)
                guard position != 0 || size != 0 else { throw FanLevelError.invalidField("steel_\(index)") }
                let offset = 0x0760 + index * 4
                putWord(position, at: offset)
                bytes[offset + 2] = UInt8(size)
            }
        }

        // A level with no title still has to carry a name field.
        let title = fields.values["name"] ?? ""
        let padded = title.padding(toLength: 32, withPad: " ", startingAt: 0)
        for (index, scalar) in padded.unicodeScalars.enumerated() where index < 32 {
            bytes[0x07E0 + index] = UInt8(scalar.value < 128 ? scalar.value : 32)
        }
        return Data(bytes)
    }

    /// The ground set a text level names, when it names one.
    ///
    /// Text levels say `style = Crystal` rather than giving a number, and the
    /// number differs between releases, so the name has to survive to whoever
    /// loads the artwork. It is not stored in the record.
    public static func styleName(fromINI text: String) -> String? {
        let name = parse(text).values["style"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (name?.isEmpty ?? true) ? nil : name
    }

    /// Retains exact text steel rectangles without the DOS record's grid and size limits.
    /// Disable steel only to restore an attempt saved before text steel support.
    public static func level(fromINI text: String, includeSteel: Bool = true) throws -> ClassicLevel {
        let record = try record(fromINI: text, encodeSteel: false)
        let steel = includeSteel ? try steelAreas(parse(text)) : []
        return try ClassicLevel(data: record, steelOverride: steel)
    }
}
