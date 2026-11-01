# 2.4 build 104 preparation

Status: release in progress, 1 November 2026. Mac 2.4 build 104 is public; iOS and tvOS submissions remain open. Candidate mobile build numbers are 39 and 18, but App Store Connect must confirm them before archiving. The previous published Mac source is `96dc81b8491dfdb58683f0e32025fc4c8137aa1c` (2.3 build 102). The Mac candidate was built from `a19e9ad44681fe286f8a69c32d522295514ab459`; the current `main` is `59b04b18`.

**Owner confirmation, 1 November 2026:** The owner confirmed that all release
checks are complete and green. This closes the earlier audio crackling, Duo
gameplay stutter, and rendered Mac state/input acceptance gates. The message
did not include separate device logs or measurements. See
[runtime performance](../../RuntimePerformance.md) and
[platform parity](../../PlatformFeatureParity.md) for the recorded limits.

Local iOS development build 41 passed the owner's physical Gen8 checks for menu
music, level start, heavy nuke, pause/resume and saved-level Resume. Build 40 was
rejected after a symbolicated effects-start crash. Build 42 is signed and exported
with the same audio source as 41, a clear loading page and removal of repeated
saved-Journey reads during browser setup. Build-42 device acceptance and Duo
verification remain pending. These local candidates are not App Store submissions.

## Release scope and checks

Classic rewind history and seek behaviour changed since the published Mac source. The engine-change policy applies: run affected regression and replay checks on the frozen candidate, verify preserved fixture manifests and record affected-route evidence. The manifest checks on 31 October passed for 120 Classic solution fixtures, 322 campaign fixtures, 120 Lemmings 2 fixtures and 70 carry-over fixtures. Hash checks alone do not establish that routes still win. The headless Classic rewind and replay suites passed against the working source subsequently committed as `32c733e2`, including rewind export and verification in a fresh simulation. The affected engine checks passed on `bf3cbfff` on 1 November 2026; see [engine checks](#engine-checks-1-november-2026).

The version-history check passed for 2.4 build 104 and `git diff --check` passed on the working candidate. The owner confirmed all release checks green on 1 November. The current source still records sequel panel layout and localisation limits in [platform parity](../../PlatformFeatureParity.md).

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

- **Mac:** [2.4 build 104 is public](https://github.com/ErikVeland/Lemmings/releases/tag/v2.4). Standard and slim universal packages are signed, notarised and accepted by Gatekeeper. The live signed updater feed contains all five recent delta bases.
- **iOS and Duo:** Local development candidates archived and signed through build 42. No App Store archive or submission. Check App Store Connect build numbers and signing, then follow the existing distribution groups after Mac publication.
- **tvOS:** Not archived or submitted. Check App Store Connect build numbers and signing after iOS submission.
- **Sideloading:** Not delivered. Follow the channel register in [iOS distribution](../../IOSDistribution.md) after the higher-priority deliveries.

The source commit was pushed to `main` during preparation. Mac publication is recorded below.

## Access recheck, 31 October 2026

On 31 October, the session could not access the keychain search list or GitHub CLI credentials. The owner-supplied Developer ID profile and signing identity were available during the 1 November package attempt. The connected GitHub reader confirmed 2.3 build 102 as the latest public app release. No 2.4 release was published in that attempt.

## Public cloud sync

The owner added automatic public iCloud sync and private device linking to 2.4.
See [implementation and acceptance](CloudSync.md). The public Mac signer now
requires production CloudKit provisioning before compilation. The owner-supplied
Developer ID CloudKit profile is installed and passes signing preflight.
`ULPrivateLibrary` was deployed to Production on 1 November and verified by a
fresh export. Signed-package checks and two-device acceptance remain required. No public sync availability is claimed yet.

## Mac package attempt, 1 November 2026

The version-history and signing-capability preflights passed for build 104.
The affected engine checks above remain applicable: commits after `bf3cbfff`
did not change simulation outcome code. The release build passed rescue-proof
and hint checks.

The standard universal app was built from `10fae692` with the production
CloudKit profile. Automated app integration checks and the foreground launch
check were skipped with `SKIP_RELEASE_TESTS=1`. The affected Classic rewind and
replay checks are recorded above. The package run did not launch the app or run
tests.

Apple accepted notarisation submission
`5f611ab1-8bb3-43ac-9b89-835c0e590920`. The ticket was stapled and validated.
The downloaded standard ZIP passed Gatekeeper as Notarized Developer ID. The
local archive is
`/Users/veland/Downloads/UltimateLemmings-2.4-build104-20261101-135609-standard.zip`,
size 2,057,774,741 bytes, SHA-256
`03135df1051d29474bd237b9060f5e4e4f69f9f2f4fc18d92e066ddfc13f77cd`.

The package script stopped while preparing the Sparkle feed because the local
update directory lacks the five recent shipped archives needed to build direct
deltas from builds 102, 99, 98, 97 and 96. The standard package is not a
published release. The slim download, signed update feed and public release
were not completed.

The owner confirmed all checks complete and green after this package attempt.
The standard ZIP above was built from `10fae692`, one documentation-only commit
behind the current source. Rebuild or verify the final Mac package against
`e10df1eb` before publication. The update feed still requires the five recent
delta base archives. The slim download and public release were not completed.

## Final Mac package and feed, 1 November 2026

The owner confirmed release checks complete and green. The current universal
Mac build was made from `a19e9ad4`, including the supporter-credit change, with
the production CloudKit profile. Rescue-proof and hint gates passed. Automated
app integration and foreground launch checks were skipped under the approved
release policy; the affected engine checks are recorded above.

Apple accepted standard notarisation submission
`4d7eb5bc-902f-482b-a5c2-791271fcf7e3` and slim submission
`95090279-8e5b-43b7-b32b-9d81061e3a9a`. Both tickets were stapled and validated.
Both ZIPs passed Gatekeeper as Notarized Developer ID. The standard package is
2,057,774,759 bytes (SHA-256
`911fa2e6d75366aaf1b8afe0b87b9b8c7096770641345760c48f076c8aa4c066`); the slim
package is 273,702,460 bytes (SHA-256
`75d7699c0082cb08150c0b6ecfa42d659c3bc8e81f45bbb9d213995c139e7e87`).

The signed update archive is 2,057,773,792 bytes (SHA-256
`0626bf42266651858dd18d6d96d55480f51b276c0b66814872002cc4b734675b`). The
signed appcast contains 28 items, including build 104 and direct deltas from
builds 102, 99, 98, 97 and 96. `check-release-inputs.sh` passed. The slim ZIP is
kept out of the updater feed so an update preserves the full music library.

The [Mac release](https://github.com/ErikVeland/Lemmings/releases/tag/v2.4)
was published from source commit `a19e9ad44681fe286f8a69c32d522295514ab459`.
GitHub reports the standard ZIP at 2,057,773,792 bytes and the slim ZIP at
273,702,460 bytes. The live main-branch feed points to build 104 and contains
five direct deltas. The feed publication commit is `59b04b18`.

## iOS and tvOS distribution gate

App Store Connect returned an unauthenticated session, no Apple Distribution
identity is installed, and the local configuration has no issuer ID for its
App Store Connect API key. The Mac Developer ID and notarisation credentials do
not grant App Store distribution. The iOS and tvOS build numbers, archive
signing and submissions are therefore not verified or submitted. Resume after
App Store Connect sign-in and Apple Distribution signing are available; confirm
the next build numbers and retain the store processing receipts.
