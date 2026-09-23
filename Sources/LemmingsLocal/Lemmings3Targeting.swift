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
  let active: Bool
}

/// Picks which lemming a click or hover point resolves to.
///
/// `Lemmings3PlayWindow.assign(x:y:)` calls this, so hover and click agree.
/// Pulling the decision out here lets it run without an AppKit window.
enum Lemmings3Targeting {
  static func nearest(
    among candidates: [Lemmings3TargetCandidate], x: Int, y: Int,
    selected: Int, favorApproaching: Bool
  ) -> Lemmings3TargetCandidate? {
    let nearby = candidates.filter { $0.active && abs($0.x - x) <= 9 && abs($0.y - 8 - y) <= 12 }
    return nearby.min(by: {
      if selected >= 3, ($0.tool == nil) != ($1.tool == nil) { return $0.tool != nil }
      if favorApproaching {
        let approachingA = (x - $0.x) * $0.direction >= 0
        let approachingB = (x - $1.x) * $1.direction >= 0
        if approachingA != approachingB { return approachingA }
      }
      return abs($0.x - x) + abs($0.y - 8 - y) < abs($1.x - x) + abs($1.y - 8 - y)
    })
  }
}
