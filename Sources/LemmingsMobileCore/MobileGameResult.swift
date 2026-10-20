import Foundation
import LemmingsAppCore
import NxlvKit

public enum MobileGameResult {
    /// Ranking telemetry requires matching conditions. Other engines still retain local results.
    @MainActor public static func capture(id: UUID, profileID: String, level: ArcadeLevel,
                               session: any MobileGameSession) -> ArcadeRun {
        let snapshot = session.snapshot
        let conditions = session.bonusSkillID.flatMap {
            level.conditions?.addingBonusSkill($0, existingLevelSkills: session.existingLevelSkills)
        } ?? level.conditions
        let recordedLevel = ArcadeLevel(id: level.id, title: level.title, game: level.game, rules: level.rules,
            total: level.total, required: level.required, conditions: conditions)
        let released = snapshot.released + ((session as? Lemmings3MobileSession)?.initialRuntime.configuration.extras.count ?? 0)
        let telemetry: TrolleyTelemetry? = level.conditions == nil ? nil : .init(
            released: released, nukeCount: session.nukeCount,
            rewindCount: session.rewindCount, undoCount: session.undoCount,
            destructiveSkillCount: TrolleyCapture.destructiveCount(session.assignedSkills),
            buildVersion: TrolleyCapture.buildVersion)
        return ArcadeRun(id: id, profileID: profileID, level: recordedLevel,
            saved: snapshot.saved, didWin: snapshot.didWin, skills: session.assignedSkills,
            seconds: Double(snapshot.tick) / session.ticksPerSecond, assisted: session.usedRewind,
            telemetry: telemetry)
    }
}
