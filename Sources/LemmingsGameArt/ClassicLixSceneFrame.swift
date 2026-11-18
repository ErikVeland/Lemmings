import NxlvKit

/**
 * Adapts cleared scene artwork without changing the engine's rendering contract.
 */
public enum ClassicLixSceneFrame {
    public static func build(_ level: ClassicRenderedLevel, simulation: ClassicDOSSimulation,
        artwork: LixArtwork? = GameArtworkResources.lixArtwork,
        theme: LixSceneArtwork.Theme = .brick, pixelScale: Int = 2) -> LixSceneArtwork.Frame? {
        artwork?.sceneArtwork?.frame(level, simulation: simulation, theme: theme, pixelScale: pixelScale)
    }
}
