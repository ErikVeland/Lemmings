import Foundation
import NxlvKit

/// Streams the shipped sequel media without constructing or advancing a game session.
public final class MobileOriginalMedia {
    public enum Item: Hashable, Sendable {
        case tribesIntroduction, tribesEnding, tribesGoldenEnding
        case chronicles(Lemmings3OriginalMovie)
        public var title: String {
            switch self {
            case .tribesIntroduction: L10n.text("Introduction")
            case .tribesEnding: L10n.text("Ending")
            case .tribesGoldenEnding: L10n.text("Gold ending")
            case .chronicles(let movie): movie.title
            }
        }
        public var needsContinue: Bool {
            switch self { case .tribesEnding, .tribesGoldenEnding: true; default: false }
        }
        public static func all(engine: String) -> [Self] {
            switch engine {
            case "lemmings2": [.tribesIntroduction, .tribesEnding, .tribesGoldenEnding]
            case "lemmings3": Lemmings3OriginalMovie.allCases.map(Self.chronicles)
            default: []
            }
        }
    }
    public let item: Item
    public private(set) var frame: MobilePixelFrame
    public private(set) var finished = false
    public private(set) var frameCount = 1
    public let soundBank: Lemmings2SoundBank?
    private var movie: FLICMovie?
    private var decoder: FLICMovie.Decoder?
    private var introduction: Lemmings2Introduction?
    private var ending: Lemmings2Ending?
    private var accumulator = 0.0
    private var sounds: [Lemmings2SoundRequest] = []
    public var frameDuration: Double {
        movie?.frameDuration ?? introduction?.animation.frameDuration ?? ending?.frameDuration ?? 1 / 30
    }
    public init(item: Item, directory: URL) throws {
        self.item = item
        switch item {
        case .chronicles(let choice):
            let source = try FLICMovie(contentsOf: directory.appendingPathComponent("MOVIE/" + choice.rawValue))
            guard source.width > 0, source.height > 0, source.width <= 1920, source.height <= 1080,
                  source.frameCount > 0, source.frameOffsets.count >= source.frameCount else { throw MobileSessionError.invalidFrame }
            var reader = source.makeDecoder()
            guard let first = try reader.nextFrame() else { throw MobileSessionError.invalidFrame }
            frame = try .init(width: first.width, height: first.height, rgba: Data(first.rgbaBytes()))
            movie = source; decoder = reader; soundBank = nil
        default:
            soundBank = (try? Data(contentsOf: directory.appendingPathComponent("MUSIC/SBLAST.VOC")))
                .flatMap { try? Lemmings2SoundBank(data: $0) }
            if item == .tribesIntroduction {
                let font = try Lemmings2FrontEndFont(data: Data(contentsOf: directory.appendingPathComponent("FONT.DAT")))
                let intro = try Lemmings2Introduction(root: directory, font: font)
                introduction = intro
                frame = try Self.indexed(intro.animation.pixels, palette: intro.animation.palette)
            } else {
                let result = try Lemmings2Ending(root: directory, assets: Lemmings2FrontEnd(root: directory), golden: item == .tribesGoldenEnding)
                ending = result
                frame = try Self.indexed(result.pixels, palette: result.palette)
            }
        }
    }
    private static func indexed(_ pixels: [UInt8], palette: [UInt8]) throws -> MobilePixelFrame {
        try .init(width: 320, height: 200, rgba: Data(MobileIndexedTerrainCache.expand(pixels, palette: palette)))
    }
    public func requestContinue() { ending?.requestContinue() }
    public func discardElapsedTime() { accumulator = 0 }
    public func drainSounds() -> [Lemmings2SoundRequest] { defer { sounds.removeAll(keepingCapacity: true) }; return sounds }
    public func advance(seconds: Double) throws {
        guard !finished, seconds.isFinite, seconds > 0 else { return }
        accumulator += min(seconds, 0.25)
        while accumulator >= frameDuration, !finished {
            accumulator -= frameDuration
            if let movie {
                guard frameCount < movie.frameCount else { finished = true; break }
                guard let next = try decoder?.nextFrame() else { throw MobileSessionError.invalidFrame }
                frame = try .init(width: next.width, height: next.height, rgba: Data(next.rgbaBytes()))
            } else if var intro = introduction {
                try intro.step(); introduction = intro; finished = intro.isComplete
                frame = try Self.indexed(intro.animation.pixels, palette: intro.animation.palette)
                sounds += intro.animation.soundSamples.compactMap(Lemmings2SoundRequest.introduction)
            } else if var result = ending {
                try result.step(); ending = result; finished = result.isComplete
                frame = try Self.indexed(result.pixels, palette: result.palette)
                sounds += result.animation.soundSamples.compactMap(Lemmings2SoundRequest.introduction)
            }
            frameCount += 1
        }
    }
}
