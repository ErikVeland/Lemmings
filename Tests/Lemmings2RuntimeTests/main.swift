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
        skills: Lemmings2Runtime.Skill.allCases.filter { $0 != .unused },
        supplies: [Int](repeating: 10, count: Lemmings2Runtime.Skill.allCases.count - 1), total: 3,
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
        stacker: [frame(8, 4, 2, 4), frame(6, 4, 2, 4)], platformer: frame(5, 6, 5, 2), stomper: frame(3, 4, 10, 4),
        scooper: Array(repeating: frame(0, 6, 12, 10), count: 12),
        fencer: Array(repeating: frame(0, 6, 12, 9), count: 2),
        clubBasher: Array(repeating: frame(0, 12, 12, 12), count: 14),
        laser: [frame(5,0,6,8)],
        flame: Array(repeating: frame(0,0,32,12), count:2), blast: frame(0,0,22,22), plant:(0..<8).map { frame(8,0,4+$0,8) }, twister:frame(2,0,12,11), stone:Array(repeating:frame(0,0,4,4),count:4), spear:Array(repeating:frame(0,7,15,1),count:16), arrow:Array(repeating:frame(0,7,14,1),count:32))
}

func testWitnessRejectsOutOfOrderInputs() throws {
    let json = """
    {"version":1,"levelSHA256":"deadbeef","population":60,"expectedSaved":1,
     "expectedTicks":100,"pointers":[],
     "inputs":[{"tick":50,"lemming":0,"skill":7},{"tick":10,"lemming":0,"skill":7}]}
    """
    let witness = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: Data(json.utf8))
    check(witness.inputsAreOrdered == false, "Witness accepted out-of-order inputs")
    print("PASS replay witness rejects out-of-order inputs")
}

func testLinkedObjects() throws {
    var trap = Lemmings2TimedTrap()
    check(!trap.touch(),"Dormant trap killed before opening")
    for _ in 0..<3 { trap.step(frameCount:10,minimum:3,maximum:5) }
    check(trap.touch(),"Open trap did not become lethal")
    for _ in 0..<20 { trap.step(frameCount:10,minimum:3,maximum:5) }
    check(trap.mode == 4 && !trap.touch() && trap.mode == 5,"Closing trap did not reverse on contact")
    let base = try fixture().configuration
    func game(_ objects: [Lemmings2InteractiveObject]) throws -> Lemmings2Runtime {
        try .init(configuration:.init(width:base.width,height:base.height,pixels:base.pixels,
            solid:base.solid,palette:base.palette,entrance:.init(x:20,y:60,width:1,height:1),
            exits:base.exits,skills:[.jumper],supplies:[1],total:1,timeLimit:120,releaseInterval:20,
            terrainMasks:base.terrainMasks,firstReleaseTick:1,interactiveObjects:objects))
    }
    let trigger = Lemmings2Runtime.Rect(x:20,y:60,width:1,height:1)
    var portals = try game([
        .init(id:1,kind:.teleporter,triggers:[trigger],frameCount:1,linkedID:2,destinationX:20,destinationY:60),
        .init(id:2,kind:.teleporter,triggers:[.init(x:70,y:60,width:1,height:1)],frameCount:1,linkedID:1,destinationX:70,destinationY:60)])
    portals.step()
    check(portals.lemmings[0].state == .teleporting && !portals.canAssign(slot:0,to:0),"Teleporter did not capture or lock its rider")
    for _ in 0..<27 { portals.step() }
    check(portals.lemmings[0].x == 70 && portals.lemmings[0].state == .teleporting,"Teleporter paired destination or transit duration is wrong")
    for _ in 0..<18 { portals.step() }
    check(portals.lemmings[0].x == 71 && portals.lemmings[0].state == .walking,"Teleporter failed to release past its trigger")
    var valve = try game([
        .init(id:1,kind:.valve,triggers:[trigger],frameCount:1,linkedID:2),
        .init(id:2,kind:.launcher,triggers:[],frameCount:4,velocityX:8,velocityY:-4,activeFrame:2)])
    valve.step()
    check(valve.lemmings[0].state == .switchingValve && valve.objectFrames[2] == 2,"Valve did not enable its paired launcher")
    for _ in 0..<9 { valve.step() }
    check(valve.lemmings[0].state == .walking && valve.lemmings[0].x == 21,"Valve interaction failed to finish")
    print("PASS timed trap phases, paired teleporters and valve-controlled launchers")
}

func testRailMachines() throws {
    let base = try fixture().configuration
    for kind in [Lemmings2RailMachine.Kind.cannon,.catapult] {
        let machine = Lemmings2RailMachine(id:9,kind:kind,x:32,y:kind == .cannon ? 36 : 52,
            minimumX:30,maximumX:34,leftControls:[.init(x:0,y:0,width:8,height:8)],
            rightControls:[.init(x:10,y:0,width:8,height:8)],
            triggers:[.init(x:20,y:60,width:60,height:8)],frameCount:12)
        var game = try Lemmings2Runtime(configuration:.init(width:base.width,height:base.height,
            pixels:base.pixels,solid:base.solid,palette:base.palette,
            entrance:.init(x:machine.captureX,y:60,width:1,height:1),exits:base.exits,
            skills:[.jumper],supplies:[1],total:1,timeLimit:120,releaseInterval:20,
            terrainMasks:base.terrainMasks,firstReleaseTick:1,machines:[machine]))
        game.step()
        check(game.lemmings[0].machineID == 9,"Rail machine failed to capture a lemming")
        check(!game.canAssign(slot:0,to:0),"Skill interrupted a machine loading sequence")
        check(game.moveMachine(x:11,y:1),"Rail control did not move the machine")
        game.step()
        check(game.lemmings[0].x == game.machines[0].riderPosition(phase:1).x,"Rider did not follow its moving machine")
        game.setAim(x:11,y:1,held:true)
        for _ in 0..<4 { game.step() }
        game.setAim(x:11,y:1,held:false)
        check(game.machines[0].x == 34,"Held rail control exceeded its rail endpoint")
        var launched = false
        for _ in 0..<70 {
            game.step()
            if let air = game.lemmings[0].air {
                check(air.velocityX == (kind == .cannon ? 8 : -8) && air.velocityY == -6,
                    "Rail machine launch velocity differs from the native values")
                launched = true; break
            }
        }
        check(launched,"Rail machine never launched its rider")
    }
    print("PASS cannon and catapult loading, held rail controls, rider alignment and launch")
}

func testChains() throws {
    let base = try fixture().configuration
    let chain = Lemmings2Chain(id:3,x:40,y:20,count:5,controls:[.init(x:30,y:0,width:16,height:8)])
    var game = try Lemmings2Runtime(configuration:.init(width:base.width,height:base.height,
        pixels:base.pixels,solid:base.solid,palette:base.palette,entrance:.init(x:48,y:40,width:1,height:1),
        exits:base.exits,skills:[.jumper],supplies:[1],total:1,timeLimit:120,releaseInterval:20,
        terrainMasks:base.terrainMasks,firstReleaseTick:1,chains:[chain]))
    game.step()
    check(game.lemmings[0].state == .chainRiding, "Falling lemming failed to grab a chain")
    game.setFan(x:20,y:-18,active:true)
    var positions = Set<Int>()
    for _ in 0..<80 { game.step(); positions.insert(game.lemmings[0].x) }
    check(game.chains[0].amplitude > 4 && positions.count > 1, "Fan failed to move chain and rider")
    check(!game.releaseChain(x:0,y:0), "Click outside the chain control released a rider")
    game.setFan(x:0,y:0,active:false)
    game.setAim(x:32,y:2,held:true)
    game.step()
    game.releasePointerInput()
    check(game.lemmings[0].state == .tumbling,
          "Held chain control failed to release its rider")
    check(game.lemmings[0].air != nil && game.supplies == [1], "Chain release spent a skill or lost launch velocity")
    print("PASS chain capture, fan response, rider movement and release control")
}

func testSuperlemAndArcher() throws {
    var flight = Lemmings2Superlem(x:80,y:220)
    for _ in 0..<19 {
        check(flight.step(targetX:200,targetY:190,solid:{_,y in y >= 220}) == .active,
              "Superlem preparation ended early")
    }
    check(flight.x == 80 && flight.y == 220, "Superlem moved before preparation finished")
    check(flight.step(targetX:200,targetY:190,solid:{_,y in y >= 220}) == .active && flight.x > 80,
          "Superlem failed to launch toward the cursor")
    var returned = false
    for _ in 0..<300 {
        let result = flight.step(targetX:flight.x,targetY:flight.y,solid:{_,y in y >= 220})
        if result == .walking { returned = true; break }
        check(result == .active, "Superlem failed during turn and landing")
    }
    check(returned, "Superlem failed to finish its landing sequence")
    var game = try fixture(wall:true)
    while game.lemmings.first?.state != .walking { game.step() }
    let slot = game.configuration.skills.firstIndex(of:.archer)!
    check(game.assign(slot:slot,to:0), "Archer assignment failed")
    for _ in 0..<16 { game.step() }
    check(game.projectiles.isEmpty, "Archer fired without aim input")
    game.setAim(x:55,y:45,held:true)
    game.step(); game.setAim(x:55,y:45,held:false)
    check(game.projectiles.count == 1 && game.projectiles[0].kind == .arrow, "Archer did not fire the aimed arrow")
    let count = game.solid.filter{$0}.count
    for _ in 0..<60 { game.step() }
    check(game.solid.filter{$0}.count > count, "Arrow did not become terrain on impact")
    print("PASS Superlem preparation, cursor flight and landing; Archer aim and terrain impact")
}

