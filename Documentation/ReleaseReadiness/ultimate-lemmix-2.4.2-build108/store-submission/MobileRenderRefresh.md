# Mobile archive and Store export refresh

Ultimate Lemmix 2.4.2, build 108. Frozen source: `1ac19c638e3f62dd48f7d4dedf17b285b961b079`.

Both cached-profile archives completed with Xcode 27.1. Each receipt confirms
unchanged shared source and publication metadata during compilation. Both
platform receipts have the same source fingerprint. Local Store-archive
preparation passed strict signature, resource and entitlement checks.

The presentation equivalence check retained all 9,600 output bytes. No engine
source changed. Test suites were skipped for this presentation-only refresh.

After the user unlocked the Mac and signed into Xcode, both Store exports
completed successfully. The earlier credential availability issue is resolved
for these exports. It did not establish account deletion.

| Platform | IPA bytes | SHA-256 |
| --- | ---: | --- |
| ios | 50,180,093 | `ed7d6d3afd733ed1c9d71301270b75101ed5722779e4054629e1e52e383d2b1f` |
| tvos | 34,356,381 | `bfa391e196aa71b4bef0290cc73f6d0995aaaa79479d74c217ba01c5564799d2` |

Both main apps use `academy.glasscode.ultimatelemmix`. The iOS Desk Clock widget
and TV Top Shelf identities are unchanged. Apple Distribution signatures,
Store profiles, shared groups, Game Center and Production cloud entitlements
pass. Apple TV retains production push. Privacy manifests and codeless resource
signatures pass. Each app contains exactly 2,298 prepared resources; the iOS
widget contains its exact 1,633-file subset. Apple's local package analyser
reports zero product errors for either export.

The verified IPAs replace the mobile files in the current Handoff. Prior IPAs
and mobile evidence are preserved at `/Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261119/Superseded/mobile-handoff-before-refresh-20261119-083355`. No restoration ZIP changed.

No build was uploaded or submitted. App Store processing, App Review and
physical-device acceptance remain separate from these local package checks.
The exports and verification receipts are under `ios-store-export` and
`tvos-store-export` in the 19 November build root. Exact commands remain in
`resume-mobile-store-exports.sh`; existing output folders must be preserved
before any future export rerun. Another compile is only required if source changes.

Machine-readable evidence: `mobile-render-refresh-results.json` and
`unified-mobile-package-results.json`.
