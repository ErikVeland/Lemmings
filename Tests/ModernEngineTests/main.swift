import Foundation
import NxlvKit

func check(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { print("FAIL: \(message)"); exit(1) }
}

var terrain = ModernTerrain(bounds: ModernRect(x: 0, y: 0, width: 320, height: 180))
terrain.addSolid(ModernRect(x: 0, y: 120, width: 320, height: 60))
let level = ModernLevel(bounds: ModernRect(x: 0, y: 0, width: 320, height: 180), spawn: ModernPoint(x: 40, y: 80), exit: ModernRect(x: 260, y: 100, width: 40, height: 20), totalLemmings: 1, requiredToSave: 1, spawnInterval: 0.1, terrain: terrain, skillInventory: [.builder: 1, .bomber: 1])
var engine = ModernLemmingsEngine(level: level)
for _ in 0..<600 { engine.update(deltaTime: 1.0 / 60.0) }
check(engine.spawned == 1, "one lemming spawns")
check(engine.dead + engine.saved == 1, "level resolves")

var skillTerrain = ModernTerrain(bounds: ModernRect(x: 0, y: 0, width: 320, height: 180))
skillTerrain.addSolid(ModernRect(x: 0, y: 120, width: 320, height: 60))
let skillLevel = ModernLevel(bounds: ModernRect(x: 0, y: 0, width: 320, height: 180), spawn: ModernPoint(x: 40, y: 110), exit: ModernRect(x: 260, y: 100, width: 40, height: 20), totalLemmings: 1, requiredToSave: 1, spawnInterval: 0.1, terrain: skillTerrain, skillInventory: [.builder: 1])
var skillEngine = ModernLemmingsEngine(level: skillLevel)
for _ in 0..<30 { skillEngine.update(deltaTime: 1.0 / 60.0) }
check(skillEngine.assign(.builder, to: 0), "builder assigns to walking lemming")
check(skillEngine.level.skillInventory[.builder] == 0, "builder inventory decrements")
check(skillEngine.lemmings[0].state == .building, "lemming enters building state")

var timeoutTerrain = ModernTerrain(bounds: ModernRect(x: 0, y: 0, width: 320, height: 180))
timeoutTerrain.addSolid(ModernRect(x: 0, y: 120, width: 320, height: 60))
let timeoutLevel = ModernLevel(bounds: ModernRect(x: 0, y: 0, width: 320, height: 180), spawn: ModernPoint(x: 40, y: 110), exit: ModernRect(x: 300, y: 100, width: 10, height: 10), totalLemmings: 1, requiredToSave: 1, spawnInterval: 0.1, terrain: timeoutTerrain, timeLimit: 0.25)
var timeoutEngine = ModernLemmingsEngine(level: timeoutLevel)
for _ in 0..<30 { timeoutEngine.update(deltaTime: 1.0 / 60.0) }
check(timeoutEngine.isComplete, "time-limited level completes at deadline")
check(!timeoutEngine.didWin, "unresolved lemming fails timeout")

var nukeEngine = ModernLemmingsEngine(level: skillLevel)
for _ in 0..<12 { nukeEngine.update(deltaTime: 1.0 / 60.0) }
nukeEngine.nuke()
for _ in 0..<240 { nukeEngine.update(deltaTime: 1.0 / 60.0) }
check(nukeEngine.dead == nukeEngine.spawned, "nuke resolves every active lemming")

var excavation = ModernTerrain(bounds: ModernRect(x: 0, y: 0, width: 100, height: 60))
excavation.addSolid(ModernRect(x: 0, y: 20, width: 100, height: 20))
excavation.addSolid(ModernRect(x: 40, y: 20, width: 20, height: 20), steel: true)
excavation.removeTerrain(in: ModernRect(x: 10, y: 25, width: 10, height: 10))
check(excavation.isSolid(at: ModernPoint(x: 5, y: 30)), "excavation preserves adjacent terrain")
check(excavation.isSolid(at: ModernPoint(x: 45, y: 30)), "excavation preserves steel terrain")
print("Modern engine tests passed")
