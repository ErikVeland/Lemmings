import Foundation

public enum Lemmings3OriginalMovie: String, CaseIterable, Sendable {
    case introduction = "INTRO.FLI", classic = "C-LEV15.FLI", shadow = "SHA-WALK.FLI"
    case egyptian = "E-LEV10.FLI", ending = "THE-END.FLI"
    public var title: String {
        switch self {
        case .introduction: L10n.text("Introduction")
        case .classic: L10n.text("Classic tribe movie")
        case .shadow: L10n.text("Shadow tribe movie")
        case .egyptian: L10n.text("Egyptian tribe movie")
        case .ending: L10n.text("Ending")
        }
    }
}
