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
  var isBlocking = false
  var canAssignSelected = true
}

/// Picks which lemming a click or hover point resolves to.
///
/// `Lemmings3PlayWindow.assign(x:y:)` and `Lemmings3Canvas.pointerTarget`
/// both call this, so click, hover and keyboard/gamepad assignment agree.
/// Pulling the decision out here lets it run without an AppKit window.
enum Lemmings3Targeting {
  static func nearest(
    among candidates: [Lemmings3TargetCandidate], x: Int, y: Int,
    selected: Int, favorApproaching: Bool, favorBombBlockers: Bool = false, favorBuilders: Bool = false
  ) -> Lemmings3TargetCandidate? {
    let nearby = candidates.filter { $0.active && abs($0.x - x) <= 9 && abs($0.y - 8 - y) <= 12 }
    func distance(_ c: Lemmings3TargetCandidate) -> Int { abs(c.x - x) + abs(c.y - 8 - y) }
    func nearer(_ a: Lemmings3TargetCandidate, _ b: Lemmings3TargetCandidate) -> Bool {
      let da = distance(a), db = distance(b)
      return da == db ? a.id < b.id : da < db
    }
    // L3 uses carried tools through Use, rather than separate Bomb and Build buttons.
    if selected == 3 {
      if favorBombBlockers, let blocker = nearby.filter({
        $0.canAssignSelected && $0.isBlocking && ($0.tool == .bomb || $0.tool == .grenade)
      }).min(by: nearer) { return blocker }
      if favorBuilders, let builder = nearby.filter({
        $0.canAssignSelected && $0.isBuilding && $0.tool == .bricks
      }).min(by: nearer) { return builder }
    }
    guard let nearest = nearby.min(by: { a, b in
      if a.canAssignSelected != b.canAssignSelected { return a.canAssignSelected }
      if selected >= 3, (a.tool == nil) != (b.tool == nil) { return a.tool != nil }
      let da = distance(a), db = distance(b)
      return da == db ? a.id < b.id : da < db
    }) else { return nil }
    if favorApproaching, selected < 3, nearest.isBuilding,
       let follower = nearby.filter({ $0.canAssignSelected && isApproaching($0, clickX: x) && isBehind($0, builder: nearest) }).min(by: {
         let da = distance($0), db = distance($1)
         return da == db ? $0.id < $1.id : da < db
       }) {
      return follower
    }
    guard favorApproaching, (x - nearest.x) * nearest.direction < 0 else { return nearest }
    let approaching = nearby.filter {
      (x - $0.x) * $0.direction >= 0 && $0.direction != nearest.direction
        && $0.canAssignSelected == nearest.canAssignSelected
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

extension Lemmings3Runtime {
    func target(x: Int, y: Int, selected: Int, favorApproaching: Bool,
                favorBombBlockers: Bool, favorBuilders: Bool) -> Lemmings3TargetCandidate? {
        guard Action.allCases.indices.contains(selected) else { return nil }
        let candidates = lemmings.map {
            Lemmings3TargetCandidate(id: $0.id, x: $0.x, y: $0.y, direction: $0.direction, tool: $0.tool,
                isBuilding: $0.state == .building, active: $0.active, isBlocking: $0.state == .blocking,
                canAssignSelected: canAssign(Action.allCases[selected], to: $0.id))
        }
        return Lemmings3Targeting.nearest(among: candidates, x: x, y: y, selected: selected,
            favorApproaching: favorApproaching, favorBombBlockers: favorBombBlockers, favorBuilders: favorBuilders)
    }

    func canAssign(_ action: Action, to id: Int) -> Bool {
        guard !isComplete, let lem = lemmings.first(where: { $0.id == id && $0.active }) else { return false }
        if action == .walker && [.climbing, .shimmying].contains(lem.state) { return true }
        if action == .walker && lem.state == .swimming { return lem.tool == .swimmer && lem.quantity >= 2 }
        guard [.walking, .blocking, .building, .digging].contains(lem.state), isSolid(lem.x, lem.y) else { return false }
        switch action {
        case .walker, .jumper: return true
        case .blocker: return lem.state != .blocking
        case .drop: return lem.tool != nil
        case .use:
            guard let tool = lem.tool, lem.quantity > 0 else { return false }
            return [.bricks, .spade, .sucker, .shimmy, .bomb, .grenade, .hadoken].contains(tool)
        }
    }

}
