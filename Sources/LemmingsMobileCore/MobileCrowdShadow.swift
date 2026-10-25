import Foundation

/// Casts a one-native-pixel shadow onto previously drawn lemmings only.
/// Create one pass per frame, then draw each sprite immediately after casting.
public struct MobileCrowdShadow {
    private var ink = Set<Int>()
    private var shaded = Set<Int>()

    public init() {}

    public mutating func cast(spriteWidth: Int, spriteHeight: Int, x: Int, y: Int,
                       width: Int, height: Int, pixels: UnsafeMutableRawBufferPointer,
                       opaque: (Int, Int) -> Bool) {
        guard spriteWidth > 0, spriteHeight > 0, width > 0, height > 0,
              width <= Int.max / height / 4, pixels.count >= width * height * 4 else { return }
        func contains(_ sx: Int, _ sy: Int) -> Bool {
            (0..<spriteWidth).contains(sx) && (0..<spriteHeight).contains(sy) && opaque(sx, sy)
        }
        let left = max(0, x - 1), right = min(width, x + spriteWidth + 1)
        let top = max(0, y - 1), bottom = min(height, y + spriteHeight + 1)
        guard left < right, top < bottom else { return }
        // Test only rear ink. Terrain, ghosts and transparent margins cannot receive a shadow.
        if !ink.isEmpty {
            for dy in top..<bottom { for dx in left..<right {
                let index = dy * width + dx
                guard ink.contains(index), !shaded.contains(index), !contains(dx - x, dy - y) else { continue }
                var edge = false
                for sy in (dy - y - 1)...(dy - y + 1) {
                    for sx in (dx - x - 1)...(dx - x + 1) where contains(sx, sy) { edge = true }
                }
                guard edge else { continue }
                for channel in 0..<3 {
                    pixels[index * 4 + channel] = UInt8((Int(pixels[index * 4 + channel]) * 62 + 50) / 100)
                }
                shaded.insert(index)
            } }
        }
        for dy in top..<bottom { for dx in left..<right where contains(dx - x, dy - y) {
            let index = dy * width + dx
            ink.insert(index)
            // New foreground ink replaces any shadow on the covered sprite.
            shaded.remove(index)
        } }
    }
}
