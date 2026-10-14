import Foundation

/// The Macintosh 1994 release contains the 32 new levels followed by all 32
/// levels from 1993. LEVL records use the classic 2,048-byte layout.
public enum ClassicHolidayCampaign {
    public static func load(resourceFork: Data, title: ClassicTitle) throws -> ClassicCampaign {
        let firstID: Int
        let ranks: [String]
        switch title {
        case .holidayLemmings1993: firstID = 32; ranks = ["Flurry", "Blizzard"]
        case .holidayLemmings1994: firstID = 0; ranks = ["Frost", "Hail"]
        default: throw SequelDataError.invalid("Not a retail Holiday campaign.")
        }
        let resources = ClassicResourceFork.resources(ofType: "LEVL", in: resourceFork)
        guard resources.count == 64, Set(resources.map(\.id)) == Set(0..<64),
              resources.allSatisfy({ $0.data.count == ClassicLevel.recordSize }) else {
            throw SequelDataError.invalid("Holiday Levels must contain all 64 original LEVL records.")
        }
        let byID = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0.data) })
        let levels = try (0..<32).map { position in
            let id = firstID + position
            let level = try ClassicLevel(data: byID[id]!)
            guard level.groundStyle == 2, level.specialStyle == 0 else {
                throw SequelDataError.invalid("Unexpected Holiday terrain style in LEVL \(id).")
            }
            return ClassicCampaignLevel(rank: ranks[position / 16], number: position % 16 + 1,
                archiveFile: id / 8, archiveSection: id % 8,
                usesOddTableProperties: false, level: level)
        }
        return ClassicCampaign(name: title.displayName, levels: levels)
    }
}
