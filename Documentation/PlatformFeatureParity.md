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

## Saved-level loading and preview activation — 30 October 2026

The shared iPhone/iPad/Duo/TV preparation actors use one serial worker with an
8 MiB stack. This removes the cooperative-worker stack exhaustion reproduced
while stepping L2 in the Beach resume regression. It keeps Classic, L2, L3 and
supported Neo preparation off the UI thread. L2/L3/Neo checkpoint reconstruction
checks cancellation between ticks. Wide layouts show the level detail page and
its opening preview during restoration instead of a carousel whose artwork has
already been suspended. Compatible saves retain their existing format and
identity. Mobile Journey playback remains Classic-only.

Level previews dispatch the page's existing forward action: Play, Ready,
Resume, Next or Retry, with the same availability and loading guards. The shared
mobile/TV canvas exposes the preview to touch, focus and accessibility; TV keeps
its neutral-activation guard. Full-image QR codes and original movies retain
their separate controls. Mac carousel clicks and accessibility presses select
and start the clicked level through the existing launch callback. Locked and
unavailable cards remain blocked. Native L2's briefing already starts from its
preview region.

Validation: 30 focused preparation/checkpoint/rewind checks, two shared preview
action/layout checks and two native Mac input/layout checks pass with isolated
saves, muted audio and offscreen windows. The Beach regression reopens a
2,000-tick save, matches the restored state hash, rewinds and returns to the same
state. Forty-eight native preview renders cover Classic, L2, L3 and Beach at
phone, landscape, tablet and TV sizes; representative captures were inspected.
The optional Cellbash fan fixture is unavailable and was skipped. iOS/tvOS SDK
modules and app entry points compile; the final frontend and UIKit preview input
tests typecheck for both SDKs. UIKit test execution, physical Duo touch/resume
timing, Siri Remote/VoiceOver delivery, the user's exact save and hosted sync
remain separate acceptance checks.

## Rewind responsiveness — 29 October 2026

Classic keeps a small recent cache alongside its long history. The mobile and
TV sessions for Lemmings 2, Lemmings 3 and NeoLemmix retain bounded in-memory
snapshots and reconstruct older positions from their full input logs. Snapshot
caches are not written to saved checkpoints. Saved action replay playback uses
native history where compatible and reconstructs in cancellable batches otherwise.
Classic replay reconstruction also yields between bounded batches. Actual memory use,
responsiveness and Siri Remote interaction on older Apple TV hardware remain
device checks.

The shared frontend now schedules held rewind from its game frame loop as well
as touch callbacks. Isolated TV L2 taps remain single-frame steps; rapid taps
within 650 ms increase the jump to 0.4, 0.8, 1.6 and 3.2 seconds. Holding repeats
and accelerates. Discrete Rewind presses similarly increase from 2 to 4, 8 and
16 seconds, even when each preceding seek has already completed. A longer gap or
cancelling action resets the burst. Dedicated backward-step controls stay precise. Rapid Rewind presses and backward steps accumulate against the
requested destination while one seek finishes, then reconstruct one combined next
destination. Trigger release stops adding distance and lets accepted movement
finish paused. Resume, other editing actions, menus, interruption and memory
pressure cancel the queue. This route covers Classic, L2, L3 and supported Neo,
including action replays, on iPhone, iPad, Duo and TV. Mac's existing synchronous
transport is unchanged. Physical Siri Remote/controller feel and audible continuity
remain unverified; no new TV rendering surface or input geometry is introduced.

Validation: 30 focused muted rewind/controller checks pass, including exact live
state hashes and assistance counts in Classic, L2, L3 and Neo. iOS/tvOS SDK
compilation passes. The broader portrait-HUD run still has two unrelated layout
test failures (20 assertions); the rewind change does not modify layout source.
The rapid-press follow-up passes 34 focused muted checks, including burst
acceleration across completed seeks and queued work; updated iOS/tvOS core and
frontend SDK modules compile. Physical-device timing, transport feedback and audio
acceptance remain open.

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
The shared timeline also uses joined dividers. As of 29 October, TV uses the
same adaptive grouped deck as landscape iPad, retaining its remote menu action
and TV status presentation without adding effects or HDR surfaces. TV Home
reflows its footer into wider buttons when a label needs more space.