func testSkiPhysics() {
    var ski = Lemmings2SkiPhysics(direction:1), x = 20, y = 180, direction = 1
    for _ in 0..<40 {
        check(ski.step(x:&x,y:&y,direction:&direction,solid:{_,py in py >= 180}) == .riding,
              "Skier stopped on flat ground")
        check(y == 180, "Skier sank into flat terrain during a physics tick")
    }
    check(x == 100 && y == 180 && ski.velocityX == 32, "Skier flat-ground speed or height differs")
    var launched = false
    for _ in 0..<20 {
        let contact = ski.step(x:&x,y:&y,direction:&direction,solid:{px,py in px < 110 && py >= 180})
        if contact == .airborne { launched = true; break }
    }
    check(launched, "Skier failed to leave a ledge")
    print("PASS Skier flat speed, terrain contact and ledge launch")
}

func testRollerGroundContact() {
    for initialDirection in [-1,1] {
        var roller = Lemmings2SkiPhysics(direction:initialDirection,mode:.roller)
        var x = 200, y = 100, direction = initialDirection
        for _ in 0..<40 {
            check(roller.step(x:&x,y:&y,direction:&direction,solid:{_,py in py >= 100}) == .riding,
                  "Roller stopped on flat terrain")
            check(y == 100, "Roller moved into flat terrain")
        }
        check(roller.velocityX == 48*initialDirection, "Roller did not settle to its native cruise speed")
        for speed in [48,64] {
            var probe = Lemmings2SkiPhysics(direction:initialDirection,landingVelocity:speed*initialDirection,mode:.roller)
            x = 200; y = 100; direction = initialDirection
            let hit = probe.step(x:&x,y:&y,direction:&direction,solid:{px,py in
                py >= 100 || (px-200)*initialDirection > 0
            })
            check(x == 200 && y == 100, "Roller crossed a wall")
            check(speed == 64 ? hit == .stunned : hit == .riding && direction == -initialDirection,
                  "Roller wall response ignored impact speed")
        }
    }
    print("PASS Roller ground height, cruise speed and directional wall impacts")
}

func testJetPackCollision() {
    var x = 20, y = 40, vx = 512, vy = -256
    Lemmings2AirCollision.bounce(x:&x,y:&y,toX:25,toY:35,velocityX:&vx,velocityY:&vy,
        solid:{px,py in px >= 23 || py <= 26})
    check(x == 22 && y == 37 && vx == -512 && vy == 256,
          "Jet Pack did not resolve and reflect both collision axes")
    x = 20; y = 40; vx = -512; vy = 256
    Lemmings2AirCollision.bounce(x:&x,y:&y,toX:15,toY:45,velocityX:&vx,velocityY:&vy,
        solid:{px,py in px <= 18 || py >= 43})
    check(x == 19 && y == 42 && vx == 512 && vy == -256,
          "Jet Pack leftward and floor collisions differ")
    print("PASS Jet Pack wall, roof and floor reflections")
}

func testAuthoredBounds() throws {
    let c = try fixture().configuration
    var game = try Lemmings2Runtime(configuration:.init(width:c.width,height:c.height,
        pixels:c.pixels,solid:c.solid,palette:c.palette,entrance:.init(x:20,y:60,width:1,height:1),
        exits:c.exits,skills:c.skills,supplies:c.supplies,total:1,timeLimit:120,releaseInterval:20,
        terrainMasks:c.terrainMasks,firstReleaseTick:1,playBounds:.init(x:10,y:1,width:15,height:70)))
    for _ in 0..<10 { game.step() }
    check(game.lost == 1 && game.lemmings[0].x == 25,
          "Lemming survived beyond the authored boundary inside the decoded terrain")
    print("PASS authored play bounds independent of terrain allocation")
}

func testMagnoBooter() {
    for initialDirection in [-1,1] {
        var boots = Lemmings2MagnoBoots(x:40,y:80), direction = initialDirection
        var orientations = Set<Int>()
        for _ in 0..<1000 {
            check(boots.step(direction:&direction,solid:{x,y in (10..<80).contains(x) && (80..<120).contains(y)}),
                  "Magno Booter detached from a rectangular surface")
            orientations.insert(boots.orientation)
        }
        check(Set([0,1,2,3]).isSubset(of:orientations), "Magno Booter failed to traverse all four sides")
    }
    var boots = Lemmings2MagnoBoots(x:40,y:80), direction = 1
    check(!boots.step(direction:&direction,solid:{_,_ in false}), "Magno Booter remained attached after terrain removal")
    print("PASS Magno Booter floor, wall, ceiling, both directions and loss of contact")
}

func testThrownTerrain(_ masks: Lemmings2TerrainMasks) throws {
    let base = try fixture(wall:true).configuration
    for skill in [Lemmings2Runtime.Skill.thrower,.spearer] {
        var game = try Lemmings2Runtime(configuration:.init(width:base.width,height:base.height,
            pixels:base.pixels,solid:base.solid,palette:base.palette,entrance:base.entrance,
            exits:base.exits,skills:[skill],supplies:[1],total:1,timeLimit:120,releaseInterval:20,
            terrainMasks:masks,firstReleaseTick:1))
        for _ in 0..<20 where game.lemmings.first?.state != .walking { game.step() }
        check(game.assign(slot:0,to:0), "Thrown terrain skill assignment failed")
        let count = game.solid.filter{$0}.count
        for _ in 0..<12 { game.step() }
        check(game.projectiles.isEmpty && game.solid.filter{$0}.count == count, "Thrown object launched before frame thirteen")
        game.step()
        check(game.projectiles.count == 1, "Thrown object was not launched")
        for _ in 0..<100 { game.step() }
        check(game.solid.filter{$0}.count > count, "Thrown object failed to become terrain")
        check(zip(base.solid,game.solid).allSatisfy{!$0.0 || $0.1}, "Thrown object destroyed existing terrain")
    }
    print("PASS Thrower and Spearer launch phases, impacts and terrain addition")
}

func testIceAndSlider() throws {
    let w = 240, h = 200
    var pixels = [UInt8](repeating:0,count:w*h)
    for y in 80..<h { for x in 0..<w { pixels[y*w+x] = 6 } }
    func iceGame(skater: Bool) throws -> Lemmings2Runtime {
        var game = try Lemmings2Runtime(configuration:.init(width:w,height:h,pixels:pixels,
            solid:pixels.map{$0 != 0},palette:[UInt8](repeating:255,count:1024),
            entrance:.init(x:20,y:75,width:1,height:1),exits:[.init(x:230,y:70,width:8,height:10)],
            skills:[.skater],supplies:[1],total:1,timeLimit:120,releaseInterval:20,
            terrainMasks:syntheticMasks(),firstReleaseTick:1,ice:[.init(x:30,y:80,width:180,height:8)]))
        game.step()
        if skater { check(game.assign(slot:0,to:0), "Skater ability assignment failed") }
        return game
    }
    var ordinary = try iceGame(skater:false), skater = try iceGame(skater:true)
    var fell = false, recovered = false, skated = false
    for _ in 0..<80 {
        ordinary.step(); skater.step()
        fell = fell || ordinary.lemmings[0].state == .iceRecovering
        recovered = recovered || ordinary.lemmings[0].direction < 0
        skated = skated || skater.lemmings[0].state == .skating
    }
    check(fell && recovered, "Ordinary lemming did not slip, recover and reverse on ice")
    check(skated && skater.lemmings[0].x > ordinary.lemmings[0].x + 50, "Skater did not cross ice faster")
    check(skater.lost == 0 && ordinary.lost == 0, "Ice unexpectedly killed a lemming")
    // A tall ledge requires a Slider to descend before the final short fall.
    for y in 80..<170 { for x in 60..<w { pixels[y*w+x] = 0 } }
    var slider = try Lemmings2Runtime(configuration:.init(width:w,height:h,pixels:pixels,
        solid:pixels.map{$0 != 0},palette:[UInt8](repeating:255,count:1024),
        entrance:.init(x:50,y:75,width:1,height:1),exits:[.init(x:230,y:160,width:8,height:10)],
        skills:[.slider],supplies:[1],total:1,timeLimit:120,releaseInterval:20,
        terrainMasks:syntheticMasks(),firstReleaseTick:1))
    slider.step(); check(slider.assign(slot:0,to:0), "Slider assignment failed")
    var slid = false
    for _ in 0..<100 { slider.step(); slid = slid || slider.lemmings[0].state == .sliding }
    check(slid && slider.lost == 0 && slider.lemmings[0].y >= 170, "Slider failed to descend the ledge alive")
    print("PASS ordinary ice slipping, Skater travel and Slider ledge descent")
}

