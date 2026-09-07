import Foundation

/// Eight original scenes, in the order selected by L2 0785–0802.
public struct Lemmings2Introduction {
    public static let sceneNames = ["INTRO","WAKING","DAYVILL","TALISMAN","CATAST","MIDDLE","TALIS2","ENDSCENE"]
    private static let bankNames = ["INTRO","WAKING","TALISMAN","TALISMAN","TALISMAN","MIDDLE","TALISMAN","ENDSCENE"]
    private static let backgroundNames: [String?] = ["NIGHTVIL","COSYROOM","VILSCENE",nil,nil,"COSYROOM","BLACK","COSYROOM"]
    private let scripts: [Data]
    private let banks: [Lemmings2FrontEnd.Bank]
    private let backgrounds: [[UInt8]]
    private let font: Lemmings2FrontEndFont
    public private(set) var scene = 0
    public private(set) var animation: Lemmings2GAL
    public private(set) var isComplete = false

    public init(root: URL, font: Lemmings2FrontEndFont) throws {
        let intro = root.appendingPathComponent("INTRODAT")
        scripts = try Self.sceneNames.map { try Data(contentsOf:intro.appendingPathComponent("SCRIPTS/\($0).GAL")) }
        var loaded: [String:Lemmings2FrontEnd.Bank] = [:]
        for name in Set(Self.bankNames) {
            loaded[name] = try .init(data:Data(contentsOf:intro.appendingPathComponent("GFXIFFS/\(name).IFF")))
        }
        banks = Self.bankNames.map { loaded[$0]! }
        backgrounds = try Self.backgroundNames.map { name in
            guard let name else { return [UInt8](repeating:0,count:64000) }
            let data = try Data(contentsOf:intro.appendingPathComponent("BCKGRNDS/\(name).DAT"))
            return try Lemmings2FrontEnd.planar(Lemmings2Compression.decode(data),width:320,height:200)
        }
        self.font = font
        animation = try .init(script:scripts[0],bank:banks[0],background:backgrounds[0],font:font)
    }
    public mutating func step() throws {
        guard !isComplete else { return }
        if animation.isComplete {
            scene += 1
            guard scene < scripts.count else { isComplete = true; return }
            animation = try .init(script:scripts[scene],bank:banks[scene],background:backgrounds[scene],font:font)
        }
        try animation.step()
    }
}
