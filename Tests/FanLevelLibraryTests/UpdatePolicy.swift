import Foundation

/**
 * Checks download policy with an isolated catalogue and no network access.
 */
func runUpdatePolicyTests(root: URL) async throws {
  let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("FanUpdatePolicy-\(UUID().uuidString)")
  defer { try? FileManager.default.removeItem(at: temporary) }
  let blockedServer = Server([:])
  let blocked = await FanLevelUpdates(delay: 0, fetch: { try await blockedServer.fetch($0, $1) })
    .check(existing: [], destination: temporary, allowedPackIDs: [])
  let blockedPaths = await blockedServer.paths
  check(blocked.added == 0 && !blocked.unavailable && blockedPaths.isEmpty
    && !FileManager.default.fileExists(atPath: temporary.path),
    "an empty reviewed catalogue makes no requests or content changes")

  let archive = try Data(contentsOf: root.appendingPathComponent("Tests/FanLevelLibraryTests/Fixtures/literal-members.zip"))
  let unreviewed = Data(#"<a href="/levelpack/999/Unreviewed">Unreviewed</a><a rel="next">Next</a>"#.utf8)
  let reviewed = Data(#"<a href="/levelpack/900/Reviewed">Reviewed</a><a href="/levelpack/998/Not-Allowed">Other</a>"#.utf8)
  let page = Data(#"<a href="/levelpack/download/900/Reviewed">Download</a>"#.utf8)
  let server = Server(["/levelpack/list?sort=-date&page=1": unreviewed,
    "/levelpack/list?sort=-date&page=2": reviewed,
    "/levelpack/900/Reviewed": page, "/levelpack/download/900/Reviewed": archive])
  let result = await FanLevelUpdates(delay: 0, fetch: { try await server.fetch($0, $1) })
    .check(existing: [], destination: temporary, allowedPackIDs: [900])
  let paths = await server.paths
  check(result.added == 1 && !result.unavailable
    && paths == ["/levelpack/list?sort=-date&page=1", "/levelpack/list?sort=-date&page=2",
                 "/levelpack/900/Reviewed", "/levelpack/download/900/Reviewed"],
    "reviewed packs remain discoverable after a page of unapproved packs")
  let files = try FileManager.default.contentsOfDirectory(atPath: temporary.path)
  check(files == ["0900-Reviewed.zip"] && result.counts["catalogue:900"] == 10,
    "only the explicitly reviewed archive enters the collection")
}
