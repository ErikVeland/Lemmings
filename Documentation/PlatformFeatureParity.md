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
| Sprite afterimages and rewind echoes | Bounded native-sprite history draws on existing surfaces; rewind retains the previous sprite samples. Reduced effects and constrained devices clear the history to prioritise responsiveness. | Budget, expiry and reduced-effects checks pass. Physical CRT presentation remains open. TV gains no extra HDR surface. |
| L2 short game | The checked five-level Classic tribe opening carries survivors through an owner-scoped saved queue. | Retry and restored-next-level populations pass. A failed shared save does not advance local carry-over. L3 carried samplers remain a shared limit. |
| Original sequel media | L2 introduction, ending and gold ending; all five original L3 FLIC movies. Shared bitmap menus provide pause, back and continuation through library and game pause routes. Covered gameplay stays paused. | All eight sources decode and advance. Automatic campaign story triggers remain separate WIP below. |
| Neo extra-skill rewards | Valid finite charges retain assistance and one-use state across checkpoint/rewind. | Charge and recovery checks pass. Individual naming remains explicitly deferred for clones, preplaced actors and unlimited populations. |

## Mac panel navigation — 29 October 2026

Mac `GameMenuPage` panels retain Back in their existing bottom action row and
add Main menu beside it, using the regular bitmap stone buttons. Shared Mac
full-window pages use a fixed bottom navigation row. Classic, L2, L3 and
supported NeoLemmix use this common presentation; mobile and TV retain their
fixed header navigation. Return callbacks and paused handovers are unchanged.

Validation: Apple Silicon Mac compilation passes. The existing navigation
regression now locates the footer controls through the panel hierarchy and
checks their bottom placement. Test suites and release audits were skipped
under the UI-only release policy. Native rendered layout, mouse/controller hit
targets and enlarged-page scrolling remain acceptance checks; no release was
packaged.

## Joined gameplay controls — 28 October 2026

Duo supplies the shared visual baseline for landscape iPad and Mac. Skills,
related navigation and playback controls use `GameControlGroupArt` and
`GameHUDControlGroup`: rounded outer ends, one-pixel borders/dividers and
separate rectangular activation targets. The mobile layout joins existing
gaps without moving a group's outside edges. Divided displays retain separate
banks, and landscape iPad's adaptive conversion retains the prior playfield
rectangle. Classic, L2 and L3 retain their native icons and stock semantics;
supported NeoLemmix keeps its configured skill count and scrollable banks.

Mac Classic/Neo and the native L2/L3 skill rows use the shared responsive
height. `GameplayKeyboard` reads each row's actual height for every top toolbar
group; Classic CRT converts that height through its displayed source mapping.
Native L2/L3 keep their engine-specific Fan/tool controls and panel reservations.
The shared timeline also uses joined dividers. The authored TV panel layout is
retained; adaptive iPhone/TV decks inherit the shared grouped renderer without
adding effects or HDR surfaces.

Validation: the Mac frontend builds, and iOS/tvOS SDK modules plus application
entry points compile; the final shared layout spacing also type-checks for both SDKs.
The muted windowless HUD check passes 108 captures across
Classic/L2/L3, nine geometries and four states. It includes two landscape iPads,
Duo main rail, book/stacked poses, selected first/last skills and Undo. It checks
complete input rectangles, activation centres, contiguous skill boundaries,
reserved regions and retained gameplay geometry. Physical touch, VoiceOver,
Siri Remote focus and composited CRT acceptance remain manual checks. Native Mac view/toolbar capture and native input acceptance remain open: the
windowless AppKit capture process could not register with the system in this
sandbox. The shared Core Graphics renderer was inspected in the mobile captures. Engine suites and release audits were skipped for this
presentation change under the release schedule; no release was packaged.

## Gameplay skill selection follow-up — 28 October 2026

The grouped adaptive HUD removes the selected green inset and underline. It
brightens the selected segment of the outer contour, draws a white/green sprite
glow, darkens and recesses the selected face, and reserves two points between
count and sprite.
Duo rail and adaptive landscape place End run separately from rate, speed and
Pause/Play. Mac Classic and NeoLemmix use the same order. L2 has no release-rate
control; L3 has its own tool actions.

The shared renderer supplies extended-linear colour values, but its current
UIKit and AppKit bitmap backing does not establish actual HDR light output.
A headroom-aware HDR presentation for the HUD remains source work, with the TV
surface budget unchanged. Mac L3's native skill tiles and Classic's fallback
baked panel icons do not yet expose an isolated alpha sprite for the glow.
Mac L2/L3 native transport remains in its authored arrangement. These gaps are
not evidence of physical-device acceptance. Native Mac offscreen capture is
blocked by AppKit registration in this environment.

## Duo bottom-corner controls — 28 October 2026

The shared HUD renderer identifies the outermost controls on Duo's lowest
visible row and extends their outside lower curves. All segments of each joined
group use the same contour, including selected borders; input and accessibility
rectangles, viewport geometry and other platforms retain their existing bounds.
The shape adapts to available group dimensions. Actual display curvature and
physical touch acceptance remain device checks.

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

