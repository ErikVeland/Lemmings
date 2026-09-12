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
    static func renderer() -> MacInterfaceRenderer? { sharedRenderer }
}
