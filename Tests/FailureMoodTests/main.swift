import Foundation

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
  precondition(condition(), message)
}

let remaining = FailureMoodDecision.deathsUntilUnrecoverable
check(remaining(0, 5, 5, 5) == 6, "The counter did not include active and unreleased lemmings")
check(remaining(0, 5, 4, 5) == 5, "One death did not lower the counter")
check(remaining(1, 4, 5, 5) == 6, "A rescued lemming incorrectly lowered the death counter")
check(remaining(0, 1, 4, 5) == 1, "The last recoverable lemming did not show one")
check(remaining(0, 0, 4, 5) == 0, "The counter did not reach zero at the funeral threshold")
check(FailureMoodDecision.isUnrecoverable(saved: 0, active: 0, unreleased: 4, required: 5),
  "The counter and funeral state disagree at zero")
check(!FailureMoodDecision.isUnrecoverable(saved: 0, active: 1, unreleased: 4, required: 5),
  "The counter and funeral state disagree at one")
check(remaining(4, 0, 1, 5) == 1, "An unreleased lemming was not counted")
check(remaining(5, 0, 0, 5) == nil, "The counter did not clear after meeting the rescue target")
check(remaining(0, 0, 0, 0) == nil, "A zero rescue target was not safe")
check(remaining(0, 1, -1, 1) == 1, "A negative unreleased count altered the counter")
let label = FailureMoodDecision.deathCounter
check(label(0, 1, 0, 1, 1, false, false).visible == "1/1 💀", "The last chance label was wrong")
check(label(0, 0, 0, 1, 1, false, false).visible == "0/1 💀", "The funeral label was wrong")
check(label(0, 9, 0, 5, 10, false, false).visible == "5/6 💀", "The death margin fraction was wrong")
check(label(1, 0, 0, 1, 1, false, false).visible == "SAFE", "A met rescue target was not marked safe")
check(label(0, 1, 0, 1, 1, true, false).visible == "0/1 💀", "A time-out loss did not show zero")
check(label(1, 0, 0, 1, 1, true, true).visible == "SAFE", "A finished win was not marked safe")
check(label(0, 1, 0, 1, 1, false, false).accessibility == "1 of 1 deaths remain before failure",
  "The compact counter lost its accessible meaning")
print("PASS remaining deaths, last chance, funeral threshold, safe goal and unreleased lemmings")
