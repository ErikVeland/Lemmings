import Foundation

/// Shared navigation for the three native engines. Each engine owns its saves
/// and completion rules. The library only accepts their reported progress.
public struct UnifiedGameLibrary: Sendable {
    public struct Entry: Equatable, Sendable {
        public let title: ClassicTitle
        public let total: Int
        public let passed: Int
        public let available: Bool
        public let detail: String

        public init(title: ClassicTitle, total: Int, passed: Int = 0,
                    available: Bool = true, detail: String = "") {
            self.title = title
            self.total = max(0, total)
            self.passed = min(max(0, passed), max(0, total))
            self.available = available
            self.detail = detail
        }
        public var isComplete: Bool { available && total > 0 && passed == total }
    }
    public enum Mode: Equatable, Sendable { case quest, singleTitle }
    public enum Destination: Equatable, Sendable {
        case title(ClassicTitle), library, questComplete
    }
    public let entries: [Entry]
    public init(entries: [Entry]) {
        self.entries = entries.sorted { $0.title.canonOrder < $1.title.canonOrder }
    }
    public var installed: [Entry] { entries.filter(\.available) }
    public var passed: Int { installed.reduce(0) { $0 + $1.passed } }
    public var total: Int { installed.reduce(0) { $0 + $1.total } }
    public var questStart: ClassicTitle? {
        installed.first(where: { !$0.isComplete })?.title ?? installed.first?.title
    }
    public func next(after title: ClassicTitle, mode: Mode) -> Destination {
        guard mode == .quest else { return .library }
        guard let entry = installed.first(where: { $0.title == title }), entry.isComplete else { return .library }
        if let next = installed.first(where: { $0.title.canonOrder > title.canonOrder }) {
            return .title(next.title)
        }
        return installed.allSatisfy(\.isComplete) ? .questComplete : .library
    }
}
