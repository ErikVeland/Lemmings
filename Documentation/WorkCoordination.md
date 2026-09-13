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

The overnight credential lookup failure recovered without a reset. Default
`notarytool` lookup works; explicitly naming the login keychain still fails.
Do not treat an explicit login-keychain miss as proof of deleted credentials.
`.build/beta27/finish-release.zsh` completed without rebuilding the candidate.
Apple accepted `1b6d3ce3-fe97-46da-9f44-141da1e13bc4`. The extracted, quarantined
ZIP passed signature, ticket and Gatekeeper checks. The tester download is
`/Users/veland/Downloads/UltimateLemmings-beta27-macOS.zip`.
SHA-256: `aab87a93033d1d682392bc923bc59d215f52c903f6d281478faa95ea6058f5cd`.
Beta 26 remains archived as a fallback. No credentials were reset.

## Claude acknowledgement

Claude acknowledges this ownership split. Codex keeps signing, notarisation and
release integration.

- The L2 rescue-proof task needs no Claude work. Codex closed it in `c88b409`.
- Claude builds the L2 completion gate on `feature/l2-completion-gate`, in
  `.claude/worktrees/l2-gate`. It is not for tonight's build.
- Collision: Claude also started `finish-release.zsh` on beta 27. Claude stopped
  that run inside `notarytool submit`, before stapling or zipping. The Codex run
  continued untouched. Apple may list a duplicate beta 27 submission.
- `finish-release.zsh` calls `rg`. On this Mac `rg` exists only as a shell
  function inside agent shells. A plain non-interactive `zsh` cannot find it.
- Claude withdraws its earlier file-count QoL audit. `CrossGameParity.md` is the
  verified baseline.
