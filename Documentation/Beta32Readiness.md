# Beta 32 readiness

15 September 2026. Version 0.1, build 32. Three private-test archives contain the
same gameplay changes and full soundtracks. Each contains arm64 and x86_64 binaries.

## Archives

All three archives are in `~/Downloads`. Each contains the same
[release notes](ReleaseNotes-beta32.md).

| Archive | Minimum macOS | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| UltimateLemmings-beta32-macOS.zip | 13.0 | 426,548,466 | `f6fa66fefb2e892dc73aa3343e0298fba4c2545ca01bdf7be3f2f74bc204cf43` |
| UltimateLemmings-beta32-macOS12.zip | 12.3 | 426,566,975 | `028205d698ffa3fdf463d0b1388a81a9708d108475582a3e923834676b64fc7e` |
| UltimateLemmings-beta32-gamecenter-macOS.zip | 13.0 | 426,557,611 | `1ad1ce21b2de5c04a5087fdaedb3362ee2b52c731d6f3b82ce5c5fa8d1221e47` |

Standard and Monterey archives are Developer ID signed, notarised and stapled.
Freshly extracted, quarantined copies pass strict signature and Gatekeeper checks.
The Game Center archive is development signed, enables both required capabilities,
and carries the same two-device profile as beta 31, valid until 11 September 2027.
It cannot be notarised and is limited to those registered Macs.

Apple accepted submissions `4eca44cb-340b-4793-8b4f-0e0bcc35f0a0` (standard) and
`9c010cef-23a2-483f-8228-3c3c9c2dedee` (Monterey).

## Source and changes

- Standard and Game Center use commit `a144460`. This includes the committed L2
  seeded solver, route recording, improved routes and runtime-test repairs.
- Monterey binaries use `1f99014`, which merges the same gameplay changes and adds
  the macOS 12.3 deployment target and compatible app delays.
- Monterey test source ends at `5b29466`. That follow-up only replaces 21 test
  delays that required macOS 13. App sources, build scripts, resources and package
  metadata are unchanged from the compiled commit. The signed archive was not modified.
- The Game Center app is copied from the standard app and re-signed with the
  development profile. Its only resource difference is the enabled leaderboard catalogue.

Source checkouts and APFS-cloned assets remain under `.build/beta32/source` and
`.build/beta32/source-macos12`. No asset-root symlinks were used. The standard
candidate audit records no source drift. The separate build and final test commits
are recorded in `binary-commits.json` and `commits.json`.

## Verification

- The complete standard candidate audit passed all 53 checks. This includes shared engines, resources, known campaign routes, recovery, input, replay movies, the app journey, sequel views and a local performance measurement.
- Additional complete app journeys passed for the standard Intel binary and for
  both Monterey architectures. Intel execution used Rosetta on the current host.
- All six signed production startup checks passed: three variants on two architectures.
- L2 runtime tests passed against the optimised production engine. The completion
  gate replayed all 64 standalone routes and 19 carry-over witnesses twice, and
  rejected damaged routes. Version conversion checks passed.
- The Trolley suite passed, including Game Center transport tests. Live account
  sign-in and score submission remain tester tasks.
- Monterey HDR checks, sequel view checks and explicit Metal 2.4 shader compilation passed.
- Every file in each archive matches its signed app. All 9,531 prior resource paths
  remain, including Macintosh resource forks and all 12 soundtrack recordings.
  Both notarised variants decode to exactly the source WAV samples. Game Center
  retains the standard build's audio bytes.
- Rendered settings, hints and sequel states were inspected, with input-target and
  state checks supplied by the app suites.

The first Monterey app-test compilation failed because the tests still used
macOS 13 sleep APIs. The test-only fix above resolved it. Failed and superseded
attempt logs remain alongside the successful results. No gameplay check was removed.

## Limits

Classic 1.0 remains open. Official Classic coverage
is 238/292, L2 is 64/120 with no complete ten-level tribe chain, and L3 is 17/90.
Unpreserved solver candidates do not increase these counts.

Physical Monterey, physical Intel, controllers, full VoiceOver journeys and sustained
performance still need testing. The Monterey Intel build omits the Swift runtime
compatibility library because this compiler supplies it only for Apple silicon.
Rosetta and target-version checks do not establish behaviour on a 2015 MacBook Pro.

Full logs, archive verification, audio sample hashes, source identities and the
candidate audit are preserved under `.build/beta32`.
