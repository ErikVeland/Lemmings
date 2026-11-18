import Foundation
import LemmingsMobileCore

private enum CheckFailure: Error { case failed(String) }

private func check(_ condition: Bool, _ message: String) throws {
    if !condition { throw CheckFailure.failed(message) }
}

private func rejects(_ operation: () throws -> Void) throws {
    do { try operation() } catch { return }
    throw CheckFailure.failed("An invalid transfer was accepted")
}

private func pureChecks() throws {
    for path in ["../MAIN.DAT", "/MAIN.DAT", "a//b", "a/./b", "a/../b", "a\\b", ".hidden",
                 "a/\u{0}b", "a\nb", "a/.hidden/b", String(repeating: "x", count: 256)] {
        try rejects { _ = try LocalImportManifest(files: [.init(path: path, bytes: 1)]).validated() }
    }
    for files in [
        [LocalImportFile(path: "MAIN.DAT", bytes: 1), .init(path: "main.dat", bytes: 1)],
        [.init(path: "a", bytes: 1), .init(path: "a/b", bytes: 1)],
        [.init(path: "MAIN.DAT", bytes: -1)],
        [.init(path: "MAIN.DAT", bytes: LocalImportManifest.maximumFileBytes + 1)]
    ] {
        try rejects { _ = try LocalImportManifest(files: files).validated() }
    }
    let request = "POST /ABC/start HTTP/1.1\r\nHost: 127.0.0.1:9999\r\nContent-Length: 2\r\n\r\n{}"
    let decoded = try LocalImportHTTPHead.decode(Data(request.utf8))
    try check(decoded?.contentLength == 2 && decoded?.method == "POST", "The valid HTTP body length changed")
    try check(try LocalImportHTTPHead.decode(Data("GET / HTTP/1.1\r\n".utf8)) == nil,
              "An incomplete header was accepted")
    for fields in [
        "Content-Length: 1\r\nContent-Length: 2", "Content-Length: 1\r\ncontent-length: 1",
        "Content-Length: +2", "Content-Length: 999999999999999999999999",
        "Transfer-Encoding: chunked", "Content-Encoding: gzip", "Expect: 100-continue", " Folded: bad"
    ] {
        try rejects {
            _ = try LocalImportHTTPHead.decode(Data(("POST / HTTP/1.1\r\nHost: local\r\n" + fields + "\r\n\r\n").utf8))
        }
    }
    try rejects { _ = try LocalImportHTTPHead.decode(Data(repeating: 65, count: 8_193)) }
    try rejects {
        _ = try LocalImportManifest(files: (0..<10_000).map {
            LocalImportFile(path: "folder\($0)/nested/MAIN.DAT", bytes: 0)
        }).validated()
    }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lemmix-transfer-tests-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let transfer = try LocalImportTransferSession(
        manifest: .init(files: [.init(path: "MAIN.DAT", bytes: 4), .init(path: "LEVELS/ONE.DAT", bytes: 0)]),
        stagingRoot: root)
    try rejects { _ = try transfer.completeDirectory() }
    try rejects { try transfer.append(Data([1]), file: 0, offset: 1) }
    try rejects { try transfer.append(Data(repeating: 0, count: 5), file: 0, offset: 0) }
    try transfer.append(Data([1, 2]), file: 0, offset: 0)
    try rejects { try transfer.append(Data([2]), file: 0, offset: 0) }
    try transfer.append(Data([3, 4]), file: 0, offset: 2)
    let complete = try transfer.completeDirectory()
    try check(try Data(contentsOf: complete.appendingPathComponent("MAIN.DAT")) == Data([1, 2, 3, 4]),
              "Chunks did not retain their order")
    try check(transfer.receivedBytes == 4, "Transfer byte accounting changed")
    transfer.cancel()
    try check(!FileManager.default.fileExists(atPath: complete.path), "Cancelled staging files remain")
    print("PASS transfer path/collision/limit guards, strict HTTP headers, ordered chunks, completion and cleanup")
}