func testClimbingPaths() {
    for direction in [-1,1] {
        var x = 50, y = 60, facing = direction
        for phase in 0..<8 {
            let contact = Lemmings2Climbing.classic(x:&x,y:&y,direction:&facing,phase:phase,
                solid:{ px,_ in (px-50)*direction >= 0 })
            check(contact == .climbing, "Climber detached from a straight wall")
        }
        check(y == 56 && x == 50, "Climber must rise four pixels per eight-frame cycle")
        let hit = Lemmings2Climbing.classic(x:&x,y:&y,direction:&facing,phase:3,solid:{_,_ in true})
        check(hit == .falling && facing == -direction && x == 50-2*direction && y == 55,
              "Climber ceiling collision did not move away from its wall")
        x = 50; y = 60; facing = direction
        let top = Lemmings2Climbing.classic(x:&x,y:&y,direction:&facing,phase:1,solid:{_,_ in false})
        check(top == .hoisting && y == 52 && x == 50, "Climber top transfer moved its feet incorrectly")
        var pose = 0, slope = 2
        x = 50; y = 60
        let overhang = Lemmings2Climbing.rock(x:&x,y:&y,direction:direction,phase:0,
            pose:&pose,previousSlope:&slope,solid:{px,_ in (px-50)*direction >= -2})
        check(overhang == .hanging && x == 50-2*direction && y == 61,
              "Rock Climber fell instead of hanging at an overhang")
        x = 50; y = 60; slope = 0; pose = 0
        for phase in 0..<8 {
            let contact = Lemmings2Climbing.rock(x:&x,y:&y,direction:direction,phase:phase,
                pose:&pose,previousSlope:&slope,solid:{px,_ in (px-50)*direction >= 0})
            check(contact == .climbing, "Rock Climber detached from a straight wall")
        }
        check(x == 50 && y == 56 && pose == 0, "Rock Climber wall cadence differs")
    }
    print("PASS Climber wall cadence, ceiling release, top transfer and Rock Climber overhangs in both directions")
}

func testTribeNuke() throws {
    let c = try fixture().configuration
    var game = try Lemmings2Runtime(configuration:.init(width:c.width,height:c.height,
        pixels:c.pixels,solid:c.solid,palette:c.palette,entrance:.init(x:20,y:60,width:1,height:1),
        exits:c.exits,skills:[.jumper],supplies:[1],total:1,timeLimit:120,releaseInterval:20,
        terrainMasks:c.terrainMasks,firstReleaseTick:1,tribe:1))
    game.step(); game.nuke(); game.step()
    for _ in 0..<74 { game.step() }
    check(game.lemmings[0].bombTicks == 1 && game.lost == 0, "Tribe nuke countdown differs")
    game.step()
    check(game.isComplete && game.lost == 1 && game.blastFlashes.count == 1,
          "Non-Classic nuke used the Classic explosion delay")
    check(game.drainSoundEvents().filter{$0 == .init(.explode)}.count == 1, "Tribe nuke missed its explosion cue")
    check(Lemmings2SoundRequest.assignment(skill:.jumper,tribe:0).sample == 15, "Jumper cue differs")
    check(Lemmings2SoundRequest.assignment(skill:.superlem,tribe:1).sample == 30, "Superlem cue differs")
    check(Lemmings2SoundRequest.assignment(skill:.surfer,tribe:1).sample == 36, "Surfer cue differs")
    for tribe in 1..<12 {
        check(Lemmings2SoundRequest.assignment(skill:.attractor,tribe:tribe).sample == 37+tribe,
              "Tribe Attractor cue differs")
    }
    print("PASS non-Classic nuke timing and native skill sound selection")
}

func testExplosionFrames() throws {
    var data = Data(Array("L2EP".utf8)+[52,0,80,0]+Array(repeating:UInt8(128),count:8320))
    data[8] = 255; data[9] = 254
    data[12] = 3; data[13] = 4
    let animation = try Lemmings2Explosion(data:data)
    check(animation.frames.count == 52 && animation.frames[0].count == 2, "Explosion frame shape differs")
    let points = animation.frames[0]
    check(points[0].x == -1 && points[0].y == -2 && points[0].colour == 0,
          "Explosion signed coordinates differ")
    check(points[1].x == 3 && points[1].y == 4 && points[1].colour == 1,
          "Hidden explosion points incorrectly advance the colour")
    do { _ = try Lemmings2Explosion(data:data.dropLast()); check(false,"Truncated explosion animation accepted") }
    catch SequelDataError.invalid { }
    print("PASS explosion animation frames, signed positions, hidden points and validation")
}

func testShimmyEdges() {
    for direction in [-1,1] {
        for climber in [false,true] {
            var x = 50, y = 60, facing = direction, phase = 20, rise = 0
            let contact = Lemmings2Shimmy.step(x:&x,y:&y,direction:&facing,phase:&phase,rise:&rise,
                slider:false,climber:climber,solid:{ px,py in py == 51 && (px-50)*direction <= 0 })
            check(contact == (climber ? .climbingTransfer : .hanging), "Shimmier missed its roof-edge transfer")
            check(x == (climber ? 50 : 50-3*direction) && y == 60,
                  "Shimmier edge transfer shifted its support position")
            check(facing == (climber ? direction : -direction), "Shimmier edge direction differs")
        }
        for slider in [false,true] {
            var x = 50, y = 60, facing = direction, phase = 17, rise = 0
            let contact = Lemmings2Shimmy.step(x:&x,y:&y,direction:&facing,phase:&phase,rise:&rise,
                slider:slider,climber:false,solid:{ px,py in px == 50+direction && py == 55 })
            check(contact == (slider ? .sliding : .hanging), "Shimmier dropped instead of transferring at an obstruction")
            check(x == (slider ? 50 : 50-direction) && facing == (slider ? -direction : direction),
                  "Shimmier obstruction transfer position differs")
        }
        var x = 50, y = 60, facing = direction, phase = 10, rise = 0
        let contact = Lemmings2Shimmy.step(x:&x,y:&y,direction:&facing,phase:&phase,rise:&rise,
            slider:false,climber:false,solid:{ _,py in py == 49 })
        check(contact == .shimming && rise == 2 && x == 50+direction && phase == 11,
              "Shimmier failed to measure a two-pixel roof rise")
    }
    print("PASS Shimmier roof edges, wall transfers, Slider transitions and ceiling rises in both directions")
}

func testAssignmentClearance() throws {
    let base = try fixture().configuration
    for clearance in [9, 10, 11] {
        var pixels = base.pixels
        for x in 0..<base.width { pixels[(60-clearance)*base.width+x] = 6 }
        var game = try Lemmings2Runtime(configuration:.init(width:base.width,height:base.height,
            pixels:pixels,solid:pixels.map { $0 != 0 },palette:base.palette,
            entrance:.init(x:20,y:59,width:1,height:1),exits:base.exits,
            skills:[.jumper,.hopper,.shimmier,.diver],supplies:[1,1,1,1],total:1,
            timeLimit:120,releaseInterval:20,terrainMasks:base.terrainMasks,firstReleaseTick:1))
        game.step()
        check(game.lemmings[0].state == .walking, "Clearance fixture did not land")
        for slot in 0..<2 {
            check(game.canAssign(slot:slot,to:0) == (clearance > 10), "Jump clearance differs at \(clearance)")
        }
        check(!game.canAssign(slot:2,to:0), "Shimmier accepted an obstructed eleven-pixel launch")
        check(game.assign(slot:3,to:0), "Diver incorrectly requires jump headroom")
        check(game.lemmings[0].state == .diving && game.supplies == [1,1,1,0], "Diver did not consume one skill")
    }
    print("PASS native Jumper, Hopper, Shimmier and Diver assignment clearance")
}

func testAdvancedMovement() throws {
    func make(_ skill: Lemmings2Runtime.Skill, ceiling: Bool = false, wall: Bool = false) throws -> Lemmings2Runtime {
        let w = 512, h = 240
        var pixels = [UInt8](repeating:0,count:w*h)
        for y in 180..<h { for x in 0..<w { pixels[y*w+x] = 6 } }
        if ceiling { for y in 160..<165 { for x in 0..<300 { pixels[y*w+x] = 6 } } }
        if wall { for y in 120..<180 { for x in 85..<90 { pixels[y*w+x] = 6 } } }
        var game = try Lemmings2Runtime(configuration:.init(width:w,height:h,pixels:pixels,
            solid:pixels.map{$0 != 0},palette:[UInt8](repeating:255,count:1024),
            entrance:.init(x:30,y:175,width:1,height:1),exits:[.init(x:500,y:170,width:8,height:10)],
            skills:[skill],supplies:[1],total:1,timeLimit:120,releaseInterval:20,
            terrainMasks:syntheticMasks(),firstReleaseTick:1))
        for _ in 0..<10 where game.lemmings.first?.state != .walking { game.step() }
        check(game.assign(slot:0,to:0), "Advanced movement assignment failed: \(skill)")
        return game
    }
    var pole = try make(.poleVaulter)
    var vaulted = false, drawnPole = false
    for _ in 0..<70 {
        pole.step()
        vaulted = vaulted || pole.lemmings[0].y < 140
        drawnPole = drawnPole || pole.lemmings[0].pole.count > 30
    }
    check(vaulted && drawnPole && pole.lost == 0, "Pole Vaulter failed to plant, vault and draw its pole")
    var carpet = try make(.magicCarpet)
    let carpetX = carpet.lemmings[0].x
    for _ in 0..<16 { carpet.step() }
    check(carpet.lemmings[0].x == carpetX && carpet.lemmings[0].y == 179, "Magic Carpet deployment timing differs")
    for _ in 0..<20 { carpet.step() }
    check(carpet.lemmings[0].x == carpetX+40 && carpet.lemmings[0].y < 180, "Magic Carpet failed to hover and travel")
    var diver = try make(.diver)
    let diveX = diver.lemmings[0].x
    for _ in 0..<3 { diver.step() }
    check(diver.lemmings[0].x == diveX, "Diver moved before its preparation frames")
    diver.step()
    check(diver.lemmings[0].x > diveX && diver.lemmings[0].y < 180, "Diver failed to launch")
    var roller = try make(.roller,wall:true)
    let rollX = roller.lemmings[0].x
    for _ in 0..<5 { roller.step() }
    check(roller.lemmings[0].x - rollX > 10, "Roller moved at walking speed")
    for _ in 0..<30 { roller.step() }
    check(roller.lemmings[0].x < 85 && roller.lost == 0, "Roller crossed a solid wall")
    var shimmy = try make(.shimmier,ceiling:true)
    var grabbed = false, moved = false, grabX = 0
    for _ in 0..<60 {
        shimmy.step()
        if shimmy.lemmings[0].state == .shimming {
            if !grabbed { grabX = shimmy.lemmings[0].x; grabbed = true }
            moved = moved || shimmy.lemmings[0].x > grabX + 8
        }
    }
    check(grabbed && moved && shimmy.lost == 0, "Shimmier failed to grab and traverse a ceiling")
    var jet = try make(.jetPack)
    for _ in 0..<20 { jet.step() }
    check(jet.lemmings[0].y < 180 && jet.lemmings[0].state == .jetPacking, "Jet Pack failed to lift off")
    for _ in 20..<150 { jet.step() }
    check(jet.lemmings[0].state == .falling && jet.lost == 0, "Jet Pack did not expire after 150 ticks")
    var twister = try make(.twister)
    let previous = twister.pixels
    for _ in 0..<4 { twister.step() }
    check(twister.pixels != previous || twister.lemmings[0].state == .twisting,
          "Twister failed to start")
    check([diver,roller,shimmy,jet,twister].allSatisfy{$0.supplies == [0]}, "Movement consumed extra stock")
    print("PASS Diver timing, Roller collision, Shimmier ceiling traversal and Jet Pack fuel expiry")
}

