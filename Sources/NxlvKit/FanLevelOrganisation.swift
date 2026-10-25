import Foundation

/// Browsing groups never replace the pack and level identities used by saves.
public enum FanLevelOrganisation {
    public static let maximumRows = 10

    public struct Pack: Equatable, Sendable {
        public let id: String
        public let title: String
        public init(id: String, title: String) { self.id = id; self.title = title }
    }

    public struct Group: Equatable, Sendable {
        public let id: String
        public let title: String
        public let packID: String?
        public let children: [Group]
        public var packIDs: [String] { packID.map { [$0] } ?? children.flatMap(\.packIDs) }

        public func group(at path: [String]) -> Group? {
            guard let first = path.first else { return self }
            return children.first { $0.id == first }?.group(at: Array(path.dropFirst()))
        }
    }

    private enum Category: String, CaseIterable {
        case learning, magazines, fan, community, ports
        var title: String {
            switch self {
            case .learning: L10n.text("Learning")
            case .magazines: L10n.text("Magazines & books")
            case .fan: L10n.text("Fan levels")
            case .community: L10n.text("Contests & community")
            case .ports: L10n.text("Ports & remakes")
            }
        }
    }

    public static func library(_ packs: [Pack], query: String = "") -> Group {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let unique = Dictionary(packs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let matches = unique.values.filter { query.isEmpty || $0.title.localizedStandardContains(query) }
        let categories = Category.allCases.compactMap { category -> Group? in
            let members = matches.filter { categoryFor($0.title) == category }
            guard !members.isEmpty else { return nil }
            let families = Dictionary(grouping: members) { series($0.title).lowercased() }
            let groups = families.map { key, packs -> Group in
                let ordered = packs.sorted { precedes($0.title, $1.title, tie: $0.id < $1.id) }
                let leaves = ordered.map { Group(id: "pack:" + $0.id, title: $0.title, packID: $0.id, children: []) }
                guard leaves.count > 1 else { return leaves[0] }
                return Group(id: "series:" + key, title: series(ordered[0].title), packID: nil,
                             children: bounded(leaves))
            }.sorted { precedes($0.title, $1.title, tie: $0.id < $1.id) }
            return Group(id: category.rawValue, title: category.title, packID: nil, children: bounded(groups))
        }
        return Group(id: "root", title: L10n.text("Fan Lemmings"), packID: nil, children: categories)
    }

    private static func precedes(_ lhs: String, _ rhs: String, tie: Bool) -> Bool {
        let order = lhs.lowercased().compare(rhs.lowercased(), options: .numeric)
        return order == .orderedSame ? tie : order == .orderedAscending
    }

    /// Alphabetical ranges also bound large series and future downloaded collections.
    private static func bounded(_ groups: [Group]) -> [Group] {
        guard groups.count > maximumRows else { return groups }
        let bands = ["0 - 9", "A - D", "E - H", "I - L", "M - P", "Q - T", "U - Z", "#"]
        func initial(_ title: String) -> String {
            String(title.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .prefix(1)).uppercased()
        }
        func band(_ title: String) -> String {
            let letter = initial(title)
            if let first = letter.first, first.isNumber { return bands[0] }
            for label in bands.dropFirst().dropLast() {
                if let first = label.first, let last = label.last, letter >= String(first), letter <= String(last) { return label }
            }
            return "#"
        }
        let byBand = Dictionary(grouping: groups) { band($0.title) }
        if byBand.count > 1 {
            return bands.compactMap { label in
                guard let members = byBand[label] else { return nil }
                return Group(id: "range:" + label, title: label, packID: nil, children: bounded(members))
            }
        }
        let letters = Dictionary(grouping: groups) { initial($0.title) }
        if letters.count > 1, letters.count <= maximumRows {
            return letters.keys.sorted().map { label in
                Group(id: "letter:" + label, title: label, packID: nil, children: bounded(letters[label]!))
            }
        }
        let size = Int(ceil(Double(groups.count) / Double(maximumRows)))
        return stride(from: 0, to: groups.count, by: size).map { start in
            let members = Array(groups[start..<min(start + size, groups.count)])
            let first = members[0], last = members[members.count - 1]
            let a = String(first.title.prefix(1)).uppercased(), b = String(last.title.prefix(1)).uppercased()
            let title = a == b ? first.title + " - " + last.title : a + " - " + b
            return Group(id: "range:" + first.id, title: title, packID: nil, children: bounded(members))
        }
    }

    private static func categoryFor(_ title: String) -> Category {
        let name = title.lowercased()
        if name == "tut" || name.contains("tutorial") || name.contains("practice") || name.contains("training") { return .learning }
        if name.contains("magazine") || name.contains("book club") || name.contains("book-club")
            || name.contains("official companion") || name == "save the lemmings" { return .magazines }
        if name.contains("contest") || name.contains("competition") || name.contains("level jam")
            || name.contains("level design game") || name == "comppak" || name == "justdigcomp"
            || name == "group levels" { return .community }
        if name.hasPrefix("dos ") || name.hasPrefix("[dos") || name.hasPrefix("amiga ") || name.hasPrefix("[amiga")
            || name.hasPrefix("genesis ") || name.hasPrefix("[genesis") || name.hasPrefix("psp special")
            || name.contains("remake") || name == "orig extra levels" { return .ports }
        return .fan
    }

    private static func series(_ title: String) -> String {
        let lower = title.lowercased()
        // Archive spelling and suffix variants of the same authored collection.
        let aliases: [(String, String)] = [
            ("geoo", "geoo"), ("elfpak", "elfpack"), ("elfpack", "elfpack"),
            ("timpack", "Timpack"), ("clamspamxmas", "ClamSpam Xmas"), ("clamspam", "ClamSpam"),
            ("grams88", "grams88"), ("lemmy556", "Lemmy556"), ("lemmy 556", "Lemmy556"),
            ("lemmings platinum", "Lemmings Platinum"), ("psp special", "PSP Special"),
            ("killermasters lemmings", "KillerMaster's Lemmings"),
            ("killermaster's lemmings", "KillerMaster's Lemmings"),
            ("ssam1221", "ssam1221's Lemmings"), ("van clan", "Van Clan"),
            ("deceit", "Deceit's Lemmings"), ("oh no more clemmings", "Oh No! More cLemmings"),
            ("oh no! more clemmings", "Oh No! More cLemmings"), ("holiday clemmings", "Holiday cLemmings"),
            ("clemmings ultimate", "cLemmings Ultimate Edition"), ("clemmings", "cLemmings"),
            ("pieuws lemmings 2007", "Pieuw's Lemmings 2007"), ("pieuw's lemmings 2007", "Pieuw's Lemmings 2007"),
            ("ji hoon", "Ji Hoon's Lemmings Remake"), ("lemmings plus dos project", "Lemmings Plus DOS Project"),
            ("dos amiga", "DOS / Amiga"), ("[dos/amiga]", "DOS / Amiga"),
            ("dos ", "DOS"), ("[dos]", "DOS"), ("amiga ", "Amiga"), ("[amiga]", "Amiga"),
            ("genesis ", "Genesis"), ("[genesis]", "Genesis")
        ]
        if let alias = aliases.first(where: { lower.hasPrefix($0.0) }) { return alias.1 }
        var stem = title.replacingOccurrences(of: "_", with: " ")
        for pattern in [#"(?i)\s*\(?version\s*\d+\)?$"#, #"(?i)\s*\(v\d+\)$"#,
                        #"(?i)[\s#(\-]*\d+\)?(?:dos|n|b|\s+preview)?$"#] {
            stem = stem.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        stem = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        // A numeric title is a title, not an empty series name.
        return stem.isEmpty ? title : stem
    }
}
