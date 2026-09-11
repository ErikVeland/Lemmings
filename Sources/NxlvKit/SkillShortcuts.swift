/// Number and letter bindings for the skills in the current level.
public struct SkillShortcuts {
    public let letters: [String?]
    /// The first letter of each skill name, before any fallback. Several skills
    /// can share one, which is what lets a repeated press cycle through them.
    public let initials: [String?]

    /// Skills whose own initial is reserved for a game control get a mnemonic
    /// rather than the next letter of their name. F is fast-forward, so a
    /// floater takes U for umbrella.
    public static let preferredLetters: [String: String] = ["floater": "u"]

    /// `i` is reserved because it opens the level hints. Without it a skill can be
    /// handed `i` as a fallback and its shortcut silently stops working.
    public init(names: [String], reserved: String = "zqnrpfxi") {
        var used = Set(reserved.map(String.init))
        var result = [String?](repeating: nil, count: names.count)
        let candidates = names.map { $0.lowercased().filter { $0.isASCII && $0.isLetter }.map(String.init) }
        // Assign initials first so a fallback cannot take another skill's initial.
        for index in names.indices {
            if let first = candidates[index].first, used.insert(first).inserted { result[index] = first }
        }
        for index in names.indices where result[index] == nil {
            let preferred = Self.preferredLetters[names[index].lowercased()].map { [$0] } ?? []
            let available = preferred + candidates[index] + "abcdefghijklmnopqrstuvwxyz".map(String.init)
            if let letter = available.first(where: { !used.contains($0) }) {
                result[index] = letter
                used.insert(letter)
            }
        }
        letters = result
        initials = candidates.map { $0.first }
    }

    /// Resolves a key press, cycling when several skills share an initial.
    ///
    /// Four skills begin with B. Binding B to one of them and pushing the rest
    /// onto unrelated letters is worse than letting B step through all four, so
    /// a repeated press moves to the next one that starts with that letter.
    public func index(for key: String, current: Int?, modern: Bool = true) -> Int? {
        let key = key.lowercased()
        guard key.count == 1 else { return nil }
        // A digit always names one skill outright.
        if Int(key) != nil { return index(for: key, modern: modern) }
        guard modern else { return nil }
        let sharing = initials.indices.filter { initials[$0] == key }
        guard sharing.count > 1 else { return index(for: key, modern: modern) }
        if let current, let position = sharing.firstIndex(of: current) {
            return sharing[(position + 1) % sharing.count]
        }
        return sharing.first
    }

    public static func cycle(from current: Int, direction: Int, available: [Bool]) -> Int? {
        guard !available.isEmpty else { return nil }
        for step in 1...available.count {
            let index = ((current + (direction < 0 ? -step : step)) % available.count + available.count) % available.count
            if available[index] { return index }
        }
        return nil
    }

    public func index(for key: String, modern: Bool = true) -> Int? {
        let key = key.lowercased()
        guard key.count == 1 else { return nil }
        if let digit = Int(key) {
            let index = digit == 0 ? 9 : digit - 1
            return letters.indices.contains(index) ? index : nil
        }
        return modern ? letters.firstIndex { $0 == key } : nil
    }

    public func hint(names: [String], modern: Bool = true) -> String {
        names.indices.map { index in
            var keys: [String] = index < 10 ? [String((index + 1) % 10)] : []
            let shared = initials[index].map { initial in
                initials.filter { $0 == initial }.count > 1
            } ?? false
            if modern, let letter = shared ? initials[index] : letters[index] {
                keys.append(letter.uppercased())
            }
            return names[index] + " (" + keys.joined(separator: "/") + ")"
        }.joined(separator: ", ")
    }
}
