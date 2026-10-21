import Foundation
import NxlvKit

/// Hand-drawn 4× numerals. Coordinates describe pixels in the original 16×20 cell, enlarged to 64×80.
public enum GameLemmingsCountdownFace {
    public static let cellWidth = 64
    public static let cellHeight = 80
    private typealias Point = (Int, Int)
    private struct Drawing {
        let contour: [Point]
        var counters: [[Point]] = []
        let light: [Point]
        let shade: [Point]
        let sparkle: Point
    }
    // Every curve, counter, terminal and facet is placed on the final grid.
    private static let drawings: [String: Drawing] = [
        "0": Drawing(contour: [(28,8),(39,8),(47,11),(53,17),(57,27),(59,42),(58,58),(54,68),
            (47,73),(34,75),(22,72),(14,66),(9,57),(7,41),(9,27),(13,18),(20,12)],
            counters: [[(27,23),(36,21),(43,26),(46,36),(46,52),(42,61),(34,64),(26,61),(22,54),(21,38),(23,28)]],
            light: [(17,21),(23,15),(30,12),(39,12),(43,15),(29,17),(24,22),(19,32),(15,37)],
            shade: [(49,47),(55,43),(54,59),(50,66),(43,70),(31,70),(25,67),(43,66),(48,60)], sparkle: (47,19)),
        "1": Drawing(contour: [(26,9),(43,9),(48,15),(47,73),(40,75),(32,72),(32,26),(25,27),(19,22),(19,17)],
            light: [(23,18),(28,13),(40,13),(43,16),(31,18),(27,22)],
            shade: [(41,29),(45,24),(44,70),(40,71),(38,65),(41,60)], sparkle: (40,18)),
        "2": Drawing(contour: [(16,12),(24,9),(43,9),(53,14),(58,22),(58,30),(54,37),(43,45),(29,55),
            (24,62),(56,62),(59,68),(58,75),(10,75),(7,69),(10,59),(18,49),(35,36),(43,29),(43,23),
            (38,20),(29,20),(23,24),(17,27),(10,24),(9,19)],
            light: [(14,18),(24,13),(40,13),(47,16),(39,16),(28,16),(20,21),(15,23)],
            shade: [(16,68),(24,66),(54,66),(56,71),(18,71)], sparkle: (49,21)),
        "3": Drawing(contour: [(16,12),(27,9),(46,9),(55,15),(59,23),(58,32),(53,39),(48,42),
            (55,46),(59,53),(60,63),(55,70),(46,75),(25,75),(14,71),(8,65),(7,58),(13,55),(19,59),
            (25,64),(39,64),(44,61),(44,55),(40,51),(31,50),(30,42),(37,38),(43,33),(44,25),
            (40,21),(27,21),(21,25),(16,28),(10,26),(8,22),(10,17)],
            light: [(14,19),(22,15),(29,13),(44,13),(49,17),(29,17),(22,20),(17,24)],
            shade: [(48,51),(54,54),(56,62),(51,68),(43,71),(28,71),(22,68),(42,67),(49,62)], sparkle: (50,25)),
        "4": Drawing(contour: [(41,9),(49,8),(53,12),(52,49),(59,51),(59,61),(52,62),(52,74),
            (43,75),(40,71),(40,62),(6,62),(5,54),(9,48)],
            counters: [[(39,29),(23,49),(40,49)]],
            light: [(13,49),(39,17),(44,14),(31,33),(20,48),(16,53),(10,56)],
            shade: [(10,56),(38,56),(44,53),(56,54),(56,59),(46,59),(47,70),(43,69),(43,58),(12,59)], sparkle: (47,20)),
        "5": Drawing(contour: [(14,9),(54,9),(57,13),(55,21),(23,21),(21,34),(32,34),(45,36),(54,42),
            (58,51),(58,61),(54,69),(45,74),(23,75),(13,71),(8,64),(8,59),(16,56),(21,61),(28,64),
            (39,63),(43,58),(43,51),(38,47),(28,45),(17,46),(9,42),(10,16)],
            light: [(16,13),(52,13),(53,16),(22,17),(19,28),(15,32),(14,22)],
            shade: [(47,49),(53,47),(55,58),(51,67),(43,70),(26,71),(20,68),(42,66),(48,60)], sparkle: (43,15)),
        "6": Drawing(contour: [(39,8),(49,10),(53,13),(51,20),(35,20),(25,24),(20,34),(18,40),(28,36),
            (42,36),(53,42),(58,51),(58,62),(54,70),(46,75),(24,75),(13,70),(8,60),(7,44),(9,29),(15,17),(26,10)],
            counters: [[(24,50),(32,47),(40,48),(44,53),(44,60),(40,64),(30,64),(24,59)]],
            light: [(15,25),(23,16),(32,12),(47,13),(48,16),(33,16),(25,20),(19,30),(15,38),(12,41)],
            shade: [(49,47),(54,51),(55,62),(50,69),(43,71),(27,71),(20,68),(43,67),(49,61)], sparkle: (48,47)),
        "7": Drawing(contour: [(11,9),(54,9),(60,14),(59,22),(52,31),(47,41),(42,51),(37,62),
            (36,73),(28,75),(23,71),(24,59),(28,46),(35,34),(42,22),(10,22),(6,18),(7,13)],
            light: [(13,13),(52,13),(55,16),(14,17),(10,17)],
            shade: [(47,27),(53,24),(43,45),(36,64),(33,71),(28,70),(31,60),(38,43)], sparkle: (51,17)),
        "8": Drawing(contour: [(27,9),(43,9),(52,14),(57,23),(57,31),(52,39),(55,44),(60,54),
            (60,64),(54,71),(46,75),(24,75),(14,71),(8,64),(7,54),(11,46),(17,40),(12,33),
            (12,23),(17,15)],
            counters: [[(27,22),(37,21),(43,26),(43,32),(38,37),(29,36),(25,31),(24,26)],
                [(27,51),(37,50),(44,54),(46,60),(42,65),(31,65),(24,61),(23,56)]],
            light: [(18,23),(24,16),(30,13),(42,13),(47,17),(31,17),(26,20),(21,28)],
            shade: [(50,49),(55,54),(56,62),(50,69),(43,71),(28,71),(21,68),(43,67),(50,61)], sparkle: (49,23)),
        "9": Drawing(contour: [(25,9),(44,9),(53,14),(58,23),(59,39),(57,55),(50,67),(40,74),
            (24,77),(16,74),(18,67),(33,65),(42,59),(46,49),(35,53),(23,51),(13,45),(8,36),(7,25),(12,16)],
            counters: [[(26,23),(36,21),(43,25),(45,32),(42,38),(33,40),(25,36),(22,30)]],
            light: [(15,24),(21,17),(28,13),(41,13),(47,17),(29,17),(23,21),(18,29)],
            shade: [(51,43),(55,39),(53,54),(47,64),(38,70),(25,73),(22,70),(36,66),(45,58)], sparkle: (49,26))
    ]
    private static let cache = GameAssetCache<GameLemmingsDisplayFace.Glyph>(capacity: 16)

