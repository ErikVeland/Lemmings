# Beta 34 readiness

18 September 2026. Version 0.1, build 34. Three private-test archives contain the
same gameplay changes and full soundtracks. Each contains arm64 and x86_64 binaries.
Build 33 was a local build only, so these archives are the first testers see of
every change since beta 32.

## Archives

All three archives are in `~/Downloads`. Each contains the same
[release notes](ReleaseNotes-beta34.md).

| Archive | Minimum macOS | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| UltimateLemmings-beta34-macOS.zip | 13.0 | 426,678,574 | `f5e7fbd5b427819a4c4157c5da69392d18d981b29650a7b206afc6a1b71754df` |
| UltimateLemmings-beta34-macOS12.zip | 12.3 | 426,696,076 | `381d62e250784d8ddc6bf7a27e5d631c22f863445ae8ac6c37e121140661b05b` |
| UltimateLemmings-beta34-gamecenter-macOS.zip | 13.0 | 426,703,857 | `05fa891c6a686baae1ad44bb8c798ad51d57ff4f6e3e37f933d18e3b00698317` |

Standard and Monterey archives are Developer ID signed, notarised and stapled.
Freshly extracted, quarantined copies pass Gatekeeper as Notarized Developer ID,
and their tickets validate offline. The Game Center archive is development signed,
enables the Game Center and spatial-audio capabilities, and carries the same
two-device profile as beta 31, valid until 11 September 2027. It cannot be
notarised and is limited to those registered Macs.

Apple accepted submissions `edf1a3c6-9860-48a3-8834-eea7d44b65d2` (standard) and
`26b576f9-f105-44c0-8675-a906ae0e9b1e` (Monterey).

## Source and changes

- Standard and Game Center use commit `be828c5` on `l2-seeded-search`.
- Monterey binaries use `20424d7` on `macos12-support`, which merges the same
  changes and keeps the macOS 12.3 deployment target.
- The Game Center app is built from the standard source with the development
  profile. Its only resource difference is the enabled leaderboard catalogue.
- Source checkouts and APFS-cloned assets remain under `.build/beta34/source` and
  `.build/beta34/source-macos12`. No asset-root links were used. The candidate
  audit records no source drift.

Changes since beta 32: player deletion, automatic player edits, a Hot Seat page
that can add players, a way out of saved runs and records that cannot be read,
the sloped-exit fix, restored countdown digits, the Macintosh-artwork crop fix,
and routes for 36 more official Classic levels.

## Verification

- The complete standard candidate audit passed all 53 checks, with no source
  drift. This includes shared engines, resources, known campaign routes, recovery,
  input, replay movies, the app journey, sequel views and a local performance
  measurement.
- Complete app journeys passed for the Monterey build on arm64 and on x86_64
  under Rosetta.
- All six signed startup checks passed: three variants on two architectures.
- Every file in each archive matches its signed app. All 9,536 beta 32 resource
  paths remain, including Macintosh resource forks. The 12 studio recordings
  decode to identical audio, although their container bytes differ.
- The Game Center build carries both capabilities and the enabled catalogue.
- Official Classic coverage is 286/292. Lemmings 2 is 73/120 and Lemmings 3 is
  41/90. There are 284 hint decks and 287 bundled winning replays.

An earlier audit run scored 52 of 53. Its `arcade-records` failure was a keyboard
focus check that cannot pass while the Mac is locked. The rerun with an unlocked
session passed. Both runs are preserved under `.build/beta34/evidence`.

## Limits

Classic 1.0 remains open. Six official Oh No! levels still have no route: Crazy 20,
Wild 9, Havoc 5, Havoc 7, Havoc 16 and Havoc 20. Havoc 20 and Havoc 5 may not be
solvable in this engine; see
[OneZeroClosure-2026-09-15.md](ReleaseReadiness/OneZeroClosure-2026-09-15.md).

Physical Monterey, physical Intel, controllers, full VoiceOver journeys and sustained
performance still need testing. The Monterey Intel build omits the Swift runtime
compatibility library because this compiler supplies it only for Apple silicon.
Rosetta and target-version checks do not establish behaviour on a 2015 MacBook Pro.

Deleting the first profile also removes the older campaign saves that predate
player profiles. Game Center scores then link to the next remaining player.

Full logs, audits, archive verification and startup results are preserved under
`.build/beta34/evidence`.
