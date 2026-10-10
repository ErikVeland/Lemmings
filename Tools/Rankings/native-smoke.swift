import Foundation

/// Check native file upload/download against the deployed service, then remove the temporary player.
@main struct NativeRankingsSmoke {
    static func main() async throws {
        guard CommandLine.arguments.count == 2, let base = URL(string: CommandLine.arguments[1]), base.scheme == "https" else {
            throw URLError(.badURL)
        }
        let token = (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "").lowercased()
        let session = URLSession(configuration: .ephemeral)
        func request(_ path: String, method: String, json: [String: Any]? = nil) throws -> URLRequest {
            var request = URLRequest(url: base.appendingPathComponent(path), timeoutInterval: 30)
            request.httpMethod = method
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            request.setValue("UltimateLemmings/1.8.2 NativeDeploymentCheck", forHTTPHeaderField: "User-Agent")
            if let json { request.httpBody = try JSONSerialization.data(withJSONObject: json); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
            return request
        }
        func check(_ response: URLResponse) throws {
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        }
        let (_, registration) = try await session.data(for: request("v1/players", method: "POST", json: ["name": "TST"]))
        try check(registration)
        do {
            let conditions: [String: Any] = ["gameID": "native-smoke", "packID": "deployment", "levelID": UUID().uuidString,
                "levelFingerprint": "smoke-v1", "rulesetVersion": "v1", "physicsMode": "test", "population": 10, "rescueRequirement": 5,
                "startingSkills": [String: Int](), "modifiers": [String: String](), "rewindPolicy": "separate-assisted-v1"]
            let raw = String(decoding: try JSONSerialization.data(withJSONObject: conditions, options: [.sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
            let id = UUID().uuidString.lowercased()
            let (_, response) = try await session.data(for: request("v1/runs", method: "POST", json: ["id": id, "conditionsJSON": raw,
                "assisted": true, "saved": 10, "population": 10, "skills": 0, "milliseconds": 12345, "won": true]))
            try check(response)
            let bytes = Data([0,0,0,24,102,116,121,112,105,115,111,109,0,0,0,0])
            let movie = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            try bytes.write(to: movie)
            defer { try? FileManager.default.removeItem(at: movie) }
            var upload = try request("v1/replays/" + id, method: "PUT")
            upload.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
            let (_, uploaded) = try await session.upload(for: upload, fromFile: movie); try check(uploaded)
            let (download, received) = try await session.download(for: request("v1/replays/" + id, method: "GET"))
            defer { try? FileManager.default.removeItem(at: download) }
            try check(received)
            guard try Data(contentsOf: download) == bytes else { throw URLError(.cannotDecodeContentData) }
            print("PASS native URLSession registration, score, file upload and file download")
        } catch {
            let (_, deletion) = try await session.data(for: request("v1/player", method: "DELETE")); try check(deletion)
            throw error
        }
        let (_, deletion) = try await session.data(for: request("v1/player", method: "DELETE")); try check(deletion)
        print("PASS temporary native test player and replay removed")
    }
}
