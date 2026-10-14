import CoreGraphics
import Foundation
import LemmingsGameArt

extension TVExperienceAudit {
    @MainActor static func checkPointer(root: URL) throws {
        let output = root.appendingPathComponent(".build/tv-experience/pointer")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let states = [("empty", false, false), ("eligible", true, true),
                      ("unavailable", false, true), ("hud", true, true)]
        let atlas = try context(width: 512, height: 128)
        atlas.setFillColor(CGColor(gray: 0.12, alpha: 1))
        atlas.fill(CGRect(x: 0, y: 0, width: 512, height: 128))
        for (index, state) in states.enumerated() {
            for scale in [1, 2] {
                let bitmap = try context(width: 128 * scale, height: 128 * scale)
                bitmap.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
                TVPlayfieldArt.drawAimPointer(at: CGPoint(x: 64, y: 64), eligible: state.1,
                                             occupied: state.2, context: bitmap)
                guard let bytes = bitmap.data?.assumingMemoryBound(to: UInt8.self) else {
                    throw Failure.invalid("Pointer pixels unavailable")
                }
                func coloured(_ x: Int, _ y: Int) -> Bool {
                    let offset = (bitmap.height - 1 - y) * bitmap.bytesPerRow + x * 4
                    return bytes[offset + 3] > 0 && (bytes[offset] > 0 || bytes[offset + 1] > 0 || bytes[offset + 2] > 0)
                }
                for y in 50 * scale..<78 * scale {
                    for x in 50 * scale..<78 * scale {
                        guard coloured(x, y) == coloured(128 * scale - 1 - x, y),
                              coloured(x, y) == coloured(x, 128 * scale - 1 - y) else {
                            throw Failure.invalid("Pointer is not square and centred: " + state.0)
                        }
                    }
                }
                guard coloured(53 * scale, 53 * scale), coloured(74 * scale, 74 * scale),
                      !coloured(64 * scale, 64 * scale), !coloured(52 * scale, 64 * scale) else {
                    throw Failure.invalid("Pointer corners or clear centre differ: " + state.0)
                }
                try png(bitmap, at: output.appendingPathComponent(state.0 + "-\(scale)x.png"))
            }
            TVPlayfieldArt.drawAimPointer(at: CGPoint(x: 64 + index * 128, y: 64), eligible: state.1,
                                         occupied: state.2, context: atlas)
        }
        try png(atlas, at: output.appendingPathComponent("states.png"))
        print("PASS 8 TV square pointer renders: empty, eligible, unavailable and HUD at 1x/2x")
    }
}
