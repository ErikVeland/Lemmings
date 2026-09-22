# Beta 35 readiness

23 September 2026. Version 0.1, build 35. One local Game Center archive for the
registered test Mac. It contains arm64 and x86_64 binaries and full soundtracks.
The owner asked for local Game Center builds unless a full three-archive build
is requested.

## Archive

| Archive | Minimum macOS | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| UltimateLemmings-beta35-gamecenter-macOS.zip | 13.0 | 426,787,231 | `e491bb85870d5de826dd96a5a959cf5bbe101b20fe8ce0c9e1e12bfed69d4059` |

The archive is in `~/Downloads`. It has an Apple Development signature, the
Game Center and spatial-audio capabilities and the enabled leaderboard
catalogue. Its profile `4620c4f0-4245-4888-8484-7caf5895acd6` lists one Mac
and expires on 11 September 2027. The beta 34 record says two devices, but the
same profile lists one. Gatekeeper rejects the archive, as expected for a
development signature.

## Source

- Commit `cbb1ee5` on `l2-seeded-search`. The frozen checkout is
  `.build/beta35/source`, with APFS-cloned game data and no links.
- Changes since beta 34: the later DOS rules for Oh No!, Xmas and Holiday;
  verified routes, hints and solution replays for all 292 official levels and
  all 60 conversions; saved runs that survive later builds.

## Saved runs

A first beta 35 candidate refused every saved run. Restore compared the
whole-engine fingerprint, so any engine change stranded all checkpoints. The
owner reported it from a Hot Seat game. Commit `4fc5c5b` fixed it before this
archive:

- Restore no longer depends on the engine fingerprint.
- Classic restore replays the inputs under the current rules, then under the
  rules the run started with, then continues from the saved engine state.
- New Classic checkpoints store the engine state. A run restored from saved
  state counts as assisted.

Copies of all 155 current Classic checkpoints from the owner's Checkpoints
folder restore with this code. The originals were not changed.

## Verification

- Cross-build recovery tests, run-recovery file tests and save recovery tests pass.
- The complete app integration suite and the sequel suite pass on this source.
- `Scripts/verify-official-classic.sh --include-conversions` passes: 352 strict
  routes, the combined quest with restores, and all rejection cases.
- DOS mechanics regressions and the 120-level soak pass.
- Rescue certificates (251 plus 17 records), the solution bundle and 350 hint
  decks were regenerated for the new engine source fingerprint.

The pre-fix candidate passed a 53-check audit and has notarised standard and
Monterey archives under `.build/beta35/prefix-*`. Do not distribute them: they
refuse saved runs. The Monterey branch has the beta 35 merge (`3ef3ba7`) and a
test fix (`e40b329`), but not the saved-run fix.

## Limits

No signed startup check ran, because it would open the owner's live profile
and checkpoints. L2 and L3 checkpoints do not store engine state yet. They
still restore by replay, which works while those engines do not change.
