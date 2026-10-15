import Foundation
import LemmingsAppCore
import NxlvKit

public enum MobileGameResult {
    /// Ranking telemetry requires matching conditions. Other engines still retain local results.
    @MainActor public static func capture(id: UUID, profileID: String, level: ArcadeLevel,
                               session: any MobileGameSession) -> ArcadeRun {
        let snapshot = session.snapshot
        let telemetry: TrolleyTelemetry? = level.conditions == nil ? nil : .init(
            released: snapshot.released, nukeCount: session.nukeCount,
            rewindCount: session.rewindCount, undoCount: session.undoCount,
            destructiveSkillCount: TrolleyCapture.destructiveCount(session.assignedSkills),
            buildVersion: TrolleyCapture.buildVersion)
        return ArcadeRun(id: id, profileID: profileID, level: level,
            saved: snapshot.saved, didWin: snapshot.didWin, skills: session.assignedSkills,
            seconds: Double(snapshot.tick) / session.ticksPerSecond, assisted: session.usedRewind,
            telemetry: telemetry)
    }
}
