import Foundation
import Security

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAIL \(message)\n".utf8))
        exit(1)
    }
}

func interactionAllowed() -> Bool {
    var allowed: DarwinBoolean = false
    check(SecKeychainGetUserInteractionAllowed(&allowed) == errSecSuccess, "Read interaction flag")
    return allowed.boolValue
}

func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    check(process.terminationStatus == 0, "Child process failed: \(executable)")
}

if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--changed-signer" {
    var fixture: SecKeychain?
    check(BackgroundKeychain.perform { SecKeychainOpen(CommandLine.arguments[2], &fixture) } == errSecSuccess, "Open fixture in rebuilt executable")
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: CommandLine.arguments[3], kSecAttrAccount as String: "library",
        kSecMatchSearchList as String: [fixture!]]
    var lookup = query
    lookup[kSecReturnData as String] = true
    var data: CFTypeRef?
    let status = BackgroundKeychain.perform { SecItemCopyMatching(lookup as CFDictionary, &data) }
    check(status == errSecInteractionNotAllowed || status == errSecAuthFailed,
          "Changed signer must fail without an authorisation dialog: \(status)")
    print("PASS changed ad hoc signer refuses Keychain access without a dialog")
    exit(0)
}

let original = interactionAllowed()
defer { _ = SecKeychainSetUserInteractionAllowed(original) }
for allowed in [false, true] {
    check(SecKeychainSetUserInteractionAllowed(allowed) == errSecSuccess, "Set interaction flag")
    for result in [errSecSuccess, errSecItemNotFound, errSecAuthFailed] {
        let status = BackgroundKeychain.perform {
            check(!interactionAllowed(), "Keychain interaction must be disabled inside every operation")
            return result
        }
        check(status == result, "Preserve the operation result")
        check(interactionAllowed() == allowed, "Restore the previous flag after success and failure")
    }
}

// Use a disposable Keychain with an explicit search list. No login credentials
// or saved application preferences are read or changed.
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lemmings-keychain-\(UUID())")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
var fixture: SecKeychain?
let password = UUID().uuidString
let created = BackgroundKeychain.perform {
    password.withCString { bytes in
        SecKeychainCreate(directory.appendingPathComponent("fixture.keychain").path,
                          UInt32(password.utf8.count), bytes, false, nil, &fixture)
    }
}
check(created == errSecSuccess, "Create disposable Keychain: \(created)")
let keychain = fixture!
defer { _ = BackgroundKeychain.perform { SecKeychainDelete(keychain) } }
let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "lemmings-keychain-regression-\(UUID())",
    kSecAttrAccount as String: "library", kSecMatchSearchList as String: [keychain]]
var entry = query
entry.removeValue(forKey: kSecMatchSearchList as String)
entry[kSecUseKeychain as String] = keychain
entry[kSecValueData as String] = Data("original-key".utf8)
check(BackgroundKeychain.perform { SecItemAdd(entry as CFDictionary, nil) } == errSecSuccess, "Add fixture key")
var lookup = query
lookup[kSecReturnData as String] = true
var data: CFTypeRef?
check(BackgroundKeychain.perform { SecItemCopyMatching(lookup as CFDictionary, &data) } == errSecSuccess, "Read authorised key")
check(data as? Data == Data("original-key".utf8), "Read the original key")

// A locked legacy Keychain exercises the same system UI gate as a changed
// executable identity. Each operation must fail without opening a dialog.
check(BackgroundKeychain.perform { SecKeychainLock(keychain) } == errSecSuccess, "Lock fixture")
for operation in [
    { SecItemCopyMatching(lookup as CFDictionary, &data) },
    { SecItemUpdate(query as CFDictionary, [kSecValueData as String: Data("replacement".utf8)] as CFDictionary) },
    { () -> OSStatus in
        var another = entry
        another[kSecAttrAccount as String] = "new-library"
        return SecItemAdd(another as CFDictionary, nil)
    }
] {
    let status = BackgroundKeychain.perform(operation)
    check(status == errSecInteractionNotAllowed || status == errSecAuthFailed,
          "Locked Keychain must reject background access without UI: \(status)")
}
check(BackgroundKeychain.perform {
    password.withCString { SecKeychainUnlock(keychain, UInt32(password.utf8.count), $0, true) }
} == errSecSuccess, "Unlock fixture with its temporary password")
check(BackgroundKeychain.perform { SecItemCopyMatching(lookup as CFDictionary, &data) } == errSecSuccess, "Read after unlock")
check(data as? Data == Data("original-key".utf8), "Refused updates preserve the stored key")
// Changing the ad hoc signing identifier changes the executable's designated
// requirement, just as rebuilding the local app does.
let rebuilt = directory.appendingPathComponent("rebuilt-tests")
try FileManager.default.copyItem(atPath: CommandLine.arguments[0], toPath: rebuilt.path)
try run("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", "lemmings.keychain.rebuilt", rebuilt.path])
try run(rebuilt.path, ["--changed-signer", directory.appendingPathComponent("fixture.keychain").path,
                       query[kSecAttrService as String] as! String])
check(BackgroundKeychain.perform { SecItemCopyMatching(lookup as CFDictionary, &data) } == errSecSuccess, "Original signer retains access")
check(data as? Data == Data("original-key".utf8), "Refused signer changes preserve the stored key")
var missing = lookup
missing[kSecAttrAccount as String] = "new-library"
check(BackgroundKeychain.perform { SecItemCopyMatching(missing as CFDictionary, nil) } == errSecItemNotFound,
      "Refused additions do not create replacement credentials")
check(interactionAllowed(), "Restore interaction after real Keychain calls")
print("PASS silent Keychain reads, updates, additions, denied access, key preservation and interaction restoration")
