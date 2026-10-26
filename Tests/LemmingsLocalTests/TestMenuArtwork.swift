import Foundation

/// Menu artwork for rendered tests: `LEMMINGS_TEST_MENU_ARTWORK` when set, else this checkout's exported artwork.
enum TestMenuArtwork {
    static var path: String {
        ProcessInfo.processInfo.environment["LEMMINGS_TEST_MENU_ARTWORK"]
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent(".build/mac-artwork/export/lemmings").path
    }
}