The muted, windowless grid audit renders the TV deck for Classic, L2 and L3,
checks non-overlapping input rectangles, and checks TV Home label widths and
activation centres at three viewport widths. Siri Remote focus and physical
TV presentation remain device acceptance checks.

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
The shape adapts to available group dimensions.

30 October correction: UIKit supplies each effective corner radius independently
through a concentric HUD corner configuration. The complete mobile deck shares
one inset contour, including the upper portion of a corner that crosses into
the skill row; the minimap uses the same outside inset. Player identity, counters
and Menu share the visible header's vertical centre, including accessibility
frames. The compact transport row uses existing skill-column boundaries where
its minimum input sizes permit, removing fractional Block/Build versus
speed/End run divider drift. Classic, L2 and L3 share this source; supported
NeoLemmix uses the Classic shell. Ordinary Mac and TV layouts retain their
existing treatment and TV effects policy.

Muted, windowless verification passes 36 Duo fixtures at two widths with
uniform and asymmetric corners, plus three TV HUD and three TV Home fixtures.
The wider rounded-HUD audit passes 108 captures using native Classic/L2/L3
content. Checks include shared divider coordinates, header centring, separated
input targets, reserved regions and pixel containment of the complete deck
outline across row boundaries. Representative asymmetric captures were
inspected. Final artwork and UIKit modules compile for iOS and tvOS; this is
SDK/source validation, not a signed app build. Native audit dependencies come
from the current host's debug products, without an older-macOS runtime claim.
Physical Duo corner values, pose transitions, touch and composited output
remain device checks. Engine suites and release audits were skipped because
this change is HUD presentation and target geometry only. Local evidence:
`.build/duo-hud-native/` and `.build/duo-hud-geometry-*-final.log`.

Inner-display follow-up, 30 October: `IMG_7966.jpg` and `IMG_7967.jpg` show
one continuous opened screen in portrait and landscape. The earlier synthetic
bitmap checks did not establish a physical corner match. The live iOS 26+ Duo
HUD now uses a native concentric outline and continuous UIKit mask over that
whole screen. It no longer redraws system radii as circular bitmap arcs. Actual
corner changes invalidate the cached mask, while identical geometry reuses it.
Native outline drawing is restricted to the header and deck; it adds no action
and does not frame the playfield. TV and ordinary phone/iPad rendering retain
their existing path, with no new TV effects.

The adaptive landscape deck removes gaps around tracking and Nuke. Tracking
fills the minimap's complete row height; Menu uses the same leading position
on inner and outer Duo displays. Six larger inner-screen fixtures across
Classic/L2/L3 supplement the compact grid checks, including shared row bounds,
Nuke adjacency and individually retained action targets. Bitmap fixtures check
layout; they cannot validate UIKit's device-resolved continuous mask. The
physical inner display, both rotations and cold-launch snapshot remain device
acceptance checks. Supported NeoLemmix retains the shared shell; its content
was not separately replayed. See [loading performance](LoadingPerformance.md)
for the explicit iOS launch storyboard and full-package build blocker.

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

## Saved Hot Seat discovery — 30 October 2026

Mac, iPhone, iPad, Duo and Apple TV list retained Hot Seats independently of
the selected solo player. Opening the saved-session list does not select a
different campaign; Resume restores the chosen session's host, roster, rule
and next turn. Mobile/TV rows include saved dates to distinguish campaigns
with the same players. Participant-scoped automatic Hot Seat selection and
journey lookup remain separate from this library-wide browser.

Mac also captures a legacy single-session pointer when its history entry is
missing, before another campaign replaces that pointer. This keeps the roster
available to the shared sync coordinator. Production saves were inspected
read-only during this correction; no recovery repair or service write ran.

Forty-five muted, offscreen checks pass: 32 cloud-library checks, one legacy
pointer regression, 11 mobile Hot Seat checks and one shared page render check.
Isolated saves cover cross-device import, an unrelated selected player, two
campaigns with the same roster, switching, next-turn retention, reopen and
offline/reconnect. The journey fixture retains Classic/L2/L3/NeoLemmix queue
identities and position; it does not run those engines or extend the separately
documented mobile journey loader. Five windowless page renders check the two
resume targets and Back at phone, Duo, iPad and TV sizes; representative images
were inspected. All eight shared modules and both application entry points
compile against the iOS and tvOS simulator SDKs; the recorded inputs match
the changed saved-session sources. Evidence: `.build/saved-hot-seat-tests.log`,
`.build/saved-hot-seat-ios-sdk.log`, `.build/saved-hot-seat-tvos-sdk.log` and
`.build/saved-hot-seats/renders/`. Physical touch, Siri Remote focus and live
provider delivery remain acceptance checks. Mid-level checkpoints remain local.

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

