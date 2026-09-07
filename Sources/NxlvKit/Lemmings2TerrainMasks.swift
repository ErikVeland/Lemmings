import Foundation

/// Native terrain operations read from the user's MASKS.DAT and INTERN.DAT.
/// These are pixel masks, not substitutes from the first Lemmings engine.
public struct Lemmings2TerrainMasks: Sendable {
    public let digger: Lemmings2SpriteFrame
    public let basher: [Lemmings2SpriteFrame]
    public let miner: [Lemmings2SpriteFrame]
    public let ropeHook: [Lemmings2SpriteFrame]
    public let arrow: [Lemmings2SpriteFrame]
    public let stone: [Lemmings2SpriteFrame]
    public let spear: [Lemmings2SpriteFrame]
    public let plant: [Lemmings2SpriteFrame]
    public let blast: Lemmings2SpriteFrame?
    public let exploder: Lemmings2SpriteFrame
    public let brick: Lemmings2SpriteFrame
    public let stacker: [Lemmings2SpriteFrame]
    public let platformer: Lemmings2SpriteFrame
    public let laser: [Lemmings2SpriteFrame]
    public let flame: [Lemmings2SpriteFrame]
    public let scooper: [Lemmings2SpriteFrame]
    public let fencer: [Lemmings2SpriteFrame]
    public let clubBasher: [Lemmings2SpriteFrame]
    public let twister: Lemmings2SpriteFrame?
    public let stomper: Lemmings2SpriteFrame?

    public init(root: URL) throws {
        let masks = try Lemmings2SpecialGraphics(data: Data(contentsOf: root.appendingPathComponent("MASKS.DAT")))
        let intern = try Lemmings2SpecialGraphics(data: Data(contentsOf: root.appendingPathComponent("INTERN.DAT")))
        func single(_ bank: Lemmings2SpecialGraphics, _ index: Int) throws -> Lemmings2SpriteFrame {
            let frames = try bank.animation(index)
            guard frames.count == 1 else { throw SequelDataError.invalid("Invalid L2 single-frame terrain mask.") }
            return frames[0]
        }
        try self.init(digger: single(masks, 7), basher: masks.animation(5), miner: masks.animation(2),
                      exploder: single(masks, 8), brick: single(intern, 13),
                      stacker: intern.animation(3), platformer: single(intern, 4), stomper: single(masks, 3), scooper: masks.animation(0),
                      fencer: masks.animation(4), clubBasher: masks.animation(6), laser: masks.animation(9), flame: masks.animation(11), blast: single(masks, 1), plant: intern.animation(18), twister: single(masks, 10), stone:intern.animation(7), spear:intern.animation(6), arrow:intern.animation(2), ropeHook:intern.animation(11))
    }

    /// Allows synthetic masks for tests without distributing commercial data.
    public init(digger: Lemmings2SpriteFrame, basher: [Lemmings2SpriteFrame],
                miner: [Lemmings2SpriteFrame], exploder: Lemmings2SpriteFrame,
                brick: Lemmings2SpriteFrame, stacker: [Lemmings2SpriteFrame],
                platformer: Lemmings2SpriteFrame, stomper: Lemmings2SpriteFrame? = nil, scooper: [Lemmings2SpriteFrame] = [],
                fencer: [Lemmings2SpriteFrame] = [], clubBasher: [Lemmings2SpriteFrame] = [], laser: [Lemmings2SpriteFrame] = [],
                flame: [Lemmings2SpriteFrame] = [], blast: Lemmings2SpriteFrame? = nil, plant: [Lemmings2SpriteFrame] = [], twister: Lemmings2SpriteFrame? = nil, stone: [Lemmings2SpriteFrame] = [], spear: [Lemmings2SpriteFrame] = [], arrow: [Lemmings2SpriteFrame] = [], ropeHook: [Lemmings2SpriteFrame] = []) throws {
        guard basher.count == 8, miner.count == 4, stacker.count == 2 else {
            throw SequelDataError.invalid("Invalid L2 terrain mask count.")
        }
        guard (ropeHook.isEmpty || ropeHook.count == 32), (arrow.isEmpty || arrow.count == 32), (stone.isEmpty || stone.count == 4), (spear.isEmpty || spear.count == 16), (plant.isEmpty || plant.count == 8), (scooper.isEmpty || scooper.count == 12), (fencer.isEmpty || fencer.count == 2),
              (clubBasher.isEmpty || clubBasher.count == 14), (laser.isEmpty || laser.count == 1),
              (flame.isEmpty || flame.count == 2) else {
            throw SequelDataError.invalid("Invalid L2 tribe digging mask count.")
        }
        for frame in [digger, exploder, brick, platformer] + basher + miner + stacker + (stomper.map { [$0] } ?? []) + scooper + fencer + clubBasher + laser + flame + (blast.map { [$0] } ?? []) + plant + stone + spear + arrow + ropeHook + (twister.map { [$0] } ?? []) {
            guard frame.width > 0, frame.height > 0, frame.width <= 256, frame.height <= 256,
                  frame.pixels.count == frame.width * frame.height, frame.opaque.count == frame.pixels.count,
                  (-256...256).contains(frame.x), (-256...256).contains(frame.y) else {
                throw SequelDataError.invalid("Invalid L2 terrain mask dimensions.")
            }
        }
        self.digger = digger; self.basher = basher; self.miner = miner
        self.exploder = exploder; self.brick = brick
        self.stacker = stacker; self.platformer = platformer; self.stomper = stomper
        self.scooper = scooper; self.fencer = fencer; self.clubBasher = clubBasher
        self.laser = laser; self.flame = flame; self.blast = blast; self.plant = plant; self.twister = twister; self.stone = stone; self.spear = spear; self.arrow = arrow; self.ropeHook = ropeHook
    }
}
