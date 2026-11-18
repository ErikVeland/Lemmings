import Foundation
import LemmingsAppCore

@main struct RecoveryIsolation {
    static func main() {
        guard let path = ProcessInfo.processInfo.environment["LEMMINGS_TEST_APPLICATION_SUPPORT"] else {
            print("FAIL: isolated recovery root is missing")
            exit(1)
        }
        let root = URL(fileURLWithPath: path, isDirectory: true)
        let storage = AppStorage(applicationSupport: root, resources: root, defaults: .standard,
                                 isIntegrationTestBuild: true)
        guard RunRecoveryStore(storage: storage).directory.standardizedFileURL
                == root.appendingPathComponent("Checkpoints").standardizedFileURL else {
            print("FAIL: recovery ignores the injected storage root, preventing a cold reopen check")
            exit(1)
        }
        print("PASS: recovery uses the injected isolated storage")
    }
}
