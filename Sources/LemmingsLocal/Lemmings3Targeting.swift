import NxlvKit

/// One lemming as the click-targeting decision needs to see it.
///
/// `Lemmings3Runtime.Lemming` has no public initializer, so this local,
/// freely-constructible shape lets tests build fixtures directly.
struct Lemmings3TargetCandidate {
  let id: Int
  let x: Int
  let y: Int
  let direction: Int
  let tool: Lemmings3Runtime.Tool?
  let isBuilding: Bool
  let active: Bool
}

/// Picks which lemming a click or hover point resolves to.
///
/// `Lemmings3PlayWindow.assign(x:y:)` and `Lemmings3Canvas.pointerTarget`
/// both call this, so click, hover and keyboard/gamepad assignment agree.
/// Pulling the decision out here lets it run without an AppKit window.
enum Lemmings3Targeting {
  static func nearest(
    among candidates: [Lemmings3TargetCandidate], x: Int, y: Int,
    selected: Int, favorApproaching: Bool
  ) -> Lemmings3TargetCandidate? {
    let nearby = candidates.filter { $0.active && abs($0.x - x) <= 9 && abs($0.y - 8 - y) <= 12 }
    func distance(_ c: Lemmings3TargetCandidate) -> Int { abs(c.x - x) + abs(c.y - 8 - y) }
    guard let nearest = nearby.min(by: { a, b in
      if selected >= 3, (a.tool == nil) != (b.tool == nil) { return a.tool != nil }
      let da = distance(a), db = distance(b)
      return da == db ? a.id < b.id : da < db
    }) else { return nil }
    if favorApproaching, selected < 3, nearest.isBuilding,
       let follower = nearby.filter({ isApproaching($0, clickX: x) && isBehind($0, builder: nearest) }).min(by: {
         let da = distance($0), db = distance($1)
         return da == db ? $0.id < $1.id : da < db
       }) {
      return follower
    }
    guard favorApproaching, (x - nearest.x) * nearest.direction < 0 else { return nearest }
    let approaching = nearby.filter {
      (x - $0.x) * $0.direction >= 0 && $0.direction != nearest.direction
        && (selected < 3 || ($0.tool == nil) == (nearest.tool == nil))
    }.min { a, b in
      let da = distance(a), db = distance(b)
      return da == db ? a.id < b.id : da < db
    }
    return approaching ?? nearest
  }

  private static func isApproaching(_ lemming: Lemmings3TargetCandidate, clickX: Int) -> Bool {
    (clickX - lemming.x) * lemming.direction >= 0
  }

  private static func isBehind(_ lemming: Lemmings3TargetCandidate, builder: Lemmings3TargetCandidate) -> Bool {
    lemming.direction == builder.direction &&
      (builder.direction > 0 ? lemming.x < builder.x : lemming.x > builder.x)
  }
}
