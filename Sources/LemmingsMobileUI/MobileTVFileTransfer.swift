#if os(tvOS)
import Foundation
import NxlvKit
import LemmingsGameArt
import LemmingsMobileCore
@preconcurrency import Network
import UIKit
import Darwin

/// A temporary, token-protected LAN transfer replaces the unavailable document picker.
/// Files are streamed to a staging directory; the existing content validator installs them.
@MainActor final class MobileTVFileTransfer: UIViewController {
    private let canvas = MobileMenuCanvas()
    private let scrollView = UIScrollView()
    private let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    private let staging = FileManager.default.temporaryDirectory.appendingPathComponent(L10n.text("TVTransfer-") + UUID().uuidString)
    private let directory: Bool
    private let importName: String
    private let exportURL: URL?
    private var completion: ((URL) -> Void)?
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private var requests: [UUID: Request] = [:]
    private var files = Set<String>()
    private var totalBytes = 0
    private var activeUploads = 0
    private var committed = false

    /// Only removes a transfer folder directly under this app's temporary directory.
    static func removeImportedFiles(_ source: URL) {
        let temporary = FileManager.default.temporaryDirectory.standardizedFileURL
        var folder = source.standardizedFileURL
        while folder.path != temporary.path && folder.path != "/" {
            if folder.deletingLastPathComponent().path == temporary.path,
               folder.lastPathComponent.hasPrefix(L10n.text("TVTransfer-")) {
                try? FileManager.default.removeItem(at: folder)
                return
            }
            folder.deleteLastPathComponent()
        }
    }

    static func importFiles(from presenter: UIViewController, directory: Bool, name: String = L10n.text("recovery key"), completion: @escaping (URL) -> Void) {
        presenter.present(MobileTVFileTransfer(directory: directory, exportURL: nil, importName: name, completion: completion), animated: true)
    }

    static func exportFile(_ url: URL, from presenter: UIViewController, completion: (() -> Void)? = nil) {
        let controller = MobileTVFileTransfer(directory: false, exportURL: url, completion: nil)
        controller.onClose = completion
        presenter.present(controller, animated: true)
    }

    private var onClose: (() -> Void)?

