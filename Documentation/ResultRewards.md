# Results and rewards

[Extra skills](ExtraSkills.md) are rare consumable rewards: one per ten distinct
three-star levels without rewind, undo or bonus skills. Results name newly earned
consumables and retain their reasons in Rewards earned. Bonus attempts have
separate records, advance the campaign, and earn no consumables or career stars.

The result screen shows what the player achieved and what to try next. Its three
stars use the existing rescue goals. A clear earns the first star and keeps
**Next level** as the primary action. Extra stars never block campaign progression.

Each star shows its rescue threshold and whether the run met it. The third star
uses a verified maximum, a best-known target, or an actual full rescue. Unknown
targets stay unknown. A failed run earns no stars, even if its rescue count meets
the threshold. The best previous rating remains visible.

On Mac, hover over a star or named award to read its condition. The whole star
is an input target. Click or use keyboard activation to open a fixed detail page.
Descriptions wrap in the shipped bitmap font. Back returns to the same result
without advancing gameplay. These controls are shared by Classic, Lemmings 2
and Lemmings 3.

On iOS and TV, select the award row to open its description. Back returns to the
result, and Next award steps through the awards from that run. An iPad pointer
also shows the description on hover without changing the result.
Screen-reader help includes each award's condition.

Earned stars arrive in a sequence of short stamps and rising chimes. The entire
sequence takes at most 0.81 seconds. Controls work immediately. It runs only on
the result page, uses six small redraws at most, and adds no gameplay rendering.
Reduced Motion shows the complete rating immediately. Chimes follow the game's
sound volume and mute state. Leaving the page cancels the sequence and sounds.

The two result cards separate **This level** from optional **Career** review:

- The level card names a new level award and shows the personal record.
  Level goals lists the rescue targets and results. Impossible full-rescue goals
  and unproven hands-off challenges are not advertised.
- The career card links to career stars, awards and any newly earned reward
  receipt. It does not display resource balances, future milestone progress or
  a philosophical interpretation. Reward reasons open only by explicit choice.
- Time records, resource balances and future career milestones remain in Records,
  Career and reward details. A clear never opens another reward page automatically.
- Career stars add the best rating for each distinct level once. Repeating a
  clear does not add stars. Improving a rating adds only the difference.
- **C** opens career progress. **G** opens level goals. Existing review shortcuts,
  retry, continue, Hot Seat ownership and paused Ready handovers remain available.

Phone and TV results use one static **Awards (N)** action instead of cycling
award names automatically. Selecting it opens the first award. Next award visits
the others, and Back returns to the same result. The optional second display
region retains its full goals and award collection when that device supports it.

Local result rankings use the existing compatible level boards. A climb displays
both ranks, such as **#2 > #1**. **All levels** opens the local career board.
Assisted and unassisted career star totals remain separate. Career achievements
retain their existing rules, which may allow assisted attempts. The board's
rewind filter does not change achievement rules.

**Worldwide** connects to Apple Game Center. Its ranked catalogue uses exact
level conditions and excludes rewinds. It has career stars, distinct clears,
three-star levels and a Most Saved board for each configured level. Career
rankings on this Mac can include levels outside the worldwide catalogue. The
worldwide page states its catalogue size and shows only scores returned by Apple.
See [Game Center setup](GameCenterSetup.md) for the release requirements.

History remains the source of truth. Results derive progress without changing old
attempts, achievements, campaign saves, or star rules. Reopening an old result
uses history up to that attempt. Gameplay speed does not affect rankings.

Validation: `Scripts/run-trolley-tests.sh` covers progress deltas, near misses,
failed attempts, record improvements, profile separation, repeated levels,
assisted runs, online catalogue filtering, offline retry, duplicate suppression,
and rendered navigation. The Game Center transport tests use a deterministic test
service; Apple account and live service testing are separate release checks.

Achievement-help checks passed offscreen with muted audio for Classic, Lemmings 2
and Lemmings 3. They cover full star targets, hover, named-award selection,
keyboard Back and Next award, and unknown targets without advancing gameplay.
The captures were inspected for wrapping and clipping. Nine shared phone, tablet
and TV renders passed action-target checks, and the iOS source compiled.
Physical touch, iPad pointer interaction and VoiceOver remain device checks.
The broader native suite later stopped at a missing hosted **Play replay** link.

The reward integration also fixes rescue-proof expiry after presentation edits.
The old fingerprint included display preferences, nuke button gestures and skill
shortcuts. These files do not participate in native replay simulation. Both audit
tools now exclude those three files. The migration checked that all 101 remaining
engine files exactly match the source snapshot that produced the existing proofs,
and validated all 178 witness hashes. It did not infer new maxima or change any
witness. The migration evidence is in
[TrolleyVerification/presentation-fingerprint-migration.json](TrolleyVerification/presentation-fingerprint-migration.json).
Changes to an engine file, or a new engine dependency, still retire the proofs.
Run `python3 Tools/TrolleyVerification/test_fingerprint.py` to check that boundary.
