import Foundation
import NxlvKit

struct Input: Codable { let tick: Int; let slot: Int; let id: Int; var aimX: Int? = nil; var aimY: Int? = nil }
struct Candidate { var game: Lemmings2Runtime; var inputs: [Input] }
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let number = Int(CommandLine.arguments[2])!
let level = try Lemmings2Level(data: Data(contentsOf: root.appendingPathComponent(String(format:"LEVELS/LEVEL%03d.DAT",number))))
let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
let masks = try Lemmings2TerrainMasks(root:root)
let initial = try Lemmings2Runtime(level:level,style:style,masks:masks,total:1,allowExperimentalTribes:true)
let goalX = initial.configuration.exits.map(\.x).reduce(0,+) / initial.configuration.exits.count
var beam = [Candidate(game: initial, inputs: [])]
func score(_ c: Candidate) -> Int {
    guard let l = c.game.lemmings.first, l.active || l.state == .saved else { return -100000 }
    if c.game.saved > 0 { return 100000 }
    return l.y * 100 - abs(l.x - goalX) - c.inputs.count * 3
}
for depth in 0..<16 {
    var next: [Candidate] = []
    for source in beam {
        var cursor = source.game
        var positions = Set<String>()
        for _ in 0..<1000 {
            if cursor.saved > 0 {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
                try encoder.encode(source.inputs).write(to:URL(fileURLWithPath:CommandLine.arguments[3]))
                print("FOUND",number,"inputs",source.inputs.count,"tick",cursor.tick); exit(0)
            }
            if cursor.isComplete { break }
            if let lem = cursor.lemmings.first, lem.active {
                let key = "\(lem.x),\(lem.y),\(lem.direction),\(lem.state)"
                if positions.insert(key).inserted && (number != 21 || lem.state == .walking) && ![.falling, .tumbling, .jumping, .floating, .stunned].contains(lem.state) {
                    for slot in cursor.supplies.indices where cursor.canAssign(slot:slot,to:0) {
                        let aims: [(Int?,Int?)] = cursor.configuration.skills[slot] == .roper
                            ? [-1,1].flatMap { direction in [-48,-24,0,24,48].map { (Optional(lem.x+64*direction),Optional(lem.y+$0)) } }
                            : [(nil,nil)]
                        for aim in aims {
                        var trial = cursor
                        let input = Input(tick:trial.tick,slot:slot,id:0,aimX:aim.0,aimY:aim.1)
                        guard trial.assign(slot:slot,to:0) else { continue }
                        if let x=aim.0, let y=aim.1 { trial.setAim(x:x,y:y,held:true) }
                        for _ in 0..<60 {
                            trial.step()
                            if trial.isComplete { break }
                        }
                        for _ in 0..<1500 {
                            guard !trial.isComplete, let moving = trial.lemmings.first,
                                  (number == 21 ? moving.state != .walking : [.falling, .tumbling, .jumping, .floating, .stunned].contains(moving.state)) else { break }
                            trial.step()
                        }
                        let candidate = Candidate(game:trial,inputs:source.inputs + [input])
                        if trial.saved > 0 {
                            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
                            try encoder.encode(candidate.inputs).write(to:URL(fileURLWithPath:CommandLine.arguments[3]))
                            print("FOUND",number,"inputs",candidate.inputs.count,"tick",trial.tick)
                            exit(0)
                        }
                        if score(candidate) > -100000 && (number != 21 || (trial.lemmings.first?.y ?? 0) >= lem.y+8) { next.append(candidate) }
                        if next.count > 1024 {
                            var unique = Set<String>()
                            next = Array(next.sorted { score($0) > score($1) }.filter {
                                guard let l=$0.game.lemmings.first else {return false}
                                return unique.insert("\(l.x),\(l.y),\(l.direction),\($0.game.supplies)").inserted
                            }.prefix(512))
                        }
                        }
                    }
                }
            }
            cursor.step()
        }
    }
    var seen = Set<String>()
    beam = next.sorted { score($0) > score($1) }.filter {
        guard let l=$0.game.lemmings.first else {return false}
        return seen.insert("\(l.x),\(l.y),\(l.direction),\($0.game.supplies)").inserted
    }.prefix(96).map{$0}
    if let best = beam.first { try JSONEncoder().encode(best.inputs).write(to:URL(fileURLWithPath:CommandLine.arguments[3]+".depth\(depth)")) }
    print("DEPTH",depth,"candidates",next.count,"best",beam.map{score($0)})
    fflush(stdout)
    if beam.isEmpty { break }
}
if let best = beam.first {
    try JSONEncoder().encode(best.inputs).write(to:URL(fileURLWithPath:CommandLine.arguments[3]+".partial"))
}
print("No replay found within the search bounds.")
