import Foundation

public enum AmigaSoundBankError: Error, Equatable, CustomStringConvertible {
    case notIFF(offset: Int)
    case notEightSVX(offset: Int, form: String)
    case truncatedChunk(offset: Int, tag: String, declared: Int, available: Int)
    case missingBody(name: String?)

    public var description: String {
        switch self {
        case let .notIFF(offset):
            return "Expected an IFF FORM at byte \(offset)."
        case let .notEightSVX(offset, form):
            return "The FORM at byte \(offset) is \(form), not 8SVX."
        case let .truncatedChunk(offset, tag, declared, available):
            return "Chunk \(tag) at byte \(offset) declares \(declared) bytes, but only \(available) remain."
        case let .missingBody(name):
            return "The sample \(name ?? "with no name") holds no BODY chunk."
        }
    }
}

/// One digitised sound from an Amiga sound bank.
public struct AmigaSound: Sendable, Equatable {
    /// The name the game gave it, when it carries one.
    ///
    /// Several sounds in the shipped banks have an empty NAME chunk. They are
    /// kept, because a sound with no name still plays. Only the named ones can
    /// be bound to a game event by name.
    public let name: String?
    /// Samples per second, which differs from one sound to the next.
    public let sampleRate: Double
    /// Samples in the range -1 to 1.
    public let samples: [Float]
}

/// Reads the digitised sound effects from the Amiga release.
///
/// `basicfx` and `fullfx` are several IFF 8SVX files written one after another
/// in a single file, each with its own name, rate and body. The format is the
/// ordinary Amiga sampled-sound format: 8 bit signed samples, one channel.
///
/// These are the sounds the Amiga game itself used, so they are the closest
/// thing to the original that the project can play.
public enum AmigaSoundBank {
    /// Reads every sound in a bank, in the order the file stores them.
    public static func decode(_ data: Data) throws -> [AmigaSound] {
        var sounds: [AmigaSound] = []
        var offset = 0
        while offset + 8 <= data.count {
            guard data.tag(at: offset) == "FORM" else {
                // Trailing padding after the last sample is not an error.
                if sounds.isEmpty { throw AmigaSoundBankError.notIFF(offset: offset) }
                break
            }
            let size = Int(data.beUInt32(at: offset + 4))
            let bodyStart = offset + 8
            guard bodyStart + size <= data.count else {
                throw AmigaSoundBankError.truncatedChunk(
                    offset: offset, tag: "FORM", declared: size,
                    available: data.count - bodyStart)
            }
            let form = data.tag(at: bodyStart)
            guard form == "8SVX" else {
                throw AmigaSoundBankError.notEightSVX(offset: offset, form: form)
            }
            sounds.append(try decodeSample(data, from: bodyStart + 4, to: bodyStart + size))
            // IFF pads every chunk to an even length.
            offset = bodyStart + size + (size & 1)
        }
        return sounds
    }

    private static func decodeSample(
        _ data: Data, from start: Int, to end: Int
    ) throws -> AmigaSound {
        var name: String?
        var rate: Double = 8363
        var body: [Float]?
        var offset = start

        while offset + 8 <= end {
            let tag = data.tag(at: offset)
            let size = Int(data.beUInt32(at: offset + 4))
            let chunkStart = offset + 8
            guard chunkStart + size <= end else {
                throw AmigaSoundBankError.truncatedChunk(
                    offset: offset, tag: tag, declared: size, available: end - chunkStart)
            }
            switch tag {
            case "NAME":
                let bytes = data.bytes(chunkStart, size)
                let text = String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
                name = text.isEmpty ? nil : text
            case "VHDR":
                // The rate is a 16 bit field, twelve bytes into the header.
                if size >= 14 { rate = Double(data.beUInt16(at: chunkStart + 12)) }
            case "BODY":
                // Eight bit signed, so -128 becomes -1 and 127 becomes almost 1.
                body = data.bytes(chunkStart, size).map { Float(Int8(bitPattern: $0)) / 128 }
            default:
                break
            }
            offset = chunkStart + size + (size & 1)
        }

        guard let body else { throw AmigaSoundBankError.missingBody(name: name) }
        return AmigaSound(name: name, sampleRate: max(1, rate), samples: body)
    }
}

extension Data {
    fileprivate func tag(at offset: Int) -> String {
        String(decoding: bytes(offset, 4), as: UTF8.self)
    }

    fileprivate func bytes(_ offset: Int, _ count: Int) -> [UInt8] {
        let base = startIndex + offset
        return Array(self[base..<Swift.min(base + count, endIndex)])
    }

    fileprivate func beUInt16(at offset: Int) -> UInt16 {
        let base = startIndex + offset
        return (UInt16(self[base]) << 8) | UInt16(self[base + 1])
    }

    fileprivate func beUInt32(at offset: Int) -> UInt32 {
        let base = startIndex + offset
        return (UInt32(self[base]) << 24) | (UInt32(self[base + 1]) << 16)
            | (UInt32(self[base + 2]) << 8) | UInt32(self[base + 3])
    }
}
