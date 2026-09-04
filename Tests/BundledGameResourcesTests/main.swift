import Foundation
import NxlvKit

func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8)); exit(1)
    }
}

do {
    guard CommandLine.arguments.count >= 2 else {
        throw SequelDataError.invalid("Pass one or more built app bundles.")
    }
    for path in CommandLine.arguments.dropFirst() {
        guard let bundle = Bundle(url: URL(fileURLWithPath: path)), let resources = bundle.resourceURL else {
            throw SequelDataError.invalid("Cannot read the built app bundle.")
        }
        let root = try BundledGameResources.lemmings2(in: bundle)
        check(root.path.hasPrefix(resources.path + "/"), "L2 resolved outside the app")
        check(!FileManager.default.fileExists(atPath: root.appendingPathComponent("L2.EXE").path)
            && !FileManager.default.fileExists(atPath: root.appendingPathComponent("PROCESS.RKO").path),
            "The bundle includes an unnecessary original interpreter")
        let files = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("LEVELS"),
            includingPropertiesForKeys: nil).filter { $0.pathExtension.lowercased() == "dat" }
        check(files.count == 124, "Embedded L2 levels are incomplete")
        for file in files { _ = try Lemmings2Level(data: Data(contentsOf: file)) }
        let campaign = try Lemmings2Campaign(root: root)
        check(campaign.levels.count == 120, "Embedded campaign is incomplete")
        let front = try Lemmings2FrontEnd(root: root)
        check(front.banks.count == 11 && front.pictures.count == 9, "Embedded original UI is incomplete")
        check(front.pointers.frames.count == 18, "Embedded original selection cursors are missing")
        let sounds = try Lemmings2SoundBank(data: Data(contentsOf: root.appendingPathComponent("MUSIC/SBLAST.VOC")))
        check(sounds.clips.count == 80, "Embedded L2 sound bank is incomplete")
        _ = try Lemmings2TerrainMasks(root: root)
        _ = try Lemmings2Sprites(data: Data(contentsOf: root.appendingPathComponent("VLEMMS.DAT")))
        guard let music = BundledGameResources.music("lemmings_2_music_mod_tsyu", in: bundle) else {
            throw SequelDataError.invalid("Embedded L2 music is missing.")
        }
        let modules = try FileManager.default.contentsOfDirectory(at: music,
            includingPropertiesForKeys: nil).filter { $0.pathExtension.lowercased() == "mod" }
        check(modules.count == 14, "Embedded L2 music is incomplete")
        for module in modules { _ = try ProTrackerModule(data: Data(contentsOf: module)) }
        if FileManager.default.fileExists(atPath: resources.appendingPathComponent("Ports/LEM3CD").path) {
            _ = try BundledGameResources.lemmings3(in: bundle)
            let classics = BundledGameResources.classicDirectories(in: bundle)
            check(classics.count >= 6, "The all-in-one bundle lacks its Classic data sets")
            let titles = Set(try classics.map { try ClassicDataSet.detect(directory: $0).title })
            check(titles.contains(.holidayLemmings1993) && titles.contains(.holidayLemmings1994),
                  "Retail Holiday campaigns are missing from the bundle")
            check(BundledGameResources.macintoshSoundImage(in: bundle) != nil, "Embedded Macintosh sound source is missing")
            for name in ["Graphics", "Levels"] {
                let fork = resources.appendingPathComponent("Ports/MacResourceForks/mac_extracted/Holiday_Lem93_94/Extras/X-Mas Demo '92/" + name + ".rsrc")
                let bytes = try Data(contentsOf: fork)
                check(!bytes.isEmpty, "Macintosh \(name) resource fork was lost during packaging")
            }
            for name in ["lemmings_music_mod", "oh_no_more_lemmings_music_mod", "holiday_lemmings_music_mod",
                         "lemmings_3_music_mod_tsyu"] {
                check(BundledGameResources.music(name, in: bundle) != nil, "Embedded music missing: \(name)")
            }
        }
        if let entries = FileManager.default.enumerator(at: resources, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
            for case let file as URL in entries {
                check(try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true,
                      "Embedded asset still links to the source checkout")
            }
        }
        print("PASS \(bundle.bundleURL.lastPathComponent): 124 L2 maps, original UI and cursors, 80 sound clips, masks, sprites and 14 music modules embedded")
    }
} catch {
    FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8)); exit(1)
}
