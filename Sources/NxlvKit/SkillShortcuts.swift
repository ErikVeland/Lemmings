/// Number and letter bindings for the skills in the current level.
public struct SkillShortcuts {
    public let letters: [String?]

    public init(names: [String], reserved: String = "zqnrpfx") {
        var used = Set(reserved.map(String.init))
        var result = [String?](repeating: nil, count: names.count)
        let candidates = names.map { $0.lowercased().filter { $0.isASCII && $0.isLetter }.map(String.init) }
        // Assign initials first so a fallback cannot take another skill's initial.
        for index in names.indices {
            if let first = candidates[index].first, used.insert(first).inserted { result[index] = first }
        }
        for index in names.indices where result[index] == nil {
            let available = candidates[index] + "abcdefghijklmnopqrstuvwxyz".map(String.init)
            if let letter = available.first(where: { !used.contains($0) }) {
                result[index] = letter
                used.insert(letter)
            }
        }
        letters = result
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
            if modern, let letter = letters[index] { keys.append(letter.uppercased()) }
            return names[index] + " (" + keys.joined(separator: "/") + ")"
        }.joined(separator: ", ")
    }
}
