# 2.4.1 build 105 preparation

Status: public Mac release preparation, 3 November 2026. The owner authorised
production signing, notarisation and publication. iOS and tvOS remain next in order.

## Completed source scope

- [x] Finish shared skilled-worker targeting and its native checks. Preserve explicit selections, legacy settings, saves and replay identity.
- [x] Flush local saves before the Mac quit decision. Bound cloud delivery to three seconds and stop cancelled lifecycle waits.
- [x] Prevent cancelled cloud work from importing progress, starting subsequent provider writes or reporting a new successful sync.
- [x] Fix the measured repeated L2 completion read. Keep current player progress and fresh imported-content checks.
- [x] Assign 2.4.1, Mac build 105, iOS build 44 and tvOS build 19. Update candidate notes, in-app notes and release history.
- [x] Build and sign the local Apple silicon app. Verify its signature after copying it to Downloads.

The [candidate notes](../../ReleaseNotes-2.4.1-build105.md) describe the player-facing changes.
The existing Mac Home accessibility correction is included.
No new game mode, sequel deck conversion or automatic story trigger was added.

## Local Mac candidate

Path: `/Users/veland/Downloads/Ultimate Lemmings 2.4.1 build 105.app`.
The app uses optimised arm64 code and identifies itself as 2.4.1 build 105.
`codesign --verify --deep --strict` passes on both the build and Downloads copies.
The app was not launched for manual acceptance.

The selected local signing profile does not authorise the shared CloudKit container.
The built app therefore has `CloudLibraryCloudKitEnabled = false`.
This candidate does not establish live iCloud service acceptance.
Public release preparation still needs its production provisioning profile.

[Validation metadata](validation.json) records the executable hash, source base,
checkout HEAD and changed production input hashes. The checkout has uncommitted changes.
The release base is the recorded Mac 2.4 build 104 source, `a19e9ad4`.

## Validation

All automated UI checks ran through `Tools/UITestRunner/run.py`, offscreen and muted.
Core and engine checks used muted, isolated test environments. No production saves
were repaired or replaced. No foreground, secondary-display or audible fallback ran.

| Check | Result | Retained evidence |
| --- | --- | --- |
| Focused Swift tests | 73 pass: 12 native action/history, 18 mobile worker/session, 43 cloud/recovery tests | [Focused tests](focused-final.txt) |
| Native engine and replay checks | L2 runtime, L3 runtime and targeting, Classic DOS replay and Neo replay pass. L2 includes 120 recorded campaign completions. | [Engine checks](engine-checks.txt) |
| Mac crowd selection and footer | Native hover, click, inspection, skill assignment, opt-out and bounds pass. Home and fallback footer labels dispatch the matching mouse and accessibility actions. | [Playfield checks](playfield-targeting.txt) |
| Mac loading, Settings and What's New | Native loading checks pass. Settings input/layout and release-note scrolling/Continue pass. | [Post-change checks](loading-after.txt) |
| Preserved fixtures | 120 Classic, 322 campaign, 120 L2 and 70 carry-over hashes match | [Classic](classic-fixtures.txt), [campaign](campaign-fixtures.txt), [L2](l2-fixtures.txt) |
| Version history and source whitespace | Pass | `Scripts/check-release-history.sh`, `git diff --check` |
| New targeting translations | All three messages exist in nine interface tables and match the eight draft packs | Structural check only; human review remains open |
| Local Mac build and signature | Optimised arm64 build passes; copied app passes strict signature verification | [Validation metadata](validation.json) |

Representative [Home](renders/footer-home.png), [fallback](renders/footer-fallback.png)
and [What's New](renders/whats-new-900.png) captures were inspected.
The Settings capture also shows the complete skilled-lemming label.

The new cancellation regressions failed before the fix. The Apple transport regression
also reproduced the missing cancellation check before the transport correction.
A separate reviewer checked the sync changes and found no remaining material issue.

The mobile worker-session tests initially overflowed L2's debug step stack on the
cooperative pool. They now use the main actor, matching gameplay, and pass.
The old standalone playfield script lacked current shared dependencies. It now
uses the full native integration build and keeps its focused targeting option.

## Loading result and limits

The repeated L2 completion read measured 219.0 ms before and 0.4 ms after.
The cache retains only initial immutable bundled campaign data. Each call restores
current progress into a copy. Tests cover changed Journey wins, session isolation
and a changed imported level. See [before](loading-before.txt) and
[after](loading-after.txt) measurements.

These are local unoptimised native-harness results with other background builds.
They are not production-device deadlines. Cold L2 decoding remains. L3's repeated
read measured about 5 ms and was left unchanged. Mac audio lifecycle scheduling
was not changed without a measured stall in that path.

## Checks deliberately left for delivery and acceptance

The targeting change affects native metadata and outcome-affecting input selection.
Affected engine/replay checks and fixture manifests ran under the release replay
policy. No physics, terrain, skill rule, replay execution or level content changed
in this patch. Broad unrelated suites and full campaign gates were skipped.

Intel compilation, notarisation, public packaging, updater-feed changes and public
publication were not run for this local candidate. iOS/tvOS SDK builds, archives,
store delivery and sideloading remain later platform work. Their version numbers
are assigned, not delivered.

Physical mouse, touch, remote/controller and VoiceOver acceptance remain open for
this candidate. Live iCloud/hosted sync and physical cross-device acceptance remain
separate from isolated reopen, offline/reconnect and cross-device import tests.
Draft translations still need human language review. The existing catalogue-wide
localisation audit also has older missing and obsolete entries. Only this patch's
new targeting messages received the focused structural check.

The owner's 1 November acceptance remains the recorded 2.4 result. It does not
certify this candidate or reopen those accepted 2.4 blockers.

## Public Mac preparation — 3 November 2026

The owner authorised the public 2.4.1 Mac release after the local build.
The installed Developer ID profile, UUID `825c160c-59cc-462a-828d-d054815b9715`,
authorises the shared CloudKit container in Production on all Macs. Its certificate
matches the installed Developer ID identity. The public signing preflight passes,
and the existing `lemmings-beta` notarisation credential authenticates. See the
[signing preflight](production-signing-preflight.json).

Public packages will use this profile explicitly. The local development build's
CloudKit limitation above does not apply to the production signing configuration.
The new engine fingerprint requires retained rescue-certificate recertification
and a matching Classic hint catalogue before packaging. Existing route inputs
are replayed without solution search.

The broad integration and foreground-launch gates will be skipped with
`SKIP_RELEASE_TESTS=1`. The affected engine checks above remain applicable.
Signing, universal architecture, notarisation, Gatekeeper, package integrity,
signed deltas and live publication checks remain required.

### Retained route recertification

All 609 retained rescue targets replayed unchanged against the current engine:
294 exact-condition certificates and 315 rescue records across 615 configurations.
Six configurations remain unknown. No search ran and no route, witness hash or
rescue outcome changed. All 352 Classic/conversion hint routes also replayed.
Their hint decks are unchanged. Only the engine fingerprint and audit time changed.
See the [recertification receipt](retained-route-recertification.json) and
[summary](recertification.txt). These checks supersede the earlier local candidate's
stale proof fingerprint and clear the package's proof/hint gate.
