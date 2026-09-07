import Foundation
import NxlvKit

func check(_ condition: Bool, _ message: String) {
    guard condition else { FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8)); exit(1) }
}
let root = URL(fileURLWithPath:CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Sources/Ports/Lemm2")
let font = try Lemmings2FrontEndFont(data:Data(contentsOf:root.appendingPathComponent("FONT.DAT")))
let bank = try Lemmings2FrontEnd.Bank(data:Data(contentsOf:root.appendingPathComponent("INTRODAT/GFXIFFS/INTRO.IFF")))
let background = [UInt8](repeating:0,count:64000)
for script in [Data([6,0,6,0,6,0,0xd0,0,0]), Data([6,0,6,0,6,0,0x80,0,0,0xf0,253,255])] {
    var animation = try Lemmings2GAL(script:script,bank:bank,background:background,font:font)
    do { try animation.step(); check(false,"Invalid or unbounded GAL commands were accepted") }
    catch SequelDataError.invalid { }
}
var introduction = try Lemmings2Introduction(root:root,font:font)
var updates = 0, scenes = Set<Int>(), sounds = Set<Int>(), visibleScenes = Set<Int>()
while !introduction.isComplete && updates < 5000 {
    try introduction.step(); updates += 1
    if introduction.scene < 8 {
        scenes.insert(introduction.scene)
        if introduction.animation.pixels.contains(where:{$0 != 0}) { visibleScenes.insert(introduction.scene) }
        sounds.formUnion(introduction.animation.soundSamples)
    }
}
check(introduction.isComplete && updates == 3902,"Original introduction failed to finish at its recorded command timing")
check(scenes == Set(0..<8) && visibleScenes == scenes,"Introduction omitted a scene or its graphics")
check(sounds == Set([54,55,57,58,59,61,62,63,64,65,66,68,69,70,72,73,74,75,76,77,78]),
      "Introduction sound callbacks changed")
print("PASS eight original GAL scenes, 3902 updates, original sound callbacks and command validation")
let assets = try Lemmings2FrontEnd(root:root)
for golden in [false,true] {
    var ending = try Lemmings2Ending(root:root,assets:assets,golden:golden)
    var frames = 0, pages = Set<Int>()
    while !ending.isComplete && frames < 10000 {
        if frames.isMultiple(of:100) { ending.requestContinue() }
        try ending.step(); frames += 1
        if !ending.isComplete { pages.insert(ending.page) }
    }
    check(ending.isComplete && pages == Set(0..<(golden ? 5 : 1)),"Ending failed to advance through its original scripts")
    print("PASS \(golden ? "ark" : "retry") ending: \(pages.count) pages, \(frames) updates")
}

let ark = try Lemmings2Ark(data:Data(contentsOf:root.appendingPathComponent("ARK.ANM")))
check(ark.frames.count == 100 && ark.frames[0] != ark.frames[99],"Ark departure movie is incomplete")
for data in [Data(),Data(repeating:0,count:772)] {
    do { _ = try Lemmings2Ark(data:data); check(false,"Malformed ark movie accepted") }
    catch SequelDataError.invalid { }
}
print("PASS original 100-frame ark departure and malformed movie validation")

let walkerURL = root.appendingPathComponent("WALKER.DAT")
if FileManager.default.fileExists(atPath:walkerURL.path) {
    let walker = try Lemmings2Walker(data:Data(contentsOf:walkerURL))
    check(walker.frames.count == 16 && walker.frames.allSatisfy {$0.opaque.contains(true)},"Walker images incomplete")
    check(Lemmings2Walker.phase(x:10,direction:1) == 0 && Lemmings2Walker.phase(x:10,direction:-1) == 8,
          "Walker pose must follow position and direction")
    print("PASS original sixteen walker poses and position-based selection")
}
var awardCampaign = try Lemmings2Campaign(root:root)
let allGold = Dictionary(uniqueKeysWithValues:awardCampaign.levels.enumerated().map { i,level in
    (i,Lemmings2Campaign.Result(startingPopulation:60,saved:60,medal:.gold,levelFingerprint:level.fingerprint))
})
try awardCampaign.restore(.init(tribe:1,level:9,results:allGold))
for newPiece in [false,true] {
    var award = try Lemmings2Award(root:root,assets:assets,campaign:awardCampaign,newPiece:newPiece)
    var fanfares: [Int] = []
    for _ in 0..<1000 { try award.step(); fanfares += award.animation.soundSamples }
    check(fanfares == (newPiece ? [50] : []),"Talisman fanfare did not follow the native script")
    check(award.animation.pixels != assets.pictures["AWARD"],"Talisman pieces were not assembled")
}
print("PASS original talisman assembly, existing pieces and new-piece fanfare")
