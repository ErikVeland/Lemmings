#if canImport(Network)
import Foundation
import LemmingsMobileCore
import Network
#if canImport(Darwin)
import Darwin
#endif

/**
 * Receives player-selected files only while the TV import page is open.
 */
@MainActor final class TVGameImportServer {
    enum State {
        case ready(URL)
        case receiving(Int64)
        case validating
        case failed(String)
    }

    var onState: ((State) -> Void)?
    var onImported: (() -> Void)?
    private static var importInProgress = false
    private let importDirectory: @Sendable (URL) throws -> Void
    private let helperURL: URL?
    private let address: String?
    private let token: String
    private let queue = DispatchQueue(label: "academy.glasscode.ultimatelemmix.transfer")
    private var listener: NWListener?
    private var peers: [UUID: Peer] = [:]
    private var transfer: LocalImportTransferSession?
    private var expiry: Task<Void, Never>?
    private var busy = false
    private var generation = UUID()

    private final class Peer {
        let connection: NWConnection
        var bytes = Data()
        var head: LocalImportHTTPHead?
        var timeout: Task<Void, Never>?
        init(_ connection: NWConnection) { self.connection = connection }
    }

    init(importDirectory: @escaping @Sendable (URL) throws -> Void, helperURL: URL?,
         address: String? = nil, token: String = UUID().uuidString.replacingOccurrences(of: "-", with: "")) {
        self.importDirectory = importDirectory
        self.helperURL = helperURL
        self.address = address
        self.token = token
    }