func testMultipleEntrances() throws {
    let base = try fixture().configuration
    let entrances = [Lemmings2Runtime.Rect(x:20,y:45,width:1,height:1), .init(x:70,y:45,width:1,height:1)]
    var game = try Lemmings2Runtime(configuration:.init(width:base.width,height:base.height,
        pixels:base.pixels,solid:base.solid,palette:base.palette,entrance:entrances[0],exits:base.exits,
        skills:[.jumper],supplies:[1],total:3,timeLimit:120,releaseInterval:2,terrainMasks:base.terrainMasks,
        firstReleaseTick:1,entrances:entrances))
    game.step()
    check(game.released == 1 && game.lemmings[0].x == 20, "First entrance release failed")
    game.step(); game.step()
    check(game.released == 2 && game.lemmings[1].x == 70, "Second entrance did not share release timing")
    game.step(); game.step()
    check(game.released == 3 && game.lemmings[2].x == 20, "Entrance order did not wrap")
    for _ in 0..<10 { game.step() }
    check(game.released == 3, "Entrances duplicated the shared population")
    print("PASS multiple entrances share population, cadence and native round-robin order")
}

func testInteractiveObjects() throws {
    let base = try fixture().configuration
    func make(_ object: Lemmings2InteractiveObject, total: Int) throws -> Lemmings2Runtime {
        try .init(configuration:.init(width:base.width,height:base.height,pixels:base.pixels,
            solid:base.solid,palette:base.palette,entrance:.init(x:20,y:60,width:1,height:1),exits:base.exits,
            skills:[.jumper],supplies:[3],total:total,timeLimit:120,releaseInterval:2,
            terrainMasks:base.terrainMasks,firstReleaseTick:1,interactiveObjects:[object]))
    }
    let trigger = Lemmings2Runtime.Rect(x:20,y:60,width:1,height:1)
    var trap = try make(.init(id:7,kind:.trap,triggers:[trigger],frameCount:4),total:3)
    trap.step()
    check(trap.lemmings[0].state == .trapped && trap.objectFrames[7] == 1,
          "Trap did not capture and animate")
    check(!trap.assign(slot:0,to:0), "Trapped lemming accepted a skill")
    for _ in 0..<5 { trap.step() }
    check(trap.lost == 2 && trap.lemmings[1].active, "Trap busy exclusion or rearming is incorrect")
    var launcher = try make(.init(id:8,kind:.launcher,triggers:[trigger],frameCount:8,
        velocityX:-10,velocityY:-5,flags:3),total:1)
    launcher.step()
    check(launcher.lemmings[0].state == .tumbling && launcher.lemmings[0].air?.velocityX == -8,
          "Launcher did not apply clamped native velocity")
    launcher.step()
    check(launcher.lemmings[0].x == 12 && launcher.lemmings[0].y == 55,
          "Launcher trajectory did not consume launch velocity")
    print("PASS trap capture, busy exclusion, rearming and launcher velocity")
}

func testFlightAndKayak() throws {
    for skill in [Lemmings2Runtime.Skill.icarusWings,.hangGlider] {
        var game = try fixture()
        while game.lemmings.first?.state != .walking { game.step() }
        let slot = game.configuration.skills.firstIndex(of:skill)!
        let x = game.lemmings[0].x, y = game.lemmings[0].y
        check(game.assign(slot:slot,to:0), "Flight skill assignment failed")
        for _ in 0..<12 { game.step() }
        check(game.lemmings[0].x == x + (skill == .icarusWings ? 12 : 24) && game.lemmings[0].y < y,
              "Flight skill lost its distinct forward speed or initial lift")
        check(game.supplies[slot] == 9, "Flight consumed extra stock")
    }
    let base = try fixture().configuration
    let water = Lemmings2Runtime.Rect(x:16,y:48,width:64,height:16)
    var game = try Lemmings2Runtime(configuration:.init(width:base.width,height:base.height,
        pixels:base.pixels,solid:base.solid,palette:base.palette,
        entrance:.init(x:24,y:40,width:1,height:1),exits:base.exits,
        skills:[.kayaker],supplies:[1],total:1,timeLimit:120,releaseInterval:2,
        terrainMasks:base.terrainMasks,firstReleaseTick:1,hazards:[water]))
    while game.lemmings.first?.state != .drowning { game.step() }
    check(game.assign(slot:0,to:0), "Kayaker could not rescue a drowning lemming")
    let x = game.lemmings[0].x
    for _ in 0..<23 { game.step() }
    check(game.lemmings[0].x == x, "Kayak moved before deployment finished")
    var packed = false
    for _ in 0..<110 { game.step(); packed = packed || game.lemmings[0].state == .kayakPacking }
    check(packed && game.lost == 0 && game.saved == 1, "Kayak failed to cross water, pack and reach the exit")
    print("PASS distinct Icarus and Hang Glider motion; Kayaker rescue, deployment, shore and exit")
}

func testNativeScooperContinuation(_ masks: Lemmings2TerrainMasks) throws {
    let base = try fixture().configuration
    for direction in [-1,1] {
        var pixels = base.pixels
        if direction < 0 { for y in 0..<60 { for x in 25..<30 { pixels[y*base.width+x] = 6 } } }
        var game = try Lemmings2Runtime(configuration:.init(width:base.width,height:base.height,
            pixels:pixels,solid:pixels.map{$0 != 0},palette:base.palette,
            entrance:.init(x:20,y:60,width:1,height:1),exits:base.exits,skills:[.scooper],supplies:[1],
            total:1,timeLimit:120,releaseInterval:20,terrainMasks:masks,firstReleaseTick:1))
        game.step()
        for _ in 0..<10 where game.lemmings[0].direction != direction { game.step() }
        let start = game.lemmings[0]
        check(game.assign(slot:0,to:0),"Native Scooper assignment failed")
        game.step()
        check(game.isSolid(start.x,start.y),"Scooper first mask removed the ground beneath its feet")
        for _ in 0..<39 { game.step() }
        check(game.lemmings[0].state == .scooping && game.lemmings[0].x == start.x+10*direction && game.lemmings[0].y == start.y+8,
            "Scooper failed to continue through two complete native cycles")
    }
    print("PASS native Scooper mask origins and sustained digging in both directions")
}

func testRoper() throws {
    var rope = try Lemmings2Rope(owner:0,x:20,y:30,targetX:70,targetY:30)
    for _ in 0..<8 { rope.step { x,_ in x == 60 } }
    check(rope.anchored && rope.finished && rope.points.last?.x == 56 && rope.anchor?.x == 56, "Rope failed to anchor at terrain")
    var missed = try Lemmings2Rope(owner:0,x:20,y:30,targetX:100,targetY:30)
    for _ in 0..<12 { missed.step { _,_ in false } }
    check(missed.finished && !missed.anchored && missed.points.count == 64, "Unanchored rope exceeded its limit")
    var game = try fixture(wall:true)
    while game.lemmings.first?.state != .walking { game.step() }
    let slot = game.configuration.skills.firstIndex(of:.roper)!
    check(game.assign(slot:slot,to:0), "Roper assignment failed")
    let original = game.solid.filter{$0}.count
    for _ in 0..<22 { game.step() }
    check(game.rope == nil && game.lemmings[0].state == .roping, "Roper fired before the player aimed")
    game.setAim(x:70,y:45,held:true)
    for _ in 0..<15 { game.step() }
    check(game.solid.filter{$0}.count > original && game.rope == nil && game.supplies[slot] == 9,
          "Roper did not create anchored terrain after aimed input")
    print("PASS Roper aim, anchor, range limit, terrain and inventory")
}

