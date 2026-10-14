import Foundation
import NxlvKit

/// A frozen overview of the attempt, shared by every mobile engine.
public struct MobilePauseSummary: Equatable, Sendable {
    public struct Field: Equatable, Sendable {
        public let label: String
        public let value: String
        public var text: String { label + ": " + value }
        public init(_ label: String, _ value: String) { self.label = label; self.value = value }
    }
    public let level: MobileLevelSummary
    public let saved: Int
    public let required: Int
    public let total: Int
    public let active: Int
    public let waiting: Int
    public let lost: Int
    public let canLose: Int
    public let status: String
    public let goalReachable: Bool
    public let fields: [Field]
    public let supplies: [Field]
    public let playDetails: String
    public let soundtrack: String
    public let track: String
    public let audio: String
    public let isReplay: Bool
    public var rescueText: String { L10n.text("Saved \(saved) / \(required) required") }

    public init(level: MobileLevelSummary, snapshot: MobileGameSnapshot, activeCount: Int,
                ticksPerSecond: Double, speed: Double, assignedSkills: Int,
                supportsRewind: Bool, usedRewind: Bool, isReplay: Bool,
                soundtrack: String, track: String?, audio: String) {
        self.level = level
        self.isReplay = isReplay
        total = max(0, snapshot.total)
        saved = min(total, max(0, snapshot.saved))
        required = max(0, snapshot.required)
        let released = min(total, max(saved, snapshot.released))
        active = min(released - saved, max(0, activeCount))
        waiting = total - released
        lost = released - saved - active
        canLose = max(0, saved + active + waiting - required)
        goalReachable = saved + active + waiting >= required
        if snapshot.isComplete { status = snapshot.didWin ? "Level complete" : "Level ended" }
        else if snapshot.isEndingRun { status = "Ending the run" }
        else if !goalReachable { status = L10n.text("Rescue target out of reach") }
        else if saved >= required { status = "Rescue target reached" }
        else { status = isReplay ? "Replay paused" : "Rescue in progress" }
        func time(_ seconds: Int) -> String {
            let seconds = max(0, seconds)
            return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
        }
        let elapsed = ticksPerSecond.isFinite && ticksPerSecond > 0
            ? Int(Double(max(0, snapshot.tick)) / ticksPerSecond) : 0
        fields = [Field("Active", "\(active)"), Field("Waiting", "\(waiting)"),
                  Field("Lost", "\(lost)"), Field("Can lose", "\(canLose)"),
                  Field("Time left", snapshot.remainingSeconds.map(time) ?? "Unlimited"),
                  Field("Elapsed", time(elapsed)),
                  Field("Speed", String(format: "%.2gX", speed)),
                  Field("Release", snapshot.releaseRate.map(String.init) ?? "Fixed")]
        let rewind = isReplay ? "Replay" : supportsRewind ? (usedRewind ? "Rewind used" : "No rewind used") : "Rewind unavailable"
        supplies = snapshot.skills.filter { !$0.isUnlimited }.map { Field($0.name, "\(max(0, $0.count))") }
        playDetails = L10n.text("\(total) lemmings   /   \(max(0, assignedSkills)) skills used   /   \(rewind)")
        self.soundtrack = soundtrack
        self.track = track ?? "No track playing"
        self.audio = audio
    }
}
