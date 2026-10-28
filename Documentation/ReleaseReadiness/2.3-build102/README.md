# 2.3 build 102 release candidate

Status: **Mac 2.3 build 102 published; all seven public assets and the appcast
are verified. Corrected iOS 2.3 build 37 and tvOS build 16 are assigned to their
existing private beta groups and show Testing in App Store Connect. The public
tag still points to build 100. Sideloading delivery remains open.**

Release source: `96dc81b8491dfdb58683f0e32025fc4c8137aa1c` on `main`
Release base: `v2.2.2`
Platform build numbers: Mac 102, iPhone/iPad/Duo 37, Apple TV 16

Corrected mobile source commit: `f8038d81bded50aafff51853677a2dd411c058ea`
The mobile menu scrolling changes are recorded in
[`mobile-submission-2026-10-27.md`](mobile-submission-2026-10-27.md).

Build 102 contains the centered main-menu logo, optical background-corner
guidance and the Hot Seat progress selector. The release notes are
[`ReleaseNotes-2.3-build102.md`](../../ReleaseNotes-2.3-build102.md).

## Source and UI checks

| Check | Result |
| --- | --- |
| Progress page, logo-centre geometry, layouts and selector hit targets | PASS; `LocalLeaderboardPageTests` |
| iOS SDK module and application-entry compile | PASS |
| tvOS SDK module and application-entry compile | PASS |
| iOS build 37 archive | PASS; signed archive created from `f8038d81` with stable Xcode 27.1 |
| iOS build 37 App Store export, upload and TestFlight assignment | PASS; App Store Connect accepted the upload, added the build to Lemmings and iOS Private Beta, and shows Testing. Beta review availability for external testers is pending Apple review. |
| Universal Mac candidate package | PASS; Developer ID signed, notarisation accepted, stapled, and Gatekeeper validation passed |
| Mac updater/feed packaging | PASS; five signed deltas cover builds 95–99; public appcast verified |
| tvOS build 16 archive, upload and TestFlight assignment | PASS; stable Xcode 27.1 archive exported and uploaded from `f8038d81`; App Store Connect processed it, added it to TV Private Beta, and shows Testing. Existing group audience remains 29 testers. |
| Release history and input checks | PASS |
| Release publication | PASS; release 424931561 published with full updater ZIP, slim ZIP and five delta assets; public appcast points to build 102 |

The iOS and tvOS checks compile sources. They do not establish store
processing or physical-device acceptance. The Mac standard and slim packages
were notarised, stapled and accepted by Gatekeeper. The public [GitHub release]
(https://github.com/ErikVeland/Lemmings/releases/tag/v2.3) contains both
packages and five deltas. GitHub reports the full ZIP SHA-256 as
`2a12460a6db2b4e33d936509e093ddb3dd5a673e0346bf907c9fdeada193eef1` and the
slim ZIP SHA-256 as
`2b023b02556de8b3e3835a64cd9bf38abbd1f2e4e9944c2288a5b51aaf59b4c4`.
The signed public appcast on `main` advertises build 102 and those five deltas.
All seven complete public downloads match GitHub asset sizes and SHA-256
digests, and each digest matches its local release artifact. See
[`publication.json`](publication.json). However, the annotated `v2.3` tag
still points to build 100 source `d1d1ddac201dd97f86dbe9ffac3f702f55ae47d9`,
while the release, appcast and assets identify source
`96dc81b8491dfdb58683f0e32025fc4c8137aa1c`. The asset and feed data are intact.
An exact compare-and-swap retag was attempted with the expected old tag object,
but automatic approval review rejected it because the supplied owner approval
was from a delegated transcript rather than a trusted direct message. No tag
change was made. Retagging affects source provenance and consumers that have
cached the old ref; the release and its files remain published. Get direct
owner approval before retrying the exact expected-old update.
Automated release gates 6–7 were skipped under repository policy after the
affected engine checks below passed; no foreground launch check was run.

## Affected engine checks

| Check | Result |
| --- | --- |
| NeoLemmix simulation | PASS; 31 groups / 21 skills, muted |
| NeoLemmix replay | PASS; muted |
| Mobile core and bundled fan levels | PASS; 338 tests in 58 suites, including 6,020 levels, muted/offscreen |
| Hot Seat ghost, Music Rewind and save recovery | PASS; muted/offscreen |
| Audio performance and spatial regressions | PASS; muted/offscreen run after the invalid-`AVAudioTime` fix |

The existing build-100 NeoLemmix simulation/replay, Classic DOS replay and
extra-skill checks remain applicable to unchanged source. The mechanical
checks used the muted, offscreen runner. No physical-device listening run was
performed. `xcdevice list` reports only the Mac; CoreSimulator is unavailable
in this session, so the Duo, iPad and Apple TV checks cannot run here.

## Open release gates

- The reported crackling remains open for Duo, iPad 8th generation and Apple TV
  4K. No clean-device listening acceptance is recorded; muted checks cannot
  close that platform gate. This did not block the Mac publication under the
  release schedule. No audible-clean claim is made for Mac. See
  [`RuntimePerformance.md`](../../RuntimePerformance.md#23-audio-and-performance-blocker--26-october-2026).
- The `lemmings-beta` profile is usable and the build 102 Mac standard and slim
  ZIPs are notarised. Corrected iOS build 37 is processed, assigned to the
  existing Lemmings and iOS Private Beta groups, and submitted for beta review.
  Corrected tvOS build 16 is processed, assigned to the existing TV Private
  Beta group, and shows Testing. Its existing 29-person audience is unchanged.
- Sustained optimized-package performance and physical-device recovery/input
  acceptance remain open as recorded in [`ReleaseScope.md`](../../ReleaseScope.md#23-release-assessment).

Mac publication is complete. iOS, tvOS and sideloading require their own signed
packages, store receipts and platform acceptance; those deliveries follow the
release schedule and do not change the Mac release status.
