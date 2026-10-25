# Cross-platform feature parity

Source audit: 26 October 2026, Australia/Brisbane. This register describes the
working checkout. It does not establish availability in an installed release.

Applicable capabilities belong on Mac, iPhone, iPad, Duo and Apple TV. Input,
layout and file transfer may adapt to the device. An engine label, shared
protocol or visible settings choice does not prove that its implementation is
connected. Check the session, renderer, input route and persistence path.

iPhone, iPad and Duo use the same mobile frontend. The normal TV application
uses that frontend with remote/controller, focus and LAN-transfer adapters.
The older standalone TV development shell is not the production parity baseline.

## 2.3 consolidation and parity work

The `feature/2.3` consolidation retained the crowd-shadow and native-session
work. The following routes are now connected in source. Device acceptance is
still required; these rows do not describe an installed release.

| Capability | Current mobile / TV implementation | Validation and limits |
| --- | --- | --- |
| L2 machine, chain and held aiming input | Native pointer commands precede ordinary assignment and survive checkpoint/replay reconstruction. Touch, keyboard/controller and TV adapters release held input on cancellation. | Native command replay passes. Physical input delivery remains open. |
| L2/L3/Neo attempt review and movie export | Bounded action documents drive isolated, read-only replay sessions, move history and movie export with native sound banks. | Exact command/state and outcome checks pass. Encoder, sharing and TV LAN transfer require device acceptance. |
| Saved and online action replays | Conditions select the matching engine and population; shared replay validation checks commands and outcome. Loading native review content uses isolated storage. | New practice recordings preserve ordered skills. Older practice recordings without the panel order cannot be reconstructed safely. |
| L2 practice | Four original maps, eight distinct skills, isolated progress and exact checkpoint restore. | All four maps pass restore/state checks. The Play route has its required preview loader. |
| Sequel PC/Mac artwork | L2/L3 terrain, actors, objects and sprite feedback use the shared reconstruction with native input geometry. | Render captures check doubled output dimensions, unchanged state and selection geometry. |
| Sprite afterimages and rewind echoes | Bounded native-sprite history draws on existing surfaces; rewind retains the previous sprite samples. Reduced effects clear the history. | Budget, expiry and reduced-effects checks pass. Physical CRT presentation remains open. TV gains no extra HDR surface. |
| L2 short game | The checked five-level Classic tribe opening carries survivors through an owner-scoped saved queue. | Retry and restored-next-level populations pass. A failed shared save does not advance local carry-over. L3 carried samplers remain a shared limit. |
| Original sequel media | L2 introduction, ending and gold ending; all five original L3 FLIC movies. Shared bitmap menus provide pause, back and continuation through library and game pause routes. Covered gameplay stays paused. | All eight sources decode and advance. Automatic campaign story triggers remain separate WIP below. |
| Neo extra-skill rewards | Valid finite charges retain assistance and one-use state across checkpoint/rewind. | Charge and recovery checks pass. Individual naming remains explicitly deferred for clones, preplaced actors and unlimited populations. |

## Remaining source work

- Automatic sequel campaign story triggers still need mobile/TV integration.
  The gallery is available, but entering a campaign and earning an ending do
  not yet invoke the matching media automatically. Mac L3 already has opening
  and earned-ending rules in `Lemmings3StoryFlow`; the previous audit incorrectly
  described that Mac implementation as incomplete. Preserve Hot Seat Ready
  boundaries and skip automatic introductions on restore or selected-level entry.
- Verified sequel solutions/checked hints and L3 carried samplers remain shared
  engine/content limits. They are not platform-specific omissions.
- Neo individual inspection/naming needs identity rules for preplaced actors,
  clones and unlimited populations before it can match the native games.

## Corrections in this audit

- Native mobile L2/L3 libraries now supply the exact primary-sprite mask and
  position to the shared selection outline and assignment pulse.
  NeoLemmix uses the same feedback state and its resolved native sprite sheets.
  Animation time follows the simulation. Reduced motion/flashes retain their
  policies. Checkpoint restore and rewind clear stale assignment feedback.
- Mobile/TV NeoLemmix now uses the shared crowd-shadow pass. The preceding fix
  connected Classic, L2 and L3. Shadows darken rear sprite ink only.
- Mobile NeoLemmix now records exact shared action commands and accepts the
  same Hot Seat ghost archive as Mac. Absolute queued spawn-interval choices
  convert to the shared command format without losing multiple changes at one
  tick. Legacy checkpoints that retain only a mid-level state cannot create a
  complete ghost and remain explicitly unsupported for that recording.
