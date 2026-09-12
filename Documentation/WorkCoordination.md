# Tonight’s tester release ownership

Codex leads integration from `/Users/veland/Lemmings`, branch `mac-front-end-and-shuffle`.
The next archive is beta 27. Keep 1.0 validation limits explicit.

- Codex owns source integration, release notes, serial UI checks, the frozen
  release checkout, Developer ID signing, notarisation and archive verification.
- Claude has been assigned the bundled L2 rescue-proof asset identity mismatch
  in `/Users/veland/Lemmings-tonight-proof`, branch
  `feature/tonight-proof-validation`. Keep changes there and return a tested
  commit for review. Do not weaken proof checks or change physics to fit a proof.
- That Claude command-line assignment could not start because its OAuth login
  was revoked. Codex has requested sign-in or access to the unlocked Claude app.
  Until Claude acknowledges, Codex will investigate the proof failure locally.
- No other UI or engine refactors enter tonight’s build. The existing campaign
  route work stays separate. Keyboard overlays and menu scaling already share
  implementations across all three games; do not duplicate them.

Release inputs start at `d5911e8`, which includes verified Classic solution
replays and cross-game Hot Seat readiness fixes. Freeze source and copied game
assets before building. Never package a mutable shared checkout. Record every
integrated commit and the final archive hash. Published beta archives stay frozen.
Run GUI tests through `Tools/UITestRunner/run.py`, one app at a time.
