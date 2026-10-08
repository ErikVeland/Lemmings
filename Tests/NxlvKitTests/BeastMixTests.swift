import Foundation
import Testing
@testable import NxlvKit

struct BeastMixTests {
    @Test func modernBeastRhythmIsCentredWithoutChangingFaithfulStereo() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        var data = try Data(contentsOf: root.appendingPathComponent("Sources/Music/lemmings_music_mod/beastI.mod"))
        // Isolate the actual bass waveform while retaining the authored patterns.
        let patterns = Int(data[952..<1080].max()!) + 1
        var offset = 1084 + patterns * 1024
        for index in 0..<31 {
            let header = 20 + index * 30
            let size = (Int(data[header + 22]) * 256 + Int(data[header + 23])) * 2
            if index != 0 { data.replaceSubrange(offset..<(offset + size), with: repeatElement(UInt8(0), count: size)) }
            offset += size
        }
        let module = try ProTrackerModule(data: data)
        #expect(ProTrackerBeastMix.percussionSamples(for: module) == [1, 5, 8])
        let tuning = ProTrackerBeastMix.tuning(for: module, existing: [:])
        #expect(Set(tuning.keys) == [0, 1, 5, 8])
        #expect(tuning.values.allSatisfy { $0.centering == 1 })
        func energy(_ preset: ProTrackerEnhancements) -> (Double, Double) {
            var player = ProTrackerEnhancedPlayer(module: module, enhancements: preset)
            var left = 0.0, right = 0.0
            for _ in 0..<(44100 * 4) {
                let sample = player.nextFrame()
                left += Double(sample.left * sample.left)
                right += Double(sample.right * sample.right)
            }
            return (left, right)
        }
        let modern = energy(.modern), faithful = energy(.faithful)
        #expect(modern.0 + modern.1 > 0.01)
        #expect(abs(modern.0 - modern.1) / (modern.0 + modern.1) < 0.12)
        #expect(faithful.0 > faithful.1 * 3)
    }
}
