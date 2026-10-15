import Foundation

/// The original release name follows the device's region, independently of its language.
public enum Lemmings3Brand: Equatable, Sendable {
    case allNewWorld
    case chronicles

    public static var current: Self {
        if #available(macOS 13, iOS 16, tvOS 16, *) {
            return Self(regionCode: Locale.current.region?.identifier)
        } else {
            return Self(regionCode: Locale.current.regionCode)
        }
    }

    public init(regionCode: String?) {
        self = regionCode?.uppercased() == "US" ? .chronicles : .allNewWorld
    }

    public var displayName: String {
        switch self {
        case .allNewWorld: return L10n.text("All New World of Lemmings")
        case .chronicles: return L10n.text("The Lemmings Chronicles")
        }
    }
}