- NeoLemmix draws earlier players with the shared native-sprite tint/cache and
  blending code, behind live actors. Ghosts add no input targets or sounds.
  Hiding them leaves their archive intact. Handovers retain the existing Ready
  boundary.

## Tester sync lifecycle — 26 October 2026

The shared `CloudLibrarySync` coordinator requests sync at startup. Both native
frontends request it on foreground activation. Mac termination now flushes local
saves and waits up to 20 seconds for a final pass. The production iPhone, iPad,
Duo and TV frontend requests UIKit background time and runs that same final pass
on background entry. It waits for active uploads and captures local progress
again, including changes made during upload. Legacy `test99` entry persists the
tester flag; existing tester credentials recover it during sync.

This applies to every player and saved Hot Seat across Classic, L2, L3 and
supported NeoLemmix completion records. Safe-menu import rules remain in place.
Mid-level checkpoints remain local on every platform. Force-quit, offline
providers and expired background time cannot guarantee completed uploads.
Physical-device lifecycle and live service acceptance remain open.

Validation: 29 `CloudLibraryTests` pass with muted audio, including repeated
lifecycle passes, an upload already in flight, changes during upload, offline
recovery and legacy tester credentials. The Mac frontend compiled in the first
successful test build. iOS/tvOS shared core SDK modules compiled. The `MobileLibraryViewController.store` access error has been corrected for
the split frontend extensions. Fresh iOS/tvOS frontend checks are recorded below.
These checks launched no app or Simulator windows.

## Shared coverage and intentional adaptations

### Journey resume integrity — 26 October 2026

Mac Home resolves the selected session's saved queue even when another session
occupies the active slot. Activating Resume restores that queue and retains the
other session's queue. Independent checkpoints retain a separate Resume level
action on Mac and the shared iPhone/iPad/Duo/TV frontend.

Starting a different route retains the journey snapshot on Mac and mobile/TV.
Mobile also retains the displaced run when the player resumes the journey.
Only completing the journey creates its completion marker on mobile. The shared
sync coordinator keeps delivery pending when a surviving journey has no roster,
instead of reporting Synced while omitting that save. Native integration builds
now use a process-specific temporary save root, separate from production data.

Focused persistence checks cover selected-session lookup for Classic, L2, L3
and NeoLemmix queue identities, reopen, unrelated-route completion, snapshot
retention and recovery, offline merges, repeated imports and missing-roster sync
status. Queue identity coverage does not expand the Classic-only mobile journey
loader. Mid-level checkpoint transfer remains local-only. Physical device resume
and provider propagation remain separate acceptance items.

The source connects native campaign play, owner-scoped checkpoints, rewind and
single stepping, Retry/Continue, named Hot Seat choices and paused Ready
handovers across the three native games. Shared libraries also provide profiles,
collections, settings, hints/coaching, records and the main audio system.
Engine-specific controls remain explicit: L2 fan and L3 tool direction have their
own controls; L2/L3 expose no release-rate setting and L3 has no nuke.

Classic supports artwork switching, deterministic review, verified solution
viewing and the separate solution ghost on mobile and TV. Matching verified
solution viewers and checked hints for L2/L3 remain a shared engine/content gap,
not a complete Mac feature that mobile merely hides. The learning curriculum is
also Classic-only across platforms.

| Adaptation | Reason to preserve it |
| --- | --- |
| Sparkle on Mac; App Store/TestFlight on mobile and TV | Platform distribution model |
| Mac menu bar; touch pages and keyboard discovery; TV focus/remote controls | Native input and window model. Home/End/F1 are handled by the mobile hardware-keyboard adapter despite their omission from command discovery. |
| iOS share sheets; TV token-protected LAN transfer | TV has no equivalent document/share picker. Capability still needs physical transfer acceptance. |
| TV omits completion glow, extra cinematic/HDR surfaces and explosion cores | Explicit owner performance instruction. Keep selection and assignment feedback. |
| Manual familiar-name entry on TV | Native contact-picker difference. Do not silently request broader contact access. |
| Duo hinge-triggered clock versus ordinary clock routes elsewhere | Device-specific hardware trigger. The shared clock remains available through platform-appropriate entry points. |

## Validation and remaining acceptance

