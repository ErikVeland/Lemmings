# Anniversary foundations source checks

19–20 October 2026. This record supports the [prioritised 2.1 roadmap](../../2.1Roadmap.md).
It covers the working tree's access, presentation, hint and review changes. It
does not replace a release candidate's engine, package or device acceptance.

## Implemented scope

- Basic Zoom is free across the three Mac native hosts, including zero-star
  profiles and damaged Superzoom storage. Saved Superzoom costs remain separate.
  Mobile and TV basic magnification was already free.
- Original and Modern select presentation independently of controls, bindings,
  interruption pause and assistance. Saved choices survive. New profiles have
  restrained flash/music defaults and no mandatory presentation chooser.
- Generic help says **General coaching** and **No level-specific hints available.**
  Exact checked routes keep deliberate spoiler tiers. Two original introductory
  levels now explain the obstacle and plan before assignments.
- Main results keep outcome and primary actions prominent. Detailed career
  accounting and awards remain available by choice. Shared mobile award rows
  stay still until selected.
- Modern assignment targets use distinct empty, eligible and unavailable shapes.
  Original pointer artwork remains unchanged. About includes offline original
  team and port credits.
- Optional five-level [Short games](../../ShortGames.md) pin exact data and route
  evidence. Mac supports Classic and L2 with isolated carry-over; mobile/TV
  supports Classic. Unavailable sequel routes explain their limits visibly.

## Automated evidence

Native UI checks use `Tools/UITestRunner/run.py`, offscreen windows and muted
audio. No check changes system volume or saved player audio preferences.
Final native runs used sandbox access for macOS registration and media services
while retaining those window and audio settings.

| Check | Result and practical limit |
| --- | --- |
| Focused Swift tests | Two About XCTest checks and 17 Swift Testing checks pass: presentation persistence, precision earnings, exact short-game catalogue, source replacement rejection and saved-run ownership. |
| Precision and settings | Free Zoom, Superzoom costs, legacy migration, cursor mapping, gestures and saved presentation preferences pass. |
| Assignment cursor | Same-colour empty/eligible/unavailable states, original pixel fixtures, scaling and modal suppression pass. Inspected bitmap renders retain distinct shapes. |
| Results and review | Full Trolley suite passes, including primary input, optional review and movie retention across retry. Separate visual checks cover compact/L2 results, Career/Rewards and five new-award pages. Collection targets are disjoint from Back. |
| Native foundations | Launch defaults, independent live controls, Zoom storage/targets and earned reward variants pass. Journey Skip passes across all three engines, solo and both Hot Seat rules, with saved revisit, charging, failed-save refunds and paused Ready. |
| Hint catalogue | 350 exact decks, 196 release-rate contexts, event ordering and spoiler boundaries pass. |
| Native hints | All 1,050 checked tiers, spoiler confirmation, exact winning ghost timing, unchanged live attempt/ownership, flat/CRT and explicit generic coaching pass. |
| Native Short games and About | Exact Classic/L2 preflight, L2 lock/L3 unavailability distinctions, six bitmap states, primary/Back targets and non-mutating browsing pass. About credits/history, offline contributors, input targets and count-reset recovery pass. |
| Shared navigation | 77 states, 1,386 layout checks and 462 bitmap renders pass, including hint availability and Short games ready/missing/loading states. |
| Shared generic hints | 36 renders cover all three engines and tiers at phone, tablet and TV widths. Inspected samples show the availability statement before coaching. |
| iOS SDK compilation | Seven modules and the app entry point pass for arm64 simulator. No simulator or physical device was launched. |
| tvOS SDK compilation | Eight modules and the app entry point pass for arm64 simulator. No simulator or physical device was launched. |
| About packaging | Offline heritage/current-note packaging passes. |
| Journey curriculum | The existing 227 teaching-ordered lessons pass the current generation check. This is not human difficulty calibration. |
| Fingerprint policy | Presentation-exclusion regression passes. All 152 included source-file hashes match the pre-existing 2.0.8 snapshot. Existing route certificates were not re-certified by these UI checks. |

The combined native run passed through hints, then exposed an L2 catalogue bug:
campaign-locked data had been labelled unavailable. Only the L2 mapping changed;
unsupported L3 data remains unavailable. A focused rerun passes the corrected
sampler and About flows. Fixture repairs use the current playlist writer and
the original Hot Seat progress scope without weakening save protections. The
About fixture was regenerated with the normal bundler for build 92.

[source-checks.json](source-checks.json) retains result excerpts and code/test
input hashes. Detailed working logs and renders are under
`.build/anniversary-foundations`, `.build/hints`, `.build/trolley` and
`.build/hint-availability-shared`.

## Remaining acceptance

The [newcomer and veteran protocol](../../BetaTesting.md#newcomer-and-veteran-playtests)
has been prepared; no human sessions are claimed. Real VoiceOver use, translated
copy review, physical touch/controller/remote journeys, composited cursor output,
audible tone, HDR appearance, live cloud propagation and sustained device loads
remain open.
Native sampler captures verify the initial carousel state and its controls.
Completed asynchronous preview artwork remains visually unchecked.

The Mac earned 0.5× Superzoom and mobile precision camera remain different
features. L3 Short games needs isolated reserve snapshots through retry, advance,
save, resume and Hot Seat. Mobile sequel playlist playback is unavailable.
Existing L3 campaign, source/media and carried-route gaps remain in
[release scope](../../ReleaseScope.md). The Classic Journey remains Classic-only.

The bundled proof stamp predates this work. Git commit `a506dc4e` reproduces its
`f185238e…` identity under that commit's presentation policy. Three still-included
files already differ in the 2.0.8 source snapshot: menu music selection,
controller-requirement text and `LocalizedError` reporting. The guarded
presentation migration correctly refuses byte identity to the old stamp.
This task leaves certificates and engine/hint resource stamps untouched; a fresh
native replay audit remains a release gate. Under the current exclusion policy,
both the pre-existing 2.0.8 snapshot and these sources hash to
`28c0c9dd95f47e80847c53620def59204c6d7776f75f36e01ddb32f2cf58fe7b`.

No full engine replay audit, universal release build, signing, notarisation,
installation or publication was performed. Prior package evidence cannot certify
this later working tree.
