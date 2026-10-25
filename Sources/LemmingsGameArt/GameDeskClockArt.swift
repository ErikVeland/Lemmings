import CoreGraphics
import Foundation
import LemmingsMobileCore
import NxlvKit

/// Draws one Desk Clock state with the shipped Macintosh artwork.
///
/// Scene positions are classic pixels on a 208 x 149 scene. Mac frames have two pixels per classic
/// pixel and draw at half size from their own origins. The context must have a top-left origin, as
/// UIKit and flipped bitmap contexts do. Decoded images are cached, so one instance serves every frame.
public final class GameDeskClockArt: @unchecked Sendable {
    public static let sceneSize = CGSize(width: 208, height: 149)

    /// Converts a known RGBA8 bitmap to red-only light without changing alpha.
    public static func applyRedNightVision(to data: UnsafeMutableRawPointer, width: Int, height: Int,
                                           bytesPerRow: Int) {
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let value = max(bytes[offset], bytes[offset + 1], bytes[offset + 2])
                bytes[offset] = UInt8(Double(value) * 0.65)
                bytes[offset + 1] = 0
                bytes[offset + 2] = 0
            }
        }
    }

    private static let hatch = CGPoint(x: 40, y: 1)
    private static let exit = CGPoint(x: 160, y: 111)
    private static let lightEdge = rgba(0xe08048)
    private static let darkEdge = rgba(0x5a1a0c)
    private static let green: UInt32 = 0x5ad04a
    private static let amber: UInt32 = 0xffb02e
    private static let white: UInt32 = 0xffffff
    private static let lemmingsBank = 1400, groundsBank = 1500, objectsBank = 1600

    private struct Sprite {
        let image: CGImage
        let frame: ClassicMacArtwork.Frame
    }
    private struct Key: Hashable {
        let source: String
        let tint: UInt32?
    }
    private enum Align { case left, center, right }

    private let artwork: ClassicMacArtwork
    private let small: ClassicMacUserInterface.Font
    private let large: ClassicMacUserInterface.Font
    /// An opaque 80 x 80 Mac-pixel tile cut from the rock piece, mirrored so that it repeats without seams.
    private let texture: [UInt8]
    private let rockTile: CGImage
    /// A wider opaque strip from the same Macintosh rock, mirrored at its edges.
    private let groundTile: CGImage
    private static let textureSize = 80

    private let lock = NSLock()
    private var sprites: [Key: Sprite?] = [:]
    private var terrain: (blocks: [[[Bool]]], image: CGImage)?
    private var dates: (calendar: Calendar, formatter: DateFormatter)?

    public init?(directory: URL) {
        guard let artwork = try? ClassicMacArtwork(directory: directory),
              let interface = ClassicMacUserInterface(artwork: artwork),
              let small = interface.font(.small), let large = interface.font(.large),
              let rock = artwork.frame(Self.groundsBank, 10),
              let texture = Self.tile(from: rock),
              let rockTile = Self.image(rgba: Data(texture), width: Self.textureSize, height: Self.textureSize),
              let ground = Self.wideGroundTile(from: rock),
              let groundTile = Self.image(rgba: Data(ground.rgba), width: ground.width, height: ground.height)
        else { return nil }
        self.artwork = artwork
        self.small = small
        self.large = large
        self.texture = texture
        self.rockTile = rockTile
        self.groundTile = groundTile
        let required = [(Self.lemmingsBank, 75), (Self.groundsBank, 3), (Self.objectsBank, 0), (Self.objectsBank, 16)]
        guard required.allSatisfy({ artwork.frame($0.0, $0.1) != nil }) else { return nil }
    }

    public func draw(_ sim: DeskClockSimulation, event: DeskClockEvent?, now: Date, time: TimeInterval,
                     in context: CGContext, rect: CGRect, nightDim: Bool) {
        lock.lock()
        defer { lock.unlock() }
        let size = Self.sceneSize
        let fit = min(rect.width / size.width, rect.height / size.height)
        guard fit > 0 else { return }
        let scale = fit >= 1 ? fit.rounded(.down) : fit
        let scene = CGRect(x: rect.minX + ((rect.width - size.width * scale) / 2).rounded(.down),
                           y: rect.minY + ((rect.height - size.height * scale) / 2).rounded(.down),
                           width: size.width * scale, height: size.height * scale)
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: scene)
        context.translateBy(x: scene.minX, y: scene.minY)
        context.scaleBy(x: scale, y: scale)
        context.interpolationQuality = .none

        drawSky(time: time, in: context)
        // Trapdoor: frames 1-9 open the doors, then frame 0 rests open.
        drawSprite(bank: Self.objectsBank, index: Self.hatchFrame(age: now.timeIntervalSince(sim.hatchOpenedAt)),
                   at: Self.hatch, in: context)
        if let event { drawEvent(event, sim: sim, now: now, time: time, in: context) }
        // Exit: the arch, with its animated top resting 6 px above on the arch's brackets.
        drawSprite(bank: Self.objectsBank, index: 16, at: Self.exit, in: context)
        let flame = 10 + Int((time * 10).rounded(.down)) % 6
        drawSprite(bank: Self.objectsBank, index: flame, at: CGPoint(x: Self.exit.x, y: Self.exit.y - 6), in: context)
        drawTerrain(sim, in: context)
        drawGrass(in: context)
        if Int(now.timeIntervalSince1970.rounded(.down)) % 2 != 0 {
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.55))
            for y in [10, 20] {
                context.fill(CGRect(x: DeskClockSimulation.colonX, y: DeskClockSimulation.digitTop + y,
                                    width: DeskClockSimulation.blockSize, height: DeskClockSimulation.blockSize))
            }
        }
        for lemming in sim.lemmings { drawLemming(lemming, in: context) }
        for lemming in sim.lemmings {
            guard let fuse = lemming.fuse, lemming.state != .ohNo else { continue }
            let count = Int(ceil(fuse.timeIntervalSince(now) - 1))
            if (1...5).contains(count) {
                text(String(count), x: CGFloat(lemming.x), y: CGFloat(lemming.y - 20), font: .small,
                     align: .center, tint: Self.white, in: context)
            }
        }
        for blast in sim.blasts where blast.until > now {
            drawSprite(bank: Self.lemmingsBank, index: 75, at: CGPoint(x: blast.x - 16, y: blast.y - 26), in: context)
        }
        // The panel line on the ground, in the game's own counter wording.
        let out = sim.lemmings.filter { ![.descend, .dig, .build].contains($0.state) }.count
        text(L10n.text("OUT \(out)"), x: 6, y: 136, font: .small, align: .left, tint: Self.green, in: context)
        text(L10n.text("IN \(sim.saved)"), x: 60, y: 136, font: .small, align: .left, tint: Self.green, in: context)
        text(dateLine(now, calendar: sim.calendar), x: 202, y: 136, font: .small, align: .right, tint: Self.green, in: context)
        if nightDim {
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// Reflows the clock scene to the widget bounds without stretching the artwork.
    public func drawWidget(_ simulation: DeskClockSimulation, event: DeskClockEvent?, now: Date,
                           in context: CGContext, rect: CGRect, compact: Bool) {
        drawAdaptive(simulation, event: event, now: now, time: 0, in: context, rect: rect,
                     compact: compact, animated: false, nightDim: false)
    }

    /// Reflows the animated scene across the display. Sky and ground reach every edge.
    public func drawFullScreen(_ simulation: DeskClockSimulation, event: DeskClockEvent?, now: Date,
                               time: TimeInterval, in context: CGContext, rect: CGRect, nightDim: Bool,
                               contentRect: CGRect? = nil) {
        drawAdaptive(simulation, event: event, now: now, time: time, in: context, rect: rect,
                     compact: false, animated: true, nightDim: nightDim, contentRect: contentRect)
    }

    private func drawAdaptive(_ simulation: DeskClockSimulation, event: DeskClockEvent?, now: Date,
                              time: TimeInterval, in context: CGContext, rect: CGRect,
                              compact: Bool, animated: Bool, nightDim: Bool, contentRect: CGRect? = nil) {
        guard rect.width > 0, rect.height > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect)
        context.translateBy(x: rect.minX, y: rect.minY)
        let fit = min(rect.width / Self.sceneSize.width, rect.height / Self.sceneSize.height)
        let unit = animated ? max(1, floor(fit)) : max(1, fit)
        context.scaleBy(x: unit, y: unit)
        context.interpolationQuality = .none
        let width = rect.width / unit, height = rect.height / unit
        let content = (contentRect ?? rect).intersection(rect)
        guard !content.isNull, content.width > 0, content.height > 0 else { return }
        let usable = CGRect(x: (content.minX - rect.minX) / unit, y: (content.minY - rect.minY) / unit,
                            width: content.width / unit, height: content.height / unit)
        // Keep the exit just above a local camera cutout, while letting the
        // playfield use the lower part of the unobstructed display.
        let ground = min(height - 16, usable.maxY - 10)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for star in Self.stars where sin((animated ? time * 1.3 : 0) + star.phase) > -0.2 {
            context.setFillColor(CGColor(gray: sin((animated ? time * 2 : 0) + star.phase) > 0.6 ? 1 : 0.4, alpha: 1))
            context.fill(CGRect(x: CGFloat(star.x) / 208 * width,
                                y: CGFloat(star.y) / 110 * ground, width: 0.5, height: 0.5))
        }

        let wide = width > height * 1.5
        let eventHeight: CGFloat = event == nil ? 0 : (wide ? 30 : 40)
        let digitFit = min((usable.width - 24) / 128, (ground - usable.minY - 22 - eventHeight) / 38)
        let digitScale = animated ? max(0.5, floor(digitFit * 2) / 2) : max(0.1, digitFit)
        let digitWidth = 128 * digitScale, digitHeight = 38 * digitScale
        let shift = animated ? DeskClockFace.burnInOffset(at: now) : (x: 0, y: 0)
        let digitX = usable.midX - digitWidth / 2 + CGFloat(shift.x) / unit
        let digitY = usable.minY + 22 + max(0, ground - usable.minY - 22 - eventHeight - digitHeight) * 0.35
            + CGFloat(shift.y) / unit
        if terrain?.blocks != simulation.blocks, let image = terrainImage(simulation) {
            terrain = (simulation.blocks, image)
        }
        if let digits = terrain?.image.cropping(to: CGRect(x: 80, y: 62, width: 256, height: 76)) {
            GameStoneArt.drawImage(digits, in: CGRect(x: digitX, y: digitY, width: digitWidth, height: digitHeight),
                                   context: context)
        }
        if animated, Int(now.timeIntervalSince1970.rounded(.down)) % 2 != 0 {
            context.setFillColor(CGColor(gray: 0, alpha: 0.55))
            for y in [10, 20] {
                context.fill(CGRect(x: digitX + CGFloat(DeskClockSimulation.colonX - 40) * digitScale,
                    y: digitY + CGFloat(y) * digitScale,
                    width: CGFloat(DeskClockSimulation.blockSize) * digitScale,
                    height: CGFloat(DeskClockSimulation.blockSize) * digitScale))
            }
        }
        drawSprite(bank: Self.objectsBank, index: Self.hatchFrame(age: now.timeIntervalSince(simulation.hatchOpenedAt)),
                   at: CGPoint(x: digitX, y: digitY - 22), in: context)
        if animated {
            for blast in simulation.blasts where blast.until > now {
                drawSprite(bank: Self.lemmingsBank, index: 75,
                    at: CGPoint(x: digitX + CGFloat(blast.x - 40) * digitScale - 16,
                                y: digitY + CGFloat(blast.y - 31) * digitScale - 26), in: context)
            }
        }
        for lemming in simulation.lemmings where lemming.y < 90 {
            context.saveGState()
            let point = Self.adaptiveLemmingPoint(x: lemming.x, y: lemming.y, digitX: digitX, digitY: digitY,
                digitScale: digitScale, ground: ground, exitX: usable.maxX - 23)
            context.translateBy(x: point.x - CGFloat(lemming.x), y: point.y - CGFloat(lemming.y))
            drawLemming(lemming, in: context)
            if animated, let fuse = lemming.fuse, lemming.state != .ohNo {
                let count = Int(ceil(fuse.timeIntervalSince(now) - 1))
                if (1...5).contains(count) {
                    text(String(count), x: CGFloat(lemming.x), y: CGFloat(lemming.y - 20), font: .small,
                         align: .center, tint: Self.white, in: context)
                }
            }
            context.restoreGState()
        }

        if let event {
            let cell = CGFloat(small.cellWidth) / 2
            let maximum = max(1, Int((usable.width - 24) / cell))
            func shortened(_ title: String, to count: Int) -> String {
                title.count > count ? String(title.prefix(max(0, count - 1))) + "." : title
            }
            let countdown = DeskClockFace.countdown(to: event.start, now: now, compact: true)
            let digits = Array(DeskClockFace.digits(for: event.start, uses24Hour: simulation.uses24Hour,
                                                   calendar: simulation.calendar))
            let clock = String(digits[0..<2]).trimmingCharacters(in: .whitespaces) + ":" + String(digits[2..<4])
            let heading = compact ? countdown : L10n.text("NEXT") + " " + clock + "  " + countdown
            let lineHeight: CGFloat = wide ? 8 : 24
            let y = digitY + digitHeight + max(4, (ground - 14 - digitY - digitHeight - lineHeight) / 2)
            if wide {
                let prefix = L10n.text("NEXT") + " " + clock + "  "
                let suffix = "  " + countdown
                let title = shortened(event.title, to: max(1, maximum - prefix.count - suffix.count))
                let x = usable.midX - CGFloat(prefix.count + title.count + suffix.count) * cell / 2
                text(prefix + title, x: x, y: y, font: .small, align: .left, tint: nil, in: context)
                text(suffix, x: x + CGFloat(prefix.count + title.count) * cell, y: y, font: .small,
                     align: .left, tint: simulation.phase == .soon ? Self.amber : Self.green, in: context)
            } else {
                text(shortened(event.title, to: maximum), x: usable.midX, y: y, font: .small,
                     align: .center, tint: nil, in: context)
                text(heading, x: usable.midX, y: y + 14, font: .small,
                     align: .center, tint: simulation.phase == .soon ? Self.amber : Self.green, in: context)
            }
        }

        // Use a broad, seamless piece of the Macintosh rock below the exit. The
        // small digit texture would repeat visibly across this long ground band.
        context.saveGState()
        context.clip(to: CGRect(x: 0, y: ground, width: width, height: height - ground))
        let groundWidth = CGFloat(groundTile.width) / 2
        let groundHeight = CGFloat(groundTile.height) / 2
        for y in stride(from: ground, to: height, by: groundHeight) {
            for x in stride(from: CGFloat(0), to: width, by: groundWidth) {
                GameStoneArt.drawImage(groundTile,
                    in: CGRect(x: x, y: y, width: groundWidth, height: groundHeight), context: context)
            }
        }
        context.restoreGState()
        for x in stride(from: CGFloat(-2), to: width, by: 70) {
            drawSprite(bank: Self.groundsBank, index: 3, at: CGPoint(x: x, y: ground - 1), in: context)
        }
        for tuft in Self.tufts {
            guard let grass = sprite(bank: Self.groundsBank, index: tuft.piece) else { continue }
            let x = CGFloat(tuft.x) / 208 * width
            guard x < width - 55, !wide || event == nil || grass.frame.height <= 24 else { continue }
            draw(grass, at: CGPoint(x: x, y: ground - CGFloat(grass.frame.height) / 2 + 1), in: context)
        }
        let exit = CGPoint(x: usable.maxX - 48, y: ground - 17)
        drawSprite(bank: Self.objectsBank, index: 16, at: exit, in: context)
        let flame = animated ? 10 + Int((time * 10).rounded(.down)) % 6 : 10
        drawSprite(bank: Self.objectsBank, index: flame, at: CGPoint(x: exit.x, y: exit.y - 6), in: context)
        for lemming in simulation.lemmings where lemming.y >= 90 {
            context.saveGState()
            let point = Self.adaptiveLemmingPoint(x: lemming.x, y: lemming.y, digitX: digitX, digitY: digitY,
                digitScale: digitScale, ground: ground, exitX: exit.x + 25)
            context.translateBy(x: point.x - CGFloat(lemming.x), y: point.y - CGFloat(lemming.y))
            drawLemming(lemming, in: context)
            if animated, let fuse = lemming.fuse, lemming.state != .ohNo {
                let count = Int(ceil(fuse.timeIntervalSince(now) - 1))
                if (1...5).contains(count) {
                    text(String(count), x: CGFloat(lemming.x), y: CGFloat(lemming.y - 20), font: .small,
                         align: .center, tint: Self.white, in: context)
                }
            }
            context.restoreGState()
        }
        let footerY = ground + 3
        if compact {
            text(dateLine(now, calendar: simulation.calendar), x: usable.midX, y: footerY,
                 font: .small, align: .center, tint: Self.green, in: context)
        } else {
            let out = simulation.lemmings.filter { ![.descend, .dig, .build].contains($0.state) }.count
            text(L10n.text("OUT \(out)"), x: usable.minX + 12, y: footerY, font: .small, align: .left, tint: Self.green, in: context)
            text(L10n.text("IN \(simulation.saved)"), x: usable.minX + 60, y: footerY, font: .small, align: .left,
                 tint: Self.green, in: context)
            text(dateLine(now, calendar: simulation.calendar), x: usable.maxX - 12, y: footerY,
                 font: .small, align: .right, tint: Self.green, in: context)
        }
        if nightDim {
            context.setFillColor(CGColor(gray: 0, alpha: 0.6))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// One horizontal world position maps to one screen position at every height. Falling
    /// must never slide a lemming sideways toward a different, decorative exit.
    static func adaptiveLemmingPoint(x sourceX: Int, y sourceY: Int, digitX: CGFloat, digitY: CGFloat,
                                     digitScale: CGFloat, ground: CGFloat, exitX: CGFloat) -> CGPoint {
        let digitBottom = CGFloat(DeskClockSimulation.digitTop + 7 * DeskClockSimulation.blockSize)
        let groundRow = CGFloat(DeskClockSimulation.groundY)
        let y = CGFloat(sourceY)
        let progress = max(0, min(1, (y - digitBottom) / (groundRow - digitBottom)))
        let digitRight = digitX + 128 * digitScale
        let source = CGFloat(sourceX)
        let x: CGFloat
        if source < 40 {
            x = source * digitX / 40
        } else if source <= 168 {
            x = digitX + (source - 40) * digitScale
        } else {
            x = digitRight + (source - 168) * (exitX - digitRight) / CGFloat(DeskClockSimulation.exitX - 168)
        }
        let digitBottomY = digitY + (digitBottom - 31) * digitScale
        let projectedY: CGFloat
        if y <= digitBottom {
            projectedY = digitY + (y - 31) * digitScale
        } else if y < groundRow {
            projectedY = digitBottomY + (ground - digitBottomY) * progress
        } else {
            projectedY = ground + y - groundRow
        }
        return CGPoint(x: x, y: projectedY)
    }

    // MARK: - Scene parts

    /// Trapdoor frames 1-9 at 10 fps from the moment it opens, then frame 0 resting open.
    static func hatchFrame(age: TimeInterval) -> Int {
        let opening = 1 + Int((max(0, age) * 10).rounded(.down))
        return opening > 9 ? 0 : opening
    }

    private static let stars: [(x: Int, y: Int, phase: Double)] = {
        var random = PrototypeRandom()
        return (0..<40).map { _ in
            let x = Int(random.next() * 208), y = Int(random.next() * 110)
            return (x, y, random.next() * 6)
        }
    }()
    private static let tufts: [(piece: Int, x: Int)] = {
        var random = PrototypeRandom()
        for _ in 0..<(40 * 3) { _ = random.next() }
        return [9, 37, 36, 39, 9, 38, 36, 9].enumerated().map { index, piece in
            (piece, 2 + index * 26 + Int(random.next() * 10))
        }
    }()

    private func drawSky(time: TimeInterval, in context: CGContext) {
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: Self.sceneSize))
        for star in Self.stars where sin(time * 1.3 + star.phase) > -0.2 {
            let bright = sin(time * 2 + star.phase) > 0.6
            context.setFillColor(bright ? CGColor(red: 1, green: 1, blue: 1, alpha: 1)
                : CGColor(red: 0x50 / 255, green: 0x60 / 255, blue: 0xa0 / 255, alpha: 1))
            context.fill(CGRect(x: CGFloat(star.x), y: CGFloat(star.y), width: 0.5, height: 0.5))
        }
    }

    private func drawEvent(_ event: DeskClockEvent, sim: DeskClockSimulation, now: Date, time: TimeInterval,
                           in context: CGContext) {
        let middle = Self.sceneSize.width / 2
        let digits = Array(DeskClockFace.digits(for: event.start, uses24Hour: sim.uses24Hour, calendar: sim.calendar))
        let clock = String(digits[0..<2]).trimmingCharacters(in: .whitespaces) + ":" + String(digits[2..<4])
        text(L10n.text("NEXT") + "  " + clock, x: middle, y: 74, font: .small, align: .center, tint: nil, in: context)
        let title = event.title.count > 24 ? String(event.title.prefix(23)) + "." : event.title
        text(title, x: middle, y: 84, font: .large, align: .center, tint: nil, in: context)
        let soon = sim.phase == .soon
        guard !soon || Int((time * 2).rounded(.down)) % 2 == 0 else { return }
        let tint: UInt32? = sim.phase == .start ? Self.green : soon ? Self.amber : nil
        text(DeskClockFace.countdown(to: event.start, now: now), x: middle, y: 97, font: .small,
             align: .center, tint: tint, in: context)
    }

    /// The solid mask filled with rock, rimmed like the prototype, then the ground slabs over it.
    private func drawTerrain(_ sim: DeskClockSimulation, in context: CGContext) {
        if terrain?.blocks != sim.blocks, let image = terrainImage(sim) {
            terrain = (sim.blocks, image)
        }
        if let image = terrain?.image {
            GameStoneArt.drawImage(image, in: CGRect(origin: .zero, size: Self.sceneSize), context: context)
        }
        // The ground is the flat slab laid three times, the middle one mirrored, as a level designer would.
        guard let slab = sprite(bank: Self.groundsBank, index: 3) else { return }
        for index in 0..<3 {
            let x = CGFloat(-2 + index * 70), y = CGFloat(DeskClockSimulation.groundY - 1)
            context.saveGState()
            if index % 2 == 1 {
                let centre = x + CGFloat(slab.frame.x) / 2 + CGFloat(slab.frame.width) / 4
                context.translateBy(x: 2 * centre, y: 0)
                context.scaleBy(x: -1, y: 1)
            }
            draw(slab, at: CGPoint(x: x, y: y), in: context)
            context.restoreGState()
        }
    }

    private func terrainImage(_ sim: DeskClockSimulation) -> CGImage? {
        let width = DeskClockSimulation.width, height = DeskClockSimulation.height
        let groundY = DeskClockSimulation.groundY
        let solid = (0..<height).map { y in (0..<width).map { x in sim.isSolid(x: x, y: y) } }
        func isSolid(_ x: Int, _ y: Int) -> Bool { x >= 0 && x < width && y >= 0 && y < height && solid[y][x] }
        let macWidth = width * 2, macHeight = height * 2, tile = Self.textureSize
        var pixels = [UInt8](repeating: 0, count: macWidth * macHeight * 4)
        for macY in 0..<macHeight {
            let y = macY / 2
            for macX in 0..<macWidth {
                let x = macX / 2
                guard solid[y][x] else { continue }
                var edge: [UInt8]?
                if y < groundY {
                    if macY % 2 == 0 && !isSolid(x, y - 1) { edge = Self.lightEdge }
                    if macY % 2 == 1 && !isSolid(x, y + 1) { edge = Self.darkEdge }
                    if macX % 2 == 1 && !isSolid(x + 1, y) { edge = Self.darkEdge }
                }
                let offset = (macY * macWidth + macX) * 4
                let source = ((macY % tile) * tile + macX % tile) * 4
                for channel in 0..<4 { pixels[offset + channel] = edge?[channel] ?? texture[source + channel] }
            }
        }
        return Self.image(rgba: Data(pixels), width: macWidth, height: macHeight)
    }

    private func drawGrass(in context: CGContext) {
        for tuft in Self.tufts {
            guard let grass = sprite(bank: Self.groundsBank, index: tuft.piece) else { continue }
            // No grass across the exit.
            let x = CGFloat(tuft.x)
            if x + CGFloat(grass.frame.width) / 2 > Self.exit.x + 8 && x < Self.exit.x + 42 { continue }
            draw(grass, at: CGPoint(x: x, y: CGFloat(DeskClockSimulation.groundY) - CGFloat(grass.frame.height) / 2 + 1),
                 in: context)
        }
    }

    private func drawLemming(_ lemming: DeskClockLemming, in context: CGContext) {
        let pose: ClassicLemmingPose, tick: Int, footOffset: Int
        var y = lemming.y
        switch lemming.state {
        case .walk: (pose, tick, footOffset) = (.walking, lemming.tick, -10)
        case .fall:
            if let umbrella = lemming.umbrellaTick {
                (pose, tick, footOffset) = (umbrella < 4 ? .umbrellaOpening : .floating, umbrella, -16)
            } else {
                (pose, tick, footOffset) = (.falling, lemming.tick, -10)
            }
        case .descend: (pose, tick, footOffset) = (.floating, lemming.tick, -16)
        case .block: (pose, tick, footOffset) = (.blocking, lemming.tick, -10)
        case .exit: (pose, tick, footOffset) = (.exiting, min(7, lemming.tick), -13)
        case .dig:
            (pose, tick, footOffset) = (.digging, lemming.tick, -12)
            y += 2
        case .build: (pose, tick, footOffset) = (.building, lemming.tick, -13)
        case .ohNo: (pose, tick, footOffset) = (.ohNo, min(15, lemming.tick), -10)
        }
        let left = lemming.facingLeft && ![.block, .exit, .ohNo].contains(lemming.state)
        let index = ClassicMacArtwork.lemmingFrameIndex(pose: pose, left: left, tick: tick)
        drawSprite(bank: Self.lemmingsBank, index: index,
                   at: CGPoint(x: lemming.x - 8, y: y + footOffset), in: context)
    }

    private func dateLine(_ now: Date, calendar: Calendar) -> String {
        if dates?.calendar != calendar {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = calendar.locale ?? .current
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "EEE d MMM"
            dates = (calendar, formatter)
        }
        guard let formatter = dates?.formatter else { return "" }
        return formatter.string(from: now).uppercased(with: formatter.locale)
    }

    // MARK: - Sprites and text

    /// Monospaced Mac text. Cells are half the font's Mac cell, so Charset1 is 6 classic px and Charset2 is 8.
    private func text(_ string: String, x: CGFloat, y: CGFloat, font face: ClassicMacUserInterface.Face, align: Align,
                      tint: UInt32?, in context: CGContext) {
        let font = face == .small ? small : large
        let cell = CGFloat(font.cellWidth) / 2
        let width = CGFloat(string.count) * cell
        var pen: CGFloat
        switch align {
        case .left: pen = x
        case .center: pen = (x - width / 2).rounded()
        case .right: pen = x - width
        }
        for character in string {
            let glyph = font.glyph(for: character) ?? (character == " " ? nil : font.glyph(for: "?"))
            if let glyph, let sprite = cached(Key(source: "\(face.rawValue):\(character)", tint: tint), frame: glyph) {
                draw(sprite, at: CGPoint(x: pen, y: y), in: context)
            }
            pen += cell
        }
    }

    private func drawSprite(bank: Int, index: Int, at point: CGPoint, in context: CGContext) {
        if let sprite = sprite(bank: bank, index: index) { draw(sprite, at: point, in: context) }
    }

    private func draw(_ sprite: Sprite, at point: CGPoint, in context: CGContext) {
        let frame = sprite.frame
        GameStoneArt.drawImage(sprite.image, in: CGRect(x: point.x + CGFloat(frame.x) / 2, y: point.y + CGFloat(frame.y) / 2,
                                                        width: CGFloat(frame.width) / 2, height: CGFloat(frame.height) / 2),
                               context: context)
    }

    private func sprite(bank: Int, index: Int) -> Sprite? {
        guard let frame = artwork.frame(bank, index) else { return nil }
        return cached(Key(source: "\(bank):\(index)", tint: nil), frame: frame)
    }

    private func cached(_ key: Key, frame: ClassicMacArtwork.Frame) -> Sprite? {
        if let sprite = sprites[key] { return sprite }
        var image = Self.image(rgba: frame.rgba, width: frame.width, height: frame.height)
        if let tint = key.tint, let plain = image { image = Self.tinted(plain, colour: tint) }
        let sprite = image.map { Sprite(image: $0, frame: frame) }
        sprites[key] = sprite
        return sprite
    }

    // MARK: - Pixels

    private static func image(rgba: Data, width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: rgba as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// The colour laid over the glyph's own pixels at 70%, as the prototype's source-atop fill does.
    private static func tinted(_ image: CGImage, colour: UInt32) -> CGImage? {
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.draw(image, in: bounds)
        context.setBlendMode(.sourceAtop)
        context.setAlpha(0.7)
        let channel = { (shift: UInt32) in CGFloat((colour >> shift) & 0xff) / 255 }
        context.setFillColor(CGColor(red: channel(16), green: channel(8), blue: channel(0), alpha: 1))
        context.fill(bounds)
        return context.makeImage()
    }

    private static func rgba(_ colour: UInt32) -> [UInt8] {
        [UInt8((colour >> 16) & 0xff), UInt8((colour >> 8) & 0xff), UInt8(colour & 0xff), 255]
    }

    /// Take the widest fully opaque 44-pixel-high part of the original rock.
    /// Mirroring gives both seams matching pixels without repeating a small motif.
    private static func wideGroundTile(from rock: ClassicMacArtwork.Frame) -> (rgba: [UInt8], width: Int, height: Int)? {
        let sourceWidth = rock.width, sourceHeight = rock.height, stripHeight = 44
        guard sourceHeight >= stripHeight else { return nil }
        let source = [UInt8](rock.rgba)
        var best = (width: 0, x: 0, y: 0)
        for top in 0...(sourceHeight - stripHeight) {
            var start = 0
            for x in 0...sourceWidth {
                let opaque = x < sourceWidth && (top..<(top + stripHeight)).allSatisfy {
                    source[($0 * sourceWidth + x) * 4 + 3] == 255
                }
                if opaque { continue }
                if x - start > best.width { best = (x - start, start, top) }
                start = x + 1
            }
        }
        guard best.width >= 80 else { return nil }
        let width = best.width * 2, height = stripHeight * 2
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            let sourceY = best.y + (y < stripHeight ? y : height - 1 - y)
            for x in 0..<width {
                let sourceX = best.x + (x < best.width ? x : width - 1 - x)
                let from = (sourceY * sourceWidth + sourceX) * 4
                let to = (y * width + x) * 4
                pixels[to..<(to + 4)] = source[from..<(from + 4)]
            }
        }
        return (pixels, width, height)
    }

    /// The first fully opaque 40 x 40 square of the rock, mirrored 2 x 2 into an 80 x 80 tile.
    private static func tile(from rock: ClassicMacArtwork.Frame) -> [UInt8]? {
        let side = textureSize / 2, width = rock.width, height = rock.height
        let bytes = [UInt8](rock.rgba)
        // Summed counts of transparent pixels, so each square is checked in constant time.
        var holes = [Int](repeating: 0, count: (width + 1) * (height + 1))
        for y in 0..<height {
            for x in 0..<width {
                let hole = bytes[(y * width + x) * 4 + 3] == 0 ? 1 : 0
                holes[(y + 1) * (width + 1) + x + 1] = hole + holes[y * (width + 1) + x + 1]
                    + holes[(y + 1) * (width + 1) + x] - holes[y * (width + 1) + x]
            }
        }
        func empty(_ x: Int, _ y: Int) -> Bool {
            holes[(y + side) * (width + 1) + x + side] - holes[y * (width + 1) + x + side]
                - holes[(y + side) * (width + 1) + x] + holes[y * (width + 1) + x] == 0
        }
        guard width > side, height > side,
              let origin = (0..<(height - side)).lazy.flatMap({ y in (0..<(width - side)).lazy.map { (x: $0, y: y) } })
                .first(where: { empty($0.x, $0.y) }) else { return nil }
        var tile = [UInt8](repeating: 0, count: textureSize * textureSize * 4)
        for y in 0..<textureSize {
            for x in 0..<textureSize {
                let sourceX = x < side ? x : 2 * side - 1 - x, sourceY = y < side ? y : 2 * side - 1 - y
                let source = ((origin.y + sourceY) * width + origin.x + sourceX) * 4
                tile.replaceSubrange((y * textureSize + x) * 4..<(y * textureSize + x) * 4 + 4,
                                     with: bytes[source..<source + 4])
            }
        }
        return tile
    }
}

/// The prototype's Park-Miller generator with seed 7, so the stars and grass sit where the owner approved them.
private struct PrototypeRandom {
    private var state: Int64 = 7

    mutating func next() -> Double {
        state = (state * 16807) % 2_147_483_647
        return Double(state) / 2_147_483_647
    }
}
