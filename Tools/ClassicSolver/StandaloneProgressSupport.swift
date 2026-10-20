#if CLASSIC_SOLVER_STANDALONE
import Foundation
import NxlvKit

enum GameProgressPreferences {
  static func fanIdentifier(pack: URL, label: String) -> String {
    let packKey = ClassicFanPack.packID(pack).map { "catalogue:\($0)" }
      ?? "file:" + pack.lastPathComponent.lowercased()
    return "v2|" + packKey + "|" + label
  }
}
#endif
