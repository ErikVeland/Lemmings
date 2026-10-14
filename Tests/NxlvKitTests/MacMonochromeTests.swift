import Foundation
import Testing
@testable import NxlvKit

struct MacMonochromeTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test func suppliedBanksKeepBinaryPixelsAndEveryAnimation() throws {
        for family in ["lemmings", "ohno", "xmas", "holiday"] {
            let directory = root.appendingPathComponent(".build/mac-artwork/export/monochrome/" + family)
            let artwork = try ClassicMacArtwork(directory: directory)
            #expect(artwork.monochrome)
            #expect(artwork.frame(1200) != nil)
            for frames in artwork.banks.values {
                for frame in frames.compactMap({ $0 }) {
                    #expect(frame.rgba.count == frame.width * frame.height * 4)
                    #expect(stride(from: 0, to: frame.rgba.count, by: 4).allSatisfy {
                        let p = frame.rgba
                        return p[$0 + 3] == 0 || (p[$0] == p[$0 + 1] && p[$0] == p[$0 + 2]
                            && (p[$0] == 0 || p[$0] == 255) && p[$0 + 3] == 255)
                    })
                }
            }
            for pose in ClassicLemmingPose.allCases {
                for left in [false, true] {
                    for tick in 0..<32 {
                        #expect(artwork.lemming(pose: pose, left: left, tick: tick) != nil)
                    }
                }
            }
        }
        let colour = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        #expect(!colour.monochrome)
    }

    @Test func artworkChoiceRequiresInstalledBanksAndSurvivesSaving() throws {
        let absent = ClassicSettingsOptions.available(hasDOSData: true, hasAmigaDisk: true,
            hasMacintoshDisk: true, moduleCount: 0)
        #expect(!absent.graphics.contains(.macintoshMonochrome))
        let installed = ClassicSettingsOptions.available(hasDOSData: true, hasAmigaDisk: true,
            hasMacintoshDisk: true, moduleCount: 0, hasMacintoshMonochromeArtwork: true)
        #expect(installed.graphics.contains(.macintoshMonochrome))
        var settings = ClassicSettings()
        settings.graphics = .macintoshMonochrome
        let restored = try JSONDecoder().decode(ClassicSettings.self, from: JSONEncoder().encode(settings))
        #expect(restored.graphics == .macintoshMonochrome)
        #expect(installed.correcting(restored).graphics == .macintoshMonochrome)
        #expect(absent.correcting(restored).graphics != .macintoshMonochrome)
    }

    @Test func fallbackDitherKeepsMasksAndAuthoredBlackAndWhite() {
        let source = Data([0, 0, 0, 255, 255, 255, 255, 255,
                           120, 100, 80, 0, 128, 128, 128, 255])
        let output = ClassicMacScene.monochromeRGBA(source, width: 2)
        #expect(output.prefix(12) == source.prefix(12))
        #expect(output[15] == 255)
        #expect(output[12] == output[13] && output[13] == output[14])
        #expect(output[12] == 0 || output[12] == 255)
    }

    @Test func terrainAndObjectsCoverEachCampaignStyle() throws {
        let folders = [
            ("lemmings", "Content/lemming1.pc"),
            ("ohno", "Sources/Ports/oh_no_more_lemmings_dos-1991-11-14_2232"),
            ("xmas", "Sources/Ports/xmas_dos_XmasLemmingsV1.9"),
            ("xmas", "Sources/Ports/xmas_dos_XmasLemmingsV1.9a1"),
            ("holiday", ".build/local/Ultimate Lemmings.app/Contents/Resources/Ports/holiday_native_1993"),
            ("holiday", ".build/local/Ultimate Lemmings.app/Contents/Resources/Ports/holiday_native_1994")]
        for (family, folder) in folders {
            let directory = root.appendingPathComponent(folder)
            let artwork = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/monochrome/" + family))
            let campaign = try ClassicDataSet.detect(directory: directory).campaign
            var checked = Set<String>()
            for entry in campaign.levels {
                let level = entry.level
                // Check every mapping, then compose one scene per style and special picture.
                for object in level.objects {
                    let sequences = try #require(artwork.objects[level.groundStyle])
                    #expect(sequences.indices.contains(object.id))
                    let sequence = sequences[object.id]
                    for frame in 0..<sequence.count {
                        #expect(artwork.frame(1600 + level.groundStyle, sequence.base + frame) != nil)
                    }
                }
                guard checked.insert("\(level.groundStyle)/\(level.specialStyle)").inserted else { continue }
                let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
                let special = level.specialStyle > 0
                    ? try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: directory) : nil
                let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special)
                let scene = try ClassicMacScene(level: level, rendered: rendered, artwork: artwork, groundSet: ground)
                #expect(scene.width == rendered.width * 2 && scene.height == rendered.height * 2)
                #expect(scene.terrainRGBA.contains(255))
                var terrain = try ClassicDOSTerrain(renderedLevel: rendered)
                let empty = try #require(terrain.solidMask.firstIndex(of: 0))
                let added = terrain.addSolid(x: empty % rendered.width, y: empty / rendered.width)
                #expect(added)
                let pixels = scene.terrainFrame(terrain: terrain)
                let offset = ((empty / rendered.width * 2) * scene.width + empty % rendered.width * 2) * 4
                #expect(Array(pixels[offset..<offset + 4]) == [255, 255, 255, 255])
            }
        }
    }
}
