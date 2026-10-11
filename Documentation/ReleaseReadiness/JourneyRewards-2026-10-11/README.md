# Journey placement, precision rewards and Menu visibility

Learning-17 moves **Come back!** from lesson 21 to lesson 71, in Intermediate.
Its bombers and builders match the owner’s two-bomber bridge description; the
other named candidates have no builders. This placement follows that playtest.
The stored witness uses two bombers and does not verify the bridge route.
Cellbash remains lesson 2. Saved journeys retain their current lesson, owner,
run ID and history, with every unvisited lesson still queued.

Mac journey and playlist results now enter saved career history across Classic,
Lemmings 2 and Lemmings 3. Previously they were previews, so their stars did not
fund precision uses. The shared result panel shows each newly credited use as
`+1 ZOOM` and, when earned, `+1 SUPERZOOM`, in the existing bitmap lettering.
The existing rates remain one Zoom per three no-Rewind career stars and one
Superzoom per three distinct no-Rewind three-star levels. Repeat clears do not
add credit. Preview results and failed saves do not claim a saved reward.
Native sequel results now include a Rewind marker in their telemetry so assisted
runs can be saved separately; they do not fund precision rewards.

The shared gameplay Menu fades after three seconds, over 0.6 seconds. Hover and
keyboard focus reveal it. Its 88 × 44 input target, accessibility, Q and Escape
remain available. Reduced motion hides it without animation. Results and paused
Ready handovers retain their navigation actions. L3’s original HUD Game menu
action remains in its native status strip; the shared return-to-library stone
Menu is the fading control in all three engines.

## Validation

- [Core tests](core-tests.log): 22 tests passed. Coverage includes every saved
  journey migration position around the moved lesson, repeated wins, improving
  stars, Rewind and failed runs, separate owners and reward persistence.
- [Precision wallet checks](precision-ledger.log): existing rates, spending,
  retry refunds, failed-run costs, cursor mapping and scroll gestures passed.
- [Generation](journey-generation.log) and [consistency check](journey-check.log)
  passed for 294 lessons and 1,627 review candidates.
- [Native compilation](native-compile.log) and [runtime](native-runtime.log)
  passed through `Tools/UITestRunner/run.py` in its default offscreen mode with
  `LEMMINGS_TEST_AUDIO=muted`. Classic/L2/L3 sequence completion callbacks save
  career results; owner and paused handover checks still pass. Reward wallet
  balances, reopening records, bitmap captions and accessibility were checked
  at 900- and 1,600-point widths. Menu hover, focus, unchanged input targets,
  reduced motion, result visibility and Q/Escape were checked in all engines.
- Captures were inspected for reward panels, failure panels, full/half/hidden
  Menu artwork and gameplay targets. [Menu alpha measurements](menu-alpha.log)
  confirm full opacity, 0.502 halfway and zero when hidden in all three engines.
  Commercial artwork captures stay in ignored `.build/precision-reward-renders`,
  `.build/exit-progress` and `.build/celebration-renders`.

Apple’s audio equalizer requires service access outside the sandbox. The native
checks remained muted and offscreen with that access. They did not take desktop
focus. Sparkle was reused from the verified previous local build because the
sandbox could not resolve GitHub during the initial dependency lookup.

## Separate Mac candidate

`.build/journey-rewards-beta/Ultimate Lemmings.app` is an unoptimised arm64
candidate with a distinct preview bundle ID and ad-hoc signature. Its inherited
version metadata is 1.9.1 (76), not a published 2.0 release. It includes the prior
completion-music and golden-rim fixes. [Build and signature verification](candidate-build.log)
and [resource validation](candidate-resources.log) passed for all three games,
all four RGBA artwork banks and learning-17, with Cellbash second and Come back!
in Intermediate at lesson 71. It was not launched or installed over the current
app. [Source hashes](source-sha256.txt) were unchanged through native testing and
candidate compilation; [candidate hashes](candidate-sha256.txt) identify the build.

## Scope

These are Mac AppKit changes plus the shared learning curriculum and reward
snapshot. The installed iPad build 8 has not been replaced. These checks do not
establish UIKit/device parity or audible music acceptance.
