import Foundation
import CryptoKit
import NxlvKit

/// Combines embedded packs, automatic downloads and optional local packs.
///
/// A pack is a zip holding levels in one of three shapes. A `.lvl` file is one
/// level. A `.ini` file is one level written as text. A `.dat` file is a DOS
/// archive of many levels, and it is the commonest of the three, so a browser
/// that ignores it shows most packs as empty.
///
/// The zips are read with the system `unzip` rather than an archive library.
/// Browsing reads a file per keypress, which is not worth a dependency.
enum FanLevelLibrary {
  private static let bundledFingerprints = GameAssetCache<String>(capacity: 4096)
  /**
   * These source bytes used the whole Ports revision in existing learning runs.
   */
  private static let previousOhYesScopedRevision = "843c764dea3913f6e03c46d08b0fa53761dcc48c65b6628bbe7f0d01204df9ad"
  private static let previousOhYesSavedRevision = "fc020d72e88706953d4737e1b5fa09f5b653d7a70e4e1c1fa1cfa5546a24a908"
  /// Where the chosen folder is remembered between runs.
  static let folderKey = "FanLevelFolder"

  static var folder: URL? {
    UserDefaults.standard.string(forKey: folderKey).map { URL(fileURLWithPath: $0) }
  }

  /// One playable level inside a pack.
  ///
  /// `section` names which level inside a DOS archive, and is nil for the
  /// shapes that keep one level per file.
  struct Entry: Sendable {
    let file: String
    let section: Int?
    let label: String
  }

  // MARK: - Progress

  /// What the player has passed, and how big each pack is.
  ///
  /// Fan levels are not part of the campaign flow, which is saved per release
  /// and tracks a run in order. These are hundreds of unrelated packs played in
  /// any order, so progress is just a set of levels passed.
  ///
  /// Counting a pack means opening it and decoding its archives, which is far
  /// too slow to do while drawing a menu. Counts are therefore remembered once
  /// found, and the total on the front screen counts the packs measured so far.
  enum Progress {
    private static let passedKey = "FanLevelsPassed"
    private static let countsKey = "FanLevelCountsV2"
    private static let identifierVersion = "v2"

    /// A stable level identity. Catalogue numbers survive descriptive filename
    /// changes and keep packs with the same display name separate.
    static func identifier(pack: URL, label: String) -> String {
      stablePrefix(pack) + label
    }

    static func legacyIdentifier(pack: URL, label: String) -> String {
      "\(displayName(of: pack))|\(label)"
    }

    private static func stablePrefix(_ pack: URL) -> String {
      "\(identifierVersion)|\(countKey(pack))|"
    }

    @MainActor private static func savePassed(_ values: Set<String>) {
      UserDefaults.standard.set(
        Array(values).sorted(),
        forKey: ArcadeStore.shared.progressKey(passedKey))
    }

    @MainActor static var passed: Set<String> {
      Set(UserDefaults.standard.stringArray(forKey: ArcadeStore.shared.progressKey(passedKey)) ?? [])
    }

    @MainActor static func record(pack: URL, label: String) {
      var all = passed
      let removedLegacy = all.remove(
        legacyIdentifier(pack: pack, label: label)) != nil
      let inserted = all.insert(identifier(pack: pack, label: label)).inserted
      guard removedLegacy || inserted else { return }
      savePassed(all)
    }

    @MainActor static func hasPassed(pack: URL, label: String) -> Bool {
      let current = identifier(pack: pack, label: label)
      var all = passed
      if all.contains(current) { return true }
      guard all.remove(legacyIdentifier(pack: pack, label: label)) != nil else {
        return false
      }
      all.insert(current)
      savePassed(all)
      return true
    }

    static func countKey(_ pack: URL) -> String {
      packID(pack).map { "catalogue:\($0)" } ?? "file:" + pack.lastPathComponent.lowercased()
    }

    static var counts: [String: Int] {
      UserDefaults.standard.dictionary(forKey: countsKey) as? [String: Int] ?? [:]
    }

    static func setCount(_ count: Int, for pack: URL) {
      var all = counts
      let key = countKey(pack)
      guard all[key] != count else { return }
      all[key] = count
      UserDefaults.standard.set(all, forKey: countsKey)
    }

    static func removeCount(for pack: URL) {
      var all = counts
      guard all.removeValue(forKey: countKey(pack)) != nil else { return }
      UserDefaults.standard.set(all, forKey: countsKey)
    }

    /// Levels in the packs measured so far.
    static func total(for packs: [URL]) -> Int {
      let known = counts
      return packs.reduce(0) { $0 + (known[countKey($1)] ?? 0) }
    }

    static func mergeCounts(_ measured: [String: Int]) {
      var all = counts
      all.merge(measured) { _, new in new }
      UserDefaults.standard.set(all, forKey: countsKey)
    }

    static func seedBundledCounts() {
      guard let folder = bundledFolder,
        let data = try? Data(contentsOf: folder.appendingPathComponent("level-counts.json")),
        let index = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
      var all = counts
      for (filename, count) in index where count >= 0 {
        let pack = folder.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: pack.path) { all[countKey(pack)] = count }
      }
      UserDefaults.standard.set(all, forKey: countsKey)
    }
    /**
     * Returns passes that belong to packs currently installed.
     */
    @MainActor static func passedCount(for packs: [URL]) -> Int {
      let all = passed
      let stablePrefixes = Set(packs.map(stablePrefix))
      let currentCount = all.count { saved in
        stablePrefixes.contains { saved.hasPrefix($0) }
      }
      let legacyPacks = Dictionary(
        grouping: packs,
        by: { legacyIdentifier(pack: $0, label: "") })
      let legacyCount = all.count { saved in
        guard !saved.hasPrefix(identifierVersion + "|"),
              let match = legacyPacks.first(where: {
                saved.hasPrefix($0.key)
              }) else { return false }
        let label = String(saved.dropFirst(match.key.count))
        return !match.value.contains { pack in
          all.contains(identifier(pack: pack, label: label))
        }
      }
      return currentCount + legacyCount
    }

    /// Whether every pack in the folder has been measured.
    static func isComplete(for packs: [URL]) -> Bool {
      let known = counts
      return packs.allSatisfy { known[countKey($0)] != nil }
    }