Mobile and TV fast-forward share the same bounded simulation loop for Classic,
L2, L3 and NeoLemmix. The loop reserves time for simulation after input work and
checks completion without rebuilding the HUD snapshot on each native tick. The
frame path reuses snapshots and panel artwork and avoids duplicate pitch updates.
Replay recording, rewind and saved-run recovery remain enabled; their cost,
sustained 10× throughput and touch responsiveness still require profiling and
acceptance on older physical devices.

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

### Progress and Leaderboards — 26 October 2026

Home has two separate entries. Progress belongs to the active local player.
Leaderboards ranks players against each other.

Progress shows the player's career stars, cleared levels and three-star
levels. It opens Records, Achievements and Play Insights. Back is its only
footer action.

Leaderboards has two rows of tabs above one ranked list. The first row picks
who: World, Game Center (Mac, when available) or This device (This Mac on Mac).
The second row picks the category: Career stars, Levels cleared or Three-star
levels. The active player's row is highlighted. On iPhone, iPad, Duo and Apple
TV, Game Center opens Apple's own leaderboard screen. Share my records is a
single toggle on World. Per-level lists stay on each result screen and in Mac
level records. They rank players by Fastest 100% first, then Fastest clear,
Least skills and Most saved, from direct runs only.

| Platform | Progress | Leaderboards | Level list on result | Source check |
| --- | --- | --- | --- | --- |
| Mac | Records window | World, Game Center, This Mac | Yes, Classic, L2, L3 | `swift build` |
| iPhone, iPad, Duo | Shared page | World, This device, Apple Game Center | Yes | `LevelLeaderboardResultTests`; iOS SDK compile |
| Apple TV | Shared page | World, This device, Apple Game Center | Yes | tvOS SDK compile |

Limits: the hosted service returns only rank, name and score for each entry.
World therefore shows one score column. This device and This Mac also show
cleared and three-star counts. More World columns need a server change. Mobile
and TV staging now enables Game Center only when the exact iOS bundle and board
catalogue have an Apple-verified activation record. The repository currently has
a Mac activation record only, so iPhone, iPad, Duo and Apple TV candidate builds
keep this service disabled. Developer ID and ad-hoc Mac builds also switch it
off; App Store, TestFlight and development signing are the supported routes.
Not yet checked: rendered captures, live service data, physical devices and
controller focus on Apple TV.

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
safe content vertically while drawing their header and bottom surfaces to the
screen edges. The adaptive deck fills the display width on outer and opened
screens. Skill rows and interior corners stay square. Only the last bottom
control receives the outside bottom-right curve. Header Menu stays on the right;
its curved outer surface reaches the display top while its icon stays safe.
Extended rectangular input/accessibility targets cover these visible surfaces.
Short landscape rows shrink to preserve the playfield and 44-point targets.
Camera and hinge reservations remain active. TV keeps its existing presentation.

Duo and iPad library menus draw a 90%-opaque black backdrop with Overlay blending in the same scrolling surface
as their content, with equal 12-point margins and an inset corner radius. The
background and content scroll together; navigation stays fixed. Only the background
layer uses Overlay; controls and text retain normal compositing. Mobile measurement
is reused for drawing and input targets, and drawing waits for committed geometry.
Mac page trees and release-note scroll tiling finish before presentation.
Windowless renders of What's new and Settings at outer Duo, opened Duo and iPad
sizes verify the Overlay surface and at least 44-point action targets. Mac frontend
typechecking and iOS/tvOS SDK compilation pass. Engine test suites were skipped for
this presentation-only change. Physical first-frame presentation and Core Animation
blending remain device checks.
Confirmed hinge capability is retained per device, avoiding a phone-to-Duo layout
change on subsequent launches. The first-ever hinge callback and real pose/safe-area
changes still need physical-device acceptance. Identical page assignments do not
rebuild targets. Mac nested page layout completes synchronously before display.

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

Portrait phone library, gameplay, pause, solution and original media menus
extend their scrolling viewport towards the display edges. On Duo, library and
gameplay pages keep their title above fixed navigation and begin scrolling below
that navigation. Initial and
final content positions retain clearance for system regions and fixed navigation;
the pause footer remains pinned inside that clearance. This shared presentation
covers all engines. Split displays retain separate viewports on each side of the
hinge. Physical Duo scrolling, touch and VoiceOver acceptance remain outstanding.

The mobile source currently has no About route or About screen to validate.
The Duo static-heading treatment covers the existing shared reading pages; an
About screen must adopt the same layout if added. Rendered and physical-device
acceptance for the new header remains outstanding.

### Duo edge layout validation — 29 October 2026

The updated muted, windowless HUD audit covers 108 Classic/L2/L3 renders,
including outer portrait, short landscape, opened, book and tabletop fixtures.
It checks square interior corners, outside-only curves, unchanged action centres,
44-point safe targets and extended edge targets without overlap. Nine additional
Home, What’s new and Settings captures exercise the shared scrolling backdrop
at top, middle and bottom positions, equal margins and 95% opacity. Representative HUD and reading captures were
inspected. Mac compilation passes; iOS/tvOS SDK validation is recorded separately.
Native NeoLemmix
rendering, UIKit hinge delivery, first-launch stability, physical touch and exact
hardware corner matching remain device/content acceptance gaps. The shared
NeoLemmix frontend uses the same controls. No simulation code changed.