func testProjectiles(_ masks: Lemmings2TerrainMasks) throws {
    var motion = try Lemmings2Projectile(kind:.bazooka,x:20,y:60,velocityX:8,velocityY:-3)
    motion.step()
    check(motion.x == 28 && motion.y == 57 && motion.velocityX == 64, "Projectile did not consume old velocity")
    motion.step()
    check(motion.x == 36 && motion.y == 54 && motion.velocityY == -16, "Projectile gravity timer differs")
    for skill in [Lemmings2Runtime.Skill.bazooka, .mortar] {
        let width = 180, height = 140
        var pixels = [UInt8](repeating:0,count:width*height)
        for y in 0..<height { for x in 0..<width where y >= 120 || (x >= 95 && x < 110) { pixels[y*width+x] = 6 } }
        var game = try Lemmings2Runtime(configuration:.init(width:width,height:height,pixels:pixels,
            solid:pixels.map{$0 != 0},palette:[UInt8](repeating:255,count:1024),
            entrance:.init(x:35,y:120,width:1,height:1),exits:[.init(x:165,y:110,width:10,height:10)],
            skills:[skill],supplies:[1],total:1,timeLimit:120,releaseInterval:2,
            terrainMasks:masks,firstReleaseTick:1))
        game.step(); check(game.assign(slot:0,to:0), "Projectile skill assignment failed")
        let original = game.pixels
        var launched = false
        for _ in 0..<100 { game.step(); launched = launched || !game.projectiles.isEmpty }
        check(launched && game.pixels != original && game.projectiles.isEmpty,
              "Projectile failed to launch, collide, explode and finish")
        check(game.supplies == [0], "Projectile spent extra stock")
    }
    print("PASS Bazooka and Mortar launch, projectile motion, terrain impact and completion")
}

func testPlanter(_ masks: Lemmings2TerrainMasks) throws {
    let base = try fixture().configuration
    var game = try Lemmings2Runtime(configuration:.init(width:base.width,height:base.height,
        pixels:base.pixels,solid:base.solid,palette:base.palette,
        entrance:.init(x:40,y:60,width:1,height:1),exits:base.exits,
        skills:[.planter],supplies:[1],total:1,timeLimit:120,releaseInterval:2,
        terrainMasks:masks,firstReleaseTick:1))
    game.step(); check(game.assign(slot:0,to:0), "Planter assignment failed")
    let original = game.pixels
    for _ in 0..<21 { game.step() }
    check(game.pixels == original, "Planter grew before frame twenty-two")
    for _ in 0..<9 { game.step() }
    check(game.pixels != original && game.lemmings[0].state == .walking,
          "Planter did not grow native terrain and finish at frame thirty")
    print("PASS Planter growth frames, native terrain and completion timing")
}

func testRockClimber() throws {
    var game = try fixture(wall:true)
    while game.lemmings.first?.state != .walking { game.step() }
    let slot = game.configuration.skills.firstIndex(of:.rockClimber)!
    check(game.assign(slot:slot,to:0) && !game.assign(slot:slot,to:0), "Rock Climber ability assignment failed")
    var climbed = false, hoisted = false
    for _ in 0..<130 {
        game.step()
        climbed = climbed || game.lemmings[0].state == .rockClimbing
        hoisted = hoisted || game.lemmings[0].state == .hoisting
    }
    check(climbed && hoisted && game.lemmings[0].rockClimber && game.lemmings[0].state != .dead,
          "Rock Climber climbed=\(climbed) hoisted=\(hoisted) lost=\(game.lost) state=\(game.lemmings[0].state) pos=\(game.lemmings[0].x),\(game.lemmings[0].y)")
    print("PASS Rock Climber permanent ability, wall ascent and hoist")
}

func testBallooner() throws {
    let width = 120, height = 140
    var pixels = [UInt8](repeating:0,count:width*height)
    for y in Array(40..<44) + Array(120..<height) { for x in 0..<width { pixels[y*width+x] = 6 } }
    var game = try Lemmings2Runtime(configuration:.init(width:width,height:height,pixels:pixels,
        solid:pixels.map{$0 != 0},palette:[UInt8](repeating:255,count:1024),
        entrance:.init(x:30,y:110,width:1,height:1),exits:[.init(x:105,y:110,width:10,height:10)],
        skills:[.ballooner],supplies:[1],total:1,timeLimit:120,releaseInterval:2,
        terrainMasks:syntheticMasks(),firstReleaseTick:1))
    while game.lemmings.first?.state != .walking { game.step() }
    check(game.assign(slot:0,to:0), "Ballooner assignment failed")
    let startY = game.lemmings[0].y
    for _ in 0..<7 { game.step() }
    check(game.lemmings[0].y == startY, "Ballooner rose before inflation finished")
    var rose = false, popped = false
    for _ in 0..<100 {
        game.step()
        rose = rose || game.lemmings[0].y < startY
        popped = popped || game.lemmings[0].state == .falling
    }
    check(rose && popped && game.lost == 0, "Ballooner failed to rise, pop at the roof and survive")
    print("PASS Ballooner inflation, upward drift, roof contact and falling recovery")
}

func testFillSkills() throws {
    for kind in [Lemmings2FillParticle.Kind.filler, .sand, .glue] {
        var particle = Lemmings2FillParticle(x:20,y:20,direction:-1,kind:kind)
        let settled = particle.step { x,y in x == 21 && y == 20 }
        check(settled == (kind == .glue), "Glue adhesion does not differ from loose fill")
    }
    var filler = Lemmings2FillParticle(x:20,y:20,direction:-1,kind:.filler)
    var sand = Lemmings2FillParticle(x:20,y:20,direction:-1,kind:.sand)
    let corner: (Int,Int)->Bool = { x,y in (x == 19 && y == 20) || (x == 20 && y == 21) }
    check(filler.step(solid:corner), "Filler did not settle at supported corner")
    check(!sand.step(solid:corner) && sand.x == 21 && sand.direction == 1, "Sand did not reverse at supported corner")
    for skill in [Lemmings2Runtime.Skill.filler, .sandPourer, .gluePourer] {
        var game = try fixture(wall:true)
        while game.lemmings.first?.state != .walking { game.step() }
        let slot = game.configuration.skills.firstIndex(of:skill)!
        let original = game.solid.filter{$0}.count
        check(game.assign(slot:slot,to:0), "Fill skill assignment failed")
        var moving = false
        for _ in 0..<240 {
            game.step(); moving = moving || !game.fillParticles.isEmpty
        }
        let added = game.solid.filter{$0}.count - original
        check(moving && added > 0 && added <= 78, "Fill \(skill) emission: moving=\(moving), added=\(added), state=\(game.lemmings[0].state)")
        check(game.fillParticles.isEmpty && game.supplies[slot] == 9,
              "Fill stream failed to finish or consumed extra stock")
    }
    print("PASS distinct fill, sand and glue rules, emission limits and settling")
}

func testAttractor() throws {
    var game = try fixture()
    while game.lemmings.first?.state != .walking { game.step() }
    let slot = game.configuration.skills.firstIndex(of:.attractor)!
    check(game.assign(slot:slot,to:0), "Attractor assignment failed")
    for _ in 0..<80 { game.step() }
    check(game.lemmings[0].state == .attracting && game.lemmings.dropFirst().contains { $0.state == .dancing },
          "Attractor did not hold nearby walkers")
    let builder = game.configuration.skills.firstIndex(of:.builder)!
    check(game.assign(slot:builder,to:0), "Attractor could not be interrupted")
    game.step()
    check(!game.lemmings.contains { $0.state == .dancing }, "Dancers remained held after Attractor stopped")
    print("PASS Attractor capture, interrupt and dancer release")
}

func testFanAndParachuter() throws {
    let drag = Lemmings2FanPhysics.step(x:0,y:0,velocityX:2000,velocityY:-257,fanX:0,fanY:0,power:0)
    check(drag.velocityX == 1500 && drag.deltaX == 5 && drag.velocityY == -192 && drag.deltaY == -1,
          "Fan drag or signed fixed-point rounding changed")
    check(Lemmings2FanPhysics.power(heldTicks:0) == 0
        && Lemmings2FanPhysics.power(heldTicks:8) == 12800
        && Lemmings2FanPhysics.power(heldTicks:64) == 128000
        && Lemmings2FanPhysics.power(heldTicks:72) == 307200, "Fan ramp differs from original")
    let right = Lemmings2FanPhysics.step(x:32,y:16,velocityX:0,velocityY:0,fanX:0,fanY:0,power:307200)
    let left = Lemmings2FanPhysics.step(x:-32,y:16,velocityX:0,velocityY:0,fanX:0,fanY:0,power:307200)
    check(right.velocityX > 0 && left.velocityX < 0 && right.velocityY == 0, "Fan direction points toward cursor")
    check(right.velocityX == 449 && left.velocityX == -448, "Fan force lost fixed-point precision before multiplication")
    let distant = Lemmings2FanPhysics.step(x:128,y:16,velocityX:0,velocityY:0,fanX:0,fanY:0,power:307200)
    check(distant.deltaX == 0 && distant.velocityX == 0, "Fan exceeded original range")
    let masks = try syntheticMasks()
    let width = 180, height = 180
    var pixels = [UInt8](repeating:0,count:width*height)
    for y in 160..<height { for x in 0..<width { pixels[y*width+x] = 6 } }
    var game = try Lemmings2Runtime(configuration:.init(width:width,height:height,
        pixels:pixels,solid:pixels.map{$0 != 0},palette:[UInt8](repeating:255,count:1024),
        entrance:.init(x:40,y:20,width:1,height:1),exits:[.init(x:160,y:150,width:10,height:10)],
        skills:[.parachuter],supplies:[1],total:1,timeLimit:120,releaseInterval:2,
        terrainMasks:masks,firstReleaseTick:1))
    game.step(); check(game.assign(slot:0,to:0), "Parachuter assignment failed")
    var opened = false
    for _ in 0..<180 { game.step(); opened = opened || game.lemmings[0].state == .parachuting }
    check(opened && game.lemmings[0].parachuter && game.lost == 0, "Parachuter failed to survive long fall")
    print("PASS fan ramp, range, signed drag, direction and Parachuter landing")
}

