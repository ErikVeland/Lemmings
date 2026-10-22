import CoreGraphics
import Foundation
import LemmingsMobileCore
import NxlvKit

/**
 * The app and widgets draw the same terrain clock from the shipped Macintosh frames.
 */
public final class GameDeskClockArt {
    public static let sceneSize = CGSize(width: 208, height: 149)
    private let artwork: ClassicMacArtwork
    private let typography: GameMenuTypography
    private var images: [String: CGImage] = [:]
    private var digitTile: CGImage?

    public init?(directory: URL) {
        guard let artwork = try? ClassicMacArtwork(directory: directory),
              let interface = ClassicMacUserInterface(artwork: artwork),
              artwork.frame(1500, 10) != nil, artwork.frame(1600, 16) != nil else { return nil }
        self.artwork = artwork
        typography = GameMenuTypography(interface: interface)
    }

    public func draw(_ simulation: DeskClockSimulation, event: DeskClockEvent?, now: Date,
                     in context: CGContext, rect: CGRect, nightDim: Bool = true) {
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(rect)
        let fit = min(rect.width / 416, rect.height / 298)
        let scale = fit >= 1 ? floor(fit * 2) / 2 : fit
        context.translateBy(x: floor(rect.midX - 208 * scale), y: floor(rect.midY - 149 * scale))
        context.scaleBy(x: scale, y: scale)
        context.interpolationQuality = .none
        context.setShouldAntialias(false)

        for x in stride(from: 0, to: 416, by: 144) {
            draw(1500, 3, at: CGPoint(x: x, y: 256), context: context)
        }
        for (index, x) in [6, 58, 238, 302, 340].enumerated() {
            draw(1500, index == 0 ? 9 : 35 + index, at: CGPoint(x: x, y: 242), context: context)
        }
        if let tile = terrainTile() {
            for digit in 0..<4 {
                for row in 0..<7 { for column in 0..<5 where simulation.blocks[digit][row][column] {
                    GameStoneArt.drawImage(tile, in: CGRect(x: (DeskClockSimulation.digitX[digit] + column * 5) * 2,
                        y: (32 + row * 5) * 2, width: 10, height: 10), context: context)
                } }
            }
            for y in [84, 104] {
                GameStoneArt.drawImage(tile, in: CGRect(x: 202, y: y, width: 10, height: 10), context: context)
            }
        }
        let hatchAge = max(0, now.timeIntervalSince(simulation.hatchOpenedAt))
        let hatchFrame = hatchAge < 0.9 ? min(9, 1 + Int(hatchAge * 10)) : 0
        draw(1600, hatchFrame, at: CGPoint(x: 82, y: 0), context: context)
        draw(1600, 16, at: CGPoint(x: 346, y: 222), context: context)
        draw(1600, 10 + Int(now.timeIntervalSince1970 * 8) % 6, at: CGPoint(x: 341, y: 210), context: context)
        for lemming in simulation.lemmings {
            let pose: ClassicLemmingPose
            let offset: Int
            var tick = lemming.tick
            if let umbrella = lemming.umbrellaTick {
                pose = umbrella < 4 ? .umbrellaOpening : .floating
                tick = umbrella < 4 ? umbrella : umbrella - 4
                offset = -16
            } else {
                switch lemming.state {
                case .walk: pose = .walking; offset = -10
                case .fall: pose = .falling; offset = -10
                case .descend: pose = .floating; offset = -16
                case .block: pose = .blocking; offset = -10
                case .exit: pose = .exiting; offset = -10
                case .dig: pose = .digging; offset = -12
                case .build: pose = .building; offset = -13
                case .ohNo: pose = .ohNo; offset = -10
                }
            }
            let index = ClassicMacArtwork.lemmingFrameIndex(pose: pose, left: lemming.facingLeft, tick: tick)
            if let frame = artwork.frame(1400, index) {
                draw(1400, index, at: CGPoint(x: (lemming.x - 8) * 2 + frame.x,
                    y: (lemming.y + offset) * 2 + frame.y), context: context)
            }
            if let fuse = lemming.fuse {
                let count = max(1, min(5, Int(ceil(fuse.timeIntervalSince(now)))))
                text(String(count), in: CGRect(x: lemming.x * 2 - 12, y: lemming.y * 2 - 44, width: 24, height: 20), context: context)
            }
        }
        for blast in simulation.blasts {
            draw(1400, 75, at: CGPoint(x: blast.x * 2 - 32, y: blast.y * 2 - 28), context: context)
        }
        if let event, DeskClockFace.phase(event: event, now: now) != .calm || event.start > now {
            text(L10n.text("NEXT") + " " + event.start.formatted(date: .omitted, time: .shortened),
                in: CGRect(x: 12, y: 148, width: 392, height: 22), context: context)
            let title = GameTextLayout.truncated(event.title, width: 392, font: typography.font(.large), preservesCase: true)
            text(title, in: CGRect(x: 12, y: 175, width: 392, height: 26), face: .large, context: context)
            let blink = simulation.phase != .soon || Int(now.timeIntervalSince1970 * 2) % 2 == 0
            if blink { text(DeskClockFace.countdown(to: event.start, now: now),
                in: CGRect(x: 12, y: 207, width: 310, height: 22), context: context) }
        }
        text(L10n.text("OUT \(simulation.lemmings.count)") + "  " + L10n.text("IN \(simulation.saved)") + "  "
            + now.formatted(.dateTime.day().month(.abbreviated)),
            in: CGRect(x: 8, y: 274, width: 400, height: 20), context: context)
        if nightDim && DeskClockFace.isNight(now, calendar: .current) {
            context.setFillColor(CGColor(gray: 0, alpha: 0.5))
            context.fill(CGRect(x: 0, y: 0, width: 416, height: 298))
        }
    }

