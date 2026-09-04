import Foundation
import NxlvKit

func require(_ value: Bool, _ message: String) throws {
    if !value { throw SequelDataError.invalid(message) }
}

do {
    let record = Data([7, 0, 32, 0, 0, 0, 2, 0, 1, 1, 1, 0, 0, 0, 0])
    let sequential = try Lemmings3StyleBank(objects: record, frames: Data([0, 0, 1, 1, 0, 0, 16]), blocks: Data())
    try require(try sequential.attributes(object: 7) == [0x1000], "L3 sequential native attribute words")
    let sparse = try Lemmings3StyleBank(objects: record, frames: Data([0, 0, 0, 1, 0, 7, 0, 0, 0, 96, 0]), blocks: Data())
    try require(try sparse.attributes(object: 7) == [0x60], "L3 sparse native attribute words")
    let malformed = try Lemmings3StyleBank(objects: record, frames: Data([0, 0, 0, 1, 0, 7, 0, 1, 0, 96, 0]), blocks: Data())
    var rejected = false
    do { _ = try malformed.attributes(object: 7) } catch { rejected = true }
    try require(rejected, "L3 rejects out-of-range attribute cells")
    print("PASS native L3 attribute grids and bounds")
    let basePalette = [UInt8](repeating: 17, count: 1024)
    let spritePalette = try Lemmings3Sprites.palette(Data(repeating: 255, count: 96), over: basePalette)
    try require(spritePalette.prefix(128).allSatisfy { $0 == 255 } && Array(spritePalette.dropFirst(128)) == Array(basePalette.dropFirst(128)), "L3 creature palette masks VGA bits and preserves terrain colors")
    var badPaletteRejected = false
    do { _ = try Lemmings3Sprites.palette(Data(repeating: 0, count: 95), over: basePalette) }
    catch { badPaletteRejected = true }
    try require(badPaletteRejected, "L3 truncated creature palette rejected")
    var tags = [UInt16](repeating: 0x1000, count: 128 * 64)
    for y in 48..<64 { for x in 0..<128 { tags[y * 128 + x] = 0x20 } }
    let config = Lemmings3Runtime.Configuration(width: 128, height: 64, attributes: tags,
        entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 1, releaseInterval: 1, releaseDelay: 0)
    var game = try Lemmings3Runtime(configuration: config)
    for _ in 0..<20 { game.step() }
    try require(game.lemmings[0].state == .walking, "L3 landing")
    try require(game.assign(.blocker, to: 0), "L3 blocker assignment")
    let blockedX = game.lemmings[0].x
    for _ in 0..<10 { game.step() }
    try require(game.lemmings[0].x == blockedX, "L3 blocker holds position")
    try require(!game.assign(.blocker, to: 0), "L3 duplicate blocker rejected")
    try require(game.assign(.walker, to: 0) && game.lemmings[0].direction == 1, "L3 unblock")
    try require(game.assign(.walker, to: 0) && game.lemmings[0].direction == -1, "L3 turn")
    try require(game.assign(.walker, to: 0), "L3 turn back")
    try require(game.assign(.jumper, to: 0), "L3 jump")
    game.step()
    try require(game.lemmings[0].y < 48, "L3 jump rises")
    for _ in 0..<150 { game.step() }
    try require(game.saved == 1 && game.isComplete, "L3 jump, landing and exit")
    var replay = try Lemmings3Runtime(configuration: config)
    var duplicate = replay
    for _ in 0..<200 { replay.step(); duplicate.step() }
    try require(replay.lemmings == duplicate.lemmings, "L3 deterministic replay")
    try require(!replay.assign(.walker, to: 0), "L3 completed run rejects actions")
    var aborted = try Lemmings3Runtime(configuration: config)
    aborted.step(); aborted.abort()
    let abortedTick = aborted.tick
    aborted.step()
    try require(aborted.isComplete && aborted.lost == 1 && aborted.tick == abortedTick, "L3 abort is terminal")
    print("PASS experimental L3 landing, blocker, turn, jump, exit and deterministic ticks")

    var trapTags = tags
    for y in 46..<48 { for x in 40..<56 { trapTags[y * 128 + x] = 0x4000 } }
    let trap = Lemmings3Runtime.Trap(id: 0, cells: [.init(x: 40, y: 46), .init(x: 48, y: 46)], frameCount: 12)
    for invalid in [
        Lemmings3Runtime.Trap(id: 0, cells: trap.cells, frameCount: 12, startFrame: 12),
        Lemmings3Runtime.Trap(id: 0, cells: trap.cells, frameCount: 12, frameDelay: -1),
        Lemmings3Runtime.Trap(id: 0, cells: trap.cells, frameCount: 12, cyclePause: 128)
    ] {
        var rejected = false
        do {
            _ = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: trapTags,
                entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], traps: [invalid]))
        } catch { rejected = true }
        try require(rejected, "L3 rejects invalid trap animation bounds")
    }
    func trapGame(total: Int = 1, interval: Int = 1, covered: Bool = false) throws -> Lemmings3Runtime {
        try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: covered ? tags : trapTags,
            entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: total,
            releaseInterval: interval, releaseDelay: 0, traps: [trap]))
    }
    var victim = try trapGame()
    for _ in 0..<30 { victim.step() }
    try require(victim.lemmings[0].state == .trapped && victim.trapFrame(id: 0) > 0, "L3 native trap cell triggers animation")
    try require(!victim.assign(.jumper, to: 0), "L3 trapped lemmings reject actions")
    for _ in 0..<150 { victim.step() }
    try require(victim.lost == 1 && victim.isComplete && victim.trapFrame(id: 0) == 0, "L3 trap finishes and rearms")
    var crowd = try trapGame(total: 2)
    for _ in 0..<200 { crowd.step() }
    try require(crowd.lost == 1 && crowd.saved == 1, "L3 trap takes one victim per cycle")
    var rearmed = try trapGame(total: 2, interval: 60)
    for _ in 0..<300 { rearmed.step() }
    try require(rearmed.lost == 2, "L3 trap captures again after rearming")
    var covered = try trapGame(covered: true)
    for _ in 0..<200 { covered.step() }
    try require(covered.saved == 1, "L3 covered trap trigger is inactive")
    var jumper = try trapGame()
    for _ in 0..<200 {
        for lem in jumper.lemmings where lem.state == .walking && lem.x == 36 { _ = jumper.assign(.jumper, to: lem.id) }
        jumper.step()
    }
    try require(jumper.saved == 1, "L3 jumping clears a trap trigger")
    print("PASS L3 trap bounds, capture, animation, cooldown, covering and jumping")

    var climbTags = [UInt16](repeating: 0x1000, count: 128 * 128)
    for y in 96..<128 { for x in 0..<128 { climbTags[y * 128 + x] = 0x20 } }
    for y in 48..<96 { for x in 48..<128 { climbTags[y * 128 + x] = 0x20 } }
    var climber = try Lemmings3Runtime(configuration: .init(width: 128, height: 128, attributes: climbTags,
        entrance: .init(x: 20, y: 88), exits: [.init(x: 110, y: 46)], total: 1, releaseInterval: 1, releaseDelay: 0,
        pickups: [.init(id: 0, tool: .sucker, x: 20, y: 88)]))
    for _ in 0..<12 { climber.step() }
    try require(climber.useTool(to: 0, direction: .up), "L3 activates suckers")
    try require(climber.lemmings[0].tool == nil && climber.lemmings[0].mobilityTool == .sucker, "L3 consumes activated climbing equipment")
    var sawClimbing = false
    for _ in 0..<250 { climber.step(); sawClimbing = sawClimbing || climber.lemmings[0].state == .climbing }
    try require(sawClimbing && climber.saved == 1, "L3 climbs a wall and steps onto its top")
    var shimmyTags = [UInt16](repeating: 0x1000, count: 128 * 128)
    for y in 96..<128 { for x in 0..<128 where x < 36 || x >= 92 { shimmyTags[y * 128 + x] = 0x20 } }
    for x in 20..<100 { shimmyTags[64 * 128 + x] = 0x20 }
    func shimmyGame() throws -> Lemmings3Runtime {
        try Lemmings3Runtime(configuration: .init(width: 128, height: 128, attributes: shimmyTags,
            entrance: .init(x: 20, y: 88), exits: [.init(x: 110, y: 94)], total: 1, releaseInterval: 1, releaseDelay: 0,
            pickups: [.init(id: 0, tool: .shimmy, x: 20, y: 88)]))
    }
    var shimmier = try shimmyGame()
    for _ in 0..<12 { shimmier.step() }
    try require(shimmier.useTool(to: 0, direction: .right), "L3 activates shimmy jump")
    var sawShimmying = false
    for _ in 0..<250 { shimmier.step(); sawShimmying = sawShimmying || shimmier.lemmings[0].state == .shimmying }
    try require(sawShimmying && shimmier.saved == 1, "L3 crosses a gap along a flat ceiling")
    var interrupted = try shimmyGame()
    for _ in 0..<12 { interrupted.step() }
    _ = interrupted.useTool(to: 0, direction: .right)
    for _ in 0..<40 where interrupted.lemmings[0].state != .shimmying { interrupted.step() }
    try require(interrupted.assign(.walker, to: 0) && interrupted.lemmings[0].state == .falling && interrupted.lemmings[0].mobilityTool == nil, "L3 walker releases ceiling grip")
    shimmyTags[64 * 128 + 60] = 0x1000
    var uneven = try shimmyGame()
    for _ in 0..<12 { uneven.step() }
    _ = uneven.useTool(to: 0, direction: .right)
    for _ in 0..<200 { uneven.step() }
    try require(uneven.lost == 1, "L3 shimmy releases at an uneven ceiling")
    var tallWall = [UInt16](repeating: 0x1000, count: 128 * 512)
    for y in 480..<512 { for x in 0..<128 { tallWall[y * 128 + x] = 0x20 } }
    for y in 16..<480 { for x in 48..<128 { tallWall[y * 128 + x] = 0x20 } }
    var exhausted = try Lemmings3Runtime(configuration: .init(width: 128, height: 512, attributes: tallWall,
        entrance: .init(x: 20, y: 472), exits: [.init(x: 110, y: 14)], total: 1, releaseInterval: 1, releaseDelay: 0,
        pickups: [.init(id: 0, tool: .sucker, x: 20, y: 472)]))
    for _ in 0..<12 { exhausted.step() }
    _ = exhausted.useTool(to: 0, direction: .up)
    for _ in 0..<114 { exhausted.step() }
    try require(exhausted.lemmings[0].state == .climbing && exhausted.lemmings[0].mobilityTicks == 1, "L3 active sucker lifetime counts down")
    exhausted.step()
    try require(exhausted.lemmings[0].state == .falling && exhausted.lemmings[0].mobilityTool == nil, "L3 exhausted climber falls")
    print("PASS L3 sucker activation, wall climbing, shimmy jump, ceiling traversal and release")

    func explosiveGame(_ tool: Lemmings3Runtime.Tool, protected: Bool = false) throws -> Lemmings3Runtime {
        var run = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: tags,
            entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 1, releaseInterval: 1, releaseDelay: 0,
            pickups: [.init(id: 0, tool: tool, x: 20, y: 40), .init(id: 1, tool: .bricks, x: 30, y: 40)],
            backgroundAttributes: protected ? tags : nil))
        for _ in 0..<12 { run.step() }
        return run
    }
    var bomber = try explosiveGame(.bomb)
    try require(bomber.useTool(to: 0, direction: .up), "L3 drops bomb at feet")
    try require(bomber.explosives.count == 1 && bomber.lemmings[0].tool == nil, "L3 bomb consumption")
    try require(bomber.assign(.blocker, to: 0), "L3 bomber remains controllable after placement")
    for _ in 0..<114 { bomber.step() }
    try require(bomber.lost == 0 && bomber.terrainEdits.isEmpty, "L3 bomb waits five seconds")
    bomber.step()
    try require(bomber.lost == 1 && bomber.explosives.isEmpty && bomber.terrainEdits.values.contains(false), "L3 bomb blast kills and removes terrain")
    try require(bomber.pickups[1].quantity == 6, "L3 blast leaves tool boxes intact")
    var protectedBomb = try explosiveGame(.bomb, protected: true)
    _ = protectedBomb.useTool(to: 0, direction: .right); _ = protectedBomb.assign(.blocker, to: 0)
    for _ in 0..<115 { protectedBomb.step() }
    try require(protectedBomb.terrainEdits.isEmpty && protectedBomb.lost == 1, "L3 blast preserves permanent terrain")
    var grenadier = try explosiveGame(.grenade)
    let launchX = grenadier.lemmings[0].x
    try require(grenadier.useTool(to: 0, direction: .down), "L3 throws grenade in facing direction")
    try require(grenadier.lemmings[0].quantity == 3 && grenadier.explosives[0].velocityX == 4 && grenadier.explosives[0].velocityY == -4, "L3 four-grenade box and 45-degree launch")
    _ = grenadier.assign(.blocker, to: 0)
    for _ in 0..<183 { grenadier.step() }
    try require(grenadier.explosives.count == 1 && grenadier.explosives[0].x > launchX && grenadier.terrainEdits.isEmpty, "L3 grenade travels and waits eight seconds")
    grenadier.step()
    try require(grenadier.explosives.isEmpty && grenadier.terrainEdits.values.contains(false), "L3 grenade blast creates a crater")
    print("PASS L3 bomb and grenade inventory, fuses, terrain, permanent protection and tool-box survival")
    var fighter = try explosiveGame(.hadoken)
    let fireballX = fighter.lemmings[0].x
    try require(fighter.useTool(to: 0, direction: .left), "L3 Hadoken activation")
    try require(fighter.lemmings[0].tool == nil && fighter.fireballs.count == 1, "L3 Hadoken consumes a charge")
    fighter.step()
    try require(fighter.fireballs[0].x == fireballX + 4, "L3 Hadoken follows facing, not work direction")
    for _ in 0..<80 { fighter.step() }
    try require(fighter.fireballs.isEmpty && fighter.lost == 0 && fighter.terrainEdits.isEmpty, "L3 Hadoken does not harm lemmings or terrain")
    func creatureGame(_ kind: Lemmings3Runtime.Creature.Kind, tool: Lemmings3Runtime.Tool? = nil, total: Int = 2) throws -> Lemmings3Runtime {
        try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: tags,
            entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: total, releaseInterval: 1, releaseDelay: 0,
            pickups: tool.map { [.init(id: 0, tool: $0, x: 20, y: 40)] } ?? [],
            creatures: [.init(id: 10, kind: kind, x: 70, y: kind == .buzzard ? 20 : 48, direction: -1)]))
    }
    var charmed = try creatureGame(.fatale)
    for _ in 0..<20 { charmed.step() }
    try require(charmed.lemmings.filter { $0.charmedBy != nil }.count == 1, "L3 Fatale charms one lemming at a time")
    let charmedID = charmed.lemmings.first { $0.charmedBy != nil }!.id
    try require(charmed.assign(.blocker, to: charmedID), "L3 blocker distracts a charmed lemming")
    try require(charmed.lemmings[charmedID].charmedBy == nil && charmed.lemmings[charmedID].charmImmunity == 46, "L3 distraction clears charm and grants recovery time")
    charmed.step()
    try require(charmed.lemmings.first { $0.charmedBy != nil }?.id != charmedID, "L3 Fatale cannot immediately reclaim a distracted lemming")
    var doomed = try creatureGame(.fatale, total: 1)
    for _ in 0..<200 { doomed.step() }
    try require(doomed.lost == 1 && doomed.isComplete && doomed.lemmings[0].charmedBy == nil && doomed.creatures[0].alive, "L3 uninterrupted charm is fatal")
    var defended = try creatureGame(.fatale, tool: .hadoken, total: 1)
    for _ in 0..<12 { defended.step() }
    try require(defended.useTool(to: 0, direction: .right), "L3 charmed carrier can fire a Hadoken")
    for _ in 0..<20 { defended.step() }
    try require(!defended.creatures[0].alive && defended.lost == 0 && defended.lemmings[0].charmedBy == nil, "L3 Hadoken defeats creature and clears attraction")
    var potato = try creatureGame(.potato, total: 20)
    var previousLosses = 0
    for _ in 0..<150 {
        potato.step()
        try require(potato.lost - previousLosses <= 1, "L3 creature attack does not kill a whole crowd at once")
        previousLosses = potato.lost
    }
    try require(potato.lost > 0 && potato.released > 10, "L3 Potato Beast attacks draw reserve replacements")
    var buzzard = try creatureGame(.buzzard, total: 1)
    var sameBuzzard = buzzard
    for _ in 0..<150 { buzzard.step(); sameBuzzard.step() }
    try require(buzzard.lost == 1 && buzzard.creatures == sameBuzzard.creatures && buzzard.lemmings == sameBuzzard.lemmings, "L3 Buzzard pursuit and combat are deterministic")
    var confinedTags = tags
    for y in 0..<48 { confinedTags[y * 128 + 12] = 0x20; confinedTags[y * 128 + 40] = 0x20 }
    var creatureBomb = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: confinedTags,
        entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 1, releaseInterval: 1, releaseDelay: 0,
        pickups: [.init(id: 0, tool: .bomb, x: 20, y: 40)],
        creatures: [.init(id: 10, kind: .fatale, x: 24, y: 48), .init(id: 11, kind: .fatale, x: 32, y: 48, direction: -1)]))
    for _ in 0..<12 { creatureBomb.step() }
    try require(creatureBomb.useTool(to: 0, direction: .right) && creatureBomb.assign(.blocker, to: 0), "L3 drops bomb near creatures")
    for _ in 0..<115 { creatureBomb.step() }
    try require(creatureBomb.creatures.allSatisfy { !$0.alive }, "L3 explosion defeats creatures within its radius")
    print("PASS L3 Fatale charm, distraction, Hadoken combat, Potato attacks, reserves and Buzzard pursuit")
    var moleTags = tags
    for y in 28..<48 { for x in 50..<90 { moleTags[y * 128 + x] = 0x20 } }
    func moleGame(_ terrain: [UInt16], permanent: [UInt16]? = nil) throws -> Lemmings3Runtime {
        try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: terrain,
            entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 1, releaseInterval: 1, releaseDelay: 0,
            backgroundAttributes: permanent, creatures: [.init(id: 10, kind: .mole, x: 46, y: 48)]))
    }
    var mole = try moleGame(moleTags)
    for _ in 0..<12 { mole.step() }
    try require(mole.assign(.blocker, to: 0), "L3 mole test keeps a lemming on its route")
    for _ in 0..<100 { mole.step() }
    try require(mole.creatures[0].x > 50 && mole.terrainEdits.values.contains(false) && mole.lost == 0, "L3 mole digs destructible terrain without attacking lemmings")
    var brickBarrier = moleTags
    for y in 28..<48 { for x in 50..<90 { brickBarrier[y * 128 + x] = 0x2020 } }
    var steeredMole = try moleGame(brickBarrier)
    for _ in 0..<8 { steeredMole.step() }
    try require(steeredMole.creatures[0].digDirection == .down && steeredMole.terrainEdits.isEmpty, "L3 constructed bricks steer moles without being destroyed")
    var stoneMole = try moleGame(moleTags, permanent: moleTags)
    for _ in 0..<32 { stoneMole.step() }
    try require(stoneMole.terrainEdits.isEmpty, "L3 mole preserves permanent terrain")
    var multipleHatches = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: tags,
        entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 20, releaseInterval: 1, releaseDelay: 0,
        additionalEntrances: [.init(x: 70, y: 40)]))
    multipleHatches.step(); multipleHatches.step()
    try require(multipleHatches.lemmings.map(\.x) == [20, 70], "L3 rotates releases between native hatch positions")
    for _ in 0..<200 { multipleHatches.step() }
    try require(multipleHatches.saved == 10 && multipleHatches.reserve == 10 && multipleHatches.isComplete, "L3 multiple hatches share population and reserves")

    func toolGame(_ tool: Lemmings3Runtime.Tool, permanent: Bool = false) throws -> Lemmings3Runtime {
        var run = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: tags,
            entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 1, releaseInterval: 1, releaseDelay: 0,
            pickups: [.init(id: 0, tool: tool, x: 20, y: 40)], backgroundAttributes: permanent ? tags : nil))
        for _ in 0..<12 { run.step() }
        return run
    }
    var builder = try toolGame(.bricks)
    try require(builder.lemmings[0].tool == .bricks && builder.lemmings[0].quantity == 6 && builder.pickups[0].quantity == 0, "L3 automatic pickup")
    try require(!builder.useTool(to: 0, direction: .down), "L3 rejects straight-down building")
    try require(builder.useTool(to: 0, direction: .upRight), "L3 direction selection")
    builder.step()
    try require(builder.lemmings[0].quantity == 5 && builder.terrainEdits.values.contains(true), "L3 building changes terrain and consumes one brick")
    try require(builder.assign(.walker, to: 0), "L3 interrupts building")
    try require(builder.assign(.drop, to: 0), "L3 drops remaining inventory")
    try require(builder.lemmings[0].tool == nil && builder.pickups.last?.quantity == 5, "L3 preserves quantity on drop")
    builder.step()
    try require(builder.lemmings[0].tool == nil, "L3 does not immediately reclaim its dropped box")
    var digger = try toolGame(.spade)
    try require(digger.useTool(to: 0, direction: .down), "L3 spade direction")
    digger.step()
    try require(digger.lemmings[0].y == 56 && digger.lemmings[0].quantity == 5 && digger.terrainEdits.values.contains(false), "L3 spade cuts eight-pixel work step")
    var protected = try toolGame(.spade, permanent: true)
    try require(protected.useTool(to: 0, direction: .down), "L3 starts work before collision check")
    protected.step()
    try require(protected.terrainEdits.isEmpty && protected.lemmings[0].quantity == 6, "L3 permanent terrain blocks digging without consumption")
    var reserveRun = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: tags,
        entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 20, releaseInterval: 1, releaseDelay: 0))
    for _ in 0..<200 { reserveRun.step() }
    try require(reserveRun.isComplete && reserveRun.saved == 10 && reserveRun.reserve == 10, "L3 reserves are not released after a rescue")
    let empty = [UInt16](repeating: 0x1000, count: 128 * 64)
    var losses = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: empty,
        entrance: .init(x: 20, y: 60), exits: [.init(x: 110, y: 46)], total: 20, releaseInterval: 1, releaseDelay: 0))
    for _ in 0..<200 { losses.step() }
    try require(losses.released == 20 && losses.lost == 20 && losses.reserve == 0 && losses.isComplete, "L3 deaths release reserve replacements")
    var waterTags = tags
    for y in 40..<64 { for x in 40..<80 { waterTags[y * 128 + x] = 0x1800 } }
    var water = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: waterTags,
        entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 1, releaseInterval: 1, releaseDelay: 0))
    for _ in 0..<60 { water.step() }
    try require(water.lemmings[0].state == .drowning && water.lost == 0, "L3 water enters a drowning state")
    for _ in 0..<100 { water.step() }
    try require(water.isComplete && water.lost == 1, "L3 drowning ends the run")
    print("PASS L3 pickups, directional tools, drop, terrain protection and reserves")

    var tallTerrain = [UInt16](repeating: 0x1000, count: 128 * 256)
    for y in 48..<56 { for x in 0..<40 { tallTerrain[y * 128 + x] = 0x20 } }
    for y in 224..<256 { for x in 0..<128 { tallTerrain[y * 128 + x] = 0x20 } }
    func tallRun(umbrella: Bool) throws -> Lemmings3Runtime {
        try .init(configuration: .init(width: 128, height: 256, attributes: tallTerrain,
            entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 222)], total: 1,
            releaseInterval: 1, releaseDelay: 0,
            pickups: umbrella ? [.init(id: 0, tool: .umbrella, x: 20, y: 40)] : []))
    }
    var umbrella = try tallRun(umbrella: true)
    var unprotected = try tallRun(umbrella: false)
    var sawFloating = false
    for _ in 0..<600 {
        umbrella.step(); unprotected.step()
        sawFloating = sawFloating || umbrella.lemmings.first?.state == .floating
    }
    try require(sawFloating && umbrella.saved == 1 && umbrella.lemmings[0].tool == nil && unprotected.lost == 1,
                "L3 umbrella prevents a fatal fall and is consumed on landing")
    var clock = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: tags,
        entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 1,
        releaseInterval: 1, releaseDelay: 0, timeLimit: 1,
        pickups: [.init(id: 0, tool: .bricks, x: 20, y: 40), .init(id: 1, tool: .clock, x: 20, y: 40)]))
    for _ in 0..<30 { clock.step() }
    try require(clock.bonusSeconds == 60 && !clock.isComplete && clock.lemmings[0].tool == .bricks,
                "L3 clock grants one minute without replacing a carried tool")
    for _ in 0..<30 { clock.step() }
    try require(clock.bonusSeconds == 60, "L3 clock can only be collected once")
    func swimmerRun(quantity: Int) throws -> Lemmings3Runtime {
        try .init(configuration: .init(width: 128, height: 64, attributes: waterTags,
            entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 1,
            releaseInterval: 1, releaseDelay: 0,
            pickups: [.init(id: 0, tool: .swimmer, x: 20, y: 40, quantity: quantity)]))
    }
    var swimmer = try swimmerRun(quantity: 1)
    for _ in 0..<40 { swimmer.step() }
    try require(swimmer.lemmings[0].state == .swimming && !swimmer.assign(.walker, to: 0),
                "L3 one swimming aid cannot turn in water")
    for _ in 0..<200 { swimmer.step() }
    try require(swimmer.saved == 1 && swimmer.lemmings[0].tool == nil, "L3 swimmer leaves water and consumes its aid")
    var turningSwimmer = try swimmerRun(quantity: 2)
    for _ in 0..<40 { turningSwimmer.step() }
    try require(turningSwimmer.assign(.walker, to: 0) && turningSwimmer.lemmings[0].direction == -1
        && turningSwimmer.lemmings[0].quantity == 1, "L3 second swimming aid permits a turn")
    print("PASS L3 umbrella, automatic clock, swimming and swimming turns")

    if CommandLine.arguments.count > 1 {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let level = try Lemmings3Level(data: Data(contentsOf: root.appendingPathComponent("LEVELS/LEVEL001.DAT")))
        let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: level.style)
        let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent("LEVELS/PERM001.OBS")))
        let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent("LEVELS/TEMP001.OBS")))
        var native = try Lemmings3Runtime(level: level, style: style, permanent: permanent, temporary: temporary)
        try require(native.configuration.entrance.x == 44 && native.configuration.entrance.y == 20, "L3 native entrance cell")
        try require(native.configuration.exits.contains { $0.x == 88 && $0.y == 142 }, "L3 native exit cell")
        try require(!native.isSolid(200, 40) && native.isSolid(32, 64), "L3 background and terrain attributes")
        for _ in 0..<5000 where !native.isComplete {
            for lem in native.lemmings where lem.state == .walking && lem.y >= 144 && lem.x > 104 {
                if lem.direction == 1 { _ = native.assign(.walker, to: lem.id) }
                if lem.y > 144 { _ = native.assign(.jumper, to: lem.id) }
            }
            native.step()
        }
        try require(native.saved == 10 && native.reserve == 10 && native.survivors == 20 && native.isComplete, "L3 first tutorial: saved \(native.saved), reserve \(native.reserve), ticks \(native.tick)")
        print("PASS native L3 first tutorial: 10 rescued, 10 in reserve, \(native.tick) experimental ticks")
        var campaign = try Lemmings3ClassicCampaign(root: root)
        try require(campaign.advance(after: native) && campaign.index == 1 && campaign.population == 20, "L3 carries reserves and survivors forward")
        let progress = try JSONDecoder().decode(Lemmings3ClassicCampaign.Progress.self, from: JSONEncoder().encode(campaign.progress))
        var restored = try Lemmings3ClassicCampaign(root: root)
        try restored.restore(progress)
        try require(restored.progress == campaign.progress, "L3 progress round trip")
        var invalid = restored.progress
        invalid.population = 1000
        var rejectedProgress = false
        do { try restored.restore(invalid) } catch { rejectedProgress = true }
        try require(rejectedProgress && restored.progress == progress, "L3 rejects impossible population without mutation")
        try require(!restored.record(native), "L3 rejects a result from another level")
        for number in 2...30 {
            let candidate = campaign.levels[number - 1]
            let perm = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", candidate.permanentObjectsReference))))
            let temp = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", candidate.temporaryObjectsReference))))
            var run = try Lemmings3Runtime(level: candidate, style: style, permanent: perm, temporary: temp,
                total: number == 3 ? campaign.population : 20)
            for _ in 0..<100 { run.step() }
            try require(run.released > 0, "L3 native level smoke test \(number)")
            try require(run.creatures.count == candidate.enemyCount, "L3 native creature count \(number)")
            if [16, 20, 22].contains(number) { try require(!run.configuration.additionalEntrances.isEmpty, "L3 native multi-hatch level \(number)") }
            if number == 19 { try require(!run.configuration.traps.isEmpty, "L3 native rockfall trap") }
            if number == 5 {
                try require(run.creatures.count == 1 && run.creatures[0].kind == .fatale, "L3 Classic 5 decodes native Fatale placement")
                var badHeader = candidate.rawData; badHeader[28] = 0; badHeader[29] = 0
                var rejectedCount = false
                do { _ = try Lemmings3Runtime(level: Lemmings3Level(data: badHeader), style: style, permanent: perm, temporary: temp) }
                catch { rejectedCount = true }
                try require(rejectedCount, "L3 rejects creature-count mismatches")
            }
            if number == 3 {
                try require(run.configuration.traps.count == 4, "L3 Classic 3 decodes all four native traps")
                for _ in 0..<4000 where !run.isComplete {
                    for lem in run.lemmings where lem.state == .walking && lem.tool == .spade && lem.x >= 52 && lem.x <= 60 && lem.y < 136 {
                        _ = run.useTool(to: lem.id, direction: .down)
                    }
                    run.step()
                }
                try require(run.isComplete && run.saved == 10 && run.lost == 1 && run.reserve == 11, "L3 Classic 3 spade replay completes with carried population")
                try require(campaign.advance(after: run) && campaign.index == 3 && campaign.population == 21, "L3 advances from level 3 and retains reserves")
                print("PASS L3 Classic 3 spade replay: \(run.saved) rescued, \(run.reserve) in reserve, \(run.lost) lost, \(run.tick) experimental ticks")
            }
            print("PASS L3 Classic \(number): \(run.pickups.count) tool boxes, \(run.configuration.extras.count) extra lemmings")
            if number == 2 {
                for _ in 0..<5000 where !run.isComplete {
                    for lem in run.lemmings where lem.tool == .spade && lem.state == .walking {
                        if lem.y == 88 { _ = run.useTool(to: lem.id, direction: .down) }
                        else if lem.y == 120 && lem.direction > 0 && run.isSolid(lem.x + 1, lem.y - 8) { _ = run.useTool(to: lem.id, direction: .right) }
                    }
                    run.step()
                }
                try require(run.isComplete && run.saved == 12 && run.reserve == 10 && run.lost == 0, "L3 Classic 2 tool replay saves the band and both prisoners")
                try require(run.terrainEdits.values.contains(false), "L3 Classic 2 replay uses destructive work")
                try require(campaign.advance(after: run) && campaign.index == 2 && campaign.population == 22, "L3 carries rescued prisoners to the next level")
                print("PASS L3 Classic 2 tool replay: 12 rescued, 10 in reserve, \(run.tick) experimental ticks")
            }
        }
        let expectedCycles = [200: 28, 202: 33, 203: 26, 994: 28, 995: 14, 996: 26, 102: 13, 103: 28, 104: 24]
        var checkedTraps: Set<Int> = []
        for tribe in Lemmings3ClassicCampaign.Tribe.allCases {
            let bank = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue).permanent
            for object in bank.objects.values where expectedCycles[object.identifier] != nil {
                let nativeTags = try bank.attributes(object: object.identifier)
                let nativeCells = nativeTags.indices.filter { nativeTags[$0] & 0x4000 != 0 }
                try require(!nativeCells.isEmpty && object.animationMode == 1, "L3 native trap has trigger cells and repeat mode")
                let minX = nativeCells.map { $0 % object.columns * 8 }.min()!
                let minY = nativeCells.map { $0 / object.columns * 2 }.min()!
                let cells = nativeCells.map { Lemmings3Runtime.Point(x: 40 + $0 % object.columns * 8 - minX, y: 46 + $0 / object.columns * 2 - minY) }
                let nativeTrap = Lemmings3Runtime.Trap(id: object.identifier, cells: cells, frameCount: object.frameCount,
                    startFrame: object.animationStartFrame, frameDelay: object.animationFrameDelay, cyclePause: object.animationCyclePause)
                try require(nativeTrap.cycleTicks == expectedCycles[object.identifier], "L3 native trap cycle \(object.identifier)")
                var fixtureTags = tags
                for cell in cells { for y in cell.y..<(cell.y + 2) { for x in cell.x..<(cell.x + 8) { fixtureTags[y * 128 + x] = 0x4000 } } }
                let fixture = Lemmings3Runtime.Configuration(width: 128, height: 64, attributes: fixtureTags,
                    entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 1,
                    releaseInterval: 1, releaseDelay: 0, traps: [nativeTrap])
                var run = try Lemmings3Runtime(configuration: fixture)
                try require(run.trapFrame(id: nativeTrap.id) == 1, "L3 native trap idle frame")
                for _ in 0..<80 where run.lemmings.first?.state != .trapped { run.step() }
                try require(run.lemmings.first?.state == .trapped, "L3 native trigger captures \(nativeTrap.id)")
                for elapsed in 0..<nativeTrap.cycleTicks {
                    let expectedFrame = 1 + max(0, elapsed - nativeTrap.cyclePause) / (nativeTrap.frameDelay + 1)
                    try require(run.trapFrame(id: nativeTrap.id) == expectedFrame, "L3 trap frame timing \(nativeTrap.id) at \(elapsed)")
                    run.step()
                }
                try require(run.lost == 1 && run.trapFrame(id: nativeTrap.id) == 1, "L3 native trap finishes and returns to its idle frame")
                let crowdConfig = Lemmings3Runtime.Configuration(width: 128, height: 64, attributes: fixtureTags,
                    entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 2,
                    releaseInterval: 1, releaseDelay: 0, traps: [nativeTrap])
                var crowd = try Lemmings3Runtime(configuration: crowdConfig)
                for _ in 0..<80 where !crowd.lemmings.contains(where: { $0.state == .trapped }) { crowd.step() }
                crowd.step(); crowd.step()
                try require(crowd.lemmings.filter { $0.state == .trapped }.count == 1 && crowd.lemmings.contains { $0.id == 1 && $0.state == .walking }, "L3 native busy trap ignores a second arrival \(nativeTrap.id)")
                var rearmed = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: fixtureTags,
                    entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 2,
                    releaseInterval: 100, releaseDelay: 0, traps: [nativeTrap]))
                for _ in 0..<300 { rearmed.step() }
                try require(rearmed.lost == 2, "L3 native trap rearms for a later arrival \(nativeTrap.id)")
                checkedTraps.insert(object.identifier)
            }
        }
        try require(checkedTraps == Set(expectedCycles.keys), "L3 all nine native trap definitions tested")
        print("PASS L3 nine native trap types: trigger cells, idle frames, frame delays, cycle pauses, capture and cooldown")
        for tribe in [Lemmings3ClassicCampaign.Tribe.shadow, .egyptian] {
            var tribeCampaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
            let tribeStyle = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
            try require(try tribeStyle.constructionTile().pixels.count == 64, "L3 native construction tile for \(tribe.title)")
            try tribeCampaign.select(9)
            let savedTribe = try JSONDecoder().decode(Lemmings3ClassicCampaign.Progress.self, from: JSONEncoder().encode(tribeCampaign.progress))
            var restoredTribe = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
            try restoredTribe.restore(savedTribe)
            try require(restoredTribe.index == 9 && restoredTribe.tribe == tribe, "L3 tribe progress round trip")
            var crossTribeRejected = false
            do { try restoredTribe.restore(campaign.progress) } catch { crossTribeRejected = true }
            try require(crossTribeRejected && restoredTribe.index == 9, "L3 rejects another tribe's progress without mutation")
            var loaded = 0
            for (index, candidate) in tribeCampaign.levels.enumerated() {
                let number = tribe.firstLevel + index
                let perm = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", candidate.permanentObjectsReference))))
                let temp = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", candidate.temporaryObjectsReference))))
                var run = try Lemmings3Runtime(level: candidate, style: tribeStyle, permanent: perm, temporary: temp)
                for _ in 0..<100 { run.step() }
                try require(run.released > 0 && run.creatures.count == candidate.enemyCount, "L3 native tribe release test \(number)")
                if tribe == .shadow && index == 0 {
                    run = try Lemmings3Runtime(level: candidate, style: tribeStyle, permanent: perm, temporary: temp)
                    for _ in 0..<2000 where !run.isComplete && run.saved < 9 {
                        for lem in run.lemmings where lem.state == .walking {
                            let fetchBricks = lem.tool == nil && lem.y == 140 && lem.x > 271 && lem.x < 300 && run.pickups.contains { $0.quantity > 0 }
                            if (fetchBricks && lem.direction > 0) || (!fetchBricks && lem.direction < 0) { _ = run.assign(.walker, to: lem.id) }
                            if lem.tool == .bricks && lem.x >= 272 && lem.y > 96 {
                                _ = run.useTool(to: lem.id, direction: .upRight)
                            } else if run.isSolid(lem.x + 12, lem.y - 1) || (lem.y < 140 && !run.isSolid(lem.x + 4, lem.y)) {
                                _ = run.assign(.jumper, to: lem.id)
                            }
                        }
                        for lem in run.lemmings where lem.state == .building && lem.y <= 92 { _ = run.assign(.walker, to: lem.id) }
                        run.step()
                    }
                    try require(run.saved == 9 && run.lost == 0 && !run.isComplete && !run.terrainEdits.isEmpty, "L3 Shadow 1 bridge and jumper route rescues nine")
                    run.abort()
                    try require(run.isComplete && run.saved == 9 && run.lost == 1 && run.reserve == 10, "L3 end run retains saved lemmings and reserves")
                    let endedTick = run.tick
                    run.abort(); run.step()
                    try require(run.tick == endedTick && run.lost == 1 && run.survivors == 19 && !run.assign(.walker, to: 1), "L3 ended run is terminal and repeat-safe")
                    var sequence = try Lemmings3ClassicCampaign(root: root, tribe: .shadow)
                    try require(sequence.advance(after: run) && sequence.index == 1 && sequence.population == 19, "L3 Shadow completion advances with surviving reserves")
                    print("PASS L3 Shadow 1 bridge/jumper replay: 9 rescued, 1 abandoned, 10 in reserve, \(run.tick) experimental ticks, campaign advances")
                }
                if tribe == .egyptian && index == 0 {
                    for _ in 0..<5000 where !run.isComplete {
                        for lem in run.lemmings where lem.state == .walking && lem.tool == .spade && lem.x >= 240 && lem.y <= 80 {
                            _ = run.useTool(to: lem.id, direction: .down)
                        }
                        run.step()
                    }
                    try require(run.saved == 10 && run.lost == 0 && run.reserve == 10 && run.isComplete, "L3 Egyptian 1 spade replay")
                    var sequence = try Lemmings3ClassicCampaign(root: root, tribe: .egyptian)
                    try require(sequence.advance(after: run) && sequence.index == 1 && sequence.population == 20, "L3 Egyptian completion advances with survivors")
                    print("PASS L3 Egyptian 1 spade replay: 10 rescued, 10 in reserve, \(run.tick) experimental ticks, campaign advances")
                }
                loaded += 1
            }
            try require(loaded == 30, "L3 full tribe load coverage")
            print("PASS L3 \(tribe.title): all \(loaded) levels release, isolated progress")
        }
    }
} catch {
    FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
    exit(1)
}
