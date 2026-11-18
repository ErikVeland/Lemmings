# Mobile Store packages

> Historical record — status clarified 19 November 2026. This document retains
> the earlier investigation, service checks or separate-mobile-ID packages.
> It is not the current gate list. Use the [current handoff](README.md),
> [unified mobile identity evidence](UnifiedListingMobile.md) and
> [website release record](WebsiteRelease.md) for current status.
> All main apps now use one listing. The website is built locally, with DNS
> and TLS pending. Earlier missing-signing or separate-ID findings are retained
> as history, not current package blockers.

Candidate: Ultimate Lemmix 2.4.2, build 108. Checked 18 November 2026.

The final local packages are in `ios-store-export` and `tvos-store-export` under
`/Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118`. Use the packages with
`verification.json` and `allChecksPassed: true`. Earlier `*-export` and
`*-export-signed-resources` directories are retained investigation outputs.
They are not the final handoff.

## Reproduce the packaging

First archive the mobile target through `Scripts/build-publication.sh` with
stable Xcode, automatic signing, the final prepared resource directory and
`REGISTER_APP_GROUPS=YES`. Require a successful publication receipt with
unchanged shared sources and publication metadata. The candidate's two final
archive receipts meet those requirements.

Use `Tools/Publication/mobile_store.py` to copy the archive, sign its resource
bundles, preserve executable entitlements, and export a local Store package.
The source archive stays unchanged. The export command always selects
`destination=export`; it does not upload a build.

For example, from the repository root:

```sh
python3 Tools/Publication/mobile_store.py prepare-archive \
  --platform ios \
  --resources /Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118/mobile-resources-submission \
  --archive /Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118/UltimateLemmix-iOS.xcarchive \
  --output /Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118/UltimateLemmix-iOS-Store.xcarchive \
  --identity 'Apple Development: Erik Veland (T93G24W53E)'

python3 Tools/Publication/mobile_store.py export \
  --platform ios \
  --resources /Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118/mobile-resources-submission \
  --archive /Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118/UltimateLemmix-iOS-Store.xcarchive \
  --output /Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118/ios-store-export \
  --temporary /Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118/export-temp
```

The output paths must not already exist. For tvOS, select `--platform tvos`,
use the `UltimateLemmix-tvOS` archive names and select `tvos-store-export`.
Keep the preparation receipt, export log, ExportOptions plist and verification
JSON with the packages.

## Resolved packaging issues

The first automatic exports authenticated and obtained Store profiles, but a
copy operation failed. Apple's system `rsync` selected an incompatible Homebrew
helper through `PATH`. The packaging command now supplies a system-only path.
It also supplies a temporary directory on the external build volume.

The next exports succeeded, but Apple's `AppStoreInfo.plist` contained unsigned
resource-bundle errors, `-21411` with OS status `-67062`. The resource-only
`Localization.bundle` and Swift package bundles had no signatures. Signing them
before export removed those analysis errors.

Xcode applies Apple Distribution signatures to the apps and extensions. It
preserves valid, same-team Apple Development signatures on the codeless resource
bundles. Those resources are also sealed by the enclosing distribution signature.
The verifier checks each resource bundle for executable declarations and Mach-O
content, verifies its signature, and requires its team to match. It permits only
the four verified generated files `CodeResources`, `CodeDirectory`,
`CodeSignature` and `CodeRequirements` within their `_CodeSignature` directories.
It still checks every prepared game-data file against its original hash.

Apple distinguishes [embedded codeless resources from executable code](https://developer.apple.com/documentation/bundleresources/placing-content-in-a-bundle)
and documents [codeless signature storage and resource seals](https://developer.apple.com/documentation/technotes/tn3126-inside-code-signing-hashes).
This observed packaging behaviour does not establish server acceptance.

## Verification scope

The verifier checks both executable signatures, bundle IDs, version and build,
arm64 architecture, Store profiles, expiry, absence of development/debug access,
shared app groups, Game Center, Production cloud entitlements and tvOS production
push. It compares the packaged privacy manifests with the platform sources.
The main apps contain all 2,298 prepared files. The iOS widget contains its
1,633-file resource subset. Top Shelf reads shared local scenery and has no
copied game-data subset.

The packaged privacy inventory is the main app manifest on tvOS and the main
app plus Desk Clock widget manifests on iOS. Top Shelf has no privacy manifest;
the reviewed source uses shared local files and does not declare required-reason
API use. The verifier rejects any Apple package-analysis product errors.

No app was launched and no automated test suite ran for this packaging-only
candidate. No build was uploaded. App Store processing, account metadata,
physical-device checks and App Review remain separate gates. One earlier tvOS
export logged a transient App Store configuration request failure, `-24169`,
while still exporting successfully. Do not treat local export as proof that
Store metadata is complete.
