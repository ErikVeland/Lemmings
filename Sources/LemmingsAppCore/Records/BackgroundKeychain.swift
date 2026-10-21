import Foundation
import Security

/// Background services must never open a Keychain authorisation dialog.
enum BackgroundKeychain {
#if os(macOS)
    // The file-based Keychain interaction flag is process-wide. Serialise our
    // operations so one service cannot restore it while another still needs it.
    private static let lock = NSLock()
#endif

    static func perform(_ operation: () -> OSStatus) -> OSStatus {
#if os(macOS)
        lock.lock()
        defer { lock.unlock() }
        // LAContext only controls the data-protection Keychain. Existing Mac
        // credentials use the login Keychain, whose ACL can reject a new signer.
        var wasAllowed: DarwinBoolean = false
        let previous = SecKeychainGetUserInteractionAllowed(&wasAllowed)
        guard previous == errSecSuccess else { return previous }
        let disabled = SecKeychainSetUserInteractionAllowed(false)
        guard disabled == errSecSuccess else { return disabled }
        defer { _ = SecKeychainSetUserInteractionAllowed(wasAllowed.boolValue) }
#endif
        return operation()
    }
}
