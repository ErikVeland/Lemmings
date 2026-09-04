import Foundation
import NxlvKit

func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8)); exit(1)
    }
}

func fixture(wall: Bool = false) throws -> Lemmings2Runtime {
    let width = 120, height = 80
    var pixels = [UInt8](repeating: 0, count: width * height)
    var solid = [Bool](repeating: false, count: width * height)
    for y in 60..<height { for x in 0..<width { solid[y * width + x] = true; pixels[y * width + x] = 6 } }
    if wall { for y in 20..<60 { for x in 50..<56 { solid[y * width + x] = true; pixels[y * width + x] = 6 } } }
    let config = Lemmings2Runtime.Configuration(width: width, height: height, pixels: pixels, solid: solid,
        palette: [UInt8](repeating: 255, count: 1024),
        entrance: .init(x: 20, y: 45, width: 1, height: 1), exits: [.init(x: 90, y: 50, width: 16, height: 16)],
        skills: Lemmings2Runtime.Skill.allCases,
        supplies: [Int](repeating: 10, count: Lemmings2Runtime.Skill.allCases.count), total: 3,
        timeLimit: 120, releaseInterval: 20, terrainMasks: try syntheticMasks())
    return try Lemmings2Runtime(configuration: config)
}

// Deliberately synthetic rectangles exercise runtime phases without bundling
// original assets. Local-data tests below verify the actual native masks.
func syntheticMasks() throws -> Lemmings2TerrainMasks {
    func frame(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> Lemmings2SpriteFrame {
        .init(x: x, y: y, width: w, height: h, pixels: [UInt8](repeating: 7, count: w * h),
              opaque: [Bool](repeating: true, count: w * h))
    }
    return try .init(digger: frame(4, 0, 9, 3),
        basher: (0..<8).map { frame($0 < 4 ? 9 : 1, 7, 7, 9) },
        miner: (0..<4).map { frame($0 < 2 ? 7 : 0, 3, 9, 14) },
        exploder: frame(0, 0, 16, 22), brick: frame(8, 0, 6, 1),
        stacker: [frame(8, 4, 2, 4), frame(6, 4, 2, 4)], platformer: frame(5, 6, 5, 2))
}

func testTribeConstruction(_ masks: Lemmings2TerrainMasks) throws {
    func ready(left: Bool = false, ceiling: Bool = false, steel: Bool = false,
               obstacle: (Int, Int)? = nil) throws -> Lemmings2Runtime {
        let width = 256, height = 160
        var pixels = [UInt8](repeating: 0, count: width * height)
        var solid = [Bool](repeating: false, count: pixels.count)
        for y in 120..<height { for x in 0..<width { solid[y * width + x] = true; pixels[y * width + x] = 6 } }
        if left { for y in 0..<120 { solid[y * width + 110] = true; pixels[y * width + 110] = 6 } }
        if ceiling { for x in 0..<width { solid[108 * width + x] = true; pixels[108 * width + x] = 6 } }
        if let (x, y) = obstacle { solid[y * width + x] = true; pixels[y * width + x] = 6 }
        var game = try Lemmings2Runtime(configuration: .init(width: width, height: height, pixels: pixels,
            solid: solid, palette: [UInt8](repeating: 255, count: 1024),
            entrance: .init(x: 100, y: 119, width: 1, height: 1), exits: [.init(x: 240, y: 120, width: 1, height: 1)],
            skills: [.stacker, .platformer, .builder], supplies: [2, 2, 2], total: 1, timeLimit: 600,
            releaseInterval: 21, terrainMasks: masks,
            steel: steel ? [Bool](repeating: true, count: pixels.count) : []))
        for _ in 0..<100 {
            if let lem = game.lemmings.first, lem.state == .walking, lem.direction == (left ? -1 : 1) { return game }
            game.step()
        }
        throw SequelDataError.invalid("Construction fixture did not become ready.")
    }
    for left in [false, true] {
        var stacker = try ready(left: left)
        let start = stacker.lemmings[0], original = stacker.pixels
        check(stacker.assign(slot: 0, to: 0), "Stacker assignment")
        check(!stacker.assign(slot: 0, to: 0) && stacker.supplies[0] == 1, "Stacker reassignment consumed supply")
        for _ in 0..<6 { stacker.step() }
        check(stacker.pixels == original, "Stacker cut before frame 7")
        stacker.step()
        let column = start.x + (left ? -2 : 1)
        check(stacker.isSolid(column, start.y - 2) && stacker.isSolid(column + 1, start.y - 2)
            && !stacker.isSolid(column - 1, start.y - 2) && !stacker.isSolid(column + 2, start.y - 2),
            "Stacker did not use the native two-pixel column")
        for _ in 7..<11 { stacker.step() }
        check(stacker.lemmings[0].y == start.y - 2, "Stacker rise is not at frame 11")
        stacker.step()
        check(stacker.lemmings[0].direction == -start.direction && stacker.lemmings[0].x == start.x + start.direction,
              "Stacker did not turn and align at frame 12")
        for _ in 12..<192 { stacker.step() }
        check(stacker.lemmings[0].state == .shrugging && stacker.lemmings[0].y == start.y - 24
            && stacker.lemmings[0].direction == start.direction && stacker.lemmings[0].x == start.x + (left ? 1 : 0),
            "Stacker did not finish twelve two-pixel rises")

        var platformer = try ready(left: left)
        let p = platformer.lemmings[0], terrain = platformer.pixels
        check(platformer.assign(slot: 1, to: 0), "Platformer assignment")
        for _ in 0..<9 { platformer.step() }
        check(platformer.pixels == terrain, "Platformer acted before frame 10")
        platformer.step()
        check((1...5).allSatisfy { platformer.isSolid(p.x + $0 * p.direction, p.y - 2) }, "Platformer initial brick")
        for _ in 10..<15 { platformer.step() }
        check(platformer.lemmings[0].x == p.x + p.direction && platformer.lemmings[0].y == p.y - 2,
              "Platformer two-step climb timing")
        for _ in 15..<198 { platformer.step() }
        check(platformer.lemmings[0].state == .platformerShrugging && platformer.lemmings[0].x == p.x + 49 * p.direction
            && platformer.lemmings[0].y == p.y - 2, "Platformer twelve-brick duration or distance")
        check(platformer.assign(slot: 1, to: 0) && platformer.lemmings[0].age == 21
            && platformer.lemmings[0].work == 12, "Platformer continuation restarted the lead-in")
        let continuedX = platformer.lemmings[0].x
        for _ in 0..<193 { platformer.step() }
        check(platformer.lemmings[0].state == .platformerShrugging
            && platformer.lemmings[0].x == continuedX + 48 * p.direction && platformer.lemmings[0].y == p.y - 2,
            "Platformer continuation did not place twelve level bricks")
    }
    var ceiling = try ready(ceiling: true)
    check(ceiling.assign(slot: 0, to: 0), "Stacker ceiling fixture")
    for _ in 0..<16 { ceiling.step() }
    check(ceiling.lemmings[0].state == .walking && ceiling.lemmings[0].y == 118, "Stacker ignored its head probe")
    var blocked = try ready(obstacle: (106, 118))
    check(blocked.assign(slot: 1, to: 0), "Platformer blocked-brick fixture")
    for _ in 0..<10 { blocked.step() }
    check(blocked.lemmings[0].state == .walking && blocked.lemmings[0].x == 100,
          "Platformer ignored its brick-end probe")
    var stepBlocked = try ready(obstacle: (103, 117))
    check(stepBlocked.assign(slot: 1, to: 0), "Platformer blocked-step fixture")
    for _ in 0..<18 { stepBlocked.step() }
    check(stepBlocked.lemmings[0].state == .platformerShrugging && stepBlocked.lemmings[0].x == 103,
          "Platformer ignored its movement probe")
    for slot in 0...1 {
        var protected = try ready(steel: true)
        let before = protected.pixels
        check(protected.assign(slot: slot, to: 0), "Protected construction fixture")
        for _ in 0..<200 { protected.step() }
        check(protected.pixels == before && protected.terrainRevision == 0, "Construction overwrote protected terrain")
    }
    print("PASS native stacker and platformer masks, both directions, phases, continuation and steel")
}

func testNativeTerrainPhases(_ masks: Lemmings2TerrainMasks) throws {
    let c = try fixture().configuration
    func ready() throws -> Lemmings2Runtime {
        var game = try Lemmings2Runtime(configuration: .init(width: c.width, height: c.height,
            pixels: c.pixels, solid: c.solid, palette: c.palette, entrance: c.entrance, exits: c.exits,
            skills: c.skills, supplies: c.supplies, total: 1, timeLimit: c.timeLimit,
            releaseInterval: c.releaseInterval, terrainMasks: masks))
        while game.lemmings.first?.state != .walking { game.step() }
        return game
    }
    var builder = try ready()
    let x = builder.lemmings[0].x, y = builder.lemmings[0].y
    check(builder.assign(slot: c.skills.firstIndex(of: .builder)!, to: 0), "Native builder assignment")
    for _ in 0..<8 { builder.step() }
    check(builder.pixels == c.pixels && builder.lemmings[0].x == x, "Builder acted before frame 9")
    builder.step()
    check(builder.terrainRevision == 1, "Builder did not invalidate the terrain image")
    check((0..<6).allSatisfy { builder.pixels[(y - 1) * c.width + x + $0] == 7 }, "Original six-pixel brick or colour changed")
    check(!builder.isSolid(x - 1, y - 1) && !builder.isSolid(x + 6, y - 1), "Builder brick grew beyond native mask")
    for _ in 9..<16 { builder.step() }
    check(builder.lemmings[0].x == x + 2 && builder.lemmings[0].y == y - 1, "Builder movement must follow frame 16")
    for _ in 16..<192 { builder.step() }
    check(builder.lemmings[0].state == .shrugging && builder.lemmings[0].x == x + 24
        && builder.lemmings[0].y == y - 12, "Native twelve-brick staircase did not finish")

    var digger = try ready()
    check(digger.assign(slot: c.skills.firstIndex(of: .digger)!, to: 0), "Native digger assignment")
    for _ in 0..<7 { digger.step() }
    check(digger.pixels == c.pixels, "Digger cut before frame 8")
    digger.step()
    check(digger.lemmings[0].y == y + 1 && (-4...4).allSatisfy { !digger.isSolid(x + $0, y) }
        && digger.isSolid(x - 5, y) && digger.isSolid(x + 5, y) && digger.isSolid(x, y + 1),
        "Native digger mask or one-pixel descent changed")

    var miner = try ready()
    check(miner.assign(slot: c.skills.firstIndex(of: .miner)!, to: 0), "Native miner assignment")
    for _ in 0..<3 { miner.step() }
    check(miner.lemmings[0].x == x + 2 && miner.lemmings[0].y == y + 1, "Miner frame 3 movement")
    for _ in 3..<15 { miner.step() }
    check(miner.lemmings[0].x == x + 4 && miner.lemmings[0].y == y + 1, "Miner frame 15 movement")
    for _ in 15..<24 { miner.step() }
    check(miner.lemmings[0].x == x + 4 && miner.lemmings[0].y == y + 2, "Miner frame 0 vertical movement")

    var exploder = try ready()
    check(exploder.assign(slot: c.skills.firstIndex(of: .blocker)!, to: 0), "Exploder fixture blocker")
    check(exploder.assign(slot: c.skills.firstIndex(of: .bomber)!, to: 0), "Native exploder assignment")
    for _ in 0..<74 { exploder.step() }
    check(exploder.lemmings[0].state == .blocking && exploder.lemmings[0].bombTicks == 1, "Native 75-tick countdown")
    exploder.step()
    check(exploder.lemmings[0].state == .exploding && exploder.pixels == c.pixels, "Countdown skipped the explosion animation")
    for _ in 0..<14 { exploder.step() }
    check(exploder.pixels == c.pixels, "Exploder cut before its native action frame")
    exploder.step()
    check(exploder.pixels != c.pixels, "Exploder did not apply MASKS animation 8")
    for _ in 0..<53 { exploder.step() }
    check(exploder.isComplete && exploder.lost == 1, "Exploder did not finish its particle interval")
    print("PASS original L2 masks and builder, digger, miner, exploder action phases")
}

func testControlsAndSoundEvents() throws {
    check(Lemmings2Control.slot(x: 304, y: 170) == Lemmings2Control.nuke.rawValue, "Mushroom cloud must be nuke, not fan")
    check(Lemmings2Control.slot(x: 272, y: 190) == Lemmings2Control.fan.rawValue, "Lower-left control must be fan")
    for slot in 0..<12 {
        let x = slot < 8 ? slot * 32 : 256 + (slot - 8) % 2 * 32
        let y = slot < 8 ? 160 : 160 + (slot - 8) / 2 * 20
        check(Lemmings2Control.slot(x: x, y: y) == slot, "Control leading edge \(slot)")
        check(Lemmings2Control.slot(x: x + 31, y: y + (slot < 8 ? 39 : 19)) == slot, "Control trailing edge \(slot)")
    }
    check(Lemmings2Control.slot(x: 320, y: 170) == nil && Lemmings2Control.slot(x: 10, y: 159) == nil, "Panel bounds")
    var gesture = Lemmings2NukeGesture()
    check(!gesture.click(slot: 9, count: 1, time: 0, interval: 0.5), "Single nuke click detonated")
    check(gesture.click(slot: 9, count: 2, time: 0.2, interval: 0.5), "Double nuke click ignored")
    check(gesture.armedAt == nil, "Nuke confirmation stayed armed")
    _ = gesture.click(slot: 9, count: 1, time: 1, interval: 0.5)
    check(!gesture.click(slot: 9, count: 2, time: 2, interval: 0.5), "Stale nuke click accepted")
    _ = gesture.click(slot: 10, count: 1, time: 2.1, interval: 0.5)
    check(!gesture.click(slot: 10, count: 2, time: 2.2, interval: 0.5), "Double-click fan nuked")
    check(!gesture.click(slot: 9, count: 2, time: 2.3, interval: 0.5), "Intervening control did not disarm nuke")
    gesture.reset()
    check(gesture.armedAt == nil, "Playfield/reset did not disarm nuke")

    let c = try fixture().configuration, width = 400
    let solid = (0..<(width * 80)).map { $0 / width >= 60 }
    var run = try Lemmings2Runtime(configuration: .init(width: width, height: 80,
        pixels: solid.map { $0 ? 6 : 0 }, solid: solid, palette: c.palette,
        entrance: c.entrance, exits: [.init(x: 350, y: 40, width: 10, height: 30)],
        skills: c.skills, supplies: c.supplies, total: 3, timeLimit: 120, releaseInterval: 1,
        terrainMasks: c.terrainMasks, firstReleaseTick: 1))
    for _ in 0..<10 { run.step() }
    check(run.drainSoundEvents() == [.init(.levelStart)], "Level-start cue timing")
    let slot = c.skills.firstIndex(of: .climber)!, lem = run.lemmings[0]
    check(run.target(slot: slot, x: lem.x, y: lem.y - 5)?.id == 0, "Closest eligible hover target")
    check(run.assign(slot: slot, to: 0), "Selection assignment")
    check(run.drainSoundEvents() == [.init(.assignSkill)], "Successful assignment has no native cue")
    check(!run.assign(slot: slot, to: 0) && run.drainSoundEvents().isEmpty, "Failed assignment played sound")
    check(run.target(slot: slot, x: lem.x, y: lem.y - 5)?.id == 1, "Ineligible overlapping lemming stole selection")
    let supplies = run.supplies
    _ = run.target(slot: slot, x: lem.x, y: lem.y - 5)
    check(run.supplies == supplies && run.drainSoundEvents().isEmpty, "Hover mutated game state")
    check(run.target(slot: slot, x: 399, y: 0) == nil, "Distant hover selected a lemming")
    run.nuke()
    check(run.lemmings.allSatisfy { $0.bombTicks == nil }, "Nuke assigned outside a physics tick")
    for count in 1...3 {
        run.step()
        check(run.lemmings.filter { $0.bombTicks != nil }.count == count, "Nuke must arm one lemming per tick")
    }
    let countdown = run.lemmings[0].bombTicks
    run.nuke()
    check(run.lemmings[0].bombTicks == countdown && !run.canAssign(slot: slot, to: 1), "Repeated nuke reset countdown or allowed assignment")
    var explosions = 0
    for _ in 0..<180 {
        run.step()
        explosions += run.drainSoundEvents().filter { $0 == .init(.explode) }.count
    }
    check(run.isComplete && run.lost == 3 && run.saved == 0 && explosions == 3, "Nuke did not explode all three lemmings with sound")
    check(run.drainSoundEvents().isEmpty, "Sound events replayed after drain")
    print("PASS original control hit regions, double-click nuke, selection priority and native sound events")
}

do {
    try testControlsAndSoundEvents()
    try testTribeConstruction(syntheticMasks())
    check(Lemmings2Objects.trigger(flags: 0x1150, interaction: 0, x: 256, y: 96) == .init(x: 266, y: 96, width: 1, height: 1), "Native point trigger decoding")
    check(Lemmings2Objects.trigger(flags: 0x2830, interaction: 0, x: 0, y: 0) == .init(x: 0, y: 2, width: 4, height: 5), "Trigger clipping at tile edge")
    check(Lemmings2Objects.trigger(flags: 0x3db0, interaction: 0, x: 0, y: 0) == .init(x: 9, y: 2, width: 7, height: 6), "Large trigger clipping")
    check(Lemmings2Objects.trigger(flags: 8, interaction: 8, x: 0, y: 0) == .init(x: 0, y: 0, width: 16, height: 8), "Constant hazard trigger")
    check(Lemmings2Objects.trigger(flags: 0xc010, interaction: 0, x: 0, y: 0) == nil, "Disabled trigger was active")
    let base = try fixture().configuration
    var clock = try fixture()
    for _ in 0..<14 { clock.step() }
    check(clock.remainingSeconds == 120, "L2 clock decremented before fifteen ticks")
    clock.step()
    check(clock.remainingSeconds == 119, "L2 clock must count fifteen ticks per displayed second")
    var protected = try Lemmings2Runtime(configuration: .init(width: base.width, height: base.height,
        pixels: base.pixels, solid: base.solid, palette: base.palette, entrance: base.entrance, exits: base.exits,
        skills: base.skills, supplies: base.supplies, total: base.total, timeLimit: base.timeLimit,
        releaseInterval: base.releaseInterval, terrainMasks: base.terrainMasks, steel: base.solid))
    while !protected.lemmings.contains(where: { $0.state == .walking }) { protected.step() }
    check(protected.assign(slot: 0, to: 0), "Could not assign steel test digger")
    for _ in 0..<16 { protected.step() }
    check(protected.solid == base.solid && protected.lemmings[0].state == .walking, "Digger penetrated steel")
    _ = protected.assign(slot: base.skills.firstIndex(of: .bomber)!, to: 0)
    _ = protected.assign(slot: base.skills.firstIndex(of: .blocker)!, to: 0)
    for _ in 0..<100 { protected.step() }
    check(protected.solid == base.solid, "Explosion destroyed steel")
    var hazard = try Lemmings2Runtime(configuration: .init(width: base.width, height: base.height,
        pixels: base.pixels, solid: base.solid, palette: base.palette, entrance: base.entrance, exits: base.exits,
        skills: base.skills, supplies: base.supplies, total: base.total, timeLimit: base.timeLimit,
        releaseInterval: base.releaseInterval, terrainMasks: base.terrainMasks,
        hazards: [.init(x: 40, y: 45, width: 16, height: 16)]))
    for _ in 0..<400 { hazard.step() }
    check(hazard.isComplete && hazard.lost == 3 && hazard.saved == 0, "Hazard did not stop lemmings")
    var game = try fixture()
    let untouched = game.supplies
    check(!game.assign(slot: -1, to: 0) && !game.assign(slot: 0, to: 99), "Invalid assignment accepted")
    check(game.supplies == untouched, "Rejected assignment consumed a skill")
    for _ in 0..<400 { game.step() }
    check(game.isComplete && game.saved == 3 && game.lost == 0 && game.didWin, "Walking fixture did not complete")
    let tick = game.tick
    game.step()
    check(game.tick == tick, "Completed simulation advanced")

    var dig = try fixture()
    while !dig.lemmings.contains(where: { $0.state == .walking }) { dig.step() }
    let id = dig.lemmings[0].id
    let digSlot = dig.configuration.skills.firstIndex(of: .digger)!
    check(dig.assign(slot: digSlot, to: id), "Digger assignment failed")
    let before = dig.solid.filter { $0 }.count
    for _ in 0..<7 { dig.step() }
    check(dig.solid.filter { $0 }.count == before, "Digger cut before native frame 8")
    dig.step()
    check(dig.solid.filter { $0 }.count < before, "Digger did not remove terrain")
    check(dig.supplies[digSlot] == 9, "Skill inventory was not consumed exactly once")
    check(!dig.assign(slot: digSlot, to: id), "Digger reassignment should be rejected")
    check(dig.assign(slot: dig.configuration.skills.firstIndex(of: .builder)!, to: id), "A builder could not interrupt a digger")
    check(dig.lemmings[0].state == .building, "Interrupted digger retained the old state")

    for skill in [Lemmings2Runtime.Skill.builder, .miner, .bomber, .blocker, .floater, .climber, .basher] {
        var exercise = try fixture(wall: skill == .climber || skill == .basher)
        while !exercise.lemmings.contains(where: { $0.state == .walking && $0.x >= (skill == .basher ? 47 : 40) }) { exercise.step() }
        let slot = exercise.configuration.skills.firstIndex(of: skill)!
        check(exercise.assign(slot: slot, to: 0), "Could not assign \(skill)")
        let terrainBefore = exercise.solid.filter { $0 }.count
        if skill == .climber || skill == .floater || skill == .bomber {
            check(!exercise.assign(slot: slot, to: 0), "Duplicate permanent/countdown assignment accepted")
        }
        if skill == .bomber {
            check(exercise.assign(slot: exercise.configuration.skills.firstIndex(of: .blocker)!, to: 0), "Could not hold the bomber for the explosion test")
        }
        for _ in 0..<400 { exercise.step() }
        switch skill {
        case .builder: check(exercise.solid.filter { $0 }.count > terrainBefore, "Builder added no terrain")
        case .miner, .basher: check(exercise.solid.filter { $0 }.count < terrainBefore, "Destructive skill removed no terrain")
        case .bomber: check(exercise.lemmings[0].state == .dead && exercise.solid.filter { $0 }.count < terrainBefore, "Bomber did not finish or change terrain")
        case .blocker: check(exercise.lemmings[0].state == .blocking && exercise.lost > 0, "Blocker did not turn followers")
        case .climber: check(exercise.lemmings[0].state == .saved, "Climber did not pass the wall")
        case .floater: check(exercise.lemmings[0].floater, "Floater attribute was not retained")
        default: break
        }
    }

    var original = try fixture(), replay = try fixture()
    for tick in 0..<250 {
        if tick == 50 {
            let slot = original.configuration.skills.firstIndex(of: .builder)!
            _ = original.assign(slot: slot, to: 0); _ = replay.assign(slot: slot, to: 0)
        }
        original.step(); replay.step()
    }
    check(original.lemmings == replay.lemmings && original.pixels == replay.pixels && original.supplies == replay.supplies,
          "Native runtime is not deterministic")
    var nuke = try fixture()
    nuke.nuke(); nuke.step()
    check(nuke.isComplete && !nuke.didWin && nuke.released == 0, "Nuke before first release did not end the level")
    print("PASS native L2 walking, rescue, inventory, terrain, replay and nuke tests")

    if CommandLine.arguments.count > 1 {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let level = try Lemmings2Level(data: Data(contentsOf: root.appendingPathComponent("LEVELS/LEVEL000.DAT")))
        let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent("STYLES/CLASSIC.DAT")))
        let masks = try Lemmings2TerrainMasks(root: root)
        try testTribeConstruction(masks)
        try testNativeTerrainPhases(masks)
        var campaign = try Lemmings2ClassicCampaign(root: root)
        check(campaign.entries.count == 10, "Classic sequence is incomplete")
        for entry in campaign.entries {
            var smoke = try Lemmings2Runtime(level: entry.level, style: style, masks: masks)
            check(smoke.configuration.releaseInterval == 21 && smoke.configuration.firstReleaseTick == 51,
                  "Classic entrance and release countdown differ from PROCESS")
            for _ in 0..<50 { smoke.step() }
            check(smoke.released == 0, "Classic released before its opening countdown")
            smoke.step()
            check(smoke.released == 1, "Classic did not release at tick 51")
            let objects = try Lemmings2Objects(level: entry.level, style: style)
            for _ in 0..<120 { smoke.step() }
            check(smoke.released > 0 && !smoke.lemmings.isEmpty, "Classic level did not release lemmings")
            check(!smoke.configuration.exits.isEmpty, "Classic exit did not resolve")
            for trigger in smoke.configuration.exits {
                check(smoke.isSolid(trigger.x, trigger.y) && !smoke.isSolid(trigger.x, trigger.y - 1), "Classic exit is not aligned to a walkable surface")
                // This isolates exit interaction, not a full-level solution.
                let c = smoke.configuration
                var exitProbe = try Lemmings2Runtime(configuration: .init(width: c.width, height: c.height,
                    pixels: c.pixels, solid: c.solid, palette: c.palette,
                    entrance: .init(x: trigger.x - 1, y: trigger.y, width: 1, height: 1), exits: c.exits,
                    skills: c.skills, supplies: c.supplies, total: 1, timeLimit: c.timeLimit,
                    releaseInterval: c.releaseInterval, terrainMasks: c.terrainMasks, steel: c.steel, hazards: c.hazards))
                for _ in 0..<100 { exitProbe.step() }
                check(exitProbe.saved == 1 && exitProbe.didWin, "Native Classic exit interaction failed")
            }
            check(entry.level.maximumScreenY == 0, "Classic vertical camera bound changed")
            if entry.number == 0 { check(entry.level.maximumScreenX == 0, "First level should not scroll into unused terrain") }
            if entry.number == 9 { check(entry.level.minimumScreenX == 96 && entry.level.maximumScreenX == 416, "Native horizontal camera bounds") }
            if entry.number > 0 { check(smoke.configuration.steel.contains(true), "Classic steel missing") }
            if entry.number == 2 {
                check(objects.parts.contains(where: { $0.type == 5 && $0.x == 592 && $0.y == 96 }), "Horizontal steel extension missing")
                check(objects.parts.contains(where: { $0.type == 5 && $0.x == 608 && $0.y == 96 }), "Vertical steel extension missing")
            }
            print("PASS Classic \(entry.number + 1): \(entry.level.title), \(objects.parts.count) object parts")
        }
        struct Replay: Decodable {
            struct Input: Decodable { let tick: Int; let lemming: Int; let skill: Int }
            let version: Int
            let levelSHA256: String
            let population: Int
            let expectedSaved: Int
            let expectedTicks: Int
            let inputs: [Input]
        }
        let replayURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/classic-01.json")
        let input = try JSONDecoder().decode(Replay.self, from: Data(contentsOf: replayURL))
        check(input.version == 1 && input.levelSHA256 == level.fingerprint, "Replay uses a different native level")
        var run = try Lemmings2Runtime(level: level, style: style, masks: masks, total: input.population)
        var command = 0
        while !run.isComplete && run.tick <= input.expectedTicks {
            while command < input.inputs.count && input.inputs[command].tick == run.tick {
                let event = input.inputs[command]
                let skill = Lemmings2Runtime.Skill(rawValue: event.skill)!
                check(run.assign(slot: run.configuration.skills.firstIndex(of: skill)!, to: event.lemming),
                      "Replay input \(command) rejected at tick \(run.tick)")
                command += 1
            }
            run.step()
        }
        check(command == input.inputs.count, "Replay skipped an input")
        check(run.isComplete && run.didWin && !run.isNuking && run.saved == input.expectedSaved && run.lost == 0
            && run.released == 60 && run.tick == input.expectedTicks, "Classic 1 full-rescue replay changed")
        check(run.supplies == [19, 19, 20, 19, 13, 14, 19, 17], "Replay skill use changed")
        var tribes = try Lemmings2Campaign(root: root)
        check(tribes.levels.count == 120 && tribes.population == 60 && !tribes.isComplete, "Initial twelve-tribe campaign")
        do { try tribes.select(tribe: 0, level: 1); check(false, "Unplayed level unlocked") } catch {}
        check(tribes.record(run) && tribes.results[0]?.medal == .gold, "Full rescue did not earn native gold")
        check(tribes.advance(after: run) && tribes.level == 1 && tribes.population == 60, "Native campaign survivor carry")
        check(!tribes.record(run), "Wrong level result entered native campaign")
        let nativeProgress = tribes.progress
        var nativeRestored = try Lemmings2Campaign(root: root)
        try nativeRestored.restore(JSONDecoder().decode(Lemmings2Campaign.Progress.self,
                                                       from: JSONEncoder().encode(nativeProgress)))
        check(nativeRestored.progress == nativeProgress, "Twelve-tribe save round trip")
        do { try nativeRestored.restore(.init(version: 0, tribe: 0, level: 1, results: nativeProgress.results))
            check(false, "Old physics save accepted") } catch {}
        do { try nativeRestored.restore(.init(tribe: 0, level: 2, results: nativeProgress.results))
            check(false, "Save skipped a locked level") } catch {}
        check(nativeRestored.progress == nativeProgress, "Failed native save restore changed state")
        try tribes.select(tribe: 1)
        check(tribes.level == 0 && tribes.population == 60 && tribes.results[0]?.saved == 60, "Tribe progress not independent")
        check(Lemmings2Campaign.medal(saved: 60, total: 60, allowedLosses: 0) == .gold, "Gold threshold")
        check(Lemmings2Campaign.medal(saved: 59, total: 60, allowedLosses: 1) == .gold, "Allowed gold loss")
        check(Lemmings2Campaign.medal(saved: 30, total: 60, allowedLosses: 0) == .silver, "Silver threshold")
        check(Lemmings2Campaign.medal(saved: 29, total: 60, allowedLosses: 0) == .bronze, "Bronze threshold")
        check(Lemmings2Campaign.medal(saved: 0, total: 60, allowedLosses: 0) == .none, "Extinct tribe earned a medal")
        // This is a campaign-state fixture, not proof of gameplay completion.
        let allGold = Dictionary(uniqueKeysWithValues: nativeRestored.levels.enumerated().map { index, level in
            (index, Lemmings2Campaign.Result(startingPopulation: 60, saved: 60, medal: .gold, levelFingerprint: level.fingerprint))
        })
        try nativeRestored.restore(.init(tribe: 11, level: 9, results: allGold))
        check(nativeRestored.isComplete && nativeRestored.hasGoldenTalisman, "All twelve talisman pieces not counted")
        print("PASS twelve-tribe progress, native medal thresholds, save validation and ending eligibility")
        check(campaign.advance(after: run) && campaign.index == 1 && campaign.population == run.saved, "Survivors did not carry forward")
        check(!campaign.record(run), "A result from Classic 1 was accepted for Classic 2")
        let encoded = try JSONEncoder().encode(campaign.progress)
        var restored = try Lemmings2ClassicCampaign(root: root)
        try restored.restore(JSONDecoder().decode(Lemmings2ClassicCampaign.Progress.self, from: encoded))
        check(restored.progress == campaign.progress, "Preview progress did not round trip")
        do {
            try restored.restore(.init(index: 10, population: 0, completed: [:]))
            check(false, "Invalid preview progress accepted")
        } catch {}
        check(restored.progress == campaign.progress, "Invalid restore changed progress")
        do {
            try restored.restore(.init(version: 2, index: 0, population: 60, completed: [0: 60]))
            check(false, "Results from approximate terrain physics were accepted")
        } catch {}
        let carried = try Lemmings2Runtime(level: campaign.entries[1].level, style: style, masks: masks, total: campaign.population)
        check(!campaign.advance(after: carried), "Unfinished level advanced campaign")
        try campaign.select(9)
        check(campaign.index == 9 && campaign.population == 60, "Direct level start did not reset population")
        print("PASS original first L2 level completed natively: \(run.saved) rescued, \(run.tick) ticks")
    }
} catch {
    FileHandle.standardError.write(Data("Native L2 runtime tests failed: \(error)\n".utf8))
    exit(1)
}
