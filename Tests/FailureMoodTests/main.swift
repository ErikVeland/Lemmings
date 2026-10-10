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

MainActor.assumeIsolated {
  let transition = FailureMoodTransition(duration: 0.9, recoveryDuration: NukeMusicSweep.returnDuration)
  transition.set(active: true, now: 0)
  transition.advance(at: 0.9)
  check(transition.amount == 1, "Slowdown did not finish")
  transition.set(active: false, now: 1)
  check(transition.amount == 1, "Recovery jumped at the final explosion")
  transition.advance(at: 1.9)
  check(transition.amount > 0.5, "Recovery finished at the old abrupt timing")
  transition.set(active: false, now: 2)
  transition.advance(at: 2.2)
  check(abs(transition.amount - 0.5) < 0.0001, "Repeated updates restarted recovery")
  let halfway = transition.amount
  transition.set(active: true, now: 2.2)
  check(transition.amount == halfway, "Rewind jumped when reversing recovery")
  transition.advance(at: 3.2)
  check(transition.amount == 1, "Rewind failed to restore the mood")
  transition.set(active: false, now: 4)
  transition.advance(at: 4 + NukeMusicSweep.returnDuration)
  check(transition.amount < 0.0001, "Recovery did not reach normal")
}
print("PASS gradual 2.4-second recovery, continuous reversal and repeated updates")

MainActor.assumeIsolated {
  for oneCountTicks in [15, 17] {
    let music = FailureMusicTransition()
    let visual = FailureMoodTransition()
    music.update(failed: false, isNuking: true, allPopped: false,
      remainingTicks: oneCountTicks + 1, oneCountTicks: oneCountTicks, tick: 10, now: 0)
    music.advance(at: 1)
    check(music.rate == 1, "Nuke slowed its music while the countdown still showed two")
    music.update(failed: false, isNuking: true, allPopped: false,
      remainingTicks: oneCountTicks, oneCountTicks: oneCountTicks, tick: 11, now: 2)
    check(music.rate == 1, "The 2-to-1 transition jumped to funeral speed")
    music.advance(at: 2.45)
    check(abs(music.rate - 0.86) < 0.0001, "The countdown reaching one did not start the slowdown")
    music.advance(at: 2.9)
    check(abs(music.rate - 0.72) < 0.0001, "Nuke did not reach funeral speed")
    check(visual.amount == 0, "Music slowdown changed the recoverable run's saturation")
    music.update(failed: false, isNuking: true, allPopped: false,
      remainingTicks: 75, oneCountTicks: oneCountTicks, tick: 100, now: 5)
    music.advance(at: 5)
    check(abs(music.rate - 0.72) < 0.0001, "A later lemming restarted the nuke slowdown")
    music.update(failed: false, isNuking: true, allPopped: false, tick: 101, now: 5.1)
    check(abs(music.rate - 0.72) < 0.0001, "Explosion tails cleared funeral speed before the last pop")
    visual.set(active: true, now: 5)
    visual.advance(at: 6)
    music.update(failed: true, isNuking: true, allPopped: true, tick: 102, now: 6)
    check(abs(music.rate - 0.72) < 0.0001, "The final pop jumped to normal speed")
    music.advance(at: 6 + NukeMusicSweep.returnDuration / 2)
    check(abs(music.rate - 0.86) < 0.0001, "Nuke recovery missed its midpoint")
    music.update(failed: true, isNuking: true, allPopped: true, tick: 102, now: 7.2)
    music.advance(at: 6 + NukeMusicSweep.returnDuration)
    check(abs(music.rate - 1) < 0.0001 && visual.amount == 1, "Results lost tempo recovery or failed-run saturation")
    music.update(failed: false, isNuking: true, allPopped: false,
      remainingTicks: oneCountTicks, oneCountTicks: oneCountTicks, tick: 11, now: 9)
    music.advance(at: 9.9)
    check(abs(music.rate - 0.72) < 0.0001, "Rewind to countdown one did not restore the slowdown")
    music.update(failed: false, isNuking: true, allPopped: false,
      remainingTicks: oneCountTicks + 1, oneCountTicks: oneCountTicks, tick: 10, now: 10)
    music.advance(at: 10 + NukeMusicSweep.returnDuration)
    check(abs(music.rate - 1) < 0.0001, "Rewind before countdown one kept the slowdown")
    music.update(failed: false, isNuking: true, allPopped: false,
      remainingTicks: 1, oneCountTicks: oneCountTicks, tick: 20, now: 13)
    music.advance(at: 14)
    music.update(failed: false, isNuking: false, allPopped: false, now: 15)
    music.advance(at: 15 + NukeMusicSweep.returnDuration)
    check(abs(music.rate - 1) < 0.0001, "Undo did not restore normal speed")
    music.update(failed: true, isNuking: false, allPopped: true, now: 18)
    music.advance(at: 19)
    check(abs(music.rate - 0.72) < 0.0001, "An ordinary loss lost its funeral tempo")
  }
}
print("PASS 2-to-1 slowdown, separate saturation, staggered pops, result recovery, rewind, undo and ordinary loss")