    func start() {
        stop()
        guard !Self.importInProgress else {
            onState?(.failed("An import is finishing. Try a new address shortly."))
            return
        }
        guard token.count == 32, token.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) }),
              let address = address ?? Self.localAddress() else {
            onState?(.failed("Connect the TV to your local network."))
            return
        }
        do {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host(address), port: .any)
            parameters.includePeerToPeer = false
            let next = try NWListener(using: parameters)
            listener = next
            next.stateUpdateHandler = { [weak self, weak next] state in
                Task { @MainActor in
                    guard let self, let next, self.listener === next else { return }
                    switch state {
                    case .ready:
                        guard let port = next.port,
                              let url = URL(string: "http://\(address):\(port.rawValue)/\(self.token)/") else { return }
                        self.onState?(.ready(url))
                    case .failed:
                        self.stop()
                        self.onState?(.failed("The local transfer could not start. Try a new address."))
                    default: break
                    }
                }
            }
            next.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    guard let self else { connection.cancel(); return }
                    self.accept(connection)
                }
            }
            next.start(queue: queue)
            expiry = Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: 600_000_000_000)
                    guard let self else { return }
                    self.stop()
                    self.onState?(.failed("The transfer address expired. Choose a new address."))
                } catch {}
            }
        } catch {
            onState?(.failed("The local transfer could not start. Try a new address."))
        }
    }

    func stop() {
        generation = UUID()
        expiry?.cancel()
        expiry = nil
        listener?.cancel()
        listener = nil
        for peer in peers.values {
            peer.timeout?.cancel()
            peer.connection.cancel()
        }
        peers.removeAll()
        transfer?.cancel()
        transfer = nil
        busy = false
    }

    private func accept(_ connection: NWConnection) {
        guard listener != nil, peers.count < 4 else { connection.cancel(); return }
        let id = UUID()
        let peer = Peer(connection)
        peers[id] = peer
        peer.timeout = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 30_000_000_000)
                self?.close(id)
            } catch {}
        }
        connection.start(queue: queue)
        receive(id)
    }

    private func receive(_ id: UUID) {
        guard let peer = peers[id] else { return }
        peer.connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) {
            [weak self] data, _, complete, error in
            Task { @MainActor in
                guard let self, let peer = self.peers[id] else { return }
                if let data { peer.bytes.append(data) }
                do {
                    guard peer.bytes.count <= LocalImportHTTPHead.maximumHeaderBytes
                            + LocalImportHTTPHead.maximumBodyBytes else { throw LocalImportTransferError.limit }
                    if peer.head == nil { peer.head = try LocalImportHTTPHead.decode(peer.bytes) }
                    if let head = peer.head {
                        let expected = head.bodyOffset + head.contentLength
                        guard peer.bytes.count <= expected else { throw LocalImportTransferError.request }
                        if peer.bytes.count == expected {
                            self.handle(id, head: head, body: Data(peer.bytes[head.bodyOffset..<expected]))
                            return
                        }
                    }
                    if complete || error != nil { throw LocalImportTransferError.incomplete }
                    self.receive(id)
                } catch {
                    self.respond(id, status: 400, message: "The transfer request is invalid.")
                }
            }
        }
    }

    private func handle(_ id: UUID, head: LocalImportHTTPHead, body: Data) {
        let base = "/\(token)/"
        guard head.target.hasPrefix(base) else { respond(id, status: 404, message: "Not found."); return }
        if let origin = head.headers["origin"], origin != "http://" + (head.headers["host"] ?? "") {
            respond(id, status: 403, message: "Open the address shown on the TV.")
            return
        }
        let route = String(head.target.dropFirst(base.count))
        if head.method == "GET", route.isEmpty {
            respond(id, status: 200, type: "text/html; charset=utf-8", data: Data(page.utf8))
            return
        }
        if head.method == "GET", route == "helper", let helperURL,
           let data = try? Data(contentsOf: helperURL), data.count <= 100_000 {
            respond(id, status: 200, type: "application/zip", data: data,
                    extra: "Content-Disposition: attachment; filename=\"Ultimate-Lemmix-BYO.zip\"\r\n")
            return
        }
        guard head.method == "POST" else { respond(id, status: 404, message: "Not found."); return }
        guard !busy, !Self.importInProgress else {
            respond(id, status: 409, message: "The TV is checking the files.")
            return
        }
        do {
            if route == "start" {
                guard head.headers["content-type"]?.split(separator: ";").first == "application/json" else {
                    throw LocalImportTransferError.request
                }
                let manifest = try JSONDecoder().decode(LocalImportManifest.self, from: body)
                guard let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                    throw LocalImportTransferError.request
                }
                let next = try LocalImportTransferSession(manifest: manifest,
                    stagingRoot: cache.appendingPathComponent("Ultimate Lemmix Transfers", isDirectory: true))
                transfer?.cancel()
                transfer = next
                onState?(.receiving(0))
                respond(id, status: 200, message: "Ready.")
            } else if route.hasPrefix("file/") {
                let parts = route.dropFirst(5).components(separatedBy: "?offset=")
                guard parts.count == 2, let index = Int(parts[0]), let offset = Int64(parts[1]),
                      let transfer else { throw LocalImportTransferError.request }
                try transfer.append(body, file: index, offset: offset)
                onState?(.receiving(transfer.receivedBytes))
                respond(id, status: 200, message: "Received.")
            } else if route == "commit", body.isEmpty, let transfer {
                let directory = try transfer.completeDirectory()
                let committingTransfer = transfer
                self.transfer = nil
                let operation = importDirectory
                let epoch = generation
                busy = true
                Self.importInProgress = true
                peers[id]?.timeout?.cancel()
                onState?(.validating)
                Task { [weak self, committingTransfer] in
                    let result = await Task.detached(priority: .userInitiated) {
                        Result { try operation(directory) }
                    }.value
                    committingTransfer.cancel()
                    Self.importInProgress = false
                    guard let self, self.generation == epoch else { return }
                    self.busy = false
                    switch result {
                    case .success:
                        self.respond(id, status: 200, message: "Imported.") { [weak self] in
                            guard let self, self.generation == epoch else { return }
                            self.onImported?()
                        }
                    case .failure:
                        let message = "Check your Classic game folder, then select the files again."
                        self.onState?(.failed(message))
                        self.respond(id, status: 422, message: message)
                    }
                }
            } else {
                respond(id, status: 404, message: "Not found.")
            }
        } catch {
            respond(id, status: 400, message: (error as? LocalizedError)?.errorDescription
                ?? "Check the selected files and try again.")
        }
    }

    private func respond(_ id: UUID, status: Int, message: String,
                         completion: (@MainActor @Sendable () -> Void)? = nil) {
        let data = (try? JSONEncoder().encode(["message": message])) ?? Data()
        respond(id, status: status, type: "application/json", data: data, completion: completion)
    }

    private func respond(_ id: UUID, status: Int, type: String, data: Data,
                         extra: String = "", completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard let peer = peers[id] else { completion?(); return }
        peer.timeout?.cancel()
        let labels = [200: "OK", 400: "Bad Request", 403: "Forbidden", 404: "Not Found",
                      409: "Conflict", 422: "Unprocessable Content"]
        let headers = "HTTP/1.1 \(status) \(labels[status] ?? "Error")\r\n"
            + "Content-Type: \(type)\r\nContent-Length: \(data.count)\r\nConnection: close\r\n"
            + "Cache-Control: no-store\r\nReferrer-Policy: no-referrer\r\nX-Content-Type-Options: nosniff\r\n"
            + "Content-Security-Policy: default-src 'none'; script-src 'nonce-\(token)'; style-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'\r\n"
            + extra + "\r\n"
        peer.connection.send(content: Data(headers.utf8) + data, completion: .contentProcessed { [weak self] _ in
            Task { @MainActor in self?.close(id); completion?() }
        })
    }

    private func close(_ id: UUID) {
        guard let peer = peers.removeValue(forKey: id) else { return }
        peer.timeout?.cancel()
        peer.connection.cancel()
    }

    private static func localAddress() -> String? {
        #if canImport(Darwin)
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0 else { return nil }
        defer { freeifaddrs(first) }
        var cursor = first
        var found: [(String, String)] = []
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            guard let address = entry.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
                  entry.pointee.ifa_flags & UInt32(IFF_UP) != 0,
                  entry.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let value = String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            let parts = value.split(separator: ".").compactMap { Int($0) }
            guard parts.count == 4,
                  parts[0] == 10 || (parts[0] == 172 && (16...31).contains(parts[1]))
                    || (parts[0] == 192 && parts[1] == 168) || (parts[0] == 169 && parts[1] == 254) else { continue }
            found.append((String(cString: entry.pointee.ifa_name), value))
        }
        return found.sorted { $0.0 < $1.0 }.first?.1
        #else
        return nil
        #endif
    }

    private var page: String {
        """
        <!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
        <title>Ultimate Lemmix — Import owned games</title>
        <style>body{color:#eaf0e9;background:#152333;font:18px system-ui;max-width:44rem;margin:3rem auto;padding:1rem}button,input,a{font:inherit;margin:1rem 0;color:inherit}button{background:#39552b;padding:.8rem;border:2px solid #a8c989}a{display:block}progress{width:100%}</style>
        <h1>Import owned games</h1><p>Select your Classic DOS game folder. Keep this page and the TV import screen open.</p>
        <label>Game folder <input id="folder" type="file" webkitdirectory multiple></label>
        <p>Or select the files inside that folder:</p><input id="files" type="file" multiple>
        <button id="send" disabled>Import to TV</button><progress id="progress" max="1" value="0"></progress>
        <p id="status" role="status">Choose your game files.</p><a href="helper" download>Get asset-free BYO bundle</a>
        <script nonce="\(token)">
        const folder=document.getElementById('folder'),files=document.getElementById('files'),send=document.getElementById('send'),status=document.getElementById('status'),progress=document.getElementById('progress');
        let selected=[];
        function choose(source){selected=Array.from(source.files);send.disabled=selected.length===0;status.textContent=selected.length+' files selected.';}
        folder.onchange=()=>choose(folder);files.onchange=()=>choose(files);
        async function post(route,body,type){const response=await fetch(route,{method:'POST',body,headers:{'Content-Type':type}});const result=await response.json();if(!response.ok)throw Error(result.message);return result;}
        send.onclick=async()=>{send.disabled=true;folder.disabled=true;files.disabled=true;
        try{const rows=selected.map(file=>({path:file.webkitRelativePath?file.webkitRelativePath.split('/').slice(1).join('/'):file.name,bytes:file.size}));
        await post('start',JSON.stringify({files:rows}),'application/json');const total=selected.reduce((n,f)=>n+f.size,0);let sent=0;
        for(let i=0;i<selected.length;i++){const file=selected[i];for(let offset=0;offset<file.size;offset+=1048576){const data=file.slice(offset,offset+1048576);await post('file/'+i+'?offset='+offset,data,'application/octet-stream');sent+=data.size;progress.value=total?sent/total:1;status.textContent='Transferring '+Math.floor(progress.value*100)+'%';}}
        status.textContent='Checking game files…';await post('commit','','text/plain');progress.value=1;status.textContent='Imported. Continue on your TV.';
        }catch(error){status.textContent=error.message;}finally{send.disabled=false;folder.disabled=false;files.disabled=false;}};
        </script></html>
        """
    }
}
#endif
