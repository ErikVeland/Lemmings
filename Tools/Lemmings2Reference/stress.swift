import Foundation
import NxlvKit

// Deterministic input coverage. This checks runtime stability, not level solutions.
struct Replay: Encodable {
    struct Input: Codable { let tick:Int; let lemming:Int; let skill:Int }
    struct Pointer: Codable { let tick:Int; let x:Int; let y:Int; let fanX:Int; let fanY:Int; let fan:Bool }
    let version = 1
    let levelSHA256:String
    let population:Int
    let expectedSaved:Int
    let expectedTicks:Int
    let inputs:[Input]
    let pointers:[Pointer]
}
let period = CommandLine.arguments.count > 4 ? max(1,Int(CommandLine.arguments[4]) ?? 67) : 67
let rotation = CommandLine.arguments.count > 5 ? Int(CommandLine.arguments[5]) ?? 0 : 0
let root = URL(fileURLWithPath:CommandLine.arguments[1])
let campaign = try Lemmings2Campaign(root:root)
let masks = try Lemmings2TerrainMasks(root:root)
var assigned = Set<Int>(), passiveWins = [Int]()
var totalTicks = 0
for tribe in 0..<12 {
    let style = try Lemmings2Style(data:Data(contentsOf:root.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[tribe]).DAT")))
    for number in tribe*10..<tribe*10+10 {
        if CommandLine.arguments.count > 3 && CommandLine.arguments[3] != "all" && !CommandLine.arguments[3].split(separator:",").compactMap({Int($0)}).contains(number) { continue }
        let level = campaign.levels[number]
        var game = try Lemmings2Runtime(level:level,style:style,masks:masks,total:6)
        var assignments = 0
        var inputs = [Replay.Input](), pointers = [Replay.Pointer]()
        while !game.isComplete && game.tick <= level.timeLimitSeconds*15+1 {
            let phase = game.tick/period
            if let actor = game.lemmings.first(where:{$0.active}) {
                let dx = phase%2 == 0 ? 60 : -60
                let fan = phase%3 == 0
                let x = max(level.minimumScreenX,min(level.maximumScreenX+319,fan ? actor.x-dx : actor.x+dx))
                let y = max(level.minimumScreenY,min(level.maximumScreenY+159,fan ? actor.y+24 : actor.y-32))
                pointers.append(.init(tick:game.tick,x:x,y:y,fanX:x,fanY:y,fan:fan))
                game.setAim(x:x,y:y,held:!fan)
                game.setFan(x:x,y:y,active:fan)
            }
            if game.tick.isMultiple(of:period) {
                for offset in game.supplies.indices {
                    let slot = (offset+rotation+game.supplies.count)%game.supplies.count
                    if let actor = game.lemmings.first(where:{game.canAssign(slot:slot,to:$0.id)}) {
                        game.setFan(x:0,y:0,active:false)
                        guard game.assign(slot:slot,to:actor.id) else { continue }
                        if let p = pointers.last, p.fan { game.setFan(x:p.fanX,y:p.fanY,active:true) }
                        inputs.append(.init(tick:game.tick,lemming:actor.id,skill:game.configuration.skills[slot].rawValue))
                        assigned.insert(game.configuration.skills[slot].rawValue); assignments += 1; break
                    }
                }
            }
            game.step()
            _ = game.drainSoundEvents()
            precondition(game.saved+game.lost <= game.released,"Population accounting failed")
            precondition(game.supplies.allSatisfy{$0 >= 0},"Negative skill stock")
        }
        precondition(game.isComplete,"Level did not terminate at its time limit")
        if game.didWin && assignments == 0 { passiveWins.append(number) }
        if game.didWin && CommandLine.arguments.count > 2 {
            let folder = URL(fileURLWithPath:CommandLine.arguments[2])
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let replay = Replay(levelSHA256:level.fingerprint,population:6,expectedSaved:game.saved,
                                expectedTicks:game.tick,inputs:inputs,pointers:pointers)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(replay).write(to:folder.appendingPathComponent(String(format:"level-%03d.json",number)))
        }
        totalTicks += game.tick
        print("PASS",number,level.title,"ticks",game.tick,"saved",game.saved,"assignments",assignments)
        fflush(stdout)
    }
}
print("PASS full-duration stability runs;",totalTicks,"ticks; skills assigned:",assigned.sorted())
print("Passive completions:",passiveWins)
