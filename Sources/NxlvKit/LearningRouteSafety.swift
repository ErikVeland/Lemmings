import Foundation

/// Conservative teaching placement from reported routes, separate from measured scores.
public enum LearningRouteSafety {
    public static let lateExpertDemand = 850.0
    private static let reportedIdentities: Set<String> = [
        "classic|fan:lldb-478|Crazy.DAT#13",
        "classic|fan:lldb-480|Wicked.DAT#2",
        "classic|fan:lldb-486|Xmas 1991.DAT#2",
        "classic|fan:lldb-486|Xmas 1991.DAT#3",
        "classic|ohNoMoreLemmings-DLVEL-100|33:Crazy:14:1:5",
        "classic|ohNoMoreLemmings-DLVEL-100|62:Wicked:3:9:0",
        "classic|xmasLemmings1991-LEVEL-4|2:Xmas:3:0:2",
        "classic|xmasLemmings1991-LEVEL-4|3:Xmas:4:0:3",
    ]
    private static let reportedStates: Set<String> = [
        "2ca3f8af1521fdee1d47bcb46c92632b9aa60a3004a39f140cfd6dfe58d21c9d",
        "41595c7ecb7849c5ed662fe5bea9f9fa3e74aff9c975b5880d0699c1ecc6c631",
        "5599a2951d606da4deced2bbca5695b3f00f8797138f8e9d57b9d992c469b8b2",
        "56f8f19a1df74a39fc111bf483570771fa31b820a41ddf98f51220759b8f1fb6",
        "d491c56aa389208cc43f8f810e45349be04f9210c3c6a4d140384813bb8ee41e",
        "f5d3110d5e960c995d2a82f8b078095777b0b419ec22fad35ad9e4ad2e089331",
    ]
    public static func minimumDemand(for entry: LevelPlaylistEntry, concepts: [String] = [], assetsRevision: String = "") -> Double {
        let identity = [entry.identity.engine.rawValue, entry.identity.packID, entry.identity.levelID].joined(separator: "|")
        // Reported retail routes need more practice than their Gentle Redux counterparts.
        switch identity {
        case "classic|lemmings-LEVEL-120|11:Fun:12:0:7": return 237.5
        case "classic|lemmings-LEVEL-120|58:Tricky:29:2:0": return 257.5
        case "classic|lemmings-LEVEL-120|26:Fun:27:4:6": return 287.5
        default: break
        }
        let state = String(assetsRevision.prefix(64))
        let quirk = concepts.contains { $0 == "engine-quirk" || $0.hasPrefix("engine-quirk:") }
        return quirk || reportedIdentities.contains(identity) || reportedStates.contains(state) ? lateExpertDemand : 0
    }
}
