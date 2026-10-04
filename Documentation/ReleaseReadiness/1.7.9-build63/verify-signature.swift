import Foundation
import CryptoKit

do {
    let arguments = CommandLine.arguments
    guard arguments.count == 4,
          let key = Data(base64Encoded: arguments[2]),
          let signature = Data(base64Encoded: arguments[3]) else { exit(2) }
    let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: key)
    let archive = try Data(contentsOf: URL(fileURLWithPath: arguments[1]), options: .mappedIfSafe)
    guard publicKey.isValidSignature(signature, for: archive) else {
        FileHandle.standardError.write(Data("Archive signature does not match the app's embedded public key.\n".utf8))
        exit(1)
    }
    print("PASS Ed25519 archive signature against the shipping app's public key")
} catch {
    FileHandle.standardError.write(Data("Signature verification failed: \(error)\n".utf8))
    exit(1)
}
