#if os(macOS)
import AppKit
import Testing
@testable import LemmingsLocal

private actor CoverRequest {
    private var completion: CheckedContinuation<Void, Never>?
    private(set) var returned = false

    func hold() async {
        await withCheckedContinuation { completion = $0 }
        returned = true
    }

    var waiting: Bool { completion != nil }

    func release() {
        completion?.resume()
        completion = nil
    }
}

@MainActor struct DeferredArtworkNavigationTests {
    @Test func lateCoverCannotReplaceTheSelectionOrMoveItsTarget() async throws {
        _ = NSApplication.shared
        let carousel = LevelCoverFlowView(frame: CGRect(x: 0, y: 0, width: 900, height: 500))
        let old = CoverRequest()
        let new = CoverRequest()
        carousel.artworkLoader = { key in
            await (key == "first" ? old : new).hold()
            return LevelPreviewBitmap(width: 2, height: 2, rgba: Data(repeating: 255, count: 16))
        }
        var launched: [String] = []
        carousel.onStart = { launched.append($0.id) }
        func show(_ id: String) {
            carousel.configure(items: [.init(id: id, title: "Level", subtitle: "Classic", detail: "1", artworkKey: id)],
                reduceMotion: false)
            carousel.layoutSubtreeIfNeeded()
        }
        func waitUntil(_ ready: () async -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 5
            while !(await ready()) {
                try #require(ProcessInfo.processInfo.systemUptime < deadline)
                try await Task.sleep(nanoseconds: 5_000_000)
            }
        }
        show("first")
        try await waitUntil { await old.waiting }
        show("second")
        try await waitUntil { await new.waiting }
        let target = try #require(carousel.subviews.compactMap { $0 as? NSButton }.first)
        let rect = target.frame
        let corners = try #require(carousel.visualState(at: 0)).projectedCoverCorners
        await old.release()
        try await waitUntil { await old.returned }
        #expect(carousel.visualState(at: 0)?.hasArtwork == false)
        await new.release()
        try await waitUntil { carousel.visualState(at: 0)?.hasArtwork == true }
        let current = try #require(carousel.visualState(at: 0))
        #expect(current.artworkKey == "second" && current.projectedCoverCorners == corners)
        #expect(carousel.artworkCacheEntryCount == 1)
        #expect(target.frame == rect)
        #expect(target.accessibilityPerformPress())
        #expect(launched == ["second"])
    }
}
#endif
