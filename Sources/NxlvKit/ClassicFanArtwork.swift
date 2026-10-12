import Foundation

/// Piece matching shared by native and mobile fan artwork.
public enum ClassicFanArtwork {
    private static let artworkReleases = [
        ("holiday_native_1994", "holiday"), ("lemmings_dos_1991-07-30", "lemmings"),
        ("oh_no_more_lemmings_dos-1991-11-14_2232", "ohno"),
        ("xmas_dos_XmasLemmingsV1.9", "xmas"), ("xmas_dos_XmasLemmingsV1.9a1", "xmas")
    ]
    private static func stockGround(style: Int, folder: String, portsRoot: URL) -> ClassicGroundSet? {
        try? ClassicGroundSet.load(style: style, from: portsRoot.appendingPathComponent(folder))
    }
  /// The release artwork a fan level may borrow, and which of its pieces.
  public struct ArtworkMatch: Equatable {
    public let family: String
    public let pieces: ClassicMacPieceMatch
  }

  /// Finds the release a pack's ground set was derived from, piece by piece.
  ///
  /// Changed pieces are reconstructed from the pack's source pixels. A changed
  /// palette prevents stock pixels from replacing any of the pack's pieces.
  public static func artworkMatch(for level: ClassicLevel, ground: ClassicGroundSet,
    special: ClassicSpecialGraphic?, portsRoot: URL,
    stockGrounds: [String: ClassicGroundSet]? = nil) -> ArtworkMatch? {
    guard (0..<5).contains(ground.style) else { return nil }
    var best: (family: String, pieces: ClassicMacPieceMatch,
      share: Double, samePalette: Int, total: Int)?
    for (folder, family) in artworkReleases {
      let stock = stockGrounds != nil ? stockGrounds?[folder]
        : stockGround(style: ground.style, folder: folder, portsRoot: portsRoot)
      guard let stock else { continue }
      let structural = ClassicMacPieceMatch(
        terrain: Set(ground.terrain.compactMap { id, graphic in
          stock.terrain[id] == graphic ? id : nil
        }),
        objects: Set(ground.objects.compactMap { id, graphic in
          guard let original = stock.objects[id],
            graphic.width == original.width && graphic.height == original.height,
            graphic.frames == original.frames,
            graphic.animationType == original.animationType,
            graphic.firstFrameIndex == original.firstFrameIndex else { return nil }
          return id
        }))
      let pieces = ClassicMacPieceMatch.compare(ground, with: stock)
        ?? ClassicMacPieceMatch(terrain: [], objects: [])
      let share = structural.share(of: level) ?? 1
      let samePalette = ground.terrainPalette == stock.terrainPalette
        && ground.objectPalette == stock.objectPalette ? 1 : 0
      // Prefer the release whose source shapes the level actually uses.
      let total = structural.terrain.count + structural.objects.count
      if let held = best,
        (share, samePalette, total) <= (held.share, held.samePalette, held.total) { continue }
      best = (family, pieces, share, samePalette, total)
    }
    let fallbackFamily: String
    switch level.groundStyle {
    case 5...8: fallbackFamily = "ohno"
    case 9: fallbackFamily = "holiday"
    default: fallbackFamily = "lemmings"
    }
    var selected = best.flatMap { $0.total > 0 ? ArtworkMatch(family: $0.family, pieces: $0.pieces) : nil }
      ?? ArtworkMatch(family: fallbackFamily, pieces: ClassicMacPieceMatch(terrain: [], objects: []))
    if level.specialStyle > 0 {
      if selected.family != "lemmings" {
        selected = ArtworkMatch(family: "lemmings", pieces: ClassicMacPieceMatch(terrain: [], objects: []))
      }
      if let special,
        let stock = try? ClassicSpecialGraphic.load(index: level.specialStyle - 1,
          from: portsRoot.appendingPathComponent("lemmings_dos_1991-07-30")),
        special == stock {
        var pieces = selected.pieces
        pieces.special = true
        selected = ArtworkMatch(family: selected.family, pieces: pieces)
      }
    }
    return selected
  }

}
