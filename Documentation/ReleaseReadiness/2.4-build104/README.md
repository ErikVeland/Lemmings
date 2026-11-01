# 2.4 build 104 preparation

Status: preparation only, 31 October 2026. No 2.4 platform package has been published or submitted. Candidate version numbers are Mac 104, iOS 39 and tvOS 18; confirm the mobile numbers against App Store Connect before archiving. The previous published Mac source is `96dc81b8491dfdb58683f0e32025fc4c8137aa1c` (2.3 build 102). The candidate source was committed as `32c733e228574b148a6e695488c17098e0c62fcf` and pushed to `main` during preparation. Confirm that the source remains unchanged before packaging.

**Release blocked:** Do not publish or submit 2.4 for any platform until the
reported app-wide crackling and Duo gameplay stutter are resolved and verified.
See [runtime performance](../../RuntimePerformance.md) and
[platform parity](../../PlatformFeatureParity.md).

Local iOS development build 41 passed the owner's physical Gen8 checks for menu
music, level start, heavy nuke, pause/resume and saved-level Resume. Build 40 was
rejected after a symbolicated effects-start crash. Build 42 is signed and exported
with the same audio source as 41, a clear loading page and removal of repeated
saved-Journey reads during browser setup. Build-42 device acceptance and Duo
verification remain pending. These local candidates are not App Store submissions.

## Release scope and checks

Classic rewind history and seek behaviour changed since the published Mac source. The engine-change policy applies: run affected regression and replay checks on the frozen candidate, verify preserved fixture manifests and record affected-route evidence. The manifest checks on 31 October passed for 120 Classic solution fixtures, 322 campaign fixtures, 120 Lemmings 2 fixtures and 70 carry-over fixtures. Hash checks alone do not establish that routes still win. The headless Classic rewind and replay suites passed against the working source subsequently committed as `32c733e2`, including rewind export and verification in a fresh simulation. The affected engine checks passed on `bf3cbfff` on 1 November 2026; see [engine checks](#engine-checks-1-november-2026).

The version-history check passed for 2.4 build 104 and `git diff --check` passed on the working candidate. Rendered Mac gameplay deck states and input targets remain unverified; see [platform parity](../../PlatformFeatureParity.md). The current source also records sequel panel layout gaps and device acceptance gaps. The new in-app release copy needs localisation review.

## Engine checks, 1 November 2026

Scope: affected routes, not the full campaign gate. The candidate is
`bf3cbfff` with a clean tree. Since 2.3 (`96dc81b8`), Classic rewind changed
how it keeps keyframes and added `preparedSeek`. The Classic, NeoLemmix, L2 and
L3 simulations gained only read-only storage estimates. Tick, movement,
collision, terrain, skill, replay and level-data code did not change. The live
game steps Classic through `ClassicDOSRewind` in `GameSession`, so the affected
routes are the Classic routes played through that session path.

All checks ran headless and muted. All passed:

| Check | Result |
| --- | --- |
| Classic DOS rewind, replay and simulation regressions | Passed |
| Classic play-through | Passed |
| Official Classic quest through `GameSession`, with conversions | 352 wins, 1,056 recovery points, 352 progress resumes, 6 chapter transitions |
| Quest gate negative cases | Passed |
| Preserved Classic, campaign and L2 fixture manifests | Passed |
| NeoLemmix simulation, L2 runtime and L3 runtime | Passed |

The quest used the packaged `Ports` from local build 103 (`mac-layout-ready`),
because `Sources/Ports` has no generated Holiday native folders. Level data has
not changed since 2.3. The audit's quest build lacked `FailureMusic.swift`,
which `GameSession` has needed since `f06305941`. The audit now includes it.

Not run: the L2, L3 and fan-route campaign gates. Their engines did not change
outcome code. Mobile rewind presentation is outside the Mac scope.

## Delivery

- **Mac:** Not built, signed, notarised or published. The release script dry run could not find a Developer ID Application identity. Complete affected engine checks, rendered-state and input verification, universal packaging, signing, notarisation, package integrity and feed verification on the frozen candidate.
- **iOS and Duo:** Local development candidates archived and signed through build 42. No App Store archive or submission. Check App Store Connect build numbers and signing, then follow the existing distribution groups after Mac publication. Device acceptance remains open.
- **tvOS:** Not archived or submitted. Check App Store Connect build numbers and signing after iOS submission. Device acceptance remains open.
- **Sideloading:** Not delivered. Follow the channel register in [iOS distribution](../../IOSDistribution.md) after the higher-priority deliveries.

The local GitHub CLI authentication check failed, although the connected GitHub app responded. The source commit was pushed to `main` during preparation; no release, tag or feed was published.

## Access recheck, 31 October 2026

The current execution session still cannot access the keychain search list. `security find-identity -v -p codesigning` returned zero valid identities, and `xcrun notarytool history --keychain-profile lemmings-beta` failed with a keychain access error. The GitHub CLI reports its active credential invalid. The connected GitHub reader confirms 2.3 build 102 remains the latest public release. The 2.4 build 104 version-history gate passed again. These checks do not establish signing, notarisation or publishing access; the Mac package and subsequent platform submissions remain outstanding.

## Public cloud sync

The owner added automatic public iCloud sync and private device linking to 2.4.
See [implementation and acceptance](CloudSync.md). The public Mac signer now
requires production CloudKit provisioning before compilation. The owner-supplied
Developer ID CloudKit profile is installed and passes signing preflight.
The production schema inspection found `ULPrivateLibrary` absent, although its
required fields exist in Development. Schema deployment and two-device acceptance
remain required. No public sync availability is claimed yet.
