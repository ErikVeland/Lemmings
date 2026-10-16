/**
 * Returns every triggered actor once, ordered by trigger kind and actor ID.
 */
func uniqueDecisionActors(_ fired: [(Int, Int)]) -> [Int] {
    var offered: [Int] = []
    for (_, id) in fired.sorted(by: {
        $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0
    }) where !offered.contains(id) {
        offered.append(id)
    }
    return offered
}