@MainActor private func serverChecks() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lemmix-server-tests-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let received = root.appendingPathComponent("received.dat")
    let helper = root.appendingPathComponent("helper.zip")
    try Data([7, 8, 9]).write(to: helper)
    let server = TVGameImportServer(importDirectory: { directory in
        let bytes = try Data(contentsOf: directory.appendingPathComponent("MAIN.DAT"))
        guard bytes == Data([1, 2, 3, 4]) else { throw CheckFailure.failed("The browser changed file bytes") }
        try bytes.write(to: received)
    }, helperURL: helper, address: "127.0.0.1")
    defer { server.stop() }
    let ready: URL = try await withCheckedThrowingContinuation { continuation in
        var resumed = false
        server.onState = { state in
            guard !resumed else { return }
            switch state {
            case let .ready(url): resumed = true; continuation.resume(returning: url)
            case let .failed(message): resumed = true; continuation.resume(throwing: CheckFailure.failed(message))
            default: break
            }
        }
        server.start()
    }
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 8
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    func request(_ path: String, body: Data? = nil, type: String = "application/json",
                 origin: String? = nil) async throws -> (Data, Int) {
        guard let url = URL(string: ready.absoluteString + path) else {
            throw CheckFailure.failed("The transfer address is invalid")
        }
        var request = URLRequest(url: url)
        if let body {
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue(type, forHTTPHeaderField: "Content-Type")
        }
        if let origin { request.setValue(origin, forHTTPHeaderField: "Origin") }
        let (bytes, response) = try await session.data(for: request)
        return (bytes, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
    let (html, status) = try await request("")
    try check(status == 200 && String(decoding: html, as: UTF8.self).contains("Import owned games"),
              "The local browser page is unavailable")
    let (helperBytes, helperStatus) = try await request("helper")
    try check(helperStatus == 200 && helperBytes == Data([7, 8, 9]), "The helper download changed")
    let manifest = try JSONEncoder().encode(LocalImportManifest(files: [.init(path: "MAIN.DAT", bytes: 4)]))
    let (_, forbidden) = try await request("start", body: manifest, origin: "https://example.invalid")
    try check(forbidden == 403, "A foreign web origin started a transfer")
    let (_, started) = try await request("start", body: manifest)
    try check(started == 200, "A valid browser transfer did not start")
    let (_, incomplete) = try await request("commit", body: Data(), type: "text/plain")
    try check(incomplete == 400, "An incomplete browser transfer was installed")
    let (_, wrongOffset) = try await request("file/0?offset=1", body: Data([1]), type: "application/octet-stream")
    try check(wrongOffset == 400, "An out-of-order browser chunk was accepted")
    let (_, chunk) = try await request("file/0?offset=0", body: Data([1, 2, 3, 4]), type: "application/octet-stream")
    try check(chunk == 200, "A valid browser chunk was rejected")
    let (_, committed) = try await request("commit", body: Data(), type: "text/plain")
    try check(committed == 200 && FileManager.default.fileExists(atPath: received.path), "The native import did not finish")
    var wrong = URLComponents(url: ready, resolvingAgainstBaseURL: false)!
    wrong.path = "/00000000000000000000000000000000/helper"
    let (_, deniedResponse) = try await session.data(from: wrong.url!)
    try check((deniedResponse as? HTTPURLResponse)?.statusCode == 404, "An unauthenticated helper request succeeded")
    print("PASS loopback browser page/helper, origin/token checks, incomplete upload rejection and native import callback")
}

@MainActor private func slowInstallerChecks() async throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent("Lemmix-slow-import-" + UUID().uuidString)
    try manager.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }
    let entered = root.appendingPathComponent("entered")
    let installed = root.appendingPathComponent("installed")
    let gate = DispatchSemaphore(value: 0)
    defer { gate.signal() }
    let server = TVGameImportServer(importDirectory: { directory in
        try Data(directory.path.utf8).write(to: entered)
        guard gate.wait(timeout: .now() + 5) == .success else { throw CheckFailure.failed("The test installer timed out") }
        try Data(contentsOf: directory.appendingPathComponent("MAIN.DAT")).write(to: installed)
    }, helperURL: nil, address: "127.0.0.1")
    defer { server.stop() }
    var staleCompletion = false
    server.onImported = { staleCompletion = true }
    let ready: URL = try await withCheckedThrowingContinuation { continuation in
        var resumed = false
        server.onState = { state in
            guard !resumed else { return }
            switch state {
            case let .ready(url): resumed = true; continuation.resume(returning: url)
            case let .failed(message): resumed = true; continuation.resume(throwing: CheckFailure.failed(message))
            default: break
            }
        }
        server.start()
    }
    func post(_ route: String, _ data: Data, type: String) async throws {
        var request = URLRequest(url: URL(string: ready.absoluteString + route)!)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue(type, forHTTPHeaderField: "Content-Type")
        _ = try await URLSession.shared.data(for: request)
    }
    let manifest = try JSONEncoder().encode(LocalImportManifest(files: [.init(path: "MAIN.DAT", bytes: 4)]))
    try await post("start", manifest, type: "application/json")
    try await post("file/0?offset=0", Data([1, 2, 3, 4]), type: "application/octet-stream")
    let committing = Task { try await post("commit", Data(), type: "text/plain") }
    for _ in 0..<200 {
        if manager.fileExists(atPath: entered.path) { break }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    try check(manager.fileExists(atPath: entered.path), "The slow installer did not start")
    let source = URL(fileURLWithPath: try String(contentsOf: entered, encoding: .utf8))
    server.stop()
    let replacement = TVGameImportServer(importDirectory: { _ in
        throw CheckFailure.failed("A second installer ran during the first import")
    }, helperURL: nil, address: "127.0.0.1")
    defer { replacement.stop() }
    var refused = false
    replacement.onState = { state in if case .failed = state { refused = true } }
    replacement.start()
    try check(refused, "A new server overlapped the active native installer")
    try check(try Data(contentsOf: source.appendingPathComponent("MAIN.DAT")) == Data([1, 2, 3, 4]),
              "Closing the import page removed an active installer's source")
    gate.signal()
    _ = try? await committing.value
    for _ in 0..<200 {
        if manager.fileExists(atPath: installed.path) { break }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    try await Task.sleep(nanoseconds: 20_000_000)
    try check(manager.fileExists(atPath: installed.path) && !staleCompletion,
              "The stopped import lost its source or returned to a closed page")
    let _: URL = try await withCheckedThrowingContinuation { continuation in
        var resumed = false
        replacement.onState = { state in
            guard !resumed else { return }
            switch state {
            case let .ready(url): resumed = true; continuation.resume(returning: url)
            case let .failed(message): resumed = true; continuation.resume(throwing: CheckFailure.failed(message))
            default: break
            }
        }
        replacement.start()
    }
    print("PASS slow-import source retention, process-wide installation lease, restart and stale UI completion")
}

@main struct LocalImportTransferTests {
    @MainActor static func main() async {
        do {
            try pureChecks()
            if ProcessInfo.processInfo.environment["LEMMIX_SKIP_NETWORK_TESTS"] != "1" {
                try await serverChecks()
                try await slowInstallerChecks()
            }
        } catch {
            print("FAIL \(error)")
            exit(1)
        }
    }
}
