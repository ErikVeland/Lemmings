# 2.3 build 102 release candidate

Status: **blocked; one notarised Mac candidate is ready for review; no public
publication or store submission recorded**.

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
| iOS build 36 archive | PASS; signed archive created with active Xcode 27.2 |
| iOS build 36 App Store export | BLOCKED; retry on 27 October still reports “No Accounts” and no iOS Distribution certificate/private key |
| Universal Mac candidate package | PASS; Developer ID signed, notarisation accepted, stapled, and Gatekeeper validation passed |
| Mac updater/feed packaging | BLOCKED; generator requires the recent shipped ZIP bases, starting with build 99, which are not present in the update directory |
| tvOS build 15 archive | PASS; unsigned compile archive only, no App Store export |
| Release history and input checks | PASS |
| Release script dry run at `0b349063` | PASS; live feed comparison unavailable because `origin/main` could not be fetched; no build or upload performed |

The iOS and tvOS checks compile sources. They do not establish store
processing or physical-device acceptance. The Mac candidate ZIP is in ignored
`.build/2.3-build102-mac-candidate/packages/`; its latest notary submission
(`14ed57c0-e9b8-405a-820f-8832107b9b1b`) was accepted, stapling succeeded,
and Gatekeeper validation passed. The release script stopped before slim
package/feed verification because the shipped build 99 update base is missing.
It has not published the appcast or downloads. Automated release gates 6–7
were skipped by the repository's release policy after the affected engine
checks listed below passed; no foreground launch check was run.

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
performed. `xcdevice list` reports only the Mac; CoreSimulator is unavailable
in this session, so the Duo, iPad and Apple TV checks cannot run here.

## Open release gates

- The reported crackling remains a release blocker on Duo, iPad 8th generation
  and Apple TV 4K. The 2.3 audio assessment says there is no clean-device
  acceptance and that muted checks cannot close this gate. See
  [`RuntimePerformance.md`](../../RuntimePerformance.md#23-audio-and-performance-blocker--26-october-2026).
- The `lemmings-beta` profile is usable and the build 102 Mac standard ZIP is
  notarised. The signing keychain currently lists Developer ID Application and
  Apple Development identities, but no Apple Distribution identity. The iOS
  build 36 archive retry still fails export with “No Accounts” and no iOS
  Distribution certificate/private key. The tvOS archive is unsigned. Store
  export and submission remain unavailable.
- Sustained optimized-package performance and physical-device recovery/input
  acceptance remain open as recorded in [`ReleaseScope.md`](../../ReleaseScope.md#23-release-assessment).

The candidate is prepared for review, but publication must wait for these gates
and the required signed package and feed/store verification for each platform.
