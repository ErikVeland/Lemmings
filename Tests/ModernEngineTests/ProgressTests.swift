import Foundation
import NxlvKit

var progress = ModernCampaignProgress()
precondition(progress.isUnlocked(0))
precondition(!progress.isUnlocked(1))
progress.record(levelIndex: 0, saved: 5, required: 5, completedAt: Date(timeIntervalSince1970: 1))
precondition(progress.isUnlocked(1))
precondition(progress.result(for: 0)?.didWin == true)
let roundTrip = try ModernCampaignProgress(encoded: progress.encoded())
precondition(roundTrip == progress)
print("Modern campaign progress tests passed")
