# 2.2.2 build 99 release record

Published on 24 October 2026 at [GitHub](https://github.com/ErikVeland/Lemmings/releases/tag/v2.2.2).
The [release notes](../../ReleaseNotes-2.2.2-build99.md) lead with Duo and describe
improvements across Mac, iPhone, iPad and Apple TV.

## Delivery

| Channel | Build | Verified state at 19:03 Brisbane |
| --- | ---: | --- |
| Mac | 99 | Available: universal full/slim downloads, five signed updates and live updater feed. |
| AltStore Classic | 33 | Available: live source, icon and public IPA verified. |
| iPhone/iPad/Duo TestFlight | 33 | Waiting for Review: existing external group assigned; notes saved. |
| Apple TV TestFlight | 12 | Waiting for Review: existing groups assigned; notes saved. |

All eight public downloads match their complete SHA-256 hashes. The release tag,
latest-release identity, notes and live feeds match the candidate. See the
[public delivery](publication.json) and [AltStore delivery](altstore-publication.json)
receipts. No package was overwritten or upload repeated during draft verification.

Both Mac packages passed signing, notarisation, stapling, archive CRC and quarantine
Gatekeeper checks. The [notarisation](notarisation.json) requests are Accepted.
[Five direct patches](delta-verification.json), from builds 98, 97, 96, 95 and 93,
reconstruct all 18,942 files, links and modes. The full update and all five patches
pass [Ed25519 signature verification](signature-verification.json).

The validated iOS and TV archives retain their widgets/extensions, signatures,
content and symbols. iOS build 33 is Waiting for Review with the existing iOS
Private Beta group and automatic tester notifications. The TV transfer reached
100% before its session expired. After the owner restored authentication, Apple
showed no build 12 in builds or upload history. The new upload succeeded at
18:45:57 Brisbane. Processing then completed, and TV Beta Review was submitted
with the existing Lemmings and TV Private Beta groups and automatic notifications
on. App Store Connect confirms Waiting for Review for both platforms.
Neither new build is externally Testing yet. See [TestFlight](testflight.json).
The [AltStore validation](altstore-verification.json) checks the unencrypted IPA,
bundle signatures and declared permissions. Device re-signing and installation
remain unverified.

## Source and checks

Frozen release source: `fea37bf39fee3aa5b23f3112188b37199bc5b73e`.
Artifacts were built at `9ffc23e7118267a003dfd995f69e84ff221306c5`.
Only two Mac integration-test files changed between those commits; production
source, build scripts and tracked resources are identical. The
[source equivalence](test-only-source-equivalence.json) records this boundary.
The final audit rehashed actual inputs and bundled resources.

All 56 final audit commands pass with zero source drift. The
[results](audit-results.json), [input hashes](audit-inputs.json),
[performance measurements](audit-performance.json) and [stage receipts](validation.json)
retain evidence. The shared source gate passes 567 tests; release tooling passes
95 tests. Additional checks cover stone artwork and input targets, crowd rendering,
82 navigation states across 1,968 layouts, all three engines, and release-note
scrolling and Continue controls at three window sizes. Six note renders were
visually inspected. All automated UI tests ran offscreen with mechanical audio muted.

Earlier failed checks remain in local logs. Test corrections isolate saved progress,
find controller settings by label, retain the Settings caller, preserve explicit
Resume after Hints, and account for the replay navigation strip. No production
behaviour was changed to bypass a failure. All 151 replay-engine files match the
certified baseline; the presentation-only fan grouping file is excluded from the
engine fingerprint. See [certificate identity](../2.2.2CertificateIdentity.json).

## Acceptance limits

The owner accepted the earlier Duo tent entry, red mode and lemming movement fixes.
Later texture/spacing and physical Tent View acceptance remain unconfirmed.
Mobile touch replay acceptance on physical devices remains open. Foreground focus,
physical input, minimum-OS and Intel hardware, calendar permissions, live cloud,
AltStore re-signing, iCloud and Game Center retain their recorded limits.
No foreground test, physical-device fallback or actual updater relaunch was run.

On 26 October, the owner confirmed that the remaining human-reviewed gates in
this section are green, including physical Tent View and touch, foreground
focus, minimum-OS and Intel hardware, and the listed service and delivery
checks. This records owner confirmation. The dated external receipts above keep
their original release-time status.

Classic and The Tribes remain Complete. Chronicles and NeoLemmix remain Beta.
Mobile Journey remains Classic-only. Eight draft language packs still require human
review. Full-corpus route and source-fidelity closure remain open under the
[release scope](../../ReleaseScope.md).

Raw logs, original failures, archives and updater bases stay under the local release
output recorded in [preparation](../2.2.2Preparation.md). Raw framework logs are not
published because they can include private account metadata. The remaining work is
TestFlight upload, processing, existing-group assignment, Beta Review and verified
external Testing, followed by release-owned keep-awake cleanup.
