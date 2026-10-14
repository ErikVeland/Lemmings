import Foundation
import Testing
@testable import NxlvKit

struct MacMonochromeBackpackTests {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    @Test func allPosesKeepForegroundAndBinaryPatterns() throws {
        let hidden: Set<ClassicLemmingPose> = [.drowning, .splatting, .frying, .explosion, .exiting]
        for family in ["lemmings", "ohno", "xmas", "holiday"] {
            let artwork = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/monochrome/" + family))
            for pose in ClassicLemmingPose.allCases {
                for left in [false, true] {
                    for tick in 0..<32 {
                        let source = try #require(artwork.lemming(pose: pose, left: left, tick: tick))
                        let disabled = ClassicMonochromeBackpack.render(source, kind: nil, pose: pose, left: left)
                        #expect(disabled.rgba == source.rgba && disabled.x == source.x)
                        var patterns = Set<Data>()
                        for kind in ClassicMonochromeBackpack.Kind.allCases {
                            let frame = ClassicMonochromeBackpack.render(source, kind: kind, pose: pose, left: left)
                            if hidden.contains(pose) {
                                #expect(frame.rgba == source.rgba && frame.x == source.x)
                                continue
                            }
                            patterns.insert(frame.rgba)
                            let guide = try #require(source.backpackGuide)
                            let padding = source.x - frame.x
                            #expect(frame.width == source.width + padding * 2)
                            #expect(frame.y == source.y && frame.height == source.height)
                            var changed = false, binary = true
                            for y in 0..<frame.height { for x in 0..<frame.width {
                                let p = (y * frame.width + x) * 4
                                if frame.rgba[p + 3] != 0 {
                                    let value = frame.rgba[p]
                                    if value != 0 && value != 255 { binary = false }
                                    if frame.rgba[p + 1] != value || frame.rgba[p + 2] != value { binary = false }
                                }
                                let sx = x - padding
                                if (0..<source.width).contains(sx) {
                                    let original = (y * source.width + sx) * 4
                                    if frame.rgba[p..<p + 4] != source.rgba[original..<original + 4] { changed = true }
                                } else if frame.rgba[p + 3] != 0 { changed = true }
                            } }
                            #expect(changed, "Missing backpack: \(family) \(pose) \(left) \(tick) \(kind)")
                            #expect(binary)
                            for original in guide.foreground where source.rgba[original * 4 + 3] != 0 {
                                let p = ((original / source.width) * frame.width + original % source.width + padding) * 4
                                #expect(frame.rgba[p..<p + 4] == source.rgba[original * 4..<original * 4 + 4])
                            }
                        }
                        if !hidden.contains(pose) { #expect(patterns.count == 3) }
                    }
                    let source = try #require(artwork.lemming(pose: .walking, left: left, tick: 0))
                    let patterns = ClassicMonochromeBackpack.Kind.allCases.map {
                        ClassicMonochromeBackpack.render(source, kind: $0, pose: .walking, left: left).rgba
                    }
                    #expect(Set(patterns).count == 3)
                }
            }
        }
    }
}
