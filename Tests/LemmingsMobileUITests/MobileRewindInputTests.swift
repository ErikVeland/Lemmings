#if os(iOS)
import GameController
import Testing
import LemmingsMobileCore
@testable import LemmingsMobileUI

@MainActor struct MobileRewindInputTests {
    @Test func pollingWithoutAControllerPreservesTouchRewindUntilRelease() throws {
        guard GCController.controllers().isEmpty else { return }
        let adapter = MobileInputAdapter()
        adapter.isActive = { true }
        adapter.isMenu = { false }
        var held = false
        adapter.onRewindHeld = { held = $0 }
        var touch = MobileHUDPress(.rewind)
        for effect in touch.begin(at: 0) {
            if case .pedal(let value, _) = effect { held = value }
        }
        for frame in 0..<180 {
            adapter.poll(context: nil, at: Double(frame) / 60)
            #expect(held)
        }
        for effect in touch.end(at: 3) {
            if case .pedal(let value, _) = effect { held = value }
        }
        #expect(!held)
    }
}
#endif