func testSwimmer() throws {
    let base = try fixture().configuration
    func make(fire: Bool = false) throws -> Lemmings2Runtime {
        let hazard = Lemmings2Runtime.Rect(x:16,y:40,width:48,height:24)
        return try .init(configuration:.init(width:base.width,height:base.height,
            pixels:base.pixels,solid:base.solid,palette:base.palette,
            entrance:.init(x:24,y:40,width:1,height:1),exits:base.exits,
            skills:[.swimmer],supplies:[1],total:1,timeLimit:120,releaseInterval:2,
            terrainMasks:base.terrainMasks,firstReleaseTick:1,hazards:[hazard],
            fireHazards:fire ? [hazard] : []))
    }
    // Assign before the hazard is reached, as players must do in normal play.
    var baseGame = try fixture()
    baseGame.step()
    while baseGame.lemmings.isEmpty { baseGame.step() }
    let slot = baseGame.configuration.skills.firstIndex(of:.swimmer)!
    check(baseGame.assign(slot:slot,to:0) && baseGame.lemmings[0].swimmer,
          "Swimmer permanent ability assignment failed")
    check(!baseGame.assign(slot:slot,to:0), "Duplicate Swimmer spent inventory")
    // A trigger below the entrance gives one tick to assign the skill.
    let water = Lemmings2Runtime.Rect(x:16,y:48,width:48,height:16)
    var game = try Lemmings2Runtime(configuration:.init(width:base.width,height:base.height,
        pixels:base.pixels,solid:base.solid,palette:base.palette,
        entrance:.init(x:24,y:40,width:1,height:1),exits:base.exits,
        skills:[.swimmer],supplies:[1],total:1,timeLimit:120,releaseInterval:2,
        terrainMasks:base.terrainMasks,firstReleaseTick:1,hazards:[water]))
    game.step()
    check(game.assign(slot:0,to:0), "Swimmer assignment before water failed")
    var swam = false, left = false
    for _ in 0..<100 {
        game.step()
        swam = swam || game.lemmings[0].state == .swimming
        left = left || game.lemmings[0].state == .leavingWater
    }
    check(swam && left && game.lost == 0, "Swimmer did not cross water and leave it alive")
    var ordinary = try make(); ordinary.step()
    check(ordinary.lemmings[0].state == .drowning, "Water did not offer the native rescue interval")
    for _ in 0..<16 { ordinary.step() }
    check(ordinary.lost == 1, "Ordinary lemming survived water")
    print("PASS Swimmer permanent ability, water crossing, shore exit and ordinary drowning")
}

func testBlastBomber(_ masks: Lemmings2TerrainMasks) throws {
    let base = try fixture().configuration
    var game = try Lemmings2Runtime(configuration:.init(width:base.width,height:base.height,
        pixels:base.pixels,solid:base.solid,palette:base.palette,
        entrance:.init(x:50,y:60,width:1,height:1),exits:base.exits,
        skills:[.blastBomber],supplies:[1],total:2,timeLimit:120,releaseInterval:2,
        terrainMasks:masks,firstReleaseTick:1))
    game.step()
    check(game.assign(slot:0,to:0), "Bomber assignment failed")
    let original = game.pixels
    for _ in 0..<9 { game.step() }
    check(game.pixels == original, "Bomber cut terrain before frame ten")
    game.step()
    check(game.pixels != original, "Bomber did not apply the native blast mask")
    check(game.blastFlashes.count == 1, "Bomber omitted its visible blast flash")
    check(game.lemmings.allSatisfy { $0.state == .tumbling && $0.active },
          "Bomber failed to launch itself and nearby lemmings")
    check(game.lemmings[0].air?.velocityX == 0 && game.lemmings[0].air?.velocityY == -5,
          "Bomber centre impulse differs from original")
    check(game.lemmings[1].air!.velocityX > 0 && game.lemmings[1].air!.velocityY < 0,
          "Bomber neighbour impulse points inward")
    check(game.supplies == [0] && game.lost == 0, "Bomber consumed extra stock or killed the actor")
    game.step()
    check(game.blastFlashes.isEmpty, "Bomber flash persisted beyond its native frame")
    print("PASS Bomber frame timing, native terrain mask, flash, self and neighbour impulses")
}

func testHopper() throws {
    var game = try fixture()
    while game.lemmings.first?.state != .walking { game.step() }
    let slot = game.configuration.skills.firstIndex(of: .hopper)!
    check(game.assign(slot: slot, to: 0), "Hopper assignment failed")
    check(game.lemmings[0].air?.velocityX == 2 && game.lemmings[0].air?.velocityY == -3,
          "Hopper initial impulse differs from original")
    check(!game.assign(slot: slot, to: 0), "Airborne Hopper accepted duplicate assignment")
    var pauses = 0
    var previous = game.lemmings[0].state
    for _ in 0..<100 {
        game.step()
        let state = game.lemmings[0].state
        if state == .hopPreparing && previous != state { pauses += 1 }
        previous = state
    }
    check(pauses >= 2, "Hopper did not land and repeat its hop")
    check(game.supplies[slot] == 9, "Repeated hops consumed more than one skill")
    print("PASS Hopper launch, landing, repeated hops and inventory")
}

func testTrampolines() throws {
    let base = try fixture().configuration
    let strengths = [4,4,5,5,5,6,6,6,6,6,6,5,5,5,4,4]
    for segment in 0..<16 {
        let x = 32 + segment
        var game = try Lemmings2Runtime(configuration:.init(width:base.width,height:base.height,
            pixels:base.pixels,solid:base.solid,palette:base.palette,
            entrance:.init(x:x,y:40,width:1,height:1),exits:base.exits,
            skills:[.jumper],supplies:[1],total:1,timeLimit:120,releaseInterval:2,
            terrainMasks:base.terrainMasks,firstReleaseTick:1,
            interactiveObjects:[.init(id:4,kind:.trampoline,
                triggers:[.init(x:x,y:40,width:1,height:8)],frameCount:8)]))
        game.step()
        check(game.lemmings[0].state == .jumping, "Trampoline did not convert a falling lemming")
        check(game.lemmings[0].air?.velocityY == Int16(-strengths[segment]), "Trampoline segment strength differs from original table")
        check(game.lemmings[0].air?.velocityX == (strengths[segment] == 4 ? 3 : 4), "Trampoline horizontal impulse differs")
    }
    print("PASS all sixteen native trampoline launch segments")
}

func testBeamSkills(_ masks: Lemmings2TerrainMasks) throws {
    for skill in [Lemmings2Runtime.Skill.laserBlaster, .flameThrower] {
        let w = 120, h = 100
        var pixels = [UInt8](repeating:0,count:w*h)
        for y in 70..<h { for x in 0..<w { pixels[y*w+x] = 6 } }
        if skill == .laserBlaster {
            for y in 30..<38 { for x in 0..<w { pixels[y*w+x] = 6 } }
        } else {
            for y in 50..<70 { for x in 51..<70 { pixels[y*w+x] = 6 } }
        }
        func ready(steel: Bool) throws -> Lemmings2Runtime {
            var game = try Lemmings2Runtime(configuration:.init(width:w,height:h,pixels:pixels,
                solid:pixels.map{$0 != 0},palette:[UInt8](repeating:255,count:1024),
                entrance:.init(x:45,y:60,width:1,height:1),exits:[.init(x:100,y:60,width:10,height:10)],
                skills:[skill],supplies:[2],total:1,timeLimit:120,releaseInterval:20,terrainMasks:masks,
                firstReleaseTick:1,steel:steel ? [Bool](repeating:true,count:w*h):[]))
            while game.lemmings.first?.state != .walking { game.step() }
            return game
        }
        var game = try ready(steel:false)
        check(game.assign(slot:0,to:0), "Beam skill assignment failed")
        let original=game.pixels
        for _ in 0..<80 {
            game.step()
            if game.lemmings[0].state == .walking { break }
        }
        check(game.pixels != original && game.lemmings[0].state == .walking,
              "Beam skill did not cut terrain and stop")
        var steel = try ready(steel:true)
        check(steel.assign(slot:0,to:0), "Protected beam skill assignment failed")
        for _ in 0..<40 { steel.step() }
        check(steel.pixels == original && steel.lemmings[0].state == .walking,
              "Beam skill cut steel or failed to stop")
    }
    print("PASS Laser Blaster and Flame Thrower terrain, steel and termination")
}