    private init(directory: Bool, exportURL: URL?, importName: String = L10n.text("recovery key"), completion: ((URL) -> Void)?) {
        self.directory = directory
        self.importName = importName
        self.exportURL = exportURL
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { nil }
    override var preferredFocusEnvironments: [any UIFocusEnvironment] { [canvas] }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(scrollView)
        scrollView.addSubview(canvas)
        canvas.onAction = { [weak self] _ in self?.close() }
        show(address: L10n.text("Starting transfer"))
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            let listener = try NWListener(using: .tcp, on: .any)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        guard let port = self.listener?.port, let address = Self.localAddress() else {
                            self.show(address: L10n.text("Connect Apple TV to your local network"))
                            return
                        }
                        self.show(address: "http://\(address):\(port)/\(self.token)")
                    case .failed(let error): self.show(address: error.localizedDescription)
                    default: break
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.start(queue: .main)
        } catch { show(address: error.localizedDescription) }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.safeAreaLayoutGuide.layoutFrame.insetBy(dx: 40, dy: 20)
        let size = canvas.size(width: scrollView.bounds.width, minimumHeight: scrollView.bounds.height)
        canvas.frame = CGRect(origin: .zero, size: size)
        scrollView.contentSize = size
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        listener?.cancel()
        for (id, connection) in connections {
            if let request = requests[id] { try? request.output?.close() }
            connection.cancel()
        }
        connections.removeAll()
        requests.removeAll()
        if !committed { try? FileManager.default.removeItem(at: staging) }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu }) { close(); return }
        super.pressesBegan(presses, with: event)
    }

    private func close() {
        dismiss(animated: true) { [onClose] in onClose?() }
    }

    private func show(address: String) {
        var page = GameFrontEnd.Page(title: exportURL == nil ? L10n.text("Import files") : L10n.text("Export file"))
        page.details = [L10n.text("Open this address on another device:"), address]
        page.footer = [.init("back", L10n.text("Back"))]
        canvas.page = page
    }

    @MainActor private final class Request {
        let id = UUID()
        var header = Data()
        var remaining: Int?
        var path = ""
        var output: FileHandle?
        var uploadURL: URL?
    }

    private func accept(_ connection: NWConnection) {
        guard connections.count < 4 else { connection.cancel(); return }
        let request = Request()
        connections[request.id] = connection
        requests[request.id] = request
        connection.start(queue: .main)
        receive(connection, request)
    }

    private func receive(_ connection: NWConnection, _ request: Request) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
            Task { @MainActor in
                guard let self, self.connections[request.id] != nil else { return }
                do {
                    if let data { try self.consume(data, connection, request) }
                    if request.remaining == 0 { return }
                    if error != nil || complete { self.finish(connection, request); return }
                    self.receive(connection, request)
                } catch {
                    self.reply(L10n.text("400 Bad Request"), body: Data(error.localizedDescription.utf8), connection, request)
                }
            }
        }
    }

    private func consume(_ data: Data, _ connection: NWConnection, _ request: Request) throws {
        if request.remaining == nil {
            request.header.append(data)
            guard let end = request.header.range(of: Data("\r\n\r\n".utf8)) else {
                guard request.header.count <= 16_384 else { throw URLError(.badServerResponse) }
                return
            }
            guard end.lowerBound <= 16_384,
                  let header = String(data: request.header[..<end.lowerBound], encoding: .utf8) else { throw URLError(.badServerResponse) }
            let lines = header.components(separatedBy: "\r\n")
            let start = (lines.first ?? "").split(separator: " ")
            guard start.count == 3, let decoded = String(start[1]).removingPercentEncoding,
                  decoded == "/\(token)" || decoded.hasPrefix("/\(token)/") else {
                request.remaining = 0
                reply(L10n.text("404 Not Found"), body: Data(), connection, request)
                return
            }
            request.path = String(decoded.dropFirst(token.count + 1))
            let headers = lines.dropFirst().compactMap { line -> (String, String)? in
                guard let colon = line.firstIndex(of: ":") else { return nil }
                return (line[..<colon].lowercased(), line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces))
            }
            let lengths = headers.filter { $0.0 == "content-length" }.map(\.1)
            guard lengths.count <= 1, !headers.contains(where: { $0.0 == "transfer-encoding" }) else { throw URLError(.badServerResponse) }
            let length: Int
            if let raw = lengths.first {
                guard let value = Int(raw), value >= 0 else { throw URLError(.badServerResponse) }
                length = value
            } else { length = 0 }
            let body = Data(request.header[end.upperBound...])
            request.header.removeAll()
            request.remaining = length
            if start[0] == L10n.text("GET") {
                request.remaining = 0
                if request.path == "/download", let exportURL { sendFile(exportURL, connection, request) }
                else if request.path.isEmpty || request.path == "/" {
                    reply("200 OK", body: Data(webPage.utf8), connection, request, type: L10n.text("text/html; charset=utf-8"))
                } else { reply(L10n.text("404 Not Found"), body: Data(), connection, request) }
                return
            }
            guard start[0] == L10n.text("POST"), exportURL == nil, !committed else { throw URLError(.unsupportedURL) }
            if request.path == "/commit" {
                guard length == 0, activeUploads == 0, !files.isEmpty,
                      directory || files.count == 1 else { throw URLError(.badServerResponse) }
                committed = true
                let result = directory ? staging : staging.appendingPathComponent(files.first ?? "")
                reply("200 OK", body: Data(L10n.text("Imported").utf8), connection, request) { [weak self] in
                    guard let self else { return }
                    self.dismiss(animated: true) { [completion = self.completion] in completion?(result) }
                }
                return
            }
            guard request.path.hasPrefix("/upload/"), files.count < MobileContentStore.maximumImportEntries,
                  length <= Int(MobileContentStore.maximumImportBytes) - totalBytes else { throw URLError(.dataLengthExceedsMaximum) }
            let relative = String(request.path.dropFirst("/upload/".count))
            let parts = relative.split(separator: "/", omittingEmptySubsequences: false)
            guard !relative.isEmpty, parts.count <= 32, parts.allSatisfy({
                !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\\") && !$0.contains(":") && !$0.contains("\0")
            }), !files.contains(relative), directory || files.isEmpty else { throw URLError(.badURL) }
            let destination = staging.appendingPathComponent(relative)
            guard !FileManager.default.fileExists(atPath: destination.path) else { throw CocoaError(.fileWriteFileExists) }
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard FileManager.default.createFile(atPath: destination.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
            request.output = try FileHandle(forWritingTo: destination)
            request.uploadURL = destination
            files.insert(relative)
            totalBytes += length
            activeUploads += 1
            try consumeBody(body, connection, request)
        } else {
            try consumeBody(data, connection, request)
        }
    }

    private func consumeBody(_ data: Data, _ connection: NWConnection, _ request: Request) throws {
        guard let remaining = request.remaining, data.count <= remaining, let output = request.output else { throw URLError(.badServerResponse) }
        try output.write(contentsOf: data)
        request.remaining = remaining - data.count
        if request.remaining == 0 {
            try output.close()
            request.output = nil
            request.uploadURL = nil
            activeUploads -= 1
            reply("200 OK", body: Data("OK".utf8), connection, request)
        }
    }

    private func reply(_ status: String, body: Data, _ connection: NWConnection, _ request: Request,
                       type: String = "text/plain", onComplete: (@MainActor @Sendable () -> Void)? = nil) {
        request.remaining = 0
        let header = L10n.text("HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n")
        connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { [weak self] _ in
            Task { @MainActor in
                self?.finish(connection, request)
                onComplete?()
            }
        })
    }

    private func sendFile(_ url: URL, _ connection: NWConnection, _ request: Request) {
        do {
            let file = try FileHandle(forReadingFrom: url)
            let size = try file.seekToEnd()
            try file.seek(toOffset: 0)
            request.output = file
            let header = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=\"\(url.lastPathComponent.replacingOccurrences(of: "\"", with: ""))\"\r\nContent-Length: \(size)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n"
            connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] error in
                Task { @MainActor in
                    guard error == nil else { self?.finish(connection, request); return }
                    self?.sendChunk(connection, request)
                }
            })
        } catch { reply(L10n.text("404 Not Found"), body: Data(), connection, request) }
    }

    private func sendChunk(_ connection: NWConnection, _ request: Request) {
        guard connections[request.id] != nil else { return }
        do {
            guard let chunk = try request.output?.read(upToCount: 65_536), !chunk.isEmpty else { finish(connection, request); return }
            connection.send(content: chunk, completion: .contentProcessed { [weak self] error in
                Task { @MainActor in
                    if error == nil { self?.sendChunk(connection, request) }
                    else { self?.finish(connection, request) }
                }
            })
        } catch { finish(connection, request) }
    }

    private func finish(_ connection: NWConnection, _ request: Request) {
        try? request.output?.close()
        if let incomplete = request.uploadURL {
            activeUploads -= 1
            let relative = String(incomplete.path.dropFirst(staging.path.count + 1))
            files.remove(relative)
            try? FileManager.default.removeItem(at: incomplete)
        }
        request.output = nil
        request.uploadURL = nil
        connection.cancel()
        connections.removeValue(forKey: request.id)
        requests.removeValue(forKey: request.id)
    }

    private var webPage: String {
        if exportURL != nil {
            return L10n.text("<!doctype html><meta name=\"viewport\" content=\"width=device-width\"><title>Ultimate Lemmings</title><h1>Export file</h1><a href=\"/\(token)/download\">Download</a>")
        }
        return L10n.text("""
        <!doctype html><meta name="viewport" content="width=device-width">
        <title>Ultimate Lemmings</title><h1>Import \(directory ? L10n.text("game folder") : importName)</h1>
        <input id="files" type="file" \(directory ? L10n.text("webkitdirectory multiple") : "")>
        <button id="send">Import</button><p id="status"></p>
        <script>
        const button = document.getElementById('send'), status = document.getElementById('status');
        button.onclick = async () => {
          button.disabled = true;
          try {
            const files = Array.from(document.getElementById('files').files);
            if (!files.length) throw Error('Choose files first.');
            for (let i = 0; i < files.length; i++) {
              const file = files[i], path = file.webkitRelativePath ? file.webkitRelativePath.split('/').slice(1).join('/') : file.name;
              status.textContent = (i + 1) + ' / ' + files.length;
              const result = await fetch('/\(token)/upload/' + encodeURIComponent(path), {method:'POST', body:file});
              if (!result.ok) throw Error(await result.text());
            }
            const result = await fetch('/\(token)/commit', {method:'POST'});
            if (!result.ok) throw Error(await result.text());
            status.textContent = 'Transferred. Check Apple TV for validation.';
          } catch (error) { status.textContent = error.message; }
          button.disabled = false;
        };
        </script>
        """)
    }

    private static func localAddress() -> String? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0 else { return nil }
        defer { freeifaddrs(addresses) }
        var entry = addresses
        while let current = entry {
            defer { entry = current.pointee.ifa_next }
            guard let address = current.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
                  current.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }
            var name = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(address, socklen_t(address.pointee.sa_len), &name, socklen_t(name.count), nil, 0, NI_NUMERICHOST) == 0 {
                return String(cString: name)
            }
        }
        return nil
    }
}
#endif
