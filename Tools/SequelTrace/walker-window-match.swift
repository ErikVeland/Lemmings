import Foundation
import NxlvKit

/**
 * Compares a source RGB frame with native Beach 10 walker sprites in the same
 * displayed countdown second.
 */
struct ActorFrame {
    let id: Int
    let x: Int
    let y: Int
    let direction: Int
    let tick: Int
}

struct Match {
    let actor: ActorFrame
    let phase: Int
    let originX: Int
    let originY: Int
    let matchedPixels: Int
    let opaquePixels: Int

    var ratio: Double { Double(matchedPixels) / Double(max(1, opaquePixels)) }
}

do {
    guard CommandLine.arguments.count == 4,
          let displayedSeconds = Int(CommandLine.arguments[3]), displayedSeconds > 0 else {
        throw SequelDataError.invalid(
            "Usage: WalkerWindowMatch L2_PORTS_ROOT SOURCE_RGB24 DISPLAYED_SECONDS"
        )
    }

    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    let source = [UInt8](try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
    let frameWidth = 320
    let frameHeight = 200
    guard source.count == frameWidth * frameHeight * 3 else {
        throw SequelDataError.invalid("Source frame must be 320x200 RGB24.")
    }

    let level = try Lemmings2Level(
        data: Data(contentsOf: root.appendingPathComponent("LEVELS/LEVEL010.DAT"))
    )
    let styles = [
        "CLASSIC", "BEACH", "CAVEMAN", "CIRCUS", "EGYPTIAN", "HIGHLAND",
        "MEDIEVAL", "OUTDOOR", "POLAR", "SHADOW", "SPACE", "SPORTS"
    ]
    guard styles.indices.contains(level.style) else {
        throw SequelDataError.invalid("Beach 10 has an unknown tribe style.")
    }
    let style = try Lemmings2Style(
        data: Data(contentsOf: root.appendingPathComponent("STYLES/\(styles[level.style]).DAT"))
    )
    let masks = try Lemmings2TerrainMasks(root: root)
    let walker = try Lemmings2Walker(data: Data(contentsOf: root.appendingPathComponent("WALKER.DAT")))
    var game = try Lemmings2Runtime(level: level, style: style, masks: masks, total: 60)
    var frames: [ActorFrame] = []

    while game.remainingSeconds >= displayedSeconds, !game.isComplete {
        if game.remainingSeconds == displayedSeconds {
            frames.append(contentsOf: game.lemmings.compactMap { actor in
                guard actor.active, actor.state == .walking else { return nil }
                return ActorFrame(
                    id: actor.id,
                    x: actor.x,
                    y: actor.y,
                    direction: actor.direction,
                    tick: game.tick
                )
            })
        }
        game.step()
    }

    guard !frames.isEmpty else {
        throw SequelDataError.invalid("No native Beach 10 ticks use that displayed countdown.")
    }

    let matches = frames.map { actor -> Match in
        let phase = Lemmings2Walker.phase(x: actor.x, direction: actor.direction)
        let sprite = walker.frames[phase]
        let originX = actor.x - 2 + sprite.x
        let originY = actor.y - 10 + sprite.y
        var matched = 0
        var opaque = 0

        for pixel in sprite.pixels.indices where sprite.opaque[pixel] {
            opaque += 1
            let x = originX + pixel % sprite.width
            let y = originY + pixel / sprite.width
            guard x >= 0, x < frameWidth, y >= 0, y < frameHeight else { continue }

            let colour = Int(sprite.pixels[pixel]) * 4
            let offset = (y * frameWidth + x) * 3
            if (0..<3).allSatisfy({
                abs(Int(source[offset + $0]) - Int(style.palette[colour + $0])) <= 3
            }) {
                matched += 1
            }
        }

        return Match(
            actor: actor,
            phase: phase,
            originX: originX,
            originY: originY,
            matchedPixels: matched,
            opaquePixels: opaque
        )
    }

    print("level=\(level.title) style=\(styles[level.style]) displayedSeconds=\(displayedSeconds)")
    print("nativeTicks=\(Set(frames.map(\.tick)).sorted()) walkerAsset=WALKER.DAT")
    print("id,tick,direction,phase,drawOriginX,drawOriginY,matched,opaque,ratio")
    for match in matches.sorted(by: {
        $0.ratio == $1.ratio ? $0.matchedPixels > $1.matchedPixels : $0.ratio > $1.ratio
    }).prefix(20) {
        print("\(match.actor.id),\(match.actor.tick),\(match.actor.direction),\(match.phase),"
            + "\(match.originX),\(match.originY),\(match.matchedPixels),\(match.opaquePixels),"
            + "\(String(format: "%.3f", match.ratio))")
    }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
