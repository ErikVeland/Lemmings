# 2.0 build 2 touch beta

Status: signed Classic candidate retained. GenErik iPad installation is blocked.
The development profile includes the iPhone and excludes the iPad. No app was
installed, launched or uploaded during this preparation.

## Retained candidate

Candidate directory: `.build/ios-beta/2.0-2-touch`.

- Signed Release archive: `UltimateLemmingsIOS.xcarchive`.
- Development IPA: `Export/UltimateLemmingsIOS.ipa`.
- Extracted app: `Install/Payload/UltimateLemmingsIOS.app`.
- Version 2.0, build 2, minimum OS 16.0, arm64, iPhone and iPad families.
- Binary/dSYM UUID: `BFE1A367-12C8-30FD-82AA-E757FD4AAD1F`.
- IPA SHA-256: `424a37ada8048cbaff69da770af9d88ee51e4c0ba9cdcf3f3f2aa7d52618825b`.
- Content manifest SHA-256: `012bada8669f71d193747064cad6db469184e2783acf1cdddea7142104f80da2`.

The archive and IPA passed signature, metadata, content and matching-symbol
checks. The frozen mobile inputs stayed unchanged through export. Afterwards,
the export helper gained ZIP permission restoration. The extracted app's original
permissions were restored from the IPA. No app code or IPA bytes changed.
The helper also prefers Apple system tools for future Xcode symbol copies.
Build 1 remains available in its original candidate directory.

An App Store Connect export of the same archive is retained at
`TestFlightExport-system/UltimateLemmingsIOS.ipa`. Its SHA-256 is
`38d2a54785198bc4fe2f83a8ba3ad7ad450e4bc32d2605db0dedad0ca9dfb1ce`.
It passed signature, team/bundle profile, content and matching-symbol checks.
The distribution profile expires 10 October 2027 and does not require device
UDIDs. This IPA needs upload, processing and tester delivery through TestFlight;
it cannot replace a development installation directly. No upload occurred.

## Touch changes and verification

Skill selection enters an editable pause. Tap or hold/release assigns a skill.
The loupe uses the current bitmap with nearest-neighbour scaling. Pan and pinch
remain available. STEP advances one tick; Play resumes without elapsed-time
catch-up. MENU, Ready screens, interruptions and results block assignments.
HUD updates retain their input buttons instead of replacing them during a tap.

All 17 mobile core tests pass. Tests cover planning boundaries, held/cancelled
touches, exact loupe pixels, 44-point geometry and paused assignment/checkpoint
restoration across all three session adapters. All 55 release-tooling tests pass,
including exported device membership and executable permissions. Automated
mechanical checks ran headlessly and muted.

The source gate passed Debug and Release Simulator compilation and unsigned
Release device compilation. Its log includes a transient SwiftDriver diagnostic
with exit code zero; the gate subsequently completed successfully. XCTest linking
also reports its iOS 17 minimum against the test target's iOS 16 setting.
No Simulator was booted or shown.

All 120 bundled Classic levels render, tick and restore exact checkpoints after
50 ticks each (6,000 ticks total). These are engine/bitmap checks. Actual UIKit
renders, hit testing, loupe placement and physical-device gameplay remain pending.
The AppKit offscreen runner does not provide a verified UIKit workflow.

## iPad delivery blocker

The 11 October recheck confirmed the owner's trust statement. USB initially
identified the correct iPad, and Xcode reported a usable developer disk image.
CoreDevice still reported unsupported pairing. iMazing identified the iPad
through its alternate device service. The latest scan no longer found the iPad
on USB, so it needs reconnecting before installation.

Apple Developer lists three registered devices and requires its annual device
list update before adding this iPad. All three existing devices are selected to
stay registered. Automatic approval review rejected the Reset submission pending
the owner's explicit approval. No device registration or installation occurred.
See [the latest connection and signing check](device-install-2026-10-11.json).

The connected iPad was identified as GenErik, model iPad7,3, iPadOS 17.7.11.
Pairing timed out. Xcode could not match it as an available archive destination;
the final CoreDevice inventory reported unsupported/unavailable pairing. Device
Hub also did not list the physical iPad as available.

The new Apple account is visibly signed into stable Xcode with a developer team.
Manual profiles downloaded successfully. They still exclude this iPad. The CLI
continues to report a missing Xcode-Token for an older account entry. Do not infer
that the new account is signed out from that warning.
The active account successfully created distribution signing assets and signed
the TestFlight export. Its first export failed because Apple's rsync invoked a
Homebrew server that rejected extended attributes. A subprocess-only PATH using
Apple system tools resolved this failure.

Reconnect the iPad and keep it unlocked. Trust is already confirmed by the owner.
Complete the approved annual device-list update and register the iPad. Enable
Developer Mode for a development installation. Create a new candidate
whose exported profile includes its UDID. Install without automatically launching
the app, then complete the [manual iPad checklist](../2.0DeviceBeta.md#touch-planning).

The complete 2.0 release still includes Classic, Lemmings 2 and Lemmings 3 on
iPad, iPhone and Duo. This beta includes Classic only. L2/L3 mobile content and
rendering, Hot Seat, audio, Duo layouts and full campaign acceptance remain open.

Evidence: [build record](evidence.json), [delivery record](delivery.json),
[frozen inputs](source-manifest.json), [content manifest](content-manifest.json),
[120-level validation](content-validation.json), [core tests](mobile-core-tests.log),
[tooling tests](release-tooling-tests.log), [compilation gate](mobile-build-check.log).
See also the [TestFlight export record](testflight-export.json) and
[export result](testflight-export.log).