Menu follow-up on the consolidated `feature/2.3` branch, 26 October 2026:
the shared pause/replay renderer groups tools, fills each occupied row, and
keeps return, Main menu and the primary action fixed. Eligible skip balances
remain visible, including disabled zero balances. The focused layout checks
pass 14 tests and produce 120 pause/replay captures across 20 geometries and
three lettering sizes. These include Duo book, table and outer-screen cutout
arrangements. Compact-book and wide-phone captures were inspected. Both Apple
SDK module and application-entry checks pass with input hashes matching the
current source. Nine hostless UIKit checks pass across all three game identities,
including skip balances/refunds, one header return, focus revealing tools and
text above Resume, browser rows and Duo safe navigation. Six native captures
were produced. Compact captures exposed fallback buttons drawn beneath Resume;
the corrected clipping and group headings were rerun and inspected.

The arm64 Mac compilation and focused offscreen replay check pass. Native
solution controls retain at least 44-point targets at four sizes from 640×480
to 1600×900. Keyboard focus reveals the scrolling tools. Movie controls fill
their rows at five widths from 320 to 1600, with and without header navigation.
Retained position, camera, paused returns, ghost viewing and Hot Seat ownership
also pass. Compact solution and movie captures were inspected. All runs used
muted audio and the default background runner. Physical folding, VoiceOver and
Siri Remote delivery remain device checks.

Run `Scripts/run-platform-parity-tests.sh` with the default muted, offscreen
runner. It supplies the packaged engine identity to the test hosts so ghost
archives exercise the production validation rules. Native captures are written
to `.build/platform-parity/renders`. Run both Apple SDK checks after changing
shared UI. SDK compilation verifies source coverage, not device input delivery.

Current evidence: 44 focused core tests and three render tests pass with muted
audio and offscreen execution. They cover native sequel masks and feedback,
reduced effects, exact replay, read-only review, practice restore, carried L2
population and retry, original media decoding, Neo extra charges and early end
run. Render coverage includes PC/Mac sprite geometry and 24 menu layouts at
phone, Duo-pane and TV dimensions. Representative bitmap captures were inspected.

The shared Neo early-nuke rule now completes when no active actors remain,
without counting unreleased actors as deaths. Neo result population includes
preplaced actors and clones. The replay regression checks the same final hash.

Both iOS and tvOS SDK checks pass for all eight shared modules and their
application entry points. Their recorded input hashes match the current source.
The native Apple Silicon debug build also passes. Crowd checks pass at 1–12×
zoom and 1×/2×/3× backing scale, with 36 native and 36 mobile bitmap captures.
Compilation alone cannot establish physical input or presentation acceptance.

Physical touch, Siri Remote, controller/keyboard delivery, VoiceOver, CRT/EDR,
thermal behaviour and live service/cloud journeys remain device acceptance.
Cloud library progress does not back up every mid-level checkpoint on any
platform. App Store Connect, provisioning and production service setup are
external acceptance items, not proof of absent source capabilities.

Older matrices and port checklists contain historical claims. Use this register
for the gaps above, with [iOS coverage](IOSInterfaceParity.md),
[TV adaptations](../Apps/UltimateLemmingsTV/IOSParity.md) and
[cross-game behaviour](ReleaseReadiness/CrossGameParity.md) for detailed context.

## Duo rounded controls — 26 October 2026

Duo opts into `GameControlShape.rounded` through the existing foldable/hinge
identification, including its outer display. Shared renderers round menu cards,
stone buttons, search tools, pause panels, adaptive HUD sockets and focus rings.
Classic, L2, L3 and supported NeoLemmix use the same frontend path. Mac, ordinary
iPhone/iPad and TV keep their existing square presentation. The original full
native HUD panel remains authored artwork. Rectangular touch targets, engine
input and paused handovers remain intact. Duo HUDs retain UIKit's corner-adapted
safe area along the longer display axis. Outer-display menus use vertical
corner clearance to retain full width around local camera cutouts. The gameplay adapter no longer discards those insets on the outer
display. Scenery still extends across that display.

Muted, windowless rendering checks cover 72 Classic/L2/L3 HUD states and 120
book Home states, including focus, disabled, selected and busy controls. Their
checks cover all visible HUD targets against rounded screen masks, action sets,
touch targets and scroll reachability.
A separate control sheet checks normal, selected, focused, disabled and primary
buttons, search and passive panels, including input at transparent button corners.
Physical Duo corner clearance, pose transitions and composited output remain
unverified. Imported NeoLemmix content has shared source coverage only.
The synthetic screen-radius fixtures model the system insets. They do not
validate UIKit's reported corner geometry on physical Duo hardware.

Shared artwork compiles for Mac. Final UI modules compile against the iOS and
tvOS SDKs. Engine suites were skipped because simulation and input semantics
are unchanged. Evidence is in ignored `.build/duo-rounded/` files.
