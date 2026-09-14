# Beta 31 readiness

Version 0.1, build 31. Universal arm64 and x86_64 app, macOS 13 or later, with full
soundtracks. Two archives were built from the same frozen source: a notarised build
for all testers and a Game Center build for the two registered Macs.

## Archives

| Archive | Size | SHA-256 |
| --- | ---: | --- |
| `~/Downloads/UltimateLemmings-beta31-macOS.zip` | 426,501,519 bytes | `7f1351309af9a4b678927fbca0fdc11383f5ac64ace470b68bee015a78190b57` |
| `~/Downloads/UltimateLemmings-beta31-gamecenter-macOS.zip` | 426,526,796 bytes | `f0e2f48a1eac301d2e7dc420764d85ca406bd090bc03df619f096da0834616cf` |

Release notes: `~/Downloads/UltimateLemmings-beta31-ReleaseNotes.md`, the same file as
[ReleaseNotes-beta31.md](ReleaseNotes-beta31.md). Each archive carries it as
`Release Notes.md`.

Apple accepted notarisation `c3f8d382-d73a-4ed3-b4d0-87a2a7b0eec4` for the notarised
build. Apple also accepted `0331a659-3b93-4689-b006-8f263e890a62`, the incomplete first
candidate described below. Notarisation does not check game content.

## Changes since beta 30

- Classic Pause and Nuke use the original Amiga panel tiles.
- The solution bundle adds the Oh No! Crazy 4 and Crazy 7 full rescues. Both are
  certified rescue targets.
- Rescue certificates and checked hints were re-verified for the engine change from
  the Lemmings 2 route solver merge. No earlier certificate or hint changed outcome.
- Packaging now checks release scope and stale proofs before it builds.

Beta 30 reached only Game Center testers. The notarised build is the first to carry
its routes, Lemmings 2 carry-over chains and the Lemmings 3 level 5 route to other
testers.

## Frozen inputs

The build ran from a detached checkout of commit `47fcc8d` at `.build/beta31/source`.
The game data directories are APFS clones of the main checkout, not links. The
checkout stayed at the release commit with no changes, and the candidate audit
recorded no source drift.

## Resource comparison

Every packaged resource was compared with the beta 30 app: 9,531 files against 9,529.

- 9,512 files are byte-identical.
- 2 files are new: the Crazy 4 and Crazy 7 rescue witnesses.
- `Hints/solutions.json`, `Hints/classic.json`, `Trolley/verified-maxima.json` and
  `Trolley/engine-fingerprint.txt` changed as described above.
- `GameCenter/leaderboards.json` differs only in `enabled`. It is off in the notarised
  build and matches beta 30 exactly in the Game Center build.
- The 12 soundtrack containers differ in bytes. Their decoded audio is identical to
  beta 30 and to the source WAV recordings in both archives.

## Validation

| Check | Result |
| --- | --- |
| Candidate audit against the notarised app | 52 passed, 1 failed (see below) |
| Full Mac app journey, Apple silicon | Passed, in the audit |
| Full Mac app journey, Intel binary under Rosetta | Passed, 37 groups |
| Sequel views, replay movies, performance measurement | Passed, in the audit |
| Original 120, additional campaign, Lemmings 2 and Lemmings 3 route gates | Passed, in the audit |
| Rescue certificates | Passed, in the audit |
| Trolley suite, including Game Center transport | Passed, `PASS THE TROLLEY` |
| Signed app startup, both archives, arm64 and x86_64 | Passed |
| Notarised archive: stapled, extracted, quarantined | Gatekeeper accepted as Notarized Developer ID |
| Game Center archive: entitlement, catalogue, profile | Present, enabled, two registered Macs until 11 September 2027 |
| Every archived file against the signed app | Match, both archives |

### The failed audit check

`arcade-records` failed once with "Retry did not restore keyboard focus to the game
window (active: false, visible: true, retried: 2, key: none)". The retry action ran,
but the test app was not the active application, so its window could not take
keyboard focus. When checked afterwards, the application hosting this build session
was frontmost on the same display.

No retry or focus code changed since beta 30. The test was then run again through
`Tools/UITestRunner/run.py` from both the beta 31 source and the frozen beta 30
source. Both passed all four groups, including the focus check. The failure is an
activation race in the test environment, not a beta 31 defect. The failed audit log
is retained in `.build/beta31/audit/logs/arcade-records.log`.

## Problems found while cutting this beta

- **Missing soundtracks in the first candidate.** The first notarised candidate was
  145 MB and had no soundtracks or Macintosh resource forks. Its checkout linked the
  game data directories, and the soundtrack encoder and resource fork copier do not
  follow a link at the root. The resource comparison found it. That candidate was
  never distributed and is kept in `.build/beta31/failed-candidate-symlinked-data`.
  The same cause affects the earlier beta 26 archive. See
  [Beta26Readiness.md](Beta26Readiness.md).
- **Stale certificates.** The route solver merge changed an engine source file, so
  the packaging check rejected the rescue certificates. They were re-verified, not
  exempted.
- **A test runner deadlock during validation.** One run wrapped a script in
  `Tools/UITestRunner/run.py` although the script already calls it, so the two
  runners waited on the same lock. The run was stopped and repeated correctly. It
  affected no product or archive.

## Open limits

Classic has verified wins for 238 of 292 official levels. Lemmings 2 has wins for 64
of 120 levels and no complete ten-level tribe run. Lemmings 3 has wins for 17 of 90
levels. Live Game Center sign-in and score submission need tester validation.
Physical Intel and minimum macOS hardware, controllers, full VoiceOver support and
sustained performance remain untested. This beta does not declare Classic 1.0
complete.

Evidence is in `.build/beta31`: `package-standard.log`, `package-gamecenter.log`,
`package-verification-standard.json`, `package-verification-gamecenter.json`,
`audit/`, `rosetta.log`, `trolley-tests.log`, `ab-arcade-beta31.log`,
`ab-arcade-beta30.log`, and the startup logs.
