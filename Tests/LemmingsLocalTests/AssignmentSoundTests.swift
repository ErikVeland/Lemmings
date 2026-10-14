#if os(macOS)
import Foundation
import LemmingsAudio
import NxlvKit
import Testing

struct AssignmentSoundTests {
    @Test(arguments: ["Ports/amiga_extracted/lemmings", "Sounds/Amiga"])
    func originalAssignmentSampleLoadsFromMobileAndTVBundles(_ bankPath: String) throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        let resources = root.appendingPathComponent("Contents/Resources")
        let destination = resources.appendingPathComponent(bankPath)
        try files.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: root) }
        let plist = try PropertyListSerialization.data(fromPropertyList: [
            "CFBundleIdentifier": "academy.glasscode.lemmings.assignment." + UUID().uuidString,
            "CFBundlePackageType": "BNDL"
        ], format: .xml, options: 0)
        try plist.write(to: root.appendingPathComponent("Contents/Info.plist"))
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Ports/amiga_extracted/lemmings")
        for bank in ["basicfx", "fullfx"] {
            try files.copyItem(at: source.appendingPathComponent(bank), to: destination.appendingPathComponent(bank))
        }
        let bundle = try #require(Bundle(url: root))
        let directory = try #require(BundledGameResources.amigaSoundDirectory(in: bundle))
        #expect(directory.standardizedFileURL == destination.standardizedFileURL)
        let player = SoundEffectPlayer()
        let loaded = try player.loadAmigaSounds(directory: directory)
        #expect(loaded.contains(.assignSkill))
        final class Capture: @unchecked Sendable {
            var count = 0
            var peak: Float = 0
            var gain: Float = 0
        }
        let capture = Capture()
        player.onPlay = { samples, _, gain in
            capture.count += 1
            capture.peak = samples.map { abs($0) }.max() ?? 0
            capture.gain = gain
        }
        // Scheduling verifies the original sample without starting audio output.
        player.play(.assignSkill)
        #expect(capture.count == 1 && capture.peak > 0 && capture.gain > 0)
        #expect(!player.isRunning)
        player.setMuted(true)
        player.play(.assignSkill)
        #expect(capture.count == 1)
    }
}
#endif
