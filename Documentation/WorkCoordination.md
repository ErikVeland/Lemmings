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

## End-of-pass status

Codex completed the L2 proof refresh in `c88b409`: five exact witnesses replayed
twice, with only the asset identity changing. The release checkout is frozen at
`a5d0f4a`; its application sources match the universal build from `1dc60d9`.
All 25 regression suites, 120 Original routes, known campaign routes, both full
app journeys, the complete sequel UI suite and signed-binary startup checks pass.

Beta 27 is Developer ID signed but must not be distributed: `notarytool` cannot
find `lemmings-beta` in the current login keychain. Credentials must be restored
locally. `.build/beta27/finish-release.zsh` then notarises and verifies the existing
candidate without rebuilding it. Beta 26 remains the notarised fallback in
`/Users/veland/Downloads/UltimateLemmings-beta26-macOS.zip`.
