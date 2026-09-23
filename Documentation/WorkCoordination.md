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
No credentials were reset. Do not use beta 26 as a fallback: its archive has no
soundtracks and no Macintosh resource forks. See Beta26Readiness.md. Beta 29 is
the latest complete notarised archive.

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

## Beta 31

Claude cut beta 31 on 14 September 2026, at the user's request, while Codex was
idle. Do not reuse build number 31.

- Claude first committed the uncommitted beta 28 to 30 work and the later changes
  in reviewed, tested commits, then merged the Lemmings 2 route solver spike.
- Release commit `47fcc8d`, frozen at `.build/beta31/source` with copied game data.
- Notarised archive: `~/Downloads/UltimateLemmings-beta31-macOS.zip`.
- Game Center archive: `~/Downloads/UltimateLemmings-beta31-gamecenter-macOS.zip`.
- See `Documentation/Beta31Readiness.md` for hashes, validation and the problems found.

Never freeze a release checkout with linked game data directories. Copy or clone them.
The soundtrack encoder and resource fork copier do not follow a link at the root.

## Beta 32

Codex cut three beta 32 archives on 15 September 2026 at the user's request.
Claude's L2 route work is committed and included in all three variants. The
Monterey branch includes the same gameplay changes and targets macOS 12.3.
Standard and Game Center target macOS 13. Do not reuse build number 32.

The frozen archives, source commits, 53 passing audit checks and hardware limits
are recorded in [Beta32Readiness.md](Beta32Readiness.md). The downloads are under
`~/Downloads`; the signed apps and evidence remain under `.build/beta32`.

## Lemmings 2 and 3 route search after beta 32

Claude continued the route work on `l2-seeded-search` on 15 September 2026.

- Lemmings 2 has verified routes for 73 of 120 levels. Cavelems chains all ten
  levels, the first tribe to do so. See
  [SeededSearch.md](Lemmings2Completion/SeededSearch.md).
- Lemmings 3 has verified routes for 41 of 90 levels from the new solver in
  `Tools/Lemmings3Solver`. See [CampaignCompletion](CampaignCompletion/README.md).
- No runtime physics changed, and `Sources/NxlvKit` did not change after beta 32.
  The Trolley certificates and hints stay valid.
- Played Lemmings 2 levels are saved as seed routes. Tester recordings of the
  break levels in SeededSearch.md are the fastest way to extend the chains.

## Local build 33

The user bumped `Resources/Info.plist` to build 33 on 16 September 2026 for a
quick local, unsigned build on `l2-seeded-search`, for the user's own testing.
It was not cut with `package-beta.sh`, not signed for distribution, not
notarised, and has no release notes. Do not reuse build number 33 for an
actual tester archive; the next real archive starts at build 34.

## Beta 34

Claude cut three beta 34 archives on 18 September 2026 at the user's request.
They carry the player, saved-run and Hot Seat changes, the routes for five more
Oh No! levels, and every change since beta 32. Build 33 never reached testers.

Standard and Game Center use `be828c5`; Monterey uses `20424d7`. The frozen
checkouts, 53 passing audit checks, notarisation identifiers and archive hashes
are recorded in [Beta34Readiness.md](Beta34Readiness.md). The downloads are under
`~/Downloads`; signed apps and evidence remain under `.build/beta34`.

Do not reuse build number 34. The next archive starts at build 35.

A locked Mac fails the `arcade-records` keyboard focus check and hides the
notarytool credentials. Unlock the session before an audit or a release run.


## Beta 35

Claude cut beta 35 on 23 September 2026 as one local Game Center archive,
at the owner's request. Source `cbb1ee5`; see [Beta35Readiness.md](Beta35Readiness.md).
Do not reuse build number 35. The next archive starts at build 36.

- A new build must never invalidate saved runs. Restore must not depend on the
  engine fingerprint. Before a release that touches engines or recovery, restore
  copies of the owner's real checkpoints and run `Scripts/run-cross-build-recovery-tests.sh`.
- "Cut a build" means a local Game Center build unless the owner asks for all
  three archives.
- The notarised pre-fix beta 35 archives under `.build/beta35/prefix-*` refuse
  saved runs. Do not send them.

## Beta 36 (RC1)

Claude cut all three beta 36 archives on 23 September 2026 at the owner's
request, as RC1: the first candidate built for real, physical hardware
testing since beta 32. Standard and Game Center use `6b5f945` on
`l2-seeded-search`; Monterey uses `d8b77ca` on `macos12-support`, merged
forward through the beta 35 saved-run fix, which that branch had been
missing. See [Beta36Readiness.md](Beta36Readiness.md).
Do not reuse build number 36. The next archive starts at build 37.

- Before freezing a checkout, clone every gitignored data directory, not only
  `Sources/Ports` and `Sources/Music`. The first beta 36 packaging attempt
  failed because the frozen checkouts were missing `Content` (fan level
  packs, also gitignored), and `Tools/FanLevelCatalog/prune.py` fails hard
  on a missing pack rather than skipping it. Both checkouts were fixed by
  cloning `Content` in after the fact and rebuilding.
- The `macos12-support` worktree can silently fall behind the working branch
  on exactly the commits that matter most (it had missed the saved-run
  fix). Check `git log <monterey-branch>..<working-branch> --oneline` before
  packaging, every time, not only when a merge is expected.
- 16GB of stale per-feature `.build/*` caches and two stale git worktrees
  (`.build/beta33/source`, `.build/beta33/source-macos12`) were removed
  before this pass. Deregister a worktree with `git worktree remove` before
  deleting its directory, never a plain `rm -rf`.
