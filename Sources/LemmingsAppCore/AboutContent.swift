import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AboutContent: Sendable {
    public let heritage: String?
    public let versionHistory: String?
    public let contributors: String?

    public static let contributorCacheKey = "ContributorsMarkdownV1"
    public static let contributorsURL = URL(string: "https://glasscode.academy/lemmings-api/v1/contributors.md")!
    public static let forumsURL = URL(string: "https://www.lemmingsforums.net/")!

    public init(heritage: String? = nil, versionHistory: String? = nil, contributors: String? = nil) {
        self.heritage = heritage
        self.versionHistory = versionHistory
        self.contributors = contributors
    }

    public init(resources: URL) {
        func bundled(_ name: String) -> String? {
            guard let markdown = try? String(contentsOf: resources.appendingPathComponent("About")
                .appendingPathComponent(name), encoding: .utf8),
                !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return markdown
        }
        self.init(heritage: bundled("Heritage.md"), versionHistory: bundled("VersionHistory.md"),
                  contributors: bundled("Contributors.md"))
    }

    public static func loadContributors() async throws -> String {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.urlCache = nil
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        let request = URLRequest(url: contributorsURL, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 8)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        return try validatedContributors(data: data, response: response)
    }

    static func validatedContributors(data: Data, response: URLResponse) throws -> String {
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.url?.scheme == "https", data.count <= 65_536,
              let markdown = String(data: data, encoding: .utf8),
              !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw URLError(.badServerResponse) }
        return markdown
    }

    public struct Release: Equatable, Sendable {
        public let title: String
        public let markdown: String
        public let indexTitle: String
    }

    public static func releases(markdown: String) -> [Release] {
        var entries: [(title: String, markdown: String)] = []
        for line in markdown.components(separatedBy: "\n") {
            if line.hasPrefix("# ") {
                entries.append((String(line.dropFirst(2)), line + "\n"))
            } else if !entries.isEmpty {
                entries[entries.count - 1].markdown += line + "\n"
            }
        }
        func version(_ title: String) -> String {
            title.components(separatedBy: " · ").first ?? title
        }
        let counts = Dictionary(grouping: entries, by: { version($0.title) }).mapValues(\.count)
        return entries.map { entry in
            let shared = version(entry.title)
            let build = entry.title.components(separatedBy: " · Build ").last
            let indexTitle: String
            if (counts[shared] ?? 0) > 1, let build, build != entry.title {
                indexTitle = "\(shared) (\(build))"
            } else {
                indexTitle = shared
            }
            return Release(title: entry.title, markdown: entry.markdown, indexTitle: indexTitle)
        }
    }

    public struct Paragraph: Equatable, Sendable {
        public let text: String
        public let heading: Bool
        public let title: Bool
        public let bullet: Bool
    }

    public static func paragraphs(markdown: String) -> [Paragraph] {
        var paragraphs: [Paragraph] = []
        var pending: [String] = []
        func plain(_ text: String) -> String {
            text.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^\\)]+\\)", with: "$1", options: .regularExpression)
                .replacingOccurrences(of: "**", with: "")
        }
        func append(_ text: String, heading: Bool = false, title: Bool = false, bullet: Bool = false) {
            paragraphs.append(Paragraph(text: plain(text), heading: heading, title: title, bullet: bullet))
        }
        func flush() {
            guard !pending.isEmpty else { return }
            append(pending.joined(separator: " "))
            pending.removeAll()
        }
        var continuesList = false
        for line in markdown.components(separatedBy: "\n") {
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                flush()
                continuesList = false
            } else if text.hasPrefix("#") {
                flush()
                continuesList = false
                append(text.replacingOccurrences(of: "^#{1,6} +", with: "", options: .regularExpression),
                       heading: true, title: text.hasPrefix("# "))
            } else if text.hasPrefix("- ") || text.hasPrefix("* ") {
                flush()
                append(String(text.dropFirst(2)), bullet: true)
                continuesList = true
            } else if continuesList, let last = paragraphs.last {
                paragraphs[paragraphs.count - 1] = Paragraph(text: last.text + " " + plain(text),
                    heading: last.heading, title: last.title, bullet: last.bullet)
            } else {
                pending.append(text)
            }
        }
        flush()
        return paragraphs
    }
}
