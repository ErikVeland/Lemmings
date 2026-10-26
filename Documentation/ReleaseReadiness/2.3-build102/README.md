# 2.3 build 102 release candidate

Status: **blocked; no platform package or submission recorded**.

Candidate source: `b1dd685f` on `main`
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
| Universal Mac local app build | PASS; ad hoc signature verifies; arm64 and x86_64 |
| Release history and input checks | PASS |
| Release script dry run | PASS; no build or upload performed |

The iOS and tvOS checks compile sources. They do not establish archive,
provisioning, signing, store processing or physical-device acceptance.
The Mac preflight app is in ignored `.build/2.3-build102-mac-preflight/`; it is
ad hoc signed and is not a release package. Its first build attempt stopped on
the sandboxed Swift module cache and hardware-thread query. The successful
retry used an in-workspace module cache and `MUSIC_AAC_JOBS=2`.

## Affected engine checks

| Check | Result |
| --- | --- |
| Hot Seat ghost | PASS; rerun outside the filesystem sandbox |
| Music rewind | PASS; rerun outside the filesystem sandbox |
| Save recovery | PASS after directing the Swift module cache to `/private/tmp` |
| Audio performance and spatial regressions | PASS; muted, offscreen run after the invalid-`AVAudioTime` fix |

The existing build-100 NeoLemmix simulation/replay, Classic DOS replay and
extra-skill checks remain applicable to unchanged source. The mechanical
checks used the muted, offscreen runner. No physical-device listening run was
performed.

## Open release gates

- The reported crackling remains a release blocker on Duo, iPad 8th generation
  and Apple TV 4K. The 2.3 audio assessment says there is no clean-device
  acceptance and that muted checks cannot close this gate. See
  [`RuntimePerformance.md`](../../RuntimePerformance.md#23-audio-and-performance-blocker--26-october-2026).
- The `lemmings-beta` notary profile is now usable, and the Developer ID
  Application identity is present. Notary history shows an accepted prior
  standard archive, but it is not a build 102 package. The current signing
  identities still do not include Apple Distribution, so iOS/tvOS App Store
  signing and upload remain unavailable. No build 102 release archive has been
  Developer ID signed, notarized or uploaded.
- Sustained optimized-package performance and physical-device recovery/input
  acceptance remain open as recorded in [`ReleaseScope.md`](../../ReleaseScope.md#23-release-assessment).

The candidate is prepared for review, but publication must wait for these gates
and the required signed package and feed/store verification for each platform.
