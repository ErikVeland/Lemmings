import Foundation

/// Original talisman assembly, medal colours and award fanfare.
public struct Lemmings2Award {
    public private(set) var animation: Lemmings2GAL
    public init(root: URL, assets: Lemmings2FrontEnd, campaign: Lemmings2Campaign, newPiece: Bool) throws {
        var memory = Dictionary(uniqueKeysWithValues:(0..<12).map { ($0*2,campaign.tribeMedal($0).rawValue) })
        memory[24] = newPiece ? campaign.tribe : 65535
        memory[26] = campaign.tribeMedal(campaign.tribe).rawValue
        if newPiece { memory[campaign.tribe*2] = 0 }
        animation = try .init(script:Data(contentsOf:root.appendingPathComponent("FRONTEND/SCRIPTS/AWARD.GAL")),
            bank:assets.banks["AWARD"]!,background:assets.pictures["AWARD"]!,font:assets.font,initialMemory:memory)
    }
    public mutating func step() throws { try animation.step() }
}
