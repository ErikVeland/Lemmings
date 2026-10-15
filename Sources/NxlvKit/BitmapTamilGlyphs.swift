import Foundation

/**
 * Complete Tamil forms exported from the pixel-font prototype. Runtime drawing uses bundled pixels only.
 */
public enum BitmapTamilGlyphs {
    public struct Metrics: Sendable {
        public let x: Int, y: Int, width: Int, height: Int, advance: Int
    }
    private struct Glyph: Decodable, Sendable {
        let advance: Int, x: Int, y: Int, width: Int, height: Int
        let data: Data
    }
    private struct Face: Decodable, Sendable {
        let id: String
        let bodyHeight: Int
        let glyphs: [String: Glyph]
    }
    private struct Resource: Decodable, Sendable {
        let version: Int
        let palette: [UInt8]
        let aliases: [String: String]
        let faces: [Face]
    }
    private struct Candidate: Sendable {
        let text: String
        let characters: [Character]
    }
    private struct Catalogue: Sendable {
        let resource: Resource?
        let sequences: [String]
        let candidates: [Character: [Candidate]]
    }
    private static let frames = GameAssetCache<ClassicMacArtwork.Frame>(capacity: 4096)
    private static let catalogue: Catalogue = {
        let bundleURL: URL?
        #if SWIFT_PACKAGE
        bundleURL = Bundle.module.url(forResource: "Localization", withExtension: "bundle")
        #else
        bundleURL = Bundle.main.url(forResource: "Localization", withExtension: "bundle")
        #endif
        let url = bundleURL?.appendingPathComponent("Fonts/TamilPixelFont.json")
        let resource = url.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(Resource.self, from: $0) }
        let valid = resource.flatMap { value -> Resource? in
            guard value.version == 1, value.palette.count == 21, !value.faces.isEmpty else { return nil }
            let sequences = Set(value.faces[0].glyphs.keys)
            guard value.faces.allSatisfy({ Set($0.glyphs.keys) == sequences && $0.bodyHeight > 0 }),
                  value.aliases.values.allSatisfy({ sequences.contains($0) }),
                  value.faces.allSatisfy({ $0.glyphs.values.allSatisfy {
                      $0.width > 0 && $0.height > 0 && $0.advance > 0
                          && $0.data.count == ($0.width * $0.height + 1) / 2
                  } }) else { return nil }
            return value
        }
        let sequences = valid.map { Array(Set($0.faces[0].glyphs.keys).union($0.aliases.keys)).sorted() } ?? []
        var candidates: [Character: [Candidate]] = [:]
        for text in sequences {
            let characters = Array(text)
            guard let first = characters.first else { continue }
            candidates[first, default: []].append(Candidate(text: text, characters: characters))
        }
        for first in Array(candidates.keys) {
            candidates[first]?.sort { $0.characters.count > $1.characters.count }
        }
        return Catalogue(resource: valid, sequences: sequences, candidates: candidates)
    }()

    /**
     * Complete forms and the widespread SA-based shrii spelling. Isolated combining-sign diagnostics stay in the prototype.
     */
    public static var supportedSequences: [String] { catalogue.sequences }

    /**
     * Match complete Tamil forms before falling back to whole Unicode characters in other text.
     */
    public static func sequences(in text: String) -> [String] {
        let characters = Array(text.precomposedStringWithCanonicalMapping)
        var result: [String] = [], cursor = 0
        while cursor < characters.count {
            let candidates = catalogue.candidates[characters[cursor]] ?? []
            if let match = candidates.first(where: { candidate in
                let end = cursor + candidate.characters.count
                return end <= characters.count && characters[cursor..<end].elementsEqual(candidate.characters)
            }) {
                result.append(match.text)
                cursor += match.characters.count
            } else {
                result.append(String(characters[cursor]))
                cursor += 1
            }
        }
        return result
    }

    public static func supports(_ sequence: String) -> Bool {
        guard let resource = catalogue.resource else { return false }
        let normalised = sequence.precomposedStringWithCanonicalMapping
        return resource.faces[0].glyphs[resource.aliases[normalised] ?? normalised] != nil
    }

    private static func source(for sequence: String, cellHeight: Int) -> (Resource, Face, Glyph, Double)? {
        guard let resource = catalogue.resource else { return nil }
        let normalised = sequence.precomposedStringWithCanonicalMapping
        let canonical = resource.aliases[normalised] ?? normalised
        let bodyHeight = max(7, cellHeight <= 10 ? cellHeight : cellHeight - 4)
        let ordered = resource.faces.sorted { $0.bodyHeight < $1.bodyHeight }
        guard let face = ordered.first(where: { $0.bodyHeight >= bodyHeight }) ?? ordered.last,
              let glyph = face.glyphs[canonical] else { return nil }
        return (resource, face, glyph, Double(bodyHeight) / Double(face.bodyHeight))
    }

    /**
     * Variable Tamil advances use the requested Latin line size. ASCII retains the original font's advance.
     */
    public static func advance(for sequence: String, cellHeight: Int) -> Int? {
        guard let (_, _, glyph, scale) = source(for: sequence, cellHeight: cellHeight) else { return nil }
        return max(1, Int(ceil(Double(glyph.advance) * scale)))
    }

    /**
     * Measure bundled metrics without decoding or resampling a pixel mask.
     */
    public static func metrics(for sequence: String, cellHeight: Int, baseline: Int) -> Metrics? {
        guard let (_, _, glyph, scale) = source(for: sequence, cellHeight: cellHeight) else { return nil }
        return geometry(glyph, scale: scale, baseline: baseline)
    }

    private static func geometry(_ glyph: Glyph, scale: Double, baseline: Int) -> Metrics {
        let left = Int(floor(Double(glyph.x) * scale)), top = Int(floor(Double(glyph.y) * scale))
        return Metrics(x: left, y: baseline + top,
                       width: Int(ceil(Double(glyph.x + glyph.width) * scale)) - left,
                       height: Int(ceil(Double(glyph.y + glyph.height) * scale)) - top,
                       advance: max(1, Int(ceil(Double(glyph.advance) * scale))))
    }

    /**
     * Place the Tamil baseline on the source font's baseline and retain all negative bearings and marks.
     */
    public static func frame(for sequence: String, cellHeight: Int, baseline: Int) -> ClassicMacArtwork.Frame? {
        guard let (resource, _, glyph, scale) = source(for: sequence, cellHeight: cellHeight) else { return nil }
        let normalised = sequence.precomposedStringWithCanonicalMapping
        let key = "\(cellHeight)/\(baseline)/\(resource.aliases[normalised] ?? normalised)"
        if let cached = frames.value(for: key) { return cached }
        let bounds = geometry(glyph, scale: scale, baseline: baseline)
        let left = bounds.x, top = bounds.y - baseline, width = bounds.width, height = bounds.height
        let packed = [UInt8](glyph.data)
        func index(_ x: Int, _ y: Int) -> UInt8 {
            let offset = y * glyph.width + x, byte = packed[offset / 2]
            return offset.isMultiple(of: 2) ? byte >> 4 : byte & 15
        }
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            let sourceLeft = max(0, min(glyph.width - 1, Int(floor(Double(x + left) / scale)) - glyph.x))
            let sourceTop = max(0, min(glyph.height - 1, Int(floor(Double(y + top) / scale)) - glyph.y))
            let sourceRight = min(glyph.width, max(sourceLeft + 1, Int(ceil(Double(x + left + 1) / scale)) - glyph.x))
            let sourceBottom = min(glyph.height, max(sourceTop + 1, Int(ceil(Double(y + top + 1) / scale)) - glyph.y))
            // Area coverage keeps small pulli dots when a compact panel downsamples the face.
            var shade: UInt8 = 15
            for sourceY in sourceTop..<sourceBottom { for sourceX in sourceLeft..<sourceRight {
                let candidate = index(sourceX, sourceY)
                if candidate < 7, shade == 15 || candidate > shade { shade = candidate }
            } }
            guard shade < 7 else { continue }
            let target = (y * width + x) * 4, colour = Int(shade) * 3
            rgba[target] = resource.palette[colour]
            rgba[target + 1] = resource.palette[colour + 1]
            rgba[target + 2] = resource.palette[colour + 2]
            rgba[target + 3] = 255
        } }
        let frame = ClassicMacArtwork.Frame(x: left, y: bounds.y, width: width, height: height, rgba: Data(rgba))
        frames.insert(frame, for: key)
        return frame
    }
}
