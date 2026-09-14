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