    /**
     * Small widgets keep full-size bitmap labels beneath enlarged terrain digits.
     */
    public func drawWidget(_ simulation: DeskClockSimulation, event: DeskClockEvent?, now: Date,
                           in context: CGContext, rect: CGRect, compact: Bool) {
        guard compact else {
            draw(simulation, event: event, now: now, in: context, rect: rect, nightDim: false)
            return
        }
        guard let source = CGContext(data: nil, width: 416, height: 298, bitsPerComponent: 8,
            bytesPerRow: 416 * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        source.translateBy(x: 0, y: 298); source.scaleBy(x: 1, y: -1)
        draw(simulation, event: nil, now: now, in: source, rect: CGRect(x: 0, y: 0, width: 416, height: 298), nightDim: false)
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect)
        context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(rect)
        let width = max(1, rect.width - 16)
        if let digits = source.makeImage()?.cropping(to: CGRect(x: 80, y: 62, width: 256, height: 76)) {
            GameStoneArt.drawImage(digits, in: CGRect(x: rect.minX + 8, y: rect.minY + 12,
                width: width, height: width * 76 / 256), context: context)
        }
        let title = event?.title ?? now.formatted(.dateTime.day().month(.abbreviated))
        let fitted = GameTextLayout.truncated(title, width: width, font: typography.font(.small), preservesCase: true)
        text(fitted, in: CGRect(x: rect.minX + 8, y: rect.midY - 12, width: width, height: 22), context: context)
        if let event {
            let remaining = DeskClockFace.countdown(to: event.start, now: now, compact: true)
            let fitted = GameTextLayout.truncated(remaining, width: width, font: typography.font(.small))
            text(fitted, in: CGRect(x: rect.minX + 8, y: rect.midY + 12, width: width, height: 22), context: context)
        }
        context.translateBy(x: rect.minX + 8, y: rect.maxY - 42)
        context.scaleBy(x: 0.5, y: 0.5)
        for x in stride(from: 0, to: Int(width * 2), by: 144) {
            draw(1500, 3, at: CGPoint(x: x, y: 54), context: context)
        }
        draw(1600, 0, at: CGPoint(x: 0, y: 0), context: context)
        draw(1400, simulation.lemmings.first?.state == .ohNo ? 337 : 0,
             at: CGPoint(x: Int(width), y: 36), context: context)
        draw(1600, 16, at: CGPoint(x: width * 2 - 54, y: 20), context: context)
    }

    private func terrainTile() -> CGImage? {
        if let digitTile { return digitTile }
        guard let frame = artwork.frame(1500, 10), let image = image(1500, 10) else { return nil }
        let bytes = [UInt8](frame.rgba)
        for y in stride(from: 0, through: frame.height - 10, by: 2) {
            for x in stride(from: 0, through: frame.width - 10, by: 2) {
                let opaque = (y..<y + 10).allSatisfy { row in
                    (x..<x + 10).allSatisfy { column in bytes[(row * frame.width + column) * 4 + 3] == 255 }
                }
                if opaque {
                    digitTile = image.cropping(to: CGRect(x: x, y: y, width: 10, height: 10))
                    return digitTile
                }
            }
        }
        return nil
    }

    private func text(_ value: String, in rect: CGRect, face: GameMenuTypography.Face = .small, context: CGContext) {
        typography.menuLine(value, in: rect, context: context, face: face, preservesCase: true)
    }

    private func draw(_ bank: Int, _ frame: Int, at point: CGPoint, context: CGContext) {
        guard let image = image(bank, frame) else { return }
        GameStoneArt.drawImage(image, in: CGRect(origin: point, size: CGSize(width: image.width, height: image.height)), context: context)
    }

    private func image(_ bank: Int, _ index: Int) -> CGImage? {
        let key = "\(bank)-\(index)"
        if let cached = images[key] { return cached }
        guard let frame = artwork.frame(bank, index), let provider = CGDataProvider(data: frame.rgba as CFData),
              let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        images[key] = image
        return image
    }
}
