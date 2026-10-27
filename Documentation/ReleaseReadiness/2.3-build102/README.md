# 2.3 build 102 release candidate

Status: **Mac 2.3 build 102 published and verified; iOS, tvOS and sideloading
delivery remain open**.

Release source: `96dc81b8491dfdb58683f0e32025fc4c8137aa1c` on `main`
Release base: `v2.2.2`
Platform build numbers: Mac 102, iPhone/iPad/Duo 36, Apple TV 15

Build 102 contains the centered main-menu logo, optical background-corner
guidance and the Hot Seat progress selector. The release notes are
[`ReleaseNotes-2.3-build102.md`](../../ReleaseNotes-2.3-build102.md).

## Source and UI checks

| Check | Result |
| --- | --- |
| Progress page, logo-centre geometry, layouts and selector hit targets | PASS; `LocalLeaderboardPageTests` |
| iOS SDK module and application-entry compile | PASS |
| tvOS SDK module and application-entry compile | PASS |
| iOS build 36 archive | PASS; signed archive created with active Xcode 27.2 |
| iOS build 36 App Store export | BLOCKED; retry on 27 October still reports “No Accounts” and no iOS Distribution certificate/private key |
| Universal Mac candidate package | PASS; Developer ID signed, notarisation accepted, stapled, and Gatekeeper validation passed |
| Mac updater/feed packaging | PASS; five signed deltas cover builds 95–99; public appcast verified |
| tvOS build 15 archive | PASS; unsigned compile archive only, no App Store export |
| Release history and input checks | PASS |
| Release publication | PASS; v2.3 published with full updater ZIP, slim ZIP and five delta assets; public appcast points to build 102 |

The iOS and tvOS checks compile sources. They do not establish store
processing or physical-device acceptance. The Mac standard and slim packages
were notarised, stapled and accepted by Gatekeeper. The public [GitHub release]
(https://github.com/ErikVeland/Lemmings/releases/tag/v2.3) contains both
packages and five deltas. GitHub reports the full ZIP SHA-256 as
`2a12460a6db2b4e33d936509e093ddb3dd5a673e0346bf907c9fdeada193eef1` and the
slim ZIP SHA-256 as
`2b023b02556de8b3e3835a64cd9bf38abbd1f2e4e9944c2288a5b51aaf59b4c4`.
The signed public appcast on `main` advertises build 102 and those five deltas.
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
- The `lemmings-beta` profile is usable and the build 102 Mac standard ZIP is
  notarised. The signing keychain currently lists Developer ID Application and
  Apple Development identities, but no Apple Distribution identity. The iOS
  build 36 archive retry still fails export with “No Accounts” and no iOS
  Distribution certificate/private key. The tvOS archive is unsigned. Store
  export and submission remain unavailable.
- Sustained optimized-package performance and physical-device recovery/input
  acceptance remain open as recorded in [`ReleaseScope.md`](../../ReleaseScope.md#23-release-assessment).

Mac publication is complete. iOS, tvOS and sideloading require their own signed
packages, store receipts and platform acceptance; those deliveries follow the
release schedule and do not change the Mac release status.
