# Mobile Game Center resource refresh

Ultimate Lemmix 2.4.2, build 108. Verified 19 November 2026.

The mobile packages now use the product-specific `ulx.v1` Game Center namespace.
All 359 boards, four sets and 178 ranked conditions are retained. The Apple setup
manifest names `academy.glasscode.ultimatelemmix`. No `ul.v1` identifier remains
in either packaged Game Center JSON file. Non-identity fields are unchanged.

## Provenance

Compiled source remains `1ac19c638e3f62dd48f7d4dedf17b285b961b079`. The original
compiler receipts are preserved without alteration. No compiler or engine test
ran for this refresh.

Resource packaging uses commit `043a43dca9b701c76891d2f81d078ed2df4d6d1d`.
The Lemmix-only transform changed two Game Center files. Inventory hashes and
resource receipts were regenerated. This is a resource mutation and signing
record, not a claim that the older archive was compiled from the new commit.

Copies of the original raw archives received the verified resources. Profiles
and executable entitlements were preserved. Strict signing and the existing
mobile Store preparation and export helpers passed. Original archives and
previous exports remain unchanged.

Every exported app and extension has unchanged Mach-O content outside its
embedded signature and signing size fields. The exported file sets match the
previous packages. Changed files are limited to the two Game Center files,
resource inventory and receipt, executable signatures and resource seals. Xcode
regenerated the upload symbol files with the new archive path. Their source
debug symbol files match byte for byte.

## Verified packages

| Platform | IPA bytes | SHA-256 |
| --- | ---: | --- |
| ios | 50,180,333 | `2d76792c428849945c5763c4222841936cc735909cbb2ba15c2588294256e8d7` |
| tvos | 34,356,582 | `ea74251f9d2ca1f5df2afcf29f3cc8c3c1ac2c5ea94513f323e328c06212c96f` |

Both exports pass Apple Distribution signatures, Store profiles, privacy,
Production cloud and exact resource checks. Apple TV retains production push.
Each app contains 2,298 prepared resources. The iOS widget retains 1,633.
Apple's local package analyser reports zero product errors for either export.

Current mobile Handoff IPAs were replaced only after both exports and the
namespace/code comparisons passed. Prior Handoff files and receipts are preserved
at `/Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261119/Superseded/mobile-before-gamecenter-ulx-20261119-183758`. The restoration ZIP is unchanged.

The new exports are under `mobile-game-center-ulx/ios-store-export` and
`mobile-game-center-ulx/tvos-store-export` in the 19 November build root.
`mobile-game-center-refresh.json` records exact resource, code and package hashes.

No upload or submission occurred. App Store Connect board configuration and
live Game Center acceptance remain separate from this package verification.