    /// Bearings and advances remain exactly four times those of the large source face.
    public static func frame(_ source: ClassicMacArtwork.Frame, sequence: String) -> GameLemmingsDisplayFace.Glyph? {
        guard let drawing = drawings[sequence] else { return nil }
        let key = "\(sequence):\(source.rgba.hashValue)"
        if let glyph = cache.value(for: key) { return glyph }
        func contains(_ points: [Point], _ x: Int, _ y: Int) -> Bool {
            let px = Double(x) + 0.5, py = Double(y) + 0.5
            var result = false
            for i in points.indices {
                let a = points[i], b = points[(i + 1) % points.count]
                if (Double(a.1) > py) != (Double(b.1) > py),
                   px < Double(b.0 - a.0) * (py - Double(a.1)) / Double(b.1 - a.1) + Double(a.0) { result.toggle() }
            }
            return result
        }
        let width = source.width * 4, height = source.height * 4, left = source.x * 4, top = source.y * 4
        let body = (0..<height).flatMap { y in (0..<width).map { x in
            contains(drawing.contour, x + left, y + top)
                && !drawing.counters.contains { contains($0, x + left, y + top) }
        } }
        func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height && body[y * width + x] }
        let original = [UInt8](source.rgba)
        let ramp: [[UInt8]] = [[0,0,64],[0,48,144],[0,96,192],[48,128,208],[112,160,209],[176,192,224],[255,221,221]]
        func paint(_ x: Int, _ y: Int) -> [UInt8] {
            // Keep the original painted clusters inside the newly drawn silhouette.
            let sx = x / 4, sy = y / 4
            for radius in 0...5 {
                for dy in -radius...radius { for dx in -radius...radius where abs(dx) + abs(dy) == radius {
                    let px = sx + dx, py = sy + dy
                    guard px >= 0, py >= 0, px < source.width, py < source.height else { continue }
                    let i = (py * source.width + px) * 4
                    if original[i + 3] > 0 && original[i + 2] > 64 { return Array(original[i..<i + 3]) }
                } }
            }
            return ramp[3]
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            var rgb: [UInt8]
            if inside(x, y) {
                rgb = paint(x, y)
                if rgb == ramp[6] { rgb = ramp[5] }
                if contains(drawing.light, x + left, y + top) { rgb = ramp[4] }
                if contains(drawing.shade, x + left, y + top) { rgb = ramp[1] }
                if !inside(x + 2, y + 2) { rgb = ramp[1] }
                else if !inside(x - 1, y - 1) { rgb = ramp[5] }
                else if !inside(x - 2, y - 2) { rgb = ramp[4] }
                let dx = x + left - drawing.sparkle.0, dy = y + top - drawing.sparkle.1
                if abs(dx) + abs(dy) <= 1 { rgb = ramp[6] }
                else if abs(dx) + abs(dy) == 2 { rgb = ramp[5] }
            } else if (-2...2).contains(where: { dy in (-2...2).contains { dx in inside(x + dx, y + dy) } }) {
                rgb = ramp[0]
            } else { continue }
            pixels.replaceSubrange((y * width + x) * 4..<(y * width + x + 1) * 4, with: rgb + [255])
        } }
        let glyph = GameLemmingsDisplayFace.Glyph(x: left, y: top, width: width, height: height, rgba: Data(pixels))
        cache.insert(glyph, for: key)
        return glyph
    }
}
