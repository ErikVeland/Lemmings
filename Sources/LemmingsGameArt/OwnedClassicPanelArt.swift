import Foundation
import LemmingsAppCore
import NxlvKit

/**
 * Recovers the original control tiles from the player's native Amiga panel.
 */
enum OwnedClassicPanelArt {
    private struct Tiles: Sendable { let rows: [String: [String]]? }
    private static let generations = GameAssetCache<Tiles>(capacity: 2)

    /**
     * Caches recovered source rows for the active immutable resource bundle.
     */
    static func rows(for glyph: String) -> [String]? {
        let revision = GameResources.revision
        if let cached = generations.value(for: revision) { return cached.rows?[glyph] }
        let decoded = GameResources.file("Ports/amiga_extracted/lemmings/panel1").flatMap { url in
            guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size == 12_800, let bytes = try? Data(contentsOf: url) else { return nil as [String: [String]]? }
            return decode(bytes)
        }
        generations.insert(Tiles(rows: decoded), for: revision)
        return decoded?[glyph]
    }

    /**
     * Uses the source crops and rock recovery defined by the Classic panel audit.
     */
    static func decode(_ data: Data) -> [String: [String]]? {
        guard data.count == 12_800 else { return nil }
        let bytes = [UInt8](data)
        func pixel(_ x: Int, _ y: Int) -> Int {
            var value = 0
            for plane in 0..<4 {
                value |= Int((bytes[plane * 3_200 + y * 80 + x / 8] >> (7 - x % 8)) & 1) << plane
            }
            return value
        }
        func crop(_ slot: Int) -> [String] {
            (17..<39).map { y in
                (2..<30).map { String(pixel(slot * 32 + $0, y), radix: 16) }.joined()
            }
        }
        let rockColours: Set<Int> = [5, 9, 10, 11, 12, 13, 14]
        var lower: [Int: Int] = [:]
        for y in 25..<39 { for x in 2..<30 {
            var votes: [Int: Int] = [:]
            for slot in 0..<10 {
                let value = pixel(slot * 32 + x, y)
                if rockColours.contains(value) { votes[value, default: 0] += 1 }
            }
            if let winner = votes.max(by: { $0.value < $1.value }), winner.value >= 4,
               winner.value * 2 > votes.values.reduce(0, +) {
                lower[y * 32 + x] = winner.key
            }
        } }
        var missing = (25..<39).flatMap { y in (2..<30).map { y * 32 + $0 } }.filter { lower[$0] == nil }
        let neighbours = [14, -14, 13, -13, 15, -15, 12, -12, 16, -16, 11, -11, 17, -17, 10, -10, 18, -18]
        while !missing.isEmpty {
            let count = missing.count
            for key in missing {
                let x = key % 32
                for distance in neighbours where (2..<30).contains(x + distance) {
                    if let value = lower[key + distance] { lower[key] = value; break }
                }
            }
            missing.removeAll { lower[$0] != nil }
            guard missing.count < count else { return nil }
        }
        let rock = (17..<39).map { y in
            (2..<30).map { x in
                let top = pixel(64 + x, y)
                let value = y >= 25 ? lower[y * 32 + x]!
                    : rockColours.contains(top) ? top : lower[(49 - y) * 32 + x]!
                return String(value, radix: 16)
            }.joined()
        }
        return ["pause": crop(10), "nuke": crop(11), "rock": rock]
    }
}