Home entry updated 30 October: Mac and the shared iPhone/iPad/Duo/TV frontend
always show one primary Start Journey / Resume Journey (current level/total)
action for the selected session. Hot Seat, unrelated checkpoints, other playlists
and another session's active queue no longer suppress it. Journey activation uses
the existing level/paused Ready flow directly. Separate ordinary saves retain
their own resume controls. Starting the route retains the selected solo or Hot
Seat identity; viewing Home does not switch sessions.

Mobile/TV can resolve a cloud Journey snapshot without a local learning file and
recover legacy archived queues without reviving completed journeys. Mac migrates
an older snapshot imported after store initialisation before looking up the route.
This retains the existing Classic-only mobile Journey loader: identity tests for
L2, L3 and NeoLemmix do not establish route playback support for those engines.
Live EKV v UVA service propagation and physical-device acceptance remain open.

Validation for this update: five focused mobile persistence checks and 34 shared
Journey/cloud checks pass with isolated saves and muted audio. The source checks
include reopen, archived queues, cloud-only queues, turn retention, completion
markers, unrelated-route retention and offline/reconnect merges. The shared Home
renderer passes 120 layouts and 40 bitmap renders, including input bounds and one
primary Journey action. iOS and tvOS SDK modules and app entry points compile.
The Mac Journey integration executable compiles, but its offscreen run aborts
inside macOS `_RegisterApplication` during `NSApplication` initialisation, before
test execution. Native AppKit event delivery and runtime acceptance are therefore
blocked in this environment; no foreground fallback was used. The broader mobile
navigation audit also stops on an existing career-page target assertion before
rendering; the focused `--journey-home` check passes independently.

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

Portrait iOS What's new presents its measured page, navigation and input targets
without waiting for background scenery or foreground-activation callbacks.
The previous unbounded reveal gate could leave all portrait menu controls
invisible and disabled while scenery was pending. Scenery completion no longer
forces a page layout. Pose observation starts during appearance preparation,
with a post-attachment fallback; later scenery refreshes retain the visible
page and its scroll position. This shared library presentation applies to
Classic, L2, L3 and supported NeoLemmix scenery. Mac and TV had no portrait reveal
gate. The reported Duo launch white screen has not been reproduced here. First-frame
UIKit compositing and physical Duo hinge callback timing remain device checks;
CoreSimulator service access is unavailable in this environment.
After removing the gate, the shared UI module compiles against both the iOS and
tvOS simulator SDKs, and the iOS application entry point type-checks. Evidence:
`.build/duo-launch-fix/ios/compile.log`,
`.build/duo-launch-fix/tvos/compile.log` and
`.build/duo-launch-fix/ios/entrypoint.log`. Device diagnostics could not be read:
CoreDeviceService initialization timed out. No app was installed or launched,
and native rendered/input acceptance remains open. Engine suites and release
audits were skipped for this presentation-only correction.

