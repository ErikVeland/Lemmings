# Exact steel in text levels

13 September 2026. This closes the text-steel defect found during
[import hardening](BetaExitImportHardening.md). It does not declare a release.

## Behaviour

Text levels retain their declared steel rectangles, including positions between
DOS grid points and sizes larger than a DOS steel entry. The renderer clips each
rectangle to the playfield before scanning pixels. It rejects invalid dimensions
at import and handles extreme renderer inputs without overflow or offscreen loops.

DOS export now writes steel when it can represent every rectangle exactly. It
rejects lossy exports, including the all-zero entry that DOS treats as empty.
Loading a text level does not require a DOS-compatible steel layout.

Fan checkpoints record whether the attempt uses text steel. A missing flag retains
the previous rules. Resume stays paused and preserves the attempt and its state.
Retry starts a new attempt with exact steel. The existing engine-identity and
replayed-state checks remain required. This does not certify migration between
installed releases with different engine fingerprints.

This feature applies to Classic text imports. Native L2/L3 level formats and their
checkpoint behaviour are unchanged. Their runtime checks remain part of validation.

## Coverage

The bundled text corpus has 274 inputs. Both versions load 272 and reject the
same two. The new loader restores 1,246 rectangles across 171 files. Every other
decoded field is unchanged. Of these levels, 115 change their initial simulation
state. Rectangles outside the playfield do not change the simulation mask.

The full corpus still contains 6,395 levels and 535 fan archives. All 517 known
wins reproduce: 223 official-family routes and 294 fan routes. There are no new
load/start failures or lost wins. The existing 85 load/start failures and ten
unsuccessful candidate replays remain. The whole-corpus completion gate still
fails because 5,878 levels have no verified winning route.

## Release audit

The standard release audit includes the fan-library and text-import suites.
It also runs the newly integrated L2 completion gate, its malformed-evidence
checks and its manifest check. The input inventory includes the L2 manifest.
These checks verify recorded routes. They do not claim complete L2 coverage or
continuous completion of all tribes.

## Evidence

Evidence is under `.build/beta-exit-steel/`. The text comparison is
`text-comparison.json`. Per-level results and source inventories are under
`corpus-final/`. The frozen core sources and their hashes are under
`frozen-core/`.

- The explicit macOS 13 build passed.
- All 29 engine/data suites and the strict Original 120 route gate passed
  (`checks-final.log`, `checks.json`).
- The L2 gate reproduced all 64 recorded routes twice. Its seven damaged-route
  tests passed (`l2-completion-final.log`, `l2-negative-final.log`). The gate still
  reports 56 missing routes and no complete ten-level tribe chain.
- Fan-library and checkpoint-file tests passed (`fan-library-final.log`,
  `recovery-files-final.log`).
- The complete app journey passed with the frozen core, including legacy and
  current fan checkpoints, exact paused restore, retry upgrades, Neo recovery,
  hints, solution playback, input, audio and Hot Seat (`app-final.log`).
- The final full-corpus comparison found 115 changed initial states, no changed
  status classifications and no source or asset drift (`corpus-final/`). The
  frozen core also matches the current core source.
- Both release-audit integrity tests passed (`audit-integrity-final.log`).

Early runs exposed a DOS export encoding error, stale local app resources without
solution replays, a compiler deployment-target mismatch and a concurrent L2 helper
merge. The export error was fixed. Final validation uses explicit macOS 13 build
settings and the frozen beta 27 resources for the app journey. Earlier logs remain
available and are not release-candidate evidence.

The campaign, hardware, physical-controller, installed-release migration,
VoiceOver listening and distribution gates remain open. No signed package was
changed or produced by this pass.