func testTribeDigging(_ masks: Lemmings2TerrainMasks) throws {
    for skill in [Lemmings2Runtime.Skill.scooper, .fencer, .clubBasher] {
        let w = 120, h = 100
        var pixels = [UInt8](repeating: 0, count: w * h)
        for y in 60..<h { for x in 0..<w { pixels[y*w+x] = 6 } }
        for y in 35..<60 { for x in 50..<80 { pixels[y*w+x] = 6 } }
        func ready(steel: Bool) throws -> Lemmings2Runtime {
            var game = try Lemmings2Runtime(configuration: .init(width:w, height:h, pixels:pixels,
                solid:pixels.map{$0 != 0}, palette:[UInt8](repeating:255,count:1024),
                entrance:.init(x:45,y:45,width:1,height:1), exits:[.init(x:100,y:50,width:10,height:10)],
                skills:[skill,.builder], supplies:[2,1], total:1, timeLimit:120, releaseInterval:20,
                terrainMasks:masks, firstReleaseTick:1,
                steel:steel ? [Bool](repeating:true,count:w*h) : []))
            while game.lemmings.first?.state != .walking { game.step() }
            return game
        }
        var game = try ready(steel:false)
        let original = game.pixels
        check(game.assign(slot:0,to:0), "Tribe digging assignment failed")
        check(!game.assign(slot:0,to:0) && game.supplies[0] == 1, "Repeated tribe digging assignment spent inventory")
        if skill == .clubBasher {
            game.step(); game.step()
            check(game.pixels == original, "Club basher cut before frame 3")
        }
        for _ in 0..<8 { game.step() }
        check(game.pixels != original, "Tribe digging skill did not apply its native mask")
        var steel = try ready(steel:true)
        check(steel.assign(slot:0,to:0), "Steel tribe skill assignment failed")
        for _ in 0..<8 { steel.step() }
        check(steel.pixels == original && steel.lemmings[0].state == .walking,
              "Tribe digging skill did not stop at steel")
    }
    print("PASS Scooper, Fencer and Club Basher native terrain cuts, phases, steel and inventory")
}

func testRunner() throws {
    var game = try fixture()
    while !game.lemmings.contains(where: { $0.state == .walking }) { game.step() }
    let runner = game.configuration.skills.firstIndex(of: .runner)!
    let jump = game.configuration.skills.firstIndex(of: .jumper)!
    let start = game.lemmings[0]
    check(game.assign(slot: runner, to: 0), "Runner assignment failed")
    check(!game.assign(slot: runner, to: 0) && game.supplies[runner] == 9, "Runner repeated assignment spent supply")
    game.step()
    check(game.lemmings[0].state == .running && game.lemmings[0].x == start.x + 2, "Runner must move two checked strides")
    let x = game.lemmings[0].x, y = game.lemmings[0].y
    check(game.assign(slot: jump, to: 0), "Running Jumper assignment failed")
    game.step()
    check(game.lemmings[0].x == x + 4 && game.lemmings[0].y == y - 5, "Runner jump did not use stronger launch")
    for _ in 0..<100 {
        if game.lemmings[0].state == .running { break }
        game.step()
    }
    check(game.lemmings[0].state == .running, "Permanent running ability was lost after landing")
    print("PASS Runner speed, inventory, stronger jump and persistent ability")
}

func testJumper() throws {
    let wall = Lemmings2AirCollision.sweep(x: 0, y: 10, toX: 8, toY: 10) { x, _ in x == 3 }
    check(wall.x == 3 && wall.previousX == 2 && wall.contact == .body, "Air sweep crossed a thin wall")
    let roof = Lemmings2AirCollision.sweep(x: 4, y: 20, toX: 6, toY: 17) { _, y in y == 9 }
    check(roof.contact == .head && roof.y == 18, "Air sweep missed head contact")
    let floor = Lemmings2AirCollision.sweep(x: 4, y: 20, toX: 6, toY: 28) { _, y in y == 23 }
    check(floor.contact == .body && floor.y == 23, "Air sweep crossed a thin floor")
    var game = try fixture()
    while !game.lemmings.contains(where: { $0.state == .walking }) { game.step() }
    let start = game.lemmings[0], slot = game.configuration.skills.firstIndex(of: .jumper)!
    check(game.assign(slot: slot, to: 0), "Jumper assignment failed")
    check(!game.assign(slot: slot, to: 0) && game.supplies[slot] == 9, "Repeated airborne assignment spent supply")
    game.step()
    check(game.lemmings[0].x == start.x + 3 && game.lemmings[0].y == start.y - 4,
          "Jumper launch did not use the native old velocity")
    var landed = false
    for _ in 0..<100 {
        game.step()
        if game.lemmings[0].state == .walking {
            check(game.lemmings[0].y == start.y && game.lemmings[0].x > start.x + 10,
                  "Jumper landed inside terrain or lost horizontal travel")
            landed = true; break
        }
    }
    check(landed, "Jumper never landed")
    print("PASS Jumper launch, landing, inventory and swept wall/floor/ceiling collision")
}

