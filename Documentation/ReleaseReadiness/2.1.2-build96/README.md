# 2.1.2 build 96 release record

Mac published on 22 October 2026 at [GitHub](https://github.com/ErikVeland/Lemmings/releases/tag/v2.1.2).
All three release archives use source `48282886baf4c78217e62c90a935d8aecf74b843`.
The [release notes](../../ReleaseNotes-2.1.2-build96.md) describe shared progress,
safer Resume and recovery, current controls, refined lettering, authored individual
stories and Duo input/layout recovery.

## Delivery

| Platform | Build | State |
| --- | --- | --- |
| macOS | 96 | Published; full and slim universal downloads and signed update feed verified. |
| iPhone/iPad/Duo | 19 | Testing in the existing iOS Private Beta group. Notes saved; automatic notifications enabled. |
| Apple TV | 9 | Testing in TV Private Beta, confirmed 23 October 2026. Notes saved; automatic notifications enabled. Uploaded fonts verified; local repair confirmed. |

Both Mac archives support Apple silicon and Intel on macOS 12.3 or later.
Developer ID signatures, Apple notarisation, stapling and Gatekeeper passed after
archive extraction. The full update retains all 495 soundtrack versions; the slim
installer has the main soundtrack. Both ZIPs passed CRC and size checks.

Five direct updates, from builds 95, 93, 91, 90 and 87, reproduce all 18,567
files and links with matching file permissions and pass code-signature checks.
The installed Ed25519 public key verifies the full update and all five patches.
All seven public assets match their sizes and SHA-256 digests and respond over
HTTPS. The public signed appcast matches remote main. See the
[publication](publication.json), [delta](delta-verification.json) and
[signature](signature-verification.json) receipts.

[Mobile delivery receipts](testflight.json) record the build IDs, symbol UUIDs,
export hashes and current delivery boundaries. The TV release archive and iOS
export contain both complete font banks. A local developer-installed TV build 9
omitted artwork through a dangling build input. Its repair is installed, and the
owner confirmed restored fonts in the main menu and gameplay. Missing fonts now
stop packaging and archive/export checks; nine focused tests pass. See the
[font repair](tv-font-repair.json).

The TV upload succeeded after a fresh Xcode sign-in. On 23 October 2026,
App Store Connect confirmed 2.1.2 (9) is Testing in TV Private Beta, with 26
testers assigned. The saved test notes match the prepared copy and automatic
tester notifications are enabled. The exact uploaded IPA contains both complete
font banks, matching the retained archive. Apple Beta Review and coordinated
2.1.2 delivery are complete. The acceptance limits below remain open.

## Source and verification

The first signed preparation candidate was superseded before any upload or
publication. The final cut includes the completed invitation copy, 128 authored
ten-word assessments, Duo gesture/Ready recovery fixes and repository/roadmap
consolidation. It uses the finished 4× countdown face. The
[source provenance](source-provenance.json) identifies the exact frozen cut.

The owner waived fresh broad test suites and a new release audit for this
hotfix. Existing progress/recovery/control evidence retains its original source
scope. Later focused checks include 75 offscreen copy captures, 14 assessment
and saved-run tests, 91 focused Duo/core tests, 156 Duo bitmap captures and 13
native Duo Simulator tests. All automated windows stayed offscreen with audio
muted. A subsequently cancelled broad run is not a passing result. See the
[shared checklist](../2.1.2Checklist.md),
[copy evidence](../2.1.2Preparation-2026-10-21/invitation-copy.json),
[assessment evidence](../2.1.2Preparation-2026-10-21/assessments.json) and
[Duo evidence](../2.4Preparation-2026-10-21/README.md).

No simulation source or route witness changed from the 2.1.1 baseline. The
152-file source-equivalence record carries existing rescue evidence; the
metadata check is not a fresh route or fidelity audit. Replay and level proofing
continue separately. Classic/The Tribes remain Complete; Chronicles/NeoLemmix
remain Beta.

The device archives passed source-drift, identity, signing/profile, privacy,
content and matching-symbol checks. New prose has explicit English fallback in
the other eight languages; translation and human tone review remain pending.

Physical touch, remote/controller focus, VoiceOver, live cloud propagation,
minimum-OS/Intel hardware and sustained performance retain their acceptance
limits. Physical Duo is unavailable; the owner accepts focused Simulator
validation for now. This does not certify a complete system fold journey.
Mobile Journey playback remains Classic-only. Checkpoints and ordinary playlist
queues stay local. Earlier shared sequel history cannot reliably be reassigned
to past sessions.
