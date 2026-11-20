# Mobile packages for the shared App Store listing

Current export refresh: 19 November 2026, after the user restored Xcode credential
availability. Both packages now use frozen source `1ac19c638e3f62dd48f7d4dedf17b285b961b079`.
The cached-profile archive commands omitted `-allowProvisioningUpdates`; Store
export used the existing helper. See [Mobile render refresh](MobileRenderRefresh.md)
for the new signatures, hashes and preserved history. No upload occurred.

Candidate: Ultimate Lemmix 2.4.2, build 108. Identity revision: 19 November 2026.
The owner selected one App Store listing for Mac, iPhone, iPad and Apple TV.
The App Store Connect app is `6836347807`.

| Target | Bundle identifier |
| --- | --- |
| Mac, iOS and tvOS main apps | `academy.glasscode.ultimatelemmix` |
| Mac Desk Clock widget | `academy.glasscode.ultimatelemmix.DeskClockWidget` |
| iOS Desk Clock widget | `academy.glasscode.ultimatelemmix.ios.DeskClockWidget` |
| tvOS Top Shelf | `academy.glasscode.ultimatelemmix.tvos.TopShelf` |

The extensions keep their registered identities and valid parent-app prefix.
The shared app group, iCloud container and feature entitlements stay unchanged.
Ultimate Lemmings has no source, identity or metadata change in this revision.
The previous mobile main IDs, ending in `.ios` and `.tvos`, belong to the retained
18 November build evidence. Those IPAs do not target the selected shared listing.

The Mac package from 18 November already uses the shared main identity. Its
original receipt remains historical evidence for its unchanged package. The
product manifest now records the revised mobile IDs and explicit extension IDs,
so its new hash must not replace the original hash in the Mac receipt.

No installed app or saved data is changed by this packaging task. A different
main app ID has a separate local application container. This record does not
claim migration of a local sandbox from an earlier mobile test installation.
The existing shared cloud and app-group identifiers remain available.

## Build and package

Use `/Applications/Xcode.app/Contents/Developer`, Xcode 27.1. The build root is
`/Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261119`. Its resource directory
is an unchanged copy of the verified 2,298-file submission set from 18 November.

From the Ultimate Lemmix repository, archive iOS with:

```sh
build_root=/Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261119
TMPDIR="$build_root/temporary/" \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
zsh Scripts/build-publication.sh ultimate-lemmix ios \
  -configuration Release -destination 'generic/platform=iOS' -jobs 3 \
  -derivedDataPath "$build_root/ios-derived" \
  -archivePath "$build_root/UltimateLemmix-iOS.xcarchive" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=54WU29TRTY \
  ULTIMATE_LEMMIX_RESOURCES_DIR="$build_root/mobile-resources-submission" \
  ULTIMATE_LEMMIX_RELEASE_CHECKS=1 REGISTER_APP_GROUPS=YES archive
```

For tvOS, use platform `tvos`, destination `generic/platform=tvOS`, two jobs,
`tvos-derived` and `UltimateLemmix-tvOS.xcarchive`. Require the publication
receipt to report unchanged shared source and publication metadata.

Prepare and export the archive with:

```sh
python3 Tools/Publication/mobile_store.py prepare-archive \
  --platform ios --resources "$build_root/mobile-resources-submission" \
  --archive "$build_root/UltimateLemmix-iOS.xcarchive" \
  --output "$build_root/UltimateLemmix-iOS-Store.xcarchive" \
  --identity 'Apple Development: Erik Veland (T93G24W53E)'

python3 Tools/Publication/mobile_store.py export \
  --platform ios --resources "$build_root/mobile-resources-submission" \
  --archive "$build_root/UltimateLemmix-iOS-Store.xcarchive" \
  --output "$build_root/ios-store-export" \
  --temporary "$build_root/temporary"
```

For tvOS, use platform `tvos`, the corresponding tvOS archive names and
`tvos-store-export`. The helper exports locally. It never uploads a binary.
It verifies signatures, exact resources, profile capabilities, privacy manifests
and zero product errors from Apple's local package analyser.

No engines changed. Automated test suites, foreground apps and audio are excluded
under the release policy. Store processing, device acceptance and App Review
remain separate from local package verification.

## Verified local results

Both archive wrappers and distribution exports completed successfully. Shared
source and publication metadata remained unchanged throughout compilation.
Both package analysers report zero product errors. Neither export logged an
account authentication error.

| Platform | IPA bytes | SHA-256 |
| --- | ---: | --- |
| iOS | 50,180,093 | `ed7d6d3afd733ed1c9d71301270b75101ed5722779e4054629e1e52e383d2b1f` |
| tvOS | 34,356,381 | `bfa391e196aa71b4bef0290cc73f6d0995aaaa79479d74c217ba01c5564799d2` |

The final files are `ios-store-export/UltimateLemmixIOS.ipa` and
`tvos-store-export/UltimateLemmixTVOS.ipa` under the 19 November build root.
Each export directory contains `verification.json`, `AppStoreInfo.plist`,
`DistributionSummary.plist` and `ExportOptions.plist`. The build root also
contains the archive receipts, preparation receipts, source patch and
`unified-identity-inputs.json`.

The main apps each contain the exact 2,298 prepared resources. The iOS widget
contains its exact 1,633-file subset. Executable signatures use Apple Distribution
for team `54WU29TRTY`. Store profiles, shared groups, Game Center and Production
cloud entitlements pass verification. Apple TV uses production push service.
All codeless resource signatures and packaged privacy manifests also pass.

The [machine-readable result](unified-mobile-package-results.json) records the
new profile UUIDs, signed entitlements, compiler/SDK metadata and exact checksums.
These packages replace the old separate-mobile-ID IPAs for this shared listing.
All previous artifacts and evidence remain intact. No upload, commit or merge
was performed in this task.
