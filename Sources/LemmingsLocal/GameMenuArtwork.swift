#if os(macOS)
import AppKit
import NxlvKit

/// Menu lettering that does not depend on which release is selected.
///
/// Kept in its own file so the playfield drawing tests can compile the view
/// without pulling in the window and page machinery of the game screen.
@MainActor enum GameMenuArtwork {
    private static let sharedRenderer: MacInterfaceRenderer? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("MacArtwork/lemmings"),
              let artwork = try? ClassicMacArtwork(directory: url),
              let interface = ClassicMacUserInterface(artwork: artwork) else { return nil }
        return MacInterfaceRenderer(interface: interface)
    }()
    private static var renderFixture: MacInterfaceRenderer?
    static func renderer() -> MacInterfaceRenderer? { renderFixture ?? sharedRenderer }
    /// Offscreen captures can supply the shipped artwork without an app bundle.
    static func withRenderer<Result>(_ renderer: MacInterfaceRenderer, _ body: () throws -> Result) rethrows -> Result {
        let previous = renderFixture
        renderFixture = renderer
        defer { renderFixture = previous }
        return try body()
    }
}
#endif
