#if os(macOS)
import AppKit
import NxlvKit
import LemmingsAppCore
import LemmingsGameArt

/// Menu lettering follows the current resource generation, independently of the selected release.
@MainActor enum GameMenuArtwork {
    private static var rendererRevision: String?
    private static var sharedRenderer: MacInterfaceRenderer?
    private static func currentRenderer() -> MacInterfaceRenderer? {
        let revision = GameResources.revision
        if rendererRevision != revision {
            rendererRevision = revision
            sharedRenderer = GameArtworkResources.menuInterface.map(MacInterfaceRenderer.init(interface:))
        }
        return sharedRenderer
    }
    private static var renderFixture: MacInterfaceRenderer?
    static func renderer() -> MacInterfaceRenderer? { renderFixture ?? currentRenderer() }
    /// Offscreen captures can supply the shipped artwork without an app bundle.
    static func withRenderer<Result>(_ renderer: MacInterfaceRenderer, _ body: () throws -> Result) rethrows -> Result {
        let previous = renderFixture
        renderFixture = renderer
        defer { renderFixture = previous }
        return try body()
    }
}
#endif