func testStomper(_ masks: Lemmings2TerrainMasks) throws {
    func ready(left: Bool = false, steel: Bool = false, thinFloor: Bool = false) throws -> Lemmings2Runtime {
        let w = 120, h = 100
        var pixels = [UInt8](repeating: 0, count: w * h)
        for y in 60..<(thinFloor ? 62 : h) { for x in 0..<w { pixels[y * w + x] = 6 } }
        if left { for y in 30..<60 { pixels[y * w + 22] = 6 } }
        var game = try Lemmings2Runtime(configuration: .init(width: w, height: h,
            pixels: pixels, solid: pixels.map { $0 != 0 }, palette: [UInt8](repeating: 255, count: 1024),
            entrance: .init(x: 20, y: 45, width: 1, height: 1),
            exits: [.init(x: 100, y: 50, width: 10, height: 10)],
            skills: [.stomper, .builder], supplies: [2, 1], total: 1, timeLimit: 120,
            releaseInterval: 20, terrainMasks: masks, firstReleaseTick: 1,
            steel: steel ? [Bool](repeating: true, count: w * h) : []))
        game.step()
        check(!game.assign(slot: 0, to: 0) && game.supplies[0] == 2, "Stomper assigned during a fall")
        for _ in 0..<100 {
            if let lem = game.lemmings.first, lem.state == .walking, lem.direction == (left ? -1 : 1) { return game }
            game.step()
        }
        throw SequelDataError.invalid("Stomper fixture did not reach the floor.")
    }
    for left in [false, true] {
        var game = try ready(left: left)
        let start = game.lemmings[0], original = game.pixels
        check(game.assign(slot: 0, to: 0), "Stomper assignment failed")
        check(!game.assign(slot: 0, to: 0) && game.supplies[0] == 1, "Repeated Stomper assignment spent inventory")
        for _ in 0..<6 { game.step() }
        check(game.pixels == original && game.lemmings[0].y == start.y, "Stomper acted before frame 7")
        game.step()
        check(game.lemmings[0].y == start.y + 2 && game.lemmings[0].x == start.x,
              "Stomper did not descend two pixels on frame 7")
        check((-5...4).allSatisfy { !game.isSolid(start.x + $0, start.y) }
            && game.isSolid(start.x - 6, start.y) && game.isSolid(start.x + 5, start.y),
            "Stomper cut does not match the native ten-pixel mask")
        for _ in 0..<7 { game.step() }
        check(game.lemmings[0].y == start.y + 2, "Stomper repeated too early")
        game.step()
        check(game.lemmings[0].y == start.y + 4, "Stomper did not repeat after eight frames")
        check(game.assign(slot: 1, to: 0) && game.lemmings[0].state == .building,
              "A working Stomper could not accept another terrain skill")
    }
    var steel = try ready(steel: true)
    let original = steel.pixels, y = steel.lemmings[0].y
    _ = steel.drainSoundEvents()
    check(steel.assign(slot: 0, to: 0), "Steel Stomper assignment failed")
    for _ in 0..<7 { steel.step() }
    check(steel.pixels == original && steel.lemmings[0].state == .walking && steel.lemmings[0].y == y,
          "Stomper cut or descended through steel")
    check(steel.drainSoundEvents().filter { $0.sample == Lemmings2SoundCue.hitSteel.rawValue }.count == 1,
          "Stomper did not emit one steel impact sound")
    check(steel.drainSoundEvents().isEmpty, "Stomper replayed drained sound events")
    var drop = try ready(thinFloor: true)
    check(drop.assign(slot: 0, to: 0), "Thin-floor Stomper assignment failed")
    for _ in 0..<7 { drop.step() }
    check(drop.lemmings[0].state == .falling && drop.lemmings[0].fallDistance == 0,
          "Stomper did not fall after breaking through the floor")
    print("PASS Stomper native mask, action phases, both directions, steel, falling and inventory")
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
    var falling = try Lemmings2Runtime(configuration: .init(width: 120, height: 80,
        pixels: [UInt8](repeating: 0, count: 9600), solid: [Bool](repeating: false, count: 9600),
        palette: [UInt8](repeating: 255, count: 1024), entrance: .init(x: 20, y: 45, width: 1, height: 1),
        exits: [.init(x: 90, y: 50, width: 16, height: 16)], skills: [.climber], supplies: [0], total: 1,
        timeLimit: 120, releaseInterval: 20, terrainMasks: try syntheticMasks()))
    var falls: [Lemmings2SoundRequest] = []
    for _ in 0..<200 { falling.step(); falls += falling.drainSoundEvents() }
    check(falls.filter { $0.isBottomFall }.count == 1 && falling.lost == 1, "L2 must identify bottom deaths once")
    check(!Lemmings2SoundRequest(.fallOut).isBottomFall, "Other boundary deaths must retain their sound")
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
    try testLinkedObjects()
    try testRailMachines()
    try testChains()
    try testSuperlemAndArcher()
    testSkiPhysics()
    testRollerGroundContact()
    check(Lemmings2SkillRules.permits(.builder,during:.rolling), "Roller cannot switch to construction")
    check(Lemmings2SkillRules.permits(.jumper,during:.skiing), "Skier cannot jump")
    check(Lemmings2SkillRules.permits(.shimmier,during:.hanging), "Hanging lemming cannot shimmy")
    check(!Lemmings2SkillRules.permits(.builder,during:.filling), "Pourer accepted an interrupting construction skill")
    check(!Lemmings2SkillRules.permits(.roper,during:.throwing), "Thrower accepted an interrupting rope")
    testJetPackCollision()
    try testAuthoredBounds()
    try testWitnessRejectsOutOfOrderInputs()
    testMagnoBooter()
    try testThrownTerrain(syntheticMasks())
    try testIceAndSlider()
    testClimbingPaths()
    try testTribeNuke()
    try testExplosionFrames()
    testShimmyEdges()
    try testAssignmentClearance()
    try testAdvancedMovement()
    try testMultipleEntrances()
    try testInteractiveObjects()
    try testTrampolines()
    try testHopper()
    try testSwimmer()
    try testAttractor()
    try testFillSkills()
    try testBallooner()
    try testPlanter(syntheticMasks())
    try testRockClimber()
    try testRoper()
    try testFlightAndKayak()
    try testProjectiles(syntheticMasks())
    try testFanAndParachuter()
    try testBlastBomber(syntheticMasks())
    try testBeamSkills(syntheticMasks())
    try testTribeDigging(syntheticMasks())
    try testRunner()
    try testJumper()
    try testStomper(syntheticMasks())
    print("PASS native L2 walking, rescue, inventory, terrain, replay and nuke tests")

    if CommandLine.arguments.count > 1 {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let level = try Lemmings2Level(data: Data(contentsOf: root.appendingPathComponent("LEVELS/LEVEL000.DAT")))
        let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent("STYLES/CLASSIC.DAT")))
        let masks = try Lemmings2TerrainMasks(root: root)
        try testNativeScooperContinuation(masks)
        let nativeSprites = try Lemmings2Sprites(data: Data(contentsOf: root.appendingPathComponent("VLEMMS.DAT")))
        check(nativeSprites.animations["LM1D"]?.count == 8, "Stomper sprite bank is not eight undirected frames")
        try testBeamSkills(masks)
        try testBlastBomber(masks)
        try testPlanter(masks)
        try testThrownTerrain(masks)
        try testProjectiles(masks)
        try testTribeDigging(masks)
        try testStomper(masks)
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
        typealias Replay = Lemmings2ReplayWitness
        let wholeCampaign = try Lemmings2Campaign(root:root)
        for tribe in 0..<12 {
            let style = try Lemmings2Style(data:Data(contentsOf:root.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[tribe]).DAT")))
            for level in wholeCampaign.levels[(tribe*10)..<(tribe*10+10)] {
                var game = try Lemmings2Runtime(level:level,style:style,masks:masks,total:1)
                check(game.machines.allSatisfy{$0.minimumX <= $0.x && $0.x <= $0.maximumX},"Machine lies outside its native rail")
                let c = game.configuration
                var reachedExit = false
                for e in c.exits {
                    for y in e.y..<(e.y+e.height) {
                        for x in e.x..<(e.x+e.width) where !reachedExit && game.isSolid(x,y) && !game.isSolid(x,y-1) {
                            var probe = try Lemmings2Runtime(configuration:.init(width:c.width,height:c.height,
                                pixels:c.pixels,solid:c.solid,palette:c.palette,entrance:.init(x:x,y:y,width:1,height:1),
                                exits:c.exits,skills:c.skills,supplies:c.supplies,total:1,timeLimit:c.timeLimit,
                                releaseInterval:c.releaseInterval,terrainMasks:masks,firstReleaseTick:1,steel:c.steel,
                                exitFrameCount:c.exitFrameCount))
                            for _ in 0..<(c.exitFrameCount+3) { probe.step() }
                            reachedExit = probe.saved == 1
                        }
                    }
                }
                check(reachedExit,"Native exit is buried or cannot rescue: \(level.title)")
                for _ in 0..<180 { game.step() }
                check(game.released == 1,"Native campaign smoke test never released its lemming")
            }
        }
        print("PASS all 120 campaign levels load and advance through native physics")
        for level in try Lemmings2Practice(root:root).levels {
            let style = try Lemmings2Style(data:Data(contentsOf:root.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
            let choices: [Lemmings2Runtime.Skill] = [.jumper,.runner,.builder,.basher,.digger,.climber,.floater,.roper]
            var practice = try Lemmings2Practice.runtime(level:level,style:style,masks:masks,skills:choices)
            check(practice.configuration.skills == choices && practice.supplies == Array(repeating:99,count:8),"Practice panel ignored the selected skills")
            check(practice.configuration.levelFingerprint == nil,"Practice could be mistaken for campaign completion")
            for _ in 0..<180 { practice.step() }
            check(practice.released > 0,"Practice map failed to start")
        }
        print("PASS all four original practice maps, selected skills and separate progress")
        let fixtureDirectory = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Lemmings2CompletionTests/Fixtures")
        let fixtureURLs = try FileManager.default.contentsOfDirectory(at:fixtureDirectory,includingPropertiesForKeys:nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var completedLevels = Set<String>()
        for url in fixtureURLs {
            let name = url.deletingPathExtension().lastPathComponent
            let replay = try JSONDecoder().decode(Replay.self,from:Data(contentsOf:url))
            guard let level = wholeCampaign.levels.first(where: { $0.fingerprint == replay.levelSHA256 }) else {
                throw SequelDataError.invalid("Completion fixture uses an unknown level: \(name)")
            }
            let number = wholeCampaign.levels.firstIndex(where: { $0.fingerprint == level.fingerprint })!
            let prefix = level.style == 2 ? "cavelem" : Lemmings2Campaign.tribeNames[level.style].lowercased()
            check(name == String(format:"\(prefix)-%02d",number%10+1),"Completion fixture has the wrong tribe or level name: \(name)")
            check(completedLevels.insert(level.fingerprint).inserted,"Duplicate level completion fixture: \(name)")
            check(replay.version == 1 && replay.levelSHA256 == level.fingerprint,"Completion fixture uses a different level")
            let style = try Lemmings2Style(data:Data(contentsOf:root.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
            let outcome: Lemmings2WitnessOutcome
            do { outcome = try replay.run(level:level,style:style,masks:masks) }
            catch { check(false,"Completion changed: \(name) (\(error))"); continue }
            print("PASS \(name): \(outcome.saved) rescued, \(outcome.ticks) ticks, recorded pointer and skill inputs")
        }
        print("PASS \(completedLevels.count) distinct recorded campaign level completions")
        for (tribe,prefix,count) in [(2,"cavelem",3),(3,"circus",2)] {
        var chain = try Lemmings2Campaign(root: root)
        try chain.select(tribe: tribe)
        let chainStyle = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[tribe]).DAT")))
        for number in 1...count {
            let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent(String(format: "Lemmings2CompletionTests/Fixtures/\(prefix)-%02d.json", number))
            let replay = try JSONDecoder().decode(Replay.self, from: Data(contentsOf: url))
            check(replay.version == 1 && replay.levelSHA256 == chain.current.fingerprint,
                  "\(prefix) replay uses a different native level")
            check(replay.population == chain.population, "\(prefix) replay skipped survivor carry-over")
            var game = try Lemmings2Runtime(level: chain.current, style: chainStyle, masks: masks,
                total: chain.population, allowExperimentalTribes: true)
            var command = 0
            while !game.isComplete && game.tick <= replay.expectedTicks {
                while command < replay.inputs.count && replay.inputs[command].tick == game.tick {
                    let event = replay.inputs[command]
                    let slot = game.configuration.skills.firstIndex { $0.rawValue == event.skill }
                    check(slot != nil && game.assign(slot: slot!, to: event.lemming), "\(prefix) replay input rejected")
                    command += 1
                }
                game.step()
            }
            check(command == replay.inputs.count && game.didWin && game.saved == replay.expectedSaved
                && game.tick == replay.expectedTicks, "\(prefix) completion replay changed")
            check(chain.advance(after: game), "\(prefix) campaign rejected completed level")
            print("PASS \(prefix) \(number): \(game.saved) rescued, \(game.tick) ticks, survivor carry-over verified")
        }
        }
        let replayURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Lemmings2CompletionTests/Fixtures/classic-01.json")
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
        check(tribes.levels.count == 120 && tribes.population == 60 && tribes.tribe == 1 && tribes.current.style == 1 && !tribes.isComplete, "Initial twelve-tribe campaign starts at Beach")
        try tribes.select(tribe: 0)
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
        for invalidTribe in [-1, 12, Int.max] {
            do { try nativeRestored.restore(.init(tribe: invalidTribe, level: 0, results: nativeProgress.results))
                check(false, "Save accepted an invalid tribe") } catch {}
        }
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
        check(nativeRestored.isComplete && nativeRestored.hasGoldenTalisman && nativeRestored.canLaunchArk, "All twelve talisman pieces not counted")
        let tooFew = Dictionary(uniqueKeysWithValues: nativeRestored.levels.enumerated().map { index, level in
            (index, Lemmings2Campaign.Result(startingPopulation: 1, saved: 1, medal: .gold, levelFingerprint: level.fingerprint))
        })
        try nativeRestored.restore(.init(tribe:11,level:9,results:tooFew))
        check(nativeRestored.isComplete && nativeRestored.hasGoldenTalisman && !nativeRestored.canLaunchArk,
              "A golden talisman bypassed the ark survivor requirement")
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
