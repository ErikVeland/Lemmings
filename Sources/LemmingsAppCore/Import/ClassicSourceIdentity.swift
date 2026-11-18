import Foundation
import CryptoKit
import NxlvKit

/**
 * Links verified owned campaigns to the project's authored metadata.
 */
public enum ClassicSourceIdentity {
  public struct Alias: Equatable, Sendable {
    public let packID: String
    public let sourceRevision: String
  }

  private struct Reference {
    let campaign: String
    let simulationAssets: String
    let revision: String
  }

  /**
   * Hashes only. Revisions match Resources/Progression/learning.json.
   * Campaigns use the current decoder and complete authored rank order.
   * The two Holiday resources use the existing native Macintosh conversion.
   */
  private static let references: [String: Reference] = [
    "lemmings-LEVEL-120": Reference(
      campaign: "ee4bae181a1651a1744d722d3f26d726bfd13bee14b70c3dd7615760b51745b3",
      simulationAssets: "86a75a08de2052bcc1f10c6b4b033eaa9b53c2af92573a0240cf85b7880d5229",
      revision: "2e3e67e01c0e9d75a45354f53504d6f6c47a54da0e32b340ae0c08ba2bf247d7"),
    "ohNoMoreLemmings-DLVEL-100": Reference(
      campaign: "229f5487ab441e819ccf247ac05ca960aa87d1229a0ff30f4bb429037f82b2ba",
      simulationAssets: "eeb69ff64df5f24b4eb36ad40f0673fc2e9b3623dd5a573b33d07d9384c7a1e7",
      revision: "6dad75cd5148ba209afd886fd0c7e6dc4d6d3d92ea17eb05c98fbecc8778ac25"),
    "xmasLemmings1991-LEVEL-4": Reference(
      campaign: "22292d3464714f18da104a58e9eb5c70b7f484015f148abc08392c938b7efc03",
      simulationAssets: "4e2cfbab529002f8e69be2b273a7c0cd7584ec2404deae7d4446ad26647df809",
      revision: "b8bf363cf18f1d91186c626d8056bfc0aeaf1d1a8e789f83b2579958902089e8"),
    "xmasLemmings1992-LEVEL-4": Reference(
      campaign: "904eadac12711ed7aff2a524289e9f8131d9086f9335628dfea24cb3fe157f53",
      simulationAssets: "e61a20ad5d25e57e4df896ce6a183402487b6a769254522216e744f544d07247",
      revision: "62b793ae53f30cb131b2693f3383d550635425461187352fc7a500435284c7b7"),
    "holidayLemmings1993-MACLEVL-32": Reference(
      campaign: "5ccb7e85fe5484741ec5c7096bf7f5ad2f64cf6242dd3263146b221eaa89e009",
      simulationAssets: "e61a20ad5d25e57e4df896ce6a183402487b6a769254522216e744f544d07247",
      revision: "9b8270f81c049e91081141c6091a69a62cb8610a45c023152015d74876ada07e"),
    "holidayLemmings1994-MACLEVL-32": Reference(
      campaign: "ad67816eff19fece922fdf4ec532281c8497d84d20a5a804ce39eac67936bcf3",
      simulationAssets: "e61a20ad5d25e57e4df896ce6a183402487b6a769254522216e744f544d07247",
      revision: "e8253af9f5c99eebba38cb4a1211c3dfd0a8264dc22c94a13e6218fddbb65484"),
  ]

  /**
   * Restores metadata identity only after campaign and simulation bytes match.
   * Callers keep their current source fingerprint for load-time change checks.
   */
  public static func canonicalAlias(for dataSet: ClassicDataSet, directory: URL) -> Alias? {
    if dataSet.identifierKey == "ohYesMoreLemmings-OHYES-60" {
      return portExclusiveAlias(for: dataSet, directory: directory)
    }
    guard !Task.isCancelled, let reference = references[dataSet.identifierKey] else { return nil }
    do {
      guard try campaignFingerprint(dataSet.campaign) == reference.campaign else { return nil }
      let current = try ClassicDataSet.detect(directory: directory)
      guard current.identifierKey == dataSet.identifierKey,
        try campaignFingerprint(current.campaign) == reference.campaign,
        try simulationAssetsFingerprint(current, directory: directory) == reference.simulationAssets,
        !Task.isCancelled else { return nil }
      return Alias(packID: dataSet.identifierKey, sourceRevision: reference.revision)
    } catch { return nil }
  }

  /**
   * Checks the complete composite campaign and its stock sources before restoring metadata.
   */
  private static func portExclusiveAlias(for dataSet: ClassicDataSet, directory: URL) -> Alias? {
    let campaign = "8b86e1f450097892044500bfa368d203eee9e26abdf63d6166520990e2179a22"
    let revision = "fc020d72e88706953d4737e1b5fa09f5b653d7a70e4e1c1fa1cfa5546a24a908"
    do {
      guard !Task.isCancelled, try campaignFingerprint(dataSet.campaign) == campaign,
        let current = try PortExclusivePack.dataSet(
          amigaRoot: directory.appendingPathComponent("amiga_extracted"), portsRoot: directory),
        try campaignFingerprint(current.campaign) == campaign,
        ClassicSourceRevision.campaign(.ohYesMoreLemmings, root: directory) == revision,
        !Task.isCancelled else { return nil }
      return Alias(packID: dataSet.identifierKey, sourceRevision: revision)
    } catch { return nil }
  }

  private static func campaignFingerprint(_ campaign: ClassicCampaign) throws -> String {
    let records = try campaign.levels.map { entry -> [String: Any] in
      var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as! [String: Any]
      var level = object["level"] as! [String: Any]
      level["skills"] = ClassicSkill.allCases.map {
        [$0.rawValue, entry.level.skills[$0] ?? 0] as [Any]
      }
      object["level"] = level
      return object
    }
    return digest(try JSONSerialization.data(
      withJSONObject: records, options: [.sortedKeys, .withoutEscapingSlashes]))
  }

  private static func simulationAssetsFingerprint(_ dataSet: ClassicDataSet, directory: URL) throws -> String? {
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
    let names = ["main.dat"]
      + dataSet.groundStyles.flatMap { ["ground\($0)o.dat", "vgagr\($0).dat"] }
      + dataSet.specialIndices.map { "vgaspec\($0).dat" }
    var assets: [String: String] = [:]
    for name in names {
      let candidates = files.filter { $0.lastPathComponent.lowercased() == name }
      guard !Task.isCancelled, candidates.count == 1,
        let file = candidates.first,
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
        size <= 8_000_000 else { return nil }
      assets[name] = digest(try Data(contentsOf: file))
    }
    return digest(try JSONSerialization.data(
      withJSONObject: assets, options: [.sortedKeys, .withoutEscapingSlashes]))
  }

  private static func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
