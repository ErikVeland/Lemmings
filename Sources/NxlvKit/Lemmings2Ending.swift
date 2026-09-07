import Foundation

/// Original ending scripts and artwork. Each click advances the current caption.
public struct Lemmings2Ending {
    private let scripts: [Data]
    private let backgrounds: [[UInt8]]
    private let bank: Lemmings2FrontEnd.Bank
    private let font: Lemmings2FrontEndFont
    public let ark: Lemmings2Ark?
    public private(set) var arkFrame = 0
    public private(set) var page = 0
    public var isShowingArk: Bool { ark != nil && arkFrame < 118 }
    public var frameDuration: Double { isShowingArk ? Lemmings2Ark.frameDuration : animation.frameDuration }
    public var pixels: [UInt8] { isShowingArk ? ark!.frames[min(99,arkFrame)] : animation.pixels }
    public var palette: [UInt8] { isShowingArk ? ark!.palette : animation.palette }
    public private(set) var animation: Lemmings2GAL
    public private(set) var isComplete = false

    public init(root: URL, assets: Lemmings2FrontEnd, golden: Bool) throws {
        ark = golden ? try Lemmings2Ark(data:Data(contentsOf:root.appendingPathComponent("ARK.ANM"))) : nil
        let names = golden ? (1...5).map { "END\($0)" } : ["TOUGH"]
        scripts = try names.map { try Data(contentsOf:root.appendingPathComponent("FRONTEND/SCRIPTS/\($0).GAL")) }
        backgrounds = names.map { assets.pictures[$0] ?? assets.pictures["ROCKWALL"]! }
        bank = assets.banks[golden ? "END" : "TOUGH"]!
        font = assets.font
        animation = try .init(script:scripts[0],bank:bank,background:backgrounds[0],font:font)
    }
    public mutating func requestContinue() {
        if !isShowingArk { animation.requestContinue() }
    }
    public mutating func step() throws {
        guard !isComplete else { return }
        if isShowingArk { arkFrame += 1; return }
        if animation.isComplete {
            page += 1
            guard page < scripts.count else { isComplete = true; return }
            animation = try .init(script:scripts[page],bank:bank,background:backgrounds[page],font:font,initialPalette:animation.palette)
        }
        try animation.step()
    }
}
