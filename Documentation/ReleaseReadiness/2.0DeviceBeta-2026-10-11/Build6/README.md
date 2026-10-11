# 2.0 build 6 campaign beta

Installed on GenErik iPad Pro 10.5-inch (iPad7,3), iPadOS 17.7.11.
Apple's device app query confirms version 2.0, bundle version 6. The owner
confirms Developer Mode enabled. No automatic app launch or TestFlight upload
occurred. Manual UIKit, touch, artwork and saved-run acceptance remain open.

## Campaign recovery

The missing-data report followed replacement of verified build 4 with the
default Xcode build 1. That source-only configuration did not supply
`IOS_BETA_CONTENT_DIR`. Build 4 was first restored without uninstalling the app
or deleting its data container. [Recovery evidence](../Build4/DataRecovery/README.md)
records the before/after device queries.

Normal Xcode Debug builds now stage the approved local Classic data when
available. Explicit frozen beta content takes precedence. Missing local data
keeps an import-only build. Invalid local data fails compilation. Release builds
still require explicitly staged content. Original executables are excluded.
A normal unsigned Debug device build contains the same 26-file manifest as the
signed beta and all 120 Classic levels.

## Frozen candidate

Build 6 also includes the captured mobile camera changes and shared game artwork.
The source snapshot is retained at `.build/ios-beta/SourceSnapshot-6`; the signed
candidate is `.build/ios-beta/2.0-6-campaign`. Current workspace edits do not
rewrite that snapshot. Source hashes remained unchanged through archive/export.
The source manifest includes the shared LemmingsGameArt module and all selected
Mac artwork inputs. All 309 exported PNGs match the frozen input bytes; the
selected banks are Charset1, Charset2, Icons, Logo1 and Logo2. Actual UIKit
rendering and input targets remain part of the manual device check.

Build 5 was rejected because artwork/project changes landed during compilation.
It was never installed. The installer now rejects an exported candidate that
failed the final source/verification gate. It requires successful completion,
archive signing and export signature verification before inspecting the payload.

Xcode beta 27.2 build 27B5019j signed build 6. The export includes the exact iPad
UDID, requires iOS 16 or later, and passes signature, metadata, icon, privacy,
content and executable/dSYM UUID checks. The IPA SHA-256 is
`7508d3ea975405ae841ce77d9bb8af606bf7f31933212eeebf5a649a93c7a390`.
Its arm64 crash-symbol UUID is `CDFC196A-A221-3DFE-9C44-148BA958D8F3`.

## Validation and limits

All 67 release-tooling tests pass. All 19 mobile core tests pass against the
same core source captured in build 6. All 120 levels render and restore exact
checkpoints after 50 ticks each (6,000 ticks). Mechanical checks were headless
and muted. The first core invocation could not write to the global Clang cache;
a retry using workspace module caches passed. The archive/export logs retain
the unrelated stale-account token warning; active-team signing succeeded.

This beta provides Classic's 120 levels. L2/L3 mobile libraries, rendering and
campaigns, audio, Hot Seat, controllers, Duo layouts and full physical-device
accessibility acceptance remain open. Builds 1–4 and the stable-Xcode build 3
App Store Connect export remain retained. Build 6 is a local development beta.

Evidence: [signed export](evidence.json), [verified delivery](delivery.json),
[installed app](apps.json), [frozen inputs](source-manifest.json),
[campaign validation](content-validation.json), [artwork](artwork-validation.json),
[Debug packaging](debug-content.json), [core tests](mobile-core-tests.log),
[tooling tests](release-tooling-tests.log), [rejected build 5](rejected-build5-evidence.json).
