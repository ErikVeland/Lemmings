# Beta 23 readiness

Version 0.1, build 23 is ready for private beta testing. Universal Mac app for
Intel and Apple silicon, macOS 13 or later.

## Archives

- [Standard archive](../.build/beta23/standard/UltimateLemmings-0.1-beta23.zip): Developer ID signed, accepted by Apple, stapled, and accepted by Gatekeeper after fresh extraction and quarantine. Local records are enabled; Game Center is disabled.
- [Game Center archive](../.build/beta23/gamecenter/UltimateLemmings-0.1-beta23-gamecenter.zip): development signed with the profile covering both registered test Macs. Its signature, entitlements and device coverage were checked after fresh extraction. It cannot be notarised.

Both zips contain matching release notes, release scope, build metadata and a
validation summary. Both executables and libraries contain arm64 and x86_64 slices.

Notarisation submission: `85d32238-dfa8-4903-b14c-7113778a7b0d`.

## Frozen inputs

Base source: `186a40c88bafe7d1e13e752703344397d1edc241`, with the captured menu-artwork
selection fix in `.build/beta23/working-tree.patch`. Compiler inputs and assets
were copied before building; later shared-checkout edits are excluded.

Snapshot SHA-256: `b86a5e8383bcfcbeb423e57d68fc5c96cf007ef2c228878b42151f3ba9460a34`.

All 3,957 recorded input hashes remained unchanged. The source snapshot,
compiler-input hashes, asset/fixture manifests, archive hashes and logs are
preserved under `.build/beta23`. The app carries the same snapshot identity.

## Regression checks

- Complete app journeys passed on Apple silicon and Intel under Rosetta: 30 checks on each. These cover fonts, targeting, speed, hints, Escape, keyboard/controller wiring, Hot Seat, safe solo transitions, recovery and seasonal music.
- All 25 core/resource suites passed. Three resource-dependent checks first ran before bundle assembly; all passed against the finished app.
- All 18 Swift tests passed. Dedicated controller, speed, save and run-recovery file tests passed.
- HDR GPU output, CRT shaders, viewport geometry and playfield drawing passed. HDR tests exercise simulated headroom; they do not replace physical display validation.
- Rendered menu lettering, settings tabs and speed states were inspected. All four Macintosh artwork families and 292 official Classic Macintosh level scenes passed their checks.
- All 120 original hint routes replayed against the shipping engine. The fresh rescue audit validated 166 full-rescue certificates and 17 best-known rescue records. Every previous certificate remains, with no lower rescue result; five full-rescue proofs were added.
- All 223 preserved official Classic routes and 16 preserved L3 routes replayed successfully. This is route validation, not a complete-playthrough claim for every campaign.

The initial full app checks exposed stale rescue certificates. Both complete
journeys passed after the certificates were replayed and repackaged. The initial
Game Center profile covered only one Mac; the final archive uses the existing
two-device profile. Neither intermediate archive is a release artifact.

## Full Classic corpus comparison

All 6,395 level identities were audited: 292 official Classic levels, 60
conversions and 6,043 fan levels in 535 archives. The inventory matches the
packaged assets, with no input drift.

| Collection | Levels | Reproduced wins |
| --- | ---: | ---: |
| Lemmings | 120 | 120 |
| Oh No! More Lemmings | 100 | 66 |
| Xmas 1991 | 4 | 4 |
| Xmas 1992 | 4 | 3 |
| Holiday 1993 | 32 | 14 |
| Holiday 1994 | 32 | 16 |
| Oh Yes! conversions | 60 | 0 |
| Fan levels | 6,043 | 294 |

Compared with the previous full corpus audit (20.6), no winning route was lost,
no new load/render failure appeared, and eight more official routes won.

**The full-completion gate remains open.** 5,878 levels still lack verified
winning replays. Fan results retain 94 load/start failures and 10 rejected
candidate replays. Candidate replay rejection does not by itself prove a physics
defect. Smoke checks are not complete playthroughs or original-engine equivalence.

See [per-level results](../.build/beta23/classic-validation/levels.jsonl),
[coverage](../.build/beta23/classic-validation/coverage.json),
[regression comparison](../.build/beta23/classic-validation/regression-comparison.json)
and [input drift check](../.build/beta23/classic-validation/input-drift.json).

## Still open before 1.0

Full Classic/fan compatibility, physical Intel and minimum macOS, physical
controllers, full VoiceOver navigation, sustained performance and Game Center
account/network failure recovery remain unverified. L2 and L3 remain previews.
This private beta does not settle public distribution rights.

## Archive SHA-256

- `UltimateLemmings-0.1-beta23.zip`: `9aff38c619af3d0dc268d3dc4db7856abb4588c882324781eb64db4051b3cfe9`
- `UltimateLemmings-0.1-beta23-gamecenter.zip`: `750a05dd71773d730b84e6b120391668e6b48aed04ca8eba6b042869f8fbd875`