The 30 October startup change supplies a black iOS system launch surface with
the shipped logo and black iOS/TV windows. Shared iPhone, iPad, Duo and TV
startup shows a lightweight pixel logo/hourglass before constructing the
disk-backed library controller. Catalogue discovery transfers from the shared
background preparation worker. The normal TV path keeps its save migration;
iOS queues widget Desk Clock links until the library exists. Classic, L2, L3
and supported NeoLemmix share this app-level path. Mac and the explicit-source
TV diagnostic shell retain their existing startup. Final iOS/tvOS SDK modules
and application entry points compile. Seven windowless bitmap fixtures check
safe panes and separated artwork, including opened/folded Duo, with no action
targets. The off-main worker probe retains the archived app's 535 fan packs.
These are source and bitmap checks: physical cold-launch timing, native launch
composition, animation and widget delivery remain open. See
[loading performance](LoadingPerformance.md#first-visible-screen--30-october-2026).

The iOS SDK module and application-entry compilation pass, as does the shared
UIKit source check against the tvOS SDK. Nine muted,
windowless reading fixtures cover phone, Duo and iPad portrait sizes at the
top, middle and bottom, with fixed navigation hit tests and 44-point targets;
representative captures were inspected. These artwork fixtures do not exercise
the asynchronous UIKit reveal lifecycle. Engine suites were skipped for this
presentation-only change.

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

## Paused lemming hover identity — 29 October 2026

The shared UIKit gameplay controller now shows the aimed-at lemming's stable
name and complete two-line assessment while in a planning pause, with Inspect
while paused enabled. Classic, L2 and L3 use their existing inspection records.
TV remote/gamepad precision aim and iOS pointer/controller aim share the card;
touch retains its existing loupe and full inspection page. The passive bitmap
card sits opposite the pointer within a free playfield region, outside the HUD,
and receives no input. Resume, menus, Ready, read-only replay, fan mode and tool
direction selection hide it. Inspection records are cached for the paused tick;
running physics never reconstructs inspection history for hover. Neo individual
identity remains the separately documented source gap.

Both Apple SDK module builds and application entry points pass. The final shared
card renderer passes 1,280 muted offscreen renders: all 128 frozen stories,
five phone/tablet/720p/1080p/4K viewports and both pointer sides. Checks cover
text bounds, viewport containment, separation and pointer clearance; sample phone
and TV bitmaps were visually reviewed. Source inspection confirms the UIKit
view disables user interaction. These checks do not establish native UIKit hit
testing, Siri Remote/controller delivery, VoiceOver or physical TV readability.
Engine suites and release audits were skipped for this presentation-only change.

## Performance follow-up — 29 October 2026

Shared mobile/TV source now caches unchanged HUD and terrain work, avoids a
synchronous PCM-worker query during rewind, and uses bounded native-density flat
funeral composition. L2/L3/Neo live history retains sparse older snapshots within
its entry limit; saved action replay seeks reuse that history before reconstructing
from the start. Shared audio changes also apply to Mac. The native Mac rendering
and movie-composition paths were not replaced. See `RuntimePerformance.md` for
remaining architectural work and validation limits. Physical input, sustained
vari-speed, memory, thermal and mixed audible playback acceptance remain open.

Validation for this follow-up: the TV SDK modules and application entry point
compile; final shared iOS/tvOS UI sources typecheck against their simulator SDKs.
Focused native terrain/rewind/parity checks pass, including a 2,200-tick sparse
history comparison with independently reconstructed states. Opaque funeral pixel
composition passes offscreen and muted; no headless Metal device was available.
Audio performance programs compile, but runtime audio-unit creation failed, so
this is source validation and does not close audible playback acceptance.

### Viewport, input and PCM continuation — 29 October 2026

The shared iPhone/iPad/Duo/TV controller polls input at up to 60 Hz independently
of its 30/20 Hz scene budget. Pointer, touch selection and skill changes reuse
the current scene while its tick and camera coverage remain valid; controller
render requests coalesce. TV pointer movement and target cycling use that path.
Button event callbacks and existing targets remain intact.

Classic/L2/L3 and supported NeoLemmix scenes compose a tile-aligned viewport with
a guard band at their native artwork scale. The minimap uses a separate bounded
terrain thumbnail and live actor points. CRT preparation caches the camera scene
separately from overlays. L2 converts changed terrain colours incrementally;
dirty detection still scans its indexed terrain. Classic reduced-colour output
uses a lookup table over the composed viewport. Mac continues to use its current
full-scene presentation; it shares the audio and memory policy changes.

Rewind, held rewind, backward steps, replay move navigation and completed-replay
restart use private seek work with a 2 ms slice target. Cancellation discards that
work; only a complete reconstruction updates the session. One tick, initial
checkpoint/factory preparation or commit can exceed that target. Rewind and step
history are retained through command reconstruction and sparse acceleration.

The effects worker owns playback positions and reserved rescue-layer storage.
Bounded per-voice commands/status replace the shared control/library lock in the
production PCM path. Control-side voice reconciliation and retired-command cleanup
occur outside the handoff lock. The rewind history copy still has its own bounded
lock. This reduces contention without establishing the crackling cause or cure.

Optional terrain caches share an admission limit; checkpoint density responds to
memory availability and pressure. Sampled process footprint and sampled peak are
available through Points of Interest. These are not a hard process-memory ceiling:
native artwork, current images, GPU surfaces and snapshot copy-on-write still add
memory. TV retains its existing effects limits and gains no extra HDR surface.

Focused validation and remaining hardware acceptance are recorded in
`RuntimePerformance.md`. Physical input latency, sustained speed/frame delivery,
thermal behaviour, peak memory and audible mixed playback remain device checks.

## Viewport and input performance — 29 October 2026

The shared UIKit controller now separates input cadence from adaptive scene
presentation, reuses scene pixels for pointer/selection updates, and requests
viewport composition for Classic, L2, L3 and supported NeoLemmix. Sharp native/Mac
artwork, target states, world-space input mapping, ghosts and TV's effects budget
remain intact. Minimap scenery is sampled independently of current lemming positions.
CRT native scene caching, cropped pause previews and cropped loupe countdowns use
the same camera coordinates. Rewind and replay navigation reconstruct privately
in cancellable slices, including exact same-tick commands and assistance counts.

Shared effects PCM ownership and heavy pixel-cache budgets also apply to Mac.
Native Mac scene composition and synchronous seek callers remain separate paths.
No saved-run format, player ownership, Hot Seat handover or production save location
changed. Focused checks use isolated temporary saves. The current evidence and
remaining source/measurement limits are in `RuntimePerformance.md` under
“Viewport, input and audio worker optimisation”. Physical touch, Siri Remote,
VoiceOver, sustained thermal performance and audible playback remain device
acceptance; source compilation and headless pixel checks do not close them.

Source validation for this follow-up: all eight shared/application UI modules
compile against both simulator SDKs, with final controller primary-file checks
on each platform. Thirty-three focused engine/render tests, the standalone Classic
rewind suite and the engine-free audio worker-state checks pass. Full offline audio
execution remains blocked by audio-unit creation in this environment. No hosted
service, physical-device or audible acceptance is inferred from these results.

### Home audio ownership — 30 October 2026

The shared iPhone/iPad/Duo/Apple TV frontend now activates the Home music session
before playback and prevents outgoing game controllers from deactivating it or
applying stale pause/pitch state. This shared handover covers Classic, L2, L3 and
supported NeoLemmix routes. Soundtrack-name caching is invalidated on optional
library download/removal. Mac uses its existing desktop audio lifecycle and does
not use `AVAudioSession`; it is unchanged by this mobile session fix.

Silent, headless session ownership/order checks pass. iOS/tvOS SDK modules and
application entry points compile, including a final pass over the changed audio
frontend sources. Physical-device listening, Duo folding, interruptions,
output-route changes and sustained music acceptance
remain open. See `RuntimePerformance.md`, “Phone Home Screen, Duo folding and
menu handover”.

### Phone background audio and Duo folding — 30 October 2026

The shared iPhone/iPad/Duo/Apple TV frontend overrides menu spin-down when the
application enters the background, immediately parks music graphs and invalidates
pending session activations. Background requests cannot activate or configure the
session. Foreground entry grants permission without resuming a game itself.

The previous menu inactivity grace becomes a 120 ms spin-down without a reverb
tail, followed by existing spin-up on reactivation. Tracker playback includes its
existing PCM reserve before the short brake reaches the output. Pending cleanup
is cancelled on rapid fold/unfold. Menu suspension precedes scene layout work.
This menu path is shared across Classic, L2, L3 and supported NeoLemmix routes;
gameplay retains immediate suspension and player-driven Resume. Mac uses the
existing desktop lifecycle and default pause timing; the new short-brake API is
optional. The TV effects budget is unchanged.

Silent, headless session checks pass for background/foreground, activation races,
overlapping owners and rapid fold reactivation. iOS/tvOS SDK modules and app entry
points compile, as do the native audio performance and DJ programs. The muted,
offscreen offline run aborts during `AVAudioUnitEQ` creation (`comp != nullptr`),
before transport assertions execute. Installed-device listening,
actual background timing and Duo folding acceptance remain open. Recording
brakes still use main-actor rate/gain updates; this is not evidence that a blocked
UI thread can sustain the ramp. See `RuntimePerformance.md`, “Phone Home Screen,
Duo folding and menu handover”.
