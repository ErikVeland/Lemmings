# 2.0 build 3 device beta

Latest iPad delivery: [build 8](Build8/README.md) replaces the prototype menus
with shared bitmap title, rank/level preview, briefing, pause and results. Apple
installation and app metadata confirm version 2.0 build 8 on GenErik. The frozen
candidate retains all 120 Classic levels and the bitmap playfield. Twenty core,
67 tooling and 66 headless menu-state/target checks pass. Actual UIKit taps and
full Mac feature parity remain open. See [interface parity](../../IOSInterfaceParity.md).
The prior [build 7](Build7/README.md) resolved the black playfield presentation
path; physical rendering acceptance still awaits the owner's retest.

Status at build 3: signed Classic touch beta retained. Installation and UIKit device
acceptance remain pending. The full 2.0 release requires all three games.

Candidate: `.build/ios-beta/2.0-3-device`. Its development IPA is
`Export/UltimateLemmingsIOS.ipa`. Its matching App Store Connect IPA is
`TestFlightExport/UltimateLemmingsIOS.ipa`. Both exports passed signature,
content, metadata and matching crash-symbol checks. Neither was uploaded.
Builds 1 and 2 remain retained.

## Closed preparation gaps

Completed runs now retire their run ID. Delayed saves cannot restore them.
Delayed cleanup of a previous run preserves the retry's checkpoint. The same
storage and controller flow applies to all three engines. Regression checks
cover Classic, Lemmings 2 and Lemmings 3 identities.

The build helper can verify an already registered device with
`--registered-device-id`, without requiring Xcode to find it as a run destination.
The install helper requires an explicit UDID and checks the retained IPA hash,
executable bytes, signature, profile expiry, team, bundle ID, device membership,
content and crash-symbol UUIDs. It never launches or uploads the app. Its default
CoreDevice path verifies the installed version and build. Its iMazing path
preserves the app-info response for manual build verification.

Final preflight exposed an incorrect archive-to-export executable hash check.
Xcode re-signs during export. The helper now compares the extracted executable
with the frozen IPA and keeps the archive's crash-symbol UUID requirement.
A regression test accepts valid export re-signing and rejects altered bytes.
The helper corrections changed after the development export. A concurrent
Package.swift change also limited the Mac executable's Sparkle dependency to
macOS. Removing that one condition reproduces the exact frozen manifest hash.
Mobile Swift files and target definitions remain unchanged. The original
[package snapshot](package-at-archive.swift), [later package change](package-after-export.diff)
and [later source hashes](source-manifest-after.json) record this boundary.

## Validation

- All 19 mobile core tests pass, including both retirement checks for each engine.
- All 61 release-tooling tests pass.
- Debug and Release Simulator compilation and unsigned Release device compilation pass.
- All 120 Classic levels render and restore exact checkpoints after 50 ticks each.
- Development installation preflight passes for GenErik's registered iPhone.
- App Store Connect export signature, profile, content and matching symbols pass.

Mechanical checks were headless and muted. No Simulator or test window was
launched. The source gate still emits the previously recorded SwiftDriver
exit-zero diagnostic, conditional compilation flag warnings and the XCTest
iOS 17 linker warnings against its iOS 16 test target. It completed successfully.
These checks do not establish UIKit rendering, touch usability or device acceptance.

## Delivery blockers

GenErik's iPhone 17 Pro appears available in inventory. Its app query failed
because it was locked. The owner has been asked whether it should receive this
candidate instead of the iPad. No installation was attempted.

The iPad is absent from the latest USB and CoreDevice inventories. Its UDID is
outside the exported development profile. Apple Developer requires the annual
device-list update before registration. All three existing devices are selected
to stay registered. Automatic approval review blocked the Reset submission
pending the owner's explicit approval. Trust and the active Xcode account are
already confirmed and do not need repeating.

Reconnect and unlock the selected device. For the iPad, complete the approved
annual update, register its UDID and export a profile that includes it. Then use
the [install procedure and manual touch checklist](../2.0DeviceBeta.md).

L2/L3 mobile libraries, native renderers and campaigns, audio, Hot Seat, controller
journeys, Duo layouts and full physical-device/accessibility acceptance remain
open. This candidate does not close the full 2.0 release gates.

Evidence: [build](evidence.json), [delivery](delivery.json),
[device preflight](device-preflight.json), [frozen inputs](source-manifest.json),
[content](content-manifest.json), [120-level validation](content-validation.json),
[TestFlight export](testflight-export.json), [core tests](mobile-core-tests.log),
[tooling tests](release-tooling-tests.log), [source gate](mobile-build-check.log).
