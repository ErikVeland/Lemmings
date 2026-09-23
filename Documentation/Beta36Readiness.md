# Beta 36 readiness — RC1

23 September 2026. Version 0.1, build 36. Release Candidate 1: the first
archive since beta 32 built for real, physical hardware testing rather than
the developer's own Macs. Three archives, each with arm64 and x86_64 binaries
and full soundtracks.

## Archives

All three archives are in `~/Downloads`. Each contains the same
[release notes](ReleaseNotes-beta36.md).

| Archive | Minimum macOS | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| UltimateLemmings-beta36-macOS.zip | 13.0 | 426,763,510 | `a2b0ba9ead02be008c29de397c5184dd999bce8269dd6943f7578f8c252ebc6d` |
| UltimateLemmings-beta36-macOS12.zip | 12.3 | 426,785,951 | `217ee34ad576e4f53fe4ea9ddb874468bb4583ee03e2c9e36a00d14f621a01eb` |
| UltimateLemmings-beta36-gamecenter-macOS.zip | 13.0 | 426,788,651 | `e48953a96a9df5b7e0a50f4f09bb7494813bdf2b20dbe1fdcfc4a79cf55ff2e5` |

Standard and Monterey archives are Developer ID signed, notarised and stapled.
Freshly extracted, quarantined copies pass strict signature and Gatekeeper
checks. Apple accepted submissions `6c46d122-4a39-4f91-b35c-6326c3756f21`
(standard) and `7866c61a-5e4c-4327-9161-351551c88a57` (Monterey).

The Game Center archive is development signed with the `Lemmings macOS
Development` profile (`4620c4f0-4245-4888-8484-7caf5895acd6`, expires
11 September 2027, lists one Mac). It carries the Game Center and
spatial-audio entitlements and the enabled leaderboard catalogue. It cannot
be notarised and is limited to that registered Mac.

## Source

- Standard and Game Center use commit `6b5f945` on `l2-seeded-search`. The
  frozen checkout is `.build/beta36/source`, with APFS-cloned `Sources/Ports`,
  `Sources/Music` and `Content` (fan level packs) and no links.
- Monterey uses commit `d8b77ca` on `macos12-support`, which merges the same
  source through the saved-run fix (`4fc5c5b`) that `macos12-support` was
  previously missing. Its frozen checkout is `.build/beta36-macos12/source`,
  cloned the same way.
- Changes since beta 32 (the last archive that reached testers): the official
  Classic campaign closed at 352/352 (292 official routes plus 60 Oh Yes!
  conversions), the later DOS rules for Oh No!, Xmas and Holiday, saved runs
  that survive an engine change across builds, player deletion and Hot Seat
  additions, and the sloped-exit, countdown-digit and Macintosh-artwork
  fixes. See [release notes](ReleaseNotes-beta36.md) for the full list.

## Verification

- The complete app integration suite (arm64 and x86_64), beta regressions,
  swift tests, sequel Macintosh-artwork tests and HDR explosion tests all
  passed on the standard/Game Center source. Log:
  `.build/beta36/logs/main-verification.log`.
- `Scripts/verify-official-classic.sh --include-conversions` passed: all 292
  official routes and 60 conversion routes replay to a win, and the combined
  Classic Full Quest passed 352 wins, 1,056 saved-run recoveries, 352
  progress resumes and 6 release-chapter transitions. All six negative/
  rejection cases (missing evidence, altered outcomes, late input, for both
  official and conversion scope) correctly failed.
- `Scripts/run-cross-build-recovery-tests.sh` passed on both the
  standard/Game Center source and the Monterey source: old-rule replay,
  saved-state fallback, encoded-state continuation and foreign-level
  rejection all behave correctly. This is the fix that made beta 35's saved
  runs survive an engine change; the Monterey branch had never run this
  check before this pass, because it was missing the commit.
- `Scripts/verify-trolley-maxima.sh` passed: 251 exact-condition rescue
  certificates and 17 best-known records packaged, 562 levels audited.
- On the Monterey source: the complete app integration suite (arm64 and
  x86_64 under Rosetta), sequel Macintosh-artwork tests and cross-build
  recovery all passed. Log: `.build/beta36-macos12/logs/monterey-verification.log`.
  The Monterey worktree does not re-run the 352-route campaign replay: its
  engine and level data are identical to the source just verified above, so
  replaying the same deterministic routes there would add no new evidence.

No failures were recorded in either verification pass.

## Packaging notes

The first packaging attempt for both the standard and Monterey archives
failed: the frozen checkouts cloned `Sources/Ports` and `Sources/Music` but
not `Content`, which is gitignored the same way and holds the fan level
packs the pruning step reads. `Tools/FanLevelCatalog/prune.py` failed with a
missing-file error for `Content/LevelPacks/0003-Anatol00.zip`. Both checkouts
were fixed by cloning `Content` in, and both archives were rebuilt from the
same frozen source. The Game Center archive was unaffected and needed no
rebuild.

## Limits

Lemmings 2 has preserved wins for 73 of 120 levels and Lemmings 3 for 41 of
90; both remain preview status. Physical Intel, minimum macOS, HDR, multiple
displays and sustained performance are what this candidate exists to test —
none of them are established by this local verification pass. Live Game
Center under network loss, full VoiceOver listening journeys and physical
controller journeys still need tester validation. This build does not
declare Classic 1.0 complete.