    /// Measures any pack not yet counted. Slow, so it runs off the main thread.
    static func measure(
      _ packs: [URL], onProgress: @escaping @MainActor @Sendable () -> Void
    ) {
      DispatchQueue.global(qos: .utility).async {
        for pack in packs where counts[countKey(pack)] == nil {
          let total = entries(in: pack).count
          DispatchQueue.main.async {
            MainActor.assumeIsolated {
              setCount(total, for: pack)
              onProgress()
            }
          }
        }
      }
    }
  }

  static var bundledFolder: URL? { Bundle.main.resourceURL?.appendingPathComponent("LevelPacks") }
  static var downloadFolder: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Ultimate Lemmings/Fan Levels", isDirectory: true)
  }

  static func packID(_ url: URL) -> Int? {
    let prefix = url.lastPathComponent.prefix { $0.isNumber }
    guard url.lastPathComponent.dropFirst(prefix.count).first == "-" else { return nil }
    return Int(prefix)
  }

  /// A stable catalogue identity for a pack, independent of its local folder.
  static func catalogueID(_ url: URL) -> String {
    packID(url).map { "lldb-\($0)" }
      ?? "file-" + url.lastPathComponent.lowercased()
  }

  /**
   * Evidence-selected Golems levels in mixed packs, pinned to exact archives.
   */
  private static let golemsLevelOverrides: [Int: (revision: String, levels: Set<String>)] = [
    1: ("66ff4c33c44970e945dffee82cfe84a4787329f60ee702613f3f2cb233865bec", ["geooPk0.dat#1", "geooPk0.dat#9"]),
    2: ("4b7101f984e3ae81971b18a5ae393ca4012695528c1bbd5bb89bec70f188497f", ["geooPk1.dat#7"]),
    35: ("c4b362a6a83f5a4dc03b24849adcfd28b00c6391570eed7a84b433c8a2aa2340", ["1tseug.dat#2", "1tseug.dat#9"]),
    202: ("75635bedda453a25eb6cb4d566ad8e6d7d6a3ef60c70ebe1fbe8e7fba955d16d", [
      "mobius1.dat#0", "mobius1.dat#1", "mobius1.dat#2", "mobius1.dat#3", "mobius1.dat#4",
      "Roundabout.lvl#-1", "LemmingsInArms.lvl#-1", "hard to port!.lvl#-1",
      "PlanB.lvl#-1", "LemmingsInMotion.lvl#-1",
    ]),
    5: ("b176d65f35511c28170436b137f1543e0af5e5137146420234cc4275d4b1d677", ["Mikepak00.dat#6"]),
    14: ("e2f7796fe41470257faf24d6519a0149be727942d334c681c29878ad2ae3562e", ["Mikepak09.dat#1"]),
    20: ("d3e3cb52b86ba3528e3ed85ce4abbd14a9b7606a3a8a92c675f7f3d060ef881c", ["ISteve01.DAT#3", "ISteve01.DAT#9"]),
    22: ("ed4f8f4bfe829606383dc3fb3c832f67db960e4b822d28e54d069472140aa484", ["ISteve08.dat#6"]),
    24: ("4d59f847602022ca5bfd404856df7c1b6d0c90213fed6c6a59c4ee73550205c1", ["ISteve04.dat#9"]),
    33: ("bbfb98aa5fb0fb3cd9ea02b186483456aaa0fb417cce9b55a8f9fbb723db08bb", ["QBeez03.dat#9"]),
    75: ("5d2483e04b2a1a12413a02a0b7e3e22d6ee6970732328eacde946872504c4e38", ["JHIsan1.dat#9"]),
    78: ("185e4dbcc0eae4a8b91112c40b94efd86dee5db23da3092eeb1480fd71acf403", ["doggycharly random lvls.dat#0"]),
    82: ("dddb6c75f809935f8a093d1576a191a5ad1631dc1e9807ed9197f71014c6235a", ["Yawg01.dat#0", "Yawg01.dat#1"]),
    90: ("3a049d43042d6380f653db4196379a320bc75aaac51c7e028c1aae286e9690d4", ["Timpack3.dat#6"]),
    105: ("cf9e243e4d743cb16c0c3367fb2be8ca138f4598668946aea7bc6a13907ceaec", ["epic02.dat#3"]),
    140: ("9d421cf4304265ff343870b0dfef4b71740e9dc3bf91959b6f60ef22d4cd802c", ["Epic giga02.dat#0"]),
    160: ("3a7bf1932d5e24a8229184bb2e9b9987755748597ef8f52cdac9e9437318c3e8", ["Giga pack 01.dat#9"]),
    165: ("167151878e40f998db814e208287dacc4f2ffc5885317bedb0af505a9d8fb0ce", ["Giga pack 04.dat#5"]),
    171: ("47e0617d94895001361db1030169ce26764aca68a61ff70de9d3edd1a0550ae9", ["Giga pack 09.dat#6"]),
    179: ("4545eeb5effc99790773b4862e7c0e427ac112d5f09e484cc42d6de81362e089", ["The lemming google pack.dat#2", "The lemming google pack.dat#5"]),
    181: ("9b666aa29ad430e1c1e2655f910ebdac52b6dcac4690eb0cb9eb9a0aa8e8e27d", ["Lemmings platinum Fragle part 2.dat#10", "Lemmings platinum Fragle part 2.dat#7"]),
    191: ("a8a9340f2052f6dc167e9135979311ce6ab2db60adf526fdc5f6a9cd26260c43", ["Lemmings platinum Dangerous Part 2.dat#14"]),
    193: ("f8b9a3fb9d13756772fa9ce75bd6fb9afc80ad2149c58171849e53789c18cbd9", ["Gronklems #1.dat#2", "Gronklems #1.dat#9"]),
    196: ("9838610ce3ef81dbe34e23b74b3500f61f687bae8c9841b4c0f87b8feb7a671a", ["nortpack1.dat#8"]),
    207: ("48534ef67e558892eeced4b86cdb7c3e4cfb3c6e095c652c60e20914513b8178", ["contest1.dat#3"]),
    214: ("e5da32379ca482123b6932a0e6c70fc933e0962097d3988c3e806ac75ac00e21", ["LF Level Jam #1.dat#6"]),
    217: ("d033b19716f2dec396de130dde008e128db03feedbcb4bb7ce7d9778eabff2ba", ["PSP Special.dat#3"]),
    218: ("ff0843de66881e067975462288b74fefcbf0f28e63b1e47e026cd8232ebfcf53", ["PSP Special2.dat#2", "PSP Special2.dat#3"]),
    220: ("91d3fe47ec7780e3aaa34c45fcb0f77d14e445adc7132ab4e1a1c842fa50f198", [
      "AkseliPack01.dat#3", "AkseliPack01.dat#4", "AkseliPack01.dat#6", "AkseliPack01.dat#8",
    ]),
    482: ("9f0b55e9f63bc1d3b5f931af6cd9881f439aba28aa939e4dd79e74c8e4b847a0", ["Frost.DAT#12"]),
    484: ("a88766fb7218b24c824b4de0400c2ef124b85667d6e759bd4ee0384a46b32ae9", ["Flurry.DAT#3", "Flurry.DAT#14"]),
    485: ("48a861bf42e574cdd99346fb2d9971df01db66a7bd49cbfc036c2a074c1becc0", ["Blitz.DAT#3", "Blitz.DAT#4", "Blitz.DAT#7", "Blitz.DAT#9", "Blitz.DAT#13"]),
    222: ("bc0f3a5a7ca4091b2d0ccaf59daa544a57ee3c62c1ec55ebf3d1432ac306c162", ["ANTHPCK2.DAT#2", "ANTHPCK2.DAT#3", "ANTHPCK2.DAT#4"]),
    223: ("338c8cfbb37a5eaf6cb103e85aa2d5e40b90300abfb06dcbb503131b5e8095e1", ["ANTHPCK3.DAT#9"]),
    224: ("b2818e41664bbcc98870c9a7c5e6f20258004495061503f5c373fa255188223d", ["ANTHPCK4.DAT#7"]),
    225: ("dba9b23e61ec73dc0a22e49385a9dacbb45eb5db64bf064a794d8376617f5c1c", ["ANTHPCK5.DAT#1", "ANTHPCK5.DAT#3"]),
    232: ("e62085da6e3e1c103fc6d01686a7a8f97ce81ab2062384b5de5fd836345e0fc6", ["JANNPCK2.DAT#7", "JANNPCK2.DAT#9"]),
    233: ("9e1ebdd82d576bc770faff2e4cb37c5abf43c3ced24c94165087a891b3f9e801", ["jannpck3.dat#4", "jannpck3.dat#9"]),
    234: ("6f5f81a6646bd04141b8a02dfe890b04b2edd1453917bf55cb526be869081c17", ["JANNPCK4.DAT#0", "JANNPCK4.DAT#3"]),
    237: ("f4661115b7742bc24ceda38b5141163faf6114aac5df92316770008eada593fd", ["JEFFPCK3.DAT#5"]),
    244: ("b3b44850317ea16a3318fc64eda54fbe68451909010971d070fe3745113a1aa4", ["Martin Zurlinden 01.dat#0", "Martin Zurlinden 01.dat#8"]),
    245: ("ab231d4cf7985f416429c859113385b7bebccd4686d8e6acc72026b5bd89d2de", ["Martin Zurlinden 02.dat#4", "Martin Zurlinden 02.dat#5", "Martin Zurlinden 02.dat#6", "Martin Zurlinden 02.dat#7", "Martin Zurlinden 02.dat#8"]),
    246: ("d1e2c06fd14cc00c157cc220651bbbcbb9bf401851cce5d23de76fc54085f0bf", ["Martin Zurlinden 03.dat#0", "Martin Zurlinden 03.dat#2", "Martin Zurlinden 03.dat#3", "Martin Zurlinden 03.dat#4", "Martin Zurlinden 03.dat#5"]),
    248: ("bffc37a79925ad47b3cc6a24472381ce3741ef0f2b83048e07faacc7edc80854", ["MATTPCK1.DAT#3", "MATTPCK1.DAT#5", "MATTPCK1.DAT#6", "MATTPCK1.DAT#8"]),
    252: ("fbfde75b1e89c442ec9b6bda652b154ab79329905f336c502ca1c20cb11a7aee", ["Conway03.DAT#9"]),
    265: ("c3b7844f28dc81810eaef140a7e6786b0b92f2edff29f7812d8b035b308e880f", ["CRISFN01.dat#3", "CRISFN01.dat#5"]),
    266: ("ca8350f116a45b7c71d03cc3e236ad90a91dd5f176e930f038835793c1ca2969", ["CRISFN02.dat#6"]),
    268: ("ae52a960fb1cadef87b6dd14cb8b2f63de4e838551c265ef0a68ef8f5513257b", ["CRISFN04.dat#1", "CRISFN04.dat#7"]),
    270: ("07cd52fc4c02914a9e8d59eae729c31b9138cf9c8849d84fc3c1e04ffb781d83", ["CRISFN06.dat#0", "CRISFN06.dat#3", "CRISFN06.dat#6"]),
    271: ("a7199f77fa81457620998433d8675733495749cf2622a5220858c3428bfad2f3", ["CRISFN07.dat#5"]),
    272: ("3699a1435d39ff4358c894cf55ed94b9c916751d754cb49d07491e2ea5ce687b", ["CRISFN08.dat#0", "CRISFN08.dat#7"]),
    274: ("d4f4f470e377ee8382db6bf41749ed620aead2c15360e4416fc4873dbe290268", ["CRISFN10.dat#0"]),
    275: ("57f9871dc77797e9de33684616a66ab82022fe70197a838fc2dea3a241595757", ["CRISFN11.dat#1"]),
    277: ("1d52c584e24ffcbb1e76f5fd14d54b337c44fccef3bed898733c579d5627fb9b", ["CRISFN13.dat#6"]),
    278: ("d4799509e28cf7d168f15f512a98642af7a107ce573d45659442ead54d6ab8a3", ["CRISFN14.dat#6", "CRISFN14.dat#8"]),
    302: ("742f9b1f32285477bd4f4234cccac8b6cf64dd488bbe5a2faa6940e002c7c1f2", ["TWPAK00.dat#9"]),
    303: ("697a9fc2adb8c4a7e2b49b2741eee766cf7d944fe40b66640827db12163f0b99", ["TWPAK01.dat#3", "TWPAK01.dat#6"]),
    304: ("6c68eaadda259536e63c51ae8a2a5d12d476a21b211c6034ebeb62c3e242da77", ["TWPAK02.dat#6"]),
    306: ("f601908d736e005e8c5cf4c3591b012a80227855a13d3a70274f2edcbad45c09", ["TWPAK04.dat#3"]),
    312: ("0a836e9df23084c3d30a968c613ee4c92976108db41e070f0b2fafde3d39fe2b", ["TWPAK10.dat#7"]),
    315: ("86a8a54b434348048c63f9b2792cddce345a2ee5f2aa445c1d0b278671c79f15", ["TWPAK13.dat#0", "TWPAK13.dat#1"]),
    317: ("ebd0f5401693ba0038f81ce31381bca4471314ad26e16ec9bdddaeb591907405", ["joem1.dat#8"]),
    327: ("4ed40d2dad89484a0565b4fc472ba6db8a18a36f97c174cb4ea392eac14073c2", ["JM01.DAT#7"]),
    331: ("2d7e14e719e723aba2d4d40fa30a6e4fc7dd2134a49fb51646856ff1f694e4f3", ["JM05.DAT#8"]),
    340: ("c36feae86ac25cb45dd682d2cb962bc3df5ab3464eb2107b0953f84bfdc3ef6c", ["JM14.DAT#5"]),
    350: ("e9fa144400ed4a582d2b2ba3e425d358a6f9bffc8a8eedc4651f8407331a109c", ["MARSHY06.DAT#5"]),
    351: ("5242934a769947f697468058b9827c8cce6249ea75ecdb56ef0e8a47ca284403", ["MARSHY07.DAT#3"]),
    366: ("2058cbedd0f5a9ed82a0c5f06016b0514a17f321f93d624415f7270e8fe8b322", ["LEVIPAK2.DAT#0"]),
    367: ("b7a0484a5d4261ff136065057418586873a133c13f357670dd3636ee6e617ca0", ["LEVIPAK3.DAT#0"]),
    368: ("7499a209cd792fc43b3b35d7e389d780010014e5cb0ac5bbeac3510269b2e31a", ["levipak4.dat#9"]),
    373: ("e35bad34d4579222753f3cd2580c0629a92904876f9d603b20ae6010e733c05b", ["Insulfrog+LVL+PK+1.DAT#2"]),
    374: ("aafbe56bf545df649edde5ca3bd4e51b8f5c834e52772aaf339003420d473a26", ["justdigcomp.dat#3"]),
    385: ("42588c20a8bb7981e763a0ed51070607d8cdad7482a3dd8eaab160cb2ddad83f", ["Gronklems 3.dat#5"]),
    388: ("cbab658e9aa6d51ccaf562ec716cab9460e2999f4d2444d1e6120aea8e3251be", ["geooPk2_preview2.dat#0", "geooPk2_preview2.dat#1"]),
    393: ("6b599e67d0656e6a27f33f99916b9dafd21b04a1e7c88f8eda24e3083a087bc4", ["pieuw01.dat#9"]),
    394: ("012f8d6fde059a9781d2293d00e4426595c281d7c7a8963caaa4ff4d5c1e123c", ["pieuw02.dat#0", "pieuw02.dat#2", "pieuw02.dat#3", "pieuw02.dat#6"]),
    405: ("9af050546e82475ff3209ef5af9c8764c6a3b6edaabd43f8314ef7c1057e3a3c", ["Genesis 2P 2.dat#5"]),
    407: ("eb76b2ab3e2560baa62884dfc72464f0023e59f635a97eaee8712ff9f6a22997", ["Orig Extra Levels.dat#3"]),
    411: ("6bb5948b6af1a7cd9f6ccbee0c2d6d304cb3341e3e05072c97307856d260208c", ["mobius05.dat#1"]),
    413: ("d557c00835d843d4cae6be26d475e857735718bd18578b0a9e8de7ece008041e", ["GeoffLems_Minipack.dat#0"]),
    430: ("bdbf943f510410b7e4c304ff57a31b83134d51b32a6aeed2432eaa6f2804d835", ["LDChallenge01.dat#2"]),
    464: ("d7f87a4fddf92a2947fe7606b2ff2be1982a05c10a8f1e8282d26e6b36274727", ["Finland.dat#0"]),
    471: ("2780e3a5c021c0a6d8bf12c751e08c0ed9d28ae47683b533691e67690d1d72bc", ["RSRdnt01.dat#0"]),
    472: ("0aa4c6e70d8b2adeae926a70f881a18fbbc9dabf150fc7ee345681e3500753f8", ["LEMPACK.DAT#3", "LEMPACK.DAT#4", "levels/04.LVL#-1", "levels/05.LVL#-1"]),
    489: ("d3a60e754dd580f50f3c846b76a977903ccb3ca4997613cd7cde7879d632b080", ["Genesis Tricky.dat#29", "Genesis Tricky.dat#7"]),
    490: ("38f13b44cfdb5722c4c1438286a633a0c3f6234d72625152cd311f2294445223", ["Genesis Taxing.dat#21"]),
    491: ("f648151520692b675936d0e254663d177e91370029534658305470bb740f89b6", ["Genesis Mayhem.dat#24", "Genesis Mayhem.dat#7"]),
    494: ("fa2398637b4d298aaa26f2ba5d2a6a0445e3f4109126ed0aee32b35b2100a38d", ["JANNPCK3.DAT#4", "JANNPCK3.DAT#9"]),
    495: ("02dde42ce00cffb0a126928f96abb6df8d29b45465bb761cc0a88632828ef832", ["MARTPCK1.DAT#8"]),
    496: ("fbf2f7723f9042ccda838524e4a366e035f49c34d2d1422a7eca9017a9cb01cb", ["MARTPCK2.DAT#0", "MARTPCK2.DAT#4", "MARTPCK2.DAT#6", "MARTPCK2.DAT#8"]),
    497: ("eee114bbaf98654790d24c531e3a4757acaefef0002acee0dd93c4d9a3eba088", ["MARTPCK3.DAT#0", "MARTPCK3.DAT#2", "MARTPCK3.DAT#3", "MARTPCK3.DAT#4", "MARTPCK3.DAT#5"]),
    514: ("acb58ceaf0ecb6266e4eab3d8f9bdd75029bf512858bc2dfb9ee9901c5e68cc0", ["ssam1221 Wild 2.dat#2"]),
    519: ("477aa6f5a911af6069384bcaaa85f86d531d14c8093cdc57dd7a7e29d6738973", ["Van Clan Wild 1.dat#5"]),
    523: ("d0a5a5fd593a5d0014a255e631a302f6ce35165c11ad36c685a3bdae074bd13e", ["Deceit Tricky 1.dat#5"]),
    542: ("f1ecfbe225c1039af701815227b4af13bcf5f45ac22c7e672357b5ff485e659e", ["Pieuw 2007 Peace 2.DAT#8"]),
    543: ("dd8cb81a28c705620de06c72a7b8c3166dcf84d6862df40974d8c6b6246d7ea8", ["Pieuw 2007 Awkward 2.DAT#6"]),
    544: ("fc9991e07984a0eecfcd19be9ec2be19e8647a93b3282aa0eef563ceb5091446", ["Pieuw 2007 Artful 1.DAT#0", "Pieuw 2007 Artful 1.DAT#3", "Pieuw 2007 Artful 1.DAT#7"]),
    545: ("0b5e4bfede58cb4d8acee4ff5fb4d28ef912a472c1a5405271dc61453d7292f5", ["Pieuw 2007 Insane 1.DAT#0", "Pieuw 2007 Insane 1.DAT#3", "Pieuw 2007 Insane 2.DAT#4"]),
    548: ("be7597710bb1f6b1421623c630bb9528ac16c8968a833980f6f8441c93cfd196", ["Ji Hoon Sky 2.DAT#2"]),
    551: ("587fa1a85d2ce0c3d0c8b50d9fa6c23a5d224c5b100e7c364088fde33e35798e", ["Lemmings Plus DOS Project - 02 - Mild (Part 2).dat#8", "Lemmings Plus DOS Project - 03 - Mild (Part 3).dat#2"]),
    552: ("8187c19df391ea59e594bf9e4779b7ec81fb0034bc4a899ae09aee7396b3c042", ["Lemmings Plus DOS Project - 05 - Wimpy (Part 2).dat#6", "Lemmings Plus DOS Project - 06 - Wimpy (Part 3).dat#8"]),
    553: ("b9b763a725cf6c717f0c0c4ce65619cddbc0deadb2aef9acb55f1dd87b9483ec", ["Lemmings Plus DOS Project - 07 - Medi (Part 1).dat#0", "Lemmings Plus DOS Project - 07 - Medi (Part 1).dat#9", "Lemmings Plus DOS Project - 08 - Medi (Part 2).dat#0", "Lemmings Plus DOS Project - 08 - Medi (Part 2).dat#3", "Lemmings Plus DOS Project - 08 - Medi (Part 2).dat#4", "Lemmings Plus DOS Project - 08 - Medi (Part 2).dat#9", "Lemmings Plus DOS Project - 09 - Medi (Part 3).dat#7"]),
    554: ("bc6910d89e3d4625677d173dd9289ac64e19378a58c5ae9c2f2285875fdfeede", ["Lemmings Plus DOS Project - 11 - Danger (Part 2).dat#1", "Lemmings Plus DOS Project - 12 - Danger (Part 3).dat#9"]),
    558: ("f117ea9ccfc582e2704c654b2e11b16a8c7cb79e99600a180e356f0cac2ab53f", ["brickpk1.dat#12", "brickpk1.dat#15"]),
    567: ("60773562027df60b77ec90a106a813e80a8c349a530369d4bc8857af89ac280e", ["Conway06.dat#8"]),
    592: ("c8a9891b1a18e26e7ec27896c4ca0b61ec38abd2795d2ebd6ba81d83cb4b022b", ["LEVELPAK.DAT#1"]),
  ]
  /**
   * Bundled conversions of later official levels retain their source hatch rules.
   */
  private static let ohNoMorePackOverrides: [Int: String] = [
    478: "8d65d85e93e941b486e9543d3b6d4435495d2e56eadb53d744bd1782eb051da6",
    479: "9447da45833dc536df6fb4e25fd7dff06423ae5e67a769a9c9e94c9416ba439a",
    480: "63ab956e498283467aba9a3dd87680abe43f00fd07ae16279a6bfd950c54a0a2",
    481: "575f71040f97db65494e2fd5ab5b3a4351fa43073677480e9af4a9881b02d997",
    482: "9f0b55e9f63bc1d3b5f931af6cd9881f439aba28aa939e4dd79e74c8e4b847a0",
    483: "0543b9c913b9999d82112c55561fc37b9e765a299c6dc4ee7dbea6c1db569d9e",
    487: "4361935304ac1fd403c4a5ea63b0a4be415117ff601841b501bac0130e946a91",
    583: "1331231b1a47cc1c92aaa411bbfd05bbabe9b122406c6ab79cc673b8ed23dfd8",
  ]
  /**
   * Exact bundled copies whose official replay needs the later hatch rules.
   */
  private static let ohNoMoreLevelOverrides: [Int: (revision: String, levels: Set<String>)] = [
    264: ("73f28c4f559b796ea5d8566bd2a34905ae6465ab0d30ab8845ab981332af09bd", ["ConwayChallenges 2.DAT#6"]),
    301: ("9e526440f087a13921d8863a91fcfd5d33eaad4b3a2e44bdcd12c9ffea52c9ab", ["Pacpack2.dat#1"]),
    484: ("a88766fb7218b24c824b4de0400c2ef124b85667d6e759bd4ee0384a46b32ae9", ["Flurry.DAT#13"]),
    485: ("48a861bf42e574cdd99346fb2d9971df01db66a7bd49cbfc036c2a074c1becc0", [
      "Blitz.DAT#0", "Blitz.DAT#1", "Blitz.DAT#6", "Blitz.DAT#8",
      "Blitz.DAT#10", "Blitz.DAT#12", "Blitz.DAT#15",
    ]),
  ]
  /**
   * The bundled Frost member with an established Original-rule winning replay.
   */
  private static let originalLevelOverrides: [Int: (revision: String, levels: Set<String>)] = [
    482: ("9f0b55e9f63bc1d3b5f931af6cd9881f439aba28aa939e4dd79e74c8e4b847a0", ["Frost.DAT#3"]),
  ]
  /**
   * Selects source rules for an exact bundled pack or level with replay evidence.
   */
  static func mechanics(for pack: URL, entry: Entry? = nil) -> ClassicDOSMechanics {
    let number = packID(pack)
    let revision = archiveFingerprint(pack)
    switch (number, revision) {
    case (433, "65c251590f612944e636a2e6755b6104a9cacf65ab86b351eb0d3578371adebe"),
         (290, "14a4717cc58d0d4e922f5faa75c4a6976fd56c37b1818a9191b04bf025aeecdb"):
      return .golems
    default: break
    }
    if let entry, let number, let revision,
       let source = golemsLevelOverrides[number], source.revision == revision,
       source.levels.contains(entry.file + "#\(entry.section ?? -1)") {
      return .golems
    }
    if let entry, let number, let revision,
       let source = originalLevelOverrides[number], source.revision == revision,
       source.levels.contains(entry.file + "#\(entry.section ?? -1)") {
      return .original
    }
    if let entry, let number, let revision,
       let source = ohNoMoreLevelOverrides[number], source.revision == revision,
       source.levels.contains(entry.file + "#\(entry.section ?? -1)") {
      return .ohNoMore
    }
    if let number, let revision, ohNoMorePackOverrides[number] == revision {
      return .ohNoMore
    }
    return .original
  }

  /// Bundled packs have corpus load, render and run evidence. Other archives
  /// stay explicit and unverified until they gain the same evidence.
  static func catalogueStatus(_ url: URL) -> LevelContentStatus {
    guard let bundledFolder else { return .unverified }
    return url.deletingLastPathComponent().standardizedFileURL == bundledFolder.standardizedFileURL
      ? .playable : .unverified
  }

  /// Identifies the exact archive bytes selected by the browser.
  static func archiveFingerprint(_ url: URL) -> String? {
    let key = GameAssetCache<String>.bundledKey(url).map { "file:" + $0 }
    if let key, let cached = bundledFingerprints.value(for: key) { return cached }
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
    let result = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    if let key { bundledFingerprints.insert(result, for: key) }
    return result
  }

  static func archiveMatches(_ url: URL, fingerprint: String) -> Bool {
    archiveFingerprint(url) == fingerprint
  }

  /// "/relative/path" of an enumerated file. The enumerator may report a root
  /// under /private (App Translocation, /tmp) that `resolvingSymlinksInPath`
  /// shortens, so the key comes from the file's depth, not from the root's spelling.
  static func relativeKey(_ url: URL, level: Int) -> String {
    "/" + url.pathComponents.suffix(level).joined(separator: "/")
  }

  /// Hashes game data by relative path and bytes. Moving an unchanged import
  /// keeps its content fingerprint, while any source change invalidates it.
  static func directoryFingerprint(_ root: URL) -> String? {
    let key = GameAssetCache<String>.bundledKey(root).map { "directory:" + $0 }
    if let key, let cached = bundledFingerprints.value(for: key) { return cached }
    let root = root.resolvingSymlinksInPath().standardizedFileURL
    guard let enumerator = FileManager.default.enumerator(
      at: root,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]) else { return nil }
    let ignored = Set(["sav", "mp4", "m4a", "wav", "ogg", "mp3", "mod", "mid", "png", "jpg"])
    var entries: [String: String] = [:]
    for case let url as URL in enumerator {
      if Task.isCancelled { return nil }
      if ignored.contains(url.pathExtension.lowercased()) { continue }
      guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
            let fingerprint = archiveFingerprint(url) else { continue }
      entries[relativeKey(url, level: enumerator.level)] = fingerprint
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard !entries.isEmpty, let data = try? encoder.encode(entries) else { return nil }
    let result = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    if let key { bundledFingerprints.insert(result, for: key) }
    return result
  }

  /**
   * Identifies the data used by one Classic campaign.
   */
  static func classicSourceRevision(for title: ClassicTitle?, root: URL) -> String? {
    guard title == .ohYesMoreLemmings else { return directoryFingerprint(root) }
    let folders = Set(AmigaVersusCampaign.sources.map { "amiga_extracted/" + $0.family }
      + [PortExclusivePack.sunsoftFolder,
         ClassicStyleResolver.Release.lemmings.folders[0],
         ClassicStyleResolver.Release.ohNoMore.folders[0]])
    var revisions: [String: String] = [:]
    for folder in folders {
      revisions[folder] = directoryFingerprint(root.appendingPathComponent(folder)) ?? "missing"
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(revisions) else { return nil }
    let scoped = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    if scoped == previousOhYesScopedRevision {
      return previousOhYesSavedRevision
    }
    return scoped
  }

  static func knownLevelCount(in pack: URL) -> Int? {
    Progress.counts[Progress.countKey(pack)]
  }

  /// Embedded packs stay available even when a chosen folder is missing.
  static func packs() -> [URL] {
    packs(in: [bundledFolder, downloadFolder, folder].compactMap { $0 })
  }

  static func packs(in folders: [URL]) -> [URL] {
    var result: [String: URL] = [:]
    for folder in folders {
      let files = (try? FileManager.default.contentsOfDirectory(at: folder,
        includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
      for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where file.pathExtension.lowercased() == "zip"
          && (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
        let key = packID(file).map { "id:\($0)" } ?? "file:" + file.lastPathComponent.lowercased()
        if result[key] == nil { result[key] = file }
      }
    }
    return result.values.sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  /// A pack's name without the filing number the mirror gives it.
  static func displayName(of pack: URL) -> String {
    let stem = pack.deletingPathExtension().lastPathComponent
    let withoutNumber = stem.drop { $0.isNumber }.drop { $0 == "-" }
    return withoutNumber.replacingOccurrences(of: "-", with: " ")
  }

  /// The levels inside one pack.
  static func entries(in pack: URL) -> [Entry] {
    guard !Task.isCancelled else { return [] }
    let listing = shellResult(["/usr/bin/unzip", "-Z1", pack.path])
    guard listing.status == 0 else { return [] }
    return entries(in: pack, names: listing.output
      .split(separator: "\n").map(String.init).sorted())
  }

  /**
   * Returns decoded entries only after `unzip` verifies the complete archive.
   */
  static func validatedEntries(in pack: URL) throws -> [Entry] {
    try Task.checkCancellation()
    let validation = shellResult(["/usr/bin/unzip", "-tqq", pack.path])
    guard validation.status == 0 else {
      throw NSError(
        domain: "FanLevelLibrary",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "The fan level archive could not be verified."])
    }
    try Task.checkCancellation()
    let listing = shellResult(["/usr/bin/unzip", "-Z1", pack.path])
    guard listing.status == 0 else {
      throw NSError(
        domain: "FanLevelLibrary",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "The fan level archive could not be listed."])
    }
    return entries(in: pack, names: listing.output
      .split(separator: "\n").map(String.init).sorted())
  }

  private static func entries(in pack: URL, names: [String]) -> [Entry] {
    guard !Task.isCancelled else { return [] }
    var found: [Entry] = []
    for name in names {
      if Task.isCancelled { return [] }
      let lower = name.lowercased()
      let base = (name as NSString).lastPathComponent.lowercased()
      if lower.hasSuffix(".lvl")
        || (lower.hasSuffix(".ini") && !lower.hasSuffix("levelpack.ini")) {
        guard let raw = contents(of: name, in: pack) else { continue }
        guard (try? singleLevel(raw, name: name)) != nil else { continue }
        found.append(Entry(file: name, section: nil, label: (name as NSString).lastPathComponent))
      } else if lower.hasSuffix(".dat") {
        // Graphics archives sit beside the levels and hold no level records.
        guard !base.hasPrefix("vgaspec"), !base.hasPrefix("vgagr"),
          !base.hasPrefix("ground"), let raw = contents(of: name, in: pack),
          let sections = try? ClassicDATArchive.decode(raw),
          let slots = try? sectionSlots(for: name, count: sections.count, in: pack)
        else { continue }
        for (index, section) in sections.enumerated() {
          if Task.isCancelled { return [] }
          guard section.data.count >= ClassicLevel.recordSize,
            let level = try? ClassicLevel(
              data: section.data.prefix(ClassicLevel.recordSize))
          else { continue }
          let title = level.title.isEmpty ? "\(base) \(index + 1)" : level.title
          found.append(Entry(file: name, section: slots[index], label: title))
        }
      }
    }
    return found
  }

  /// Reads one level, and the style name when the level carries one.
  static func level(
    _ entry: Entry, in pack: URL,
    includeTextSteel: Bool = true,
    preserveTextTerrainCoordinates: Bool = false,
    preserveTextObjectCoordinates: Bool = false
  ) throws -> (ClassicLevel, String?) {
    guard let raw = contents(of: entry.file, in: pack) else {
      throw FanLevelError.wrongSize(bytes: 0)
    }
    if let section = entry.section {
      let sections = try ClassicDATArchive.decode(raw)
      let slots = try sectionSlots(for: entry.file, count: sections.count, in: pack)
      guard let index = slots.firstIndex(of: section) else {
        throw FanLevelError.wrongSize(bytes: 0)
      }
      return (
        try ClassicLevel(data: sections[index].data.prefix(ClassicLevel.recordSize)),
        nil)
    }
    return try singleLevel(raw, name: entry.file, includeTextSteel: includeTextSteel,
      preserveTextTerrainCoordinates: preserveTextTerrainCoordinates,
      preserveTextObjectCoordinates: preserveTextObjectCoordinates)
  }

  /**
   * Reads a text level's source canvas for explicit solver probes.
   */
  static func textCanvasSize(_ entry: Entry, in pack: URL) throws -> FanLevelReader.CanvasSize {
    guard entry.section == nil, entry.file.lowercased().hasSuffix(".ini"),
          let raw = contents(of: entry.file, in: pack),
          !(raw.count == ClassicLevel.recordSize && raw.prefix(32).contains(0)) else {
      throw FanLevelError.invalidField("text canvas")
    }
    let text = String(data: raw, encoding: .utf8)
      ?? (String(data: raw, encoding: .isoLatin1) ?? String(decoding: raw, as: UTF8.self))
    return try FanLevelReader.canvasSize(fromINI: text, defaultWidth: 3200, defaultHeight: 320)
  }

  /// Pruned DAT archives retain original slot identities for saved queues.
  private static func sectionSlots(for member: String, count: Int, in pack: URL) throws -> [Int] {
    let name = "classic-section-slots.json"
    guard graphicArchiveIndex.files(in: pack).contains(name) else { return Array(0..<count) }
    guard let raw = contents(of: name, in: pack),
          let mappings = try? JSONDecoder().decode([String: [Int]].self, from: raw),
          let slots = mappings[member], slots.count == count,
          Set(slots).count == slots.count, slots.allSatisfy({ (0..<10_000).contains($0) }) else {
      throw NSError(domain: "FanLevelLibrary", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid archived level slot mapping."])
    }
    return slots
  }

  static func restoredQueue(_ queue: [Entry], index: Int, in pack: URL) throws -> (entries: [Entry], index: Int) {
    let available = Set(entries(in: pack).map { $0.file + "#\($0.section ?? -1)" })
    let retained = queue.enumerated().filter { available.contains($0.element.file + "#\($0.element.section ?? -1)") }
    guard let current = retained.firstIndex(where: { $0.offset == index }) else {
      throw FanLevelError.wrongSize(bytes: 0)
    }
    return (retained.map(\.element), current)
  }

  private static func singleLevel(
    _ raw: Data, name: String,
    includeTextSteel: Bool = true,
    preserveTextTerrainCoordinates: Bool = false,
    preserveTextObjectCoordinates: Bool = false
  ) throws -> (ClassicLevel, String?) {
    // Some archived binary levels were given an .ini extension by their author.
    if name.lowercased().hasSuffix(".lvl") || (raw.count == ClassicLevel.recordSize && raw.prefix(32).contains(0)) {
      return (try FanLevelReader.level(fromLVL: raw), nil)
    }
    let text = String(data: raw, encoding: .utf8) ?? (String(data: raw, encoding: .isoLatin1) ?? String(decoding: raw, as: UTF8.self))
    return (try FanLevelReader.level(fromINI: text, includeSteel: includeTextSteel,
      preserveTerrainCoordinates: preserveTextTerrainCoordinates,
      preserveObjectCoordinates: preserveTextObjectCoordinates), FanLevelReader.styleName(fromINI: text))
  }

  /// Verified archives that retain release-local graphics slots. Names are not identities.
  /// See Documentation/ReleaseReadiness/FanStyleConventions.md for evidence and scope.
  private static let localStylePacks: [String: (bytes: Int, directory: String)] = [
    "4657df879d7b2e81e52d0f5e5f2d2d15d8d31176be4628dcfa67366c9c1450bc": (8375, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0477-DOS-Amiga-Tame.zip
    "8d65d85e93e941b486e9543d3b6d4435495d2e56eadb53d744bd1782eb051da6": (10596, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0478-DOS-Amiga-Crazy.zip
    "9447da45833dc536df6fb4e25fd7dff06423ae5e67a769a9c9e94c9416ba439a": (10598, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0479-DOS-Amiga-Wild.zip
    "63ab956e498283467aba9a3dd87680abe43f00fd07ae16279a6bfd950c54a0a2": (10497, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0480-DOS-Amiga-Wicked.zip
    "575f71040f97db65494e2fd5ab5b3a4351fa43073677480e9af4a9881b02d997": (11089, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0481-DOS-Amiga-Havoc.zip
    "fd76e9ca94eeb1d7a54ca3ae0861efecc9541422a9972c39376d40795b7258be": (2523, "xmas_dos_XmasLemmingsV1.9"), // 0486-DOS-Xmas-1991.zip
    "4361935304ac1fd403c4a5ea63b0a4be415117ff601841b501bac0130e946a91": (2124, "xmas_dos_XmasLemmingsV1.9a1"), // 0487-DOS-Xmas-1992.zip
    "b4cce71d3c06d23b8211c86de6f76ff300331d8adc0c121d3f0924ce4a23037a": (3830, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0530-Oh-No-More-cLemmings-Tame.zip
    "e7eb1cb2ed4152fe7d0b78cfcfca504b5e526cb53dc1287672410afce8f08585": (5187, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0531-Oh-No-More-cLemmings-Crazy.zip
    "06cc76ea462e87444c3294ca16d48b06d6df24af0d6e6825df4012b79e26ea5e": (6091, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0532-Oh-No-More-cLemmings-Wild.zip
    "8473c39f4bf9a6cc9b19dd6d27633e8fa7ccb8e70c52210758f6211bde8f22ba": (5576, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0533-Oh-No-More-cLemmings-Wicked.zip
    "64cd29e779476667eeb9b20370f45d6c39626711de511685c2ddf354ccd93456": (8316, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0534-Oh-No-More-cLemmings-Havoc.zip
    "1331231b1a47cc1c92aaa411bbfd05bbabe9b122406c6ab79cc673b8ed23dfd8": (5434, "oh_no_more_lemmings_dos-1991-11-14_2232"), // 0583-Amiga-Oh-No-More-Lemmings-Two-Player.zip
  ]

  private static let holidayStylePacks: [String: (bytes: Int, directory: String)] = [
    "9f0b55e9f63bc1d3b5f931af6cd9881f439aba28aa939e4dd79e74c8e4b847a0": (4533, "holiday_native_1994"), // 0482-DOS-Frost.zip
    "0543b9c913b9999d82112c55561fc37b9e765a299c6dc4ee7dbea6c1db569d9e": (6221, "holiday_native_1994"), // 0483-DOS-Hail.zip
    "a88766fb7218b24c824b4de0400c2ef124b85667d6e759bd4ee0384a46b32ae9": (5361, "holiday_native_1994"), // 0484-DOS-Flurry.zip
    "48a861bf42e574cdd99346fb2d9971df01db66a7bd49cbfc036c2a074c1becc0": (5330, "holiday_native_1994"), // 0485-DOS-Blitz.zip
    "e0b4def872bc847330ee71afc5a6e602c97aaefe65f5b0f86d28af0145245339": (2802, "holiday_native_1994"), // 0535-Holiday-cLemmings-Frost.zip
    "982bcf92e698b395415cb59da56b5ad4ac3e4f6224163e64920f0a55218b74a2": (3815, "holiday_native_1994"), // 0536-Holiday-cLemmings-Hail.zip
    "d4a17f5380fd0315dd62fc6947535c459088a28d620a6fa3d0ff27c34e50e540": (4285, "holiday_native_1994"), // 0537-Holiday-cLemmings-Flurry.zip
    "dfe8ca3aeb56899499f810a00e0953a338d4b678c018496d5919c59e4f944e0d": (3990, "holiday_native_1994"), // 0538-Holiday-cLemmings-Blitz.zip
  ]

  static func localStyleDirectory(in pack: URL, includeHoliday: Bool = false) -> String? {
    let conventions = includeHoliday ? localStylePacks.merging(holidayStylePacks) { current, _ in current } : localStylePacks
    guard let size = (try? pack.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
          conventions.values.contains(where: { $0.bytes == size }),
          let data = try? Data(contentsOf: pack, options: .mappedIfSafe), data.count == size else { return nil }
    let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    return conventions[hash]?.directory
  }

  /// Custom-level slots span the original five styles, Oh No's four, then Xmas.
  /// Resolve them independently of whichever campaign the player last opened.
  static func groundSet(for level: ClassicLevel, styleName: String?, portsRoot: URL,
                        pack: URL? = nil, entry: Entry? = nil, useLocalStyles: Bool = true, useHolidayStyles: Bool = true) throws -> ClassicGroundSet {
    let names = ["dirt", "fire", "marble", "pillar", "crystal", "brick", "rock", "snow", "bubble", "xmas"]
    let named = styleName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let name = named ?? (names.indices.contains(level.groundStyle) ? names[level.groundStyle] : "slot \(level.groundStyle)")
    let directory: URL, index: Int
    if named == nil, useLocalStyles, let pack, let local = localStyleDirectory(in: pack, includeHoliday: useHolidayStyles),
       local != "holiday_native_1994" || level.groundStyle == 2 {
      directory = portsRoot.appendingPathComponent(local); index = level.groundStyle
    } else if name == "xmas" || name == "christmas" {
      directory = portsRoot.appendingPathComponent("holiday_native_1994"); index = 2
    } else {
      switch ClassicStyleResolver(portsRoot: portsRoot).resolve(styleNamed: name == "special" ? "dirt" : name) {
      case let .found(root, slot), let .packSupplied(root, slot): directory = root; index = slot
      default: throw NSError(domain: "FanLevelLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported or missing fan graphics style: \(name)"])
      }
    }
    if let pack, let entry {
      let slot = named == nil ? level.groundStyle : index
      let ground = try graphicData("ground\(slot)o.dat", entry: entry, pack: pack)
      let graphics = try graphicData("vgagr\(slot).dat", entry: entry, pack: pack)
      if ground != nil || graphics != nil {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        func fallback(_ name: String) throws -> Data {
          guard let file = files.first(where: { $0.lastPathComponent.lowercased() == name }) else { throw ClassicGraphicsError.missingFile(name) }
          return try Data(contentsOf: file)
        }
        return try ClassicGroundSet(style: index, groundData: ground ?? fallback("ground\(index)o.dat"),
          graphicsArchiveData: graphics ?? fallback("vgagr\(index).dat"))
      }
    }
    return try ClassicGroundSet.load(style: index, from: directory)
  }

  private static let presentationGrounds = GameAssetCache<ClassicGroundSet>(capacity: 32)

  /// The stock releases whose artwork banks a fan level might borrow, most preferred first.
  private static let artworkReleases = [
    ("holiday_native_1994", "holiday"),
    ("lemmings_dos_1991-07-30", "lemmings"),
    ("oh_no_more_lemmings_dos-1991-11-14_2232", "ohno"),
    ("xmas_dos_XmasLemmingsV1.9", "xmas"),
    ("xmas_dos_XmasLemmingsV1.9a1", "xmas")
  ]

  private static func stockGround(style: Int, folder: String, portsRoot: URL) -> ClassicGroundSet? {
    let directory = portsRoot.appendingPathComponent(folder)
    let key = GameAssetCache<ClassicGroundSet>.bundledKey(directory).map { "\($0):\(style)" }
    if let key, let cached = presentationGrounds.value(for: key) { return cached }
    guard let loaded = try? ClassicGroundSet.load(style: style, from: directory) else { return nil }
    if let key { presentationGrounds.insert(loaded, for: key) }
    return loaded
  }

  /// Alternate artwork is safe only when it belongs to the exact resolved ground set.
  static func artworkFamily(for ground: ClassicGroundSet, portsRoot: URL) -> String? {
    for (folder, family) in artworkReleases
    where stockGround(style: ground.style, folder: folder, portsRoot: portsRoot) == ground {
      return family
    }
    return nil
  }

  /// The release artwork a fan level may borrow, and which of its pieces.
  struct ArtworkMatch: Equatable {
    let family: String
    let pieces: ClassicMacPieceMatch
  }

  /// A level takes alternate artwork when most of the pieces it draws are unchanged.
  /// A pack that redraws more than that has its own look, and a patchwork would hide it.
  static let minimumArtworkShare = 0.5

  /// Finds the release a pack's ground set was derived from, piece by piece.
  ///
  /// Pieces the pack changed stay in DOS pixels. A level on a special picture
  /// qualifies only when that picture is the stock one, because only the first
  /// release carries those pictures in alternate artwork.
  static func artworkMatch(for level: ClassicLevel, ground: ClassicGroundSet,
    special: ClassicSpecialGraphic?, portsRoot: URL) -> ArtworkMatch? {
    var best: (family: String, pieces: ClassicMacPieceMatch, share: Double, total: Int)?
    for (folder, family) in artworkReleases {
      guard let stock = stockGround(style: ground.style, folder: folder, portsRoot: portsRoot),
        let pieces = ClassicMacPieceMatch.compare(ground, with: stock) else { continue }
      let share = pieces.share(of: level) ?? 1
      // Releases can share a palette and many pieces, so a tie goes to the
      // one the whole set resembles most.
      let total = pieces.terrain.count + pieces.objects.count
      if let held = best, (share, total) <= (held.share, held.total) { continue }
      best = (family, pieces, share, total)
    }
    guard var best, best.share >= minimumArtworkShare else { return nil }
    if level.specialStyle > 0 {
      guard best.family == "lemmings", let special,
        let stock = try? ClassicSpecialGraphic.load(index: level.specialStyle - 1,
          from: portsRoot.appendingPathComponent("lemmings_dos_1991-07-30")),
        special == stock else { return nil }
      best.pieces.special = true
    }
    return ArtworkMatch(family: best.family, pieces: best.pieces)
  }

  static func specialGraphic(for level: ClassicLevel, entry: Entry, pack: URL, portsRoot: URL) throws -> ClassicSpecialGraphic? {
    guard level.specialStyle != 0 else { return nil }
    let index = level.specialStyle - 1
    if let data = try graphicData("vgaspec\(index).dat", entry: entry, pack: pack) {
      return try ClassicSpecialGraphic(archiveData: data)
    }
    // Some older packs encode a single filename character relative to ASCII zero.
    if (17...42).contains(index), let letter = UnicodeScalar(48 + index),
      let data = try graphicData("vgaspec\(Character(letter)).dat", entry: entry, pack: pack) {
      return try ClassicSpecialGraphic(archiveData: data)
    }
    return try ClassicSpecialGraphic.load(index: index, from: portsRoot.appendingPathComponent("lemmings_dos_1991-07-30"))
  }

  private final class GraphicArchiveIndex: @unchecked Sendable {
    private let lock = NSLock()
    private var cached: [String: (Date?, Int?, [String])] = [:]
    func files(in pack: URL) -> [String] {
      lock.lock(); defer { lock.unlock() }
      let metadata = try? pack.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
      if let saved = cached[pack.path], saved.0 == metadata?.contentModificationDate, saved.1 == metadata?.fileSize {
        return saved.2
      }
      let files = FanLevelLibrary.shell(["/usr/bin/unzip", "-Z1", pack.path]).split(separator: "\n").map(String.init)
      cached[pack.path] = (metadata?.contentModificationDate, metadata?.fileSize, files)
      return files
    }
  }
  private static let graphicArchiveIndex = GraphicArchiveIndex()

  /// Read only assets beside the level or at the archive root. Never extract paths.
  private static func graphicData(_ name: String, entry: Entry, pack: URL) throws -> Data? {
    let parent = (entry.file as NSString).deletingLastPathComponent
    let candidates = parent.isEmpty ? [name] : [parent + "/" + name, name]
    let files = graphicArchiveIndex.files(in: pack)
    for candidate in candidates {
      let matches = files.filter { $0.lowercased() == candidate.lowercased() }
      guard matches.count <= 1 else { throw ClassicGraphicsError.missingFile("Unambiguous " + candidate) }
      if let path = matches.first {
        guard let data = contents(of: path, in: pack) else { throw ClassicGraphicsError.missingFile(path) }
        return data
      }
    }
    return nil
  }

  // MARK: - Reading zips

  private static func contents(of entry: String, in pack: URL) -> Data? {
    // unzip treats member arguments as patterns, even without a shell.
    // Duplicate names would concatenate records instead of selecting one file.
    guard graphicArchiveIndex.files(in: pack).filter({ $0 == entry }).count == 1 else { return nil }
    let literal = entry.reduce(into: "") { result, character in
      if "*?[]\\".contains(character) { result.append("\\") }
      result.append(character)
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-p", pack.path, literal]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return nil }
    var out = Data()
    while let chunk = try? pipe.fileHandleForReading.read(upToCount: 64 * 1024), !chunk.isEmpty {
      guard out.count + chunk.count <= 4 * 1024 * 1024 else {
        process.terminate(); try? pipe.fileHandleForReading.close(); process.waitUntilExit()
        return nil
      }
      out.append(chunk)
    }
    process.waitUntilExit()
    return process.terminationStatus == 0 && !out.isEmpty ? out : nil
  }

  private struct ShellResult {
    let output: String
    let status: Int32?
  }

  private static func shellResult(_ arguments: [String]) -> ShellResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: arguments[0])
    process.arguments = Array(arguments.dropFirst())
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return ShellResult(output: "", status: nil) }
    let out = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return ShellResult(
      output: String(decoding: out, as: UTF8.self),
      status: process.terminationStatus)
  }

  private static func shell(_ arguments: [String]) -> String {
    shellResult(arguments).output
  }
}
