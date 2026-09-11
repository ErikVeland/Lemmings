# Post-beta-20 local gap closure

This pass closes local recovery and Hot Seat gaps. It does not declare a 1.0 release.
The beta 20 archives remain unchanged.

## Changes

- Classic fan checkpoints retain the pack, asset dataset, chosen level order and current position.
  Resume restores paused, keeps the selected skill and attempt identity, and checks
  replayed state. Leaving a fan run requests a checkpoint. Missing packs are rejected
  before replacing the live session.
- L2 practice checkpoints retain the training map and custom eight-skill panel.
  Restore recreates practice without applying its saved campaign progress, pauses,
  and retains the attempt. Invalid map and skill metadata is rejected.
- **New Hot Seat** offers a confirmed fresh start with the selected players.
  It starts with the host and a fresh shared campaign. **Choose a game** keeps the
  current campaign. Solo progress, scores and records remain separate.
- Accessibility callbacks route game-view state access to the main actor, including
  calls from a background thread. The bridge passes an optimised strict compile.
- The earlier checkpoint-file fix recovers valid backups after an oversized primary
  and discards stale file-size metadata. Hint tier three now explains opening
  release-rate changes for the 103 affected original levels.
- The release audit now includes the checkpoint-file and hint-catalogue checks.

## Validation

Tests use isolated outputs under `/Users/veland/Lemmings-recovery/.build/one-zero`.
The core library is unchanged from beta 20. These runs reuse its optimised arm64
library and frozen assets. UI suites use the shared test-runner lock.

- Full app integration: audio, controls, speed, hints, accessibility, Classic,
  NeoLemmix and fan recovery, interruption and Hot Seat boundaries.
- Sequel UI: campaign restoration and a custom L2 practice panel, exact state,
  continued play, attempt identity, invalid metadata and mouse speed controls.
- Arcade: new Hot Seat confirmation/cancellation, fresh progress, preserved solo
  data, relaunch, save failure, results, keyboard/controller handovers and records
  passed. The final native key-window assertion could not pass with the screen locked.
- File recovery: oversized-primary preservation, valid/invalid backups,
  stale writers, locks, clear semantics and invalid fan queues.
- Hint catalogue: all 120 decks, 103 rate contexts and spoiler boundaries.
- Audit integrity: both existing integrity tests.

Logs are `app-final.log`, `sequel-final.log`, `arcade-current.log`,
`recovery-files.log`, `hints.log` and `audit.log`. A worktree fixture lookup failed
before the full app rerun. The earlier Arcade run also needed the bundle fixture
path. Its complete initial run passed in `arcade-final.log`, before the final
accessibility change. Subsequent runs passed the functional assertions but failed
native key-window activation while macOS reported `CGSSessionScreenIsLocked=true`.
The unchanged beta 20 executable reproduced the same failure in
`arcade-locked-baseline.log`. The focus check remains required on an unlocked desktop. These setup failures did
not change installed saves or beta archives.

## Remaining 1.0 work

Campaign route tooling and fixtures remain reserved for Claude. This pass changes
neither their coverage nor sequel fidelity claims. The gate register retains
physical power-loss and installed-release migration trials, physical-controller
and VoiceOver journeys, sustained hardware/performance validation, and the existing
external distribution requirements. A final candidate needs its own build and
package verification.
