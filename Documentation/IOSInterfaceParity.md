# iOS and Mac interface parity

The 2.0 iOS release must preserve the Mac app's artwork, navigation and shared
features across Classic, Lemmings 2 and Lemmings 3. Touch layout may adapt the
presentation, but it must not silently drop actions or bypass player-ready
boundaries. A Classic device beta does not establish three-game parity.

## Current Classic port source

The 13 October source implements the Classic scope in the
[iPad feature parity plan](IPadFeatureParityPlan.md). Lemmings 2 and Lemmings 3
mobile campaigns and renderers remain owner-deferred. NeoLemmix remains a
separate engine decision. These exclusions do not establish three-game parity.

| Feature | Current source |
| --- | --- |
| Settings | Seven bitmap groups, preset and individual choices, controller mapping, legacy-key migration and accessibility preferences |
| Profiles and career | Stable profile IDs, original portraits, records, assisted boards, level and career achievements, ordered campaign trophies and level skips |
| Collections | Shared authoritative playlist store with mobile adapters; legacy favourites, recents, playlist order, run position and shuffle seed retained |
| Rewind and replay | Backward/forward step, held rewind, saved rewind history, read-only review with the last three successful skill uses and their ticks, verified solutions, cancellable movie export with offline effect audio |
| Teaching | Progressive hints, bundled learning journey with saved solo/Hot Seat lookup, revisit/defer progress, shared source revisions and real progression-policy analysis |
| Hot Seat | Attempt-owner records, scoped checkpoints, paused Ready pages, transactional turn saves and duplicate transition guards |
| Online | Shared Game Center IDs and score rules, iOS authentication adapter, hosted board consent, worldwide pages and verified action replay loading |
| Input | Shared command data, keyboard discovery and presses including Command+Z step back, controller remapping/aim/pan/tap/hold speed, page focus/scrolling and pointer targeting |
| Presentation | Original DOS, Mac and Amiga Classic artwork, shared CRT shaders, selection/assignment/explosion effects, calmer sprite rescue auras and shared cached scenery haze, failure transitions and result stars |
| Audio | Shared Adaptive DJ and recording/module decks, pause rhythm, speed pitch, failure/nuke recovery, retry brake, positional effects, chimes and now-playing notices |
| Information | What's New, explicit effects welcome, anonymous count consent, real local/shared Play Insights and background fan-count measurement |

Storage errors block result continuation and turn changes. Earlier Classic
checkpoints restore their exact current tick and lemming states; a checkpoint
from before rewind history was stored can rewind only from its restored state.
The owner of a solo checkpoint and the scope of a Hot Seat checkpoint determine
which saved run is resumed. Older formats and unsupported future checkpoint
versions are retained.

Migrated mobile collection identities retain their original mobile pack keys and
`mobile-v1` revision. The shared store preserves their order and ownership; this
adapter does not convert historical mobile entries into the Mac catalogue's
source-revision identity. Curated journeys use the verified Mac catalogue
identities and bundle source-revision metadata.

Game Center still requires the owner's iOS App Store Connect app record and
production configuration. The capability and entitlement are present; no account
or leaderboard configuration was changed. Downloads retain their existing
foreground-only lifecycle. The compact touch deck retains its current grouped
controls; a dedicated one-thumb edge layout remains a separate adaptive UI item.

Source verification and remaining device checks are recorded in
[Classic port evidence](ReleaseReadiness/2.0IOSParity-2026-10-12/README.md).
UIKit event delivery, VoiceOver, physical keyboard/controller/pointer, EDR/CRT,
Duo, live sign-in/download/share and audible playback need the owner's installed
candidate. Headless captures verify bitmap drawing and target geometry only.
Automated checks remain offscreen and muted.

## Latest Mac fixes, 13 October 2026

The iOS source includes the applicable Classic fixes from published macOS 1.9.4
(commit `bdb7ba5b`). Shared learning version 18, progression version 4 and the
295-lesson catalogue are bundled. Saved journeys retain their original queue,
position, progress, profile and Hot Seat turn. Resuming a different saved scope
restores its matching checkpoint and retains the previous scope's save.

The replay panel displays the last three successful uses and their exact ticks.
Seeking updates that history. Remaining stock stays in the existing HUD.
Command+Z steps back without changing plain Z zoom or intercepting system chords.
Rescue effects reuse the Mac's calmer sprite masks and bounded, asynchronous
scenery cache. Reduced flashes and HD effect choices still govern sprite auras.
The full-rescue music behaviour and Show Song Info setting already share Mac logic.

Sparkle updates and the fading floating Mac Menu button are platform-specific.
The iOS hamburger Menu control stays at the top right of the touch deck. L2/L3 mobile campaigns
and renderers remain deferred. Their Mac cache fixes do not establish an iOS port.
See [current verification](ReleaseReadiness/2.0IOSCurrent-2026-10-13/README.md)
and [iOS Game Center preparation](GameCenterSetup.md#ios-20-preparation).

## 13 October bomb and nuke countdowns

Classic iOS draws white, bold system 5–4–3–2–1 digits above each lemming for
both assigned bombs and nukes. The font and size relative to zoom match Mac.
One transparent view draws all digits at native Retina resolution, outside the
low-resolution scene and CRT texture. It follows the sprite's top edge, camera,
pixel aspect and curved CRT projection. The touch magnifier uses the same text.
All paths use the simulation's remaining fuse ticks, so pause, rewind,
checkpoint restore and nuke undo preserve the countdown. The view passes all
gameplay input through. Game artwork and minimaps retain their original resolution.

The muted headless regression checks every fuse tick across six combinations
of artwork and bomb/nuke assignment. It verifies each digit and sprite anchor,
removal when the fuse ends, rewind, checkpoint restore and nuke undo.
`Scripts/run-bomb-countdown-tests.sh` checks native text at 1×/2×/3× backing
scale and fractional zoom, fixed digit widths, expiry and camera input mapping.
It exports native-resolution previews for all five digits with DOS, Macintosh
and Amiga artwork. Physical-device gameplay, UIKit text appearance and CRT
acceptance remain pending.

Lemmings 2 uses its native `bombTicks` and `COUNTDOWN` sprites on Mac. Lemmings 3
shows remaining fuse time above thrown explosives and ends runs with abort,
without a nuke countdown. Both sequel iOS renderers and campaigns remain
owner-deferred. This Classic fix does not establish playable sequel parity.

## 13 October touch controls and camera

Fresh runs and retries centre the first entrance and fit the level height to the
playfield viewport. The shared camera supports Classic, L2 and L3 entrance
positions. Saved runs retain their existing resume and paused handover behaviour. Level
edges clamp entrance centring, and the existing maximum zoom still applies.

Portrait and landscape reuse the same controls and input handlers. Portrait
skills occupy an 80-point row. Narrow phones and larger skill
sets scroll horizontally with 44-point targets. A 48-point bottom row places
one continuous minus/rate/plus socket beside speed, nuke/undo and pause/play.
Engines without a release rate omit that socket. Rewind and backward/forward
tick controls stay visible to the left of the 44-point minimap, above skills.
Only engines that support rewind receive backward controls. Forward tick remains
dimmed and disabled while running.

Landscape places skills, the rate socket, speed, nuke/undo and pause/play in
one 80-point row. The navigation/map row stays above it. This reduces the deck
from 176 to 126 points and gives the playfield 50 more points of height.
The speed pedal uses a fast-forward glyph between its multiplier and HOLD cue.
Crowded skill banks scroll within their own clipped input region. Fixed transport
controls remain visible outside it. The 844×390 phone capture includes both
47-point side insets and the 21-point bottom inset.

The 44-point top strip keeps quantities and the pixel hamburger Menu inside the
safe area. Its background extends across the screen and under the top inset.
The top and bottom controls share the safe area's left and right edges, without
extra outer margins. The playfield occupies the space between the strips, so
map and HUD input cannot assign skills through them. Essential counters remain
below the Dynamic Island, following Apple's safe-area guidance. Hot Seat Ready
handovers remain paused until the player acts.

Tap speed to toggle the chosen fast tier. Its compact HOLD cue identifies the
pedal: hold to boost temporarily, then release to return to the chosen tier.
Rate buttons repeat while held. Nuke keeps two-tap confirmation and a 0.6-second
hold. Its active state shows Undo. Tap pause/play to toggle planning, or hold
for 0.6 seconds to open the pause menu. VoiceOver retains a separate Pause menu
action and names the speed pedal's tap and hold behaviour. Leaving a target,
changing layouts, opening a menu or losing the window cancels held input.

Validation: the unsigned iOS device build passes. Twenty-one focused, offscreen,
muted checks pass for camera framing, entrance positions, rotation, Classic/L2/L3
control sets, input timing, bitmap/touch alignment and worker-owned level preparation.
The bitmap audit passes 60 HUD states and 18 DOS/Mac/Amiga artwork states, including target sizes,
non-overlap, reserved-region avoidance and scroll reachability. Phone ready,
fast and undo captures and iPad landscape running captures were inspected.
Captures and logs stay in ignored `.build/ios-hud-feedback-*` and
`.build/ios-landscape-performance-*` paths.
An initial broad test selection stalled and was stopped; its incomplete run
is not counted as a pass.

The shared controls serve sequel session adapters, but playable L2/L3 mobile
libraries and native renderers remain deferred. UIKit gesture delivery,
VoiceOver and physical Dynamic Island devices still need installed-device
acceptance. Cramped windows and system divisions/occlusions retain the adaptive
fallback. These checks do not establish a complete L2/L3 iOS port.

## Earlier build and source increments

The dated notes below describe the state at each earlier increment. Open items
in those notes are historical; use the current matrix and evidence above for the
present source.

Build 8 introduces shared bitmap page drawing for the iOS title screen, rank
and level preview, briefing, pause, result and data/settings pages. It reuses
`GameMenuTypography`, `GameMenuFrameArt` and `GameStoneArt`. UIKit controls use
the renderer's exact target rectangles and retain accessibility names.

| Mac journey | iOS build 8 | Remaining work |
| --- | --- | --- |
| Title screen and resume | Original logo, bitmap fonts, selected row, saved-run action, Classic progress | Player/profile selection and all content families |
| Level browser | Focused Classic preview, rank pairs, level pairs, swipe navigation, Play | Cover-flow cards, favourites, filters, locks and collection journeys |
| Briefing and ready | Bitmap page, level totals and time, preview, explicit Start | Engine-specific L2/L3 briefings and campaigns |
| Gameplay planning | Classic touch targeting, pan, anchored pinch, loupe, pause-on-skill default, step and explicit resume | Full Mac QoL and physical input acceptance across all engines |
| Saved run | Shared validated checkpoint envelope, paused restore, run retirement | Complete cross-engine navigation and profile integration |
| Retry and continue | Game child replacement keeps the front-end transition inside gameplay | L2/L3 campaign carry-over and final-level policies |
| Results | Bitmap page, saved/required counts, next/retry/library | Mac celebrations, achievements, trophies, records and engine-specific outcomes |
| Settings | Persistent pause-to-assign and fast-speed controls | Full Mac settings groups, audio/music system and accessibility preferences |
| Game data | Offline Classic campaign and folder import | Native L2/L3 data libraries and rendering; approved release packaging |
| Profiles and Hot Seat | Classic family ported | Rosters, turn ownership and paused Ready handovers. L2 and L3 wait on their engines |
| Journey, collections, replays and hints | Not ported | Shared flows and their mobile input adapters |
| Controller-only navigation and Duo | Not accepted | Controller focus, reserved regions, adaptive poses and live-session continuity |

Lemmings 2 and Lemmings 3 home rows are visibly unavailable in build 8. Their
shared session/checkpoint tests do not mean that a mobile library or playable
campaign exists. Imported game folders remain a Classic-only path.

The shared renderer passes 66 headless page captures and target checks across
six iPad/phone geometries, including 320-point width, long titles, disabled
buttons, scroll reachability and gap hit rejection. This verifies the drawing
and geometric routing contract. It does not exercise UIKit event delivery,
VoiceOver focus or physical display/input behaviour. The AppKit offscreen UI
runner cannot validate UIKit. Keep these acceptance gaps open until the owner
has tested the installed candidate. No automatic foreground fallback is allowed.

Release evidence: [build 8](ReleaseReadiness/2.0DeviceBeta-2026-10-11/Build8/README.md).

The phased work to close the remaining gaps is in the
[iPad feature parity plan](IPadFeatureParityPlan.md).

## 12 October adaptive source increment

The source now keeps the Mac-style cover browser in both iPad orientations and
uses the original Classic panel where its sockets meet the 44-point touch
minimum. Compact views retain its pixel artwork in grouped targets. Speed input,
Menu lettering and the minimap use shared rendering and geometry.

Duo's availability-gated adapter reads system division and occlusion regions.
Fixed controls and scrolling pages avoid them. A horizontal division separates
level and console. Unfolding preserves zoom and camera centre and reveals more
of the same level. A brief native pixel walker celebrates menu unfolding only.
Small layouts pause the existing run and wait for an explicit Resume when space
returns. The shared controller retains the same engine session and owner.

24 core tests, 19 iOS tooling tests, 66 page captures, 40 HUD states, six cover
artwork states and three unfold frames pass headlessly and muted. The unsigned
iOS app compiles. The installed build 8 is unchanged. Native UIKit dispatch,
VoiceOver, composited cover layers and physical Duo acceptance remain open.
The compact deck still needs dedicated one-thumb edge controls. L2/L3 geometry
checks do not provide their missing native mobile libraries or renderers. Full
Mac feature parity, Hot Seat, settings and audio remain open.

See [adaptive source evidence](ReleaseReadiness/2.0AdaptiveUI-2026-10-12/README.md).

## 12 October content and soundtrack increment

The iOS library now plays every Classic-engine level that the Mac library
plays. The home page shows these families: Lemmings (120), Oh No! More Lemmings
(100), Holiday Lemmings (four packs), Oh Yes! More Lemmings! (60) and Fan
Lemmings (535 packs, 6,020 levels). A family with one pack opens its levels
directly. A family with more than one pack opens a pack list first. A saved run
reopens its own pack.

One reader serves both apps. `ZipArchive` decodes ZIP members without a system
tool. `ClassicFanPack` lists a pack, reads its levels, selects the per-pack
rules by archive hash and resolves its graphics. The Mac still uses its own
`unzip` path. A test compares the two readers on all 535 bundled packs: entries,
decoded levels, source rules, style folders and fingerprints match for each of
the 6,020 levels. A second test loads, renders and ticks every fan level and
every official level through the iOS path with no failure.

The iOS app is slim. It bundles the 54 essential tracker modules and the music
index (7.7 MB), the fan packs (5.6 MB) and the stock release folders that levels
borrow (2.2 MB). Soundtrack recordings are 18 optional libraries of 1 MB to 400
MB. Settings > Soundtrack libraries lists them. A library downloads over HTTPS,
and its size and hash are checked against the index. Each file is then written
by streaming, hashed and installed as a unit. Libraries stay out of device
backups. The Mac uses the same installer.

The tracker engine, the recording player, the vinyl stop and the library paths
moved into `LemmingsAudio`. The Mac and iOS import it. The three offline audio
test scripts follow the new file paths, and the nuke audio check passes. iOS
plays each level's assigned tune. The Soundtrack setting selects a downloaded
folder, and the matching recording replaces the module for the same composition.

Open items for this increment:

- Lemmings 2 and Lemmings 3 still need native mobile renderers and campaigns.
- Fan pack updates from the community catalogue are not connected on iOS.
- Favourites, search, collections and playlists are not ported.
- The adaptive DJ, pause rhythm and variable-speed pitch are not connected on iOS.
- Downloads run only while the app is in the foreground.
- A live download, recording playback and listening acceptance need a device.
- The slim build needs the music source tree at build time. Without it the app is silent.

## 12 October browser increment

Fan Lemmings has a Search row. The row uses the bitmap font, and the system
keyboard supplies the text. Typing narrows the pack list at once. A pack row
shows its passed count. A Check for new packs row asks the community catalogue
for packs that are not installed. It installs a pack only when its archive
validates and holds at least one level. It never replaces an installed pack.
The updater is shared code, and a test drives it with a fake network.

Every level page has a Favourite action. A starred level stays starred when its
pack gains or loses other levels. The home page shows a Favourites row when at
least one level is starred. Favourites play in their own pack's session. Their
passed marks and saved runs belong to that pack. The wide level browser has the
same action. A lone last action in a page footer now spans the full row.

Open items: collections, playlists, filters by status and the Mac's own
level-count measuring are not ported. The Mac keeps its own `unzip`-based
updater. The two updaters share one rule set by test, not by code.

## 12 October collections and playlists increment

The home page has a Collections row. Collections holds Favourites, Recently
played and Playlists. Recently played keeps the latest 50 distinct levels,
newest first, and a replay moves its level to the front.

A playlist is an ordered list of levels from any packs. The editor can rename,
reorder, remove and delete. Delete asks for a second tap. A level page can add
its level to a playlist or make a new one. Random 10 makes a playlist of ten
distinct levels from the open pack.

Play runs a playlist in order. Shuffle runs it in a repeatable random order that
the app stores with its seed, so a relaunch resumes the same sequence. A run
saves its position when each level starts. A Resume row appears on the home page
and in Collections until the run ends or its playlist is deleted. Playlist results
do not advance pack progress. An entry whose pack or level is gone stays visible,
and it blocks Play until it is removed. Tests cover the stores, the shuffle and
the saved run. The favourites, recents and playlists share one list library.

Open items: Hot Seat turn ownership does not apply yet.

## 12 October profiles and shuffle increment

Shuffle all on the Fan page counts the installed fan levels away from the main
thread, then Start runs every level once in a repeatable random order. The run
resumes from the home page like a playlist. A long list shows its titles without
opening each pack. A pack is opened when its level is selected.

The level browser shows a Playlist action beside Favourite at every size.

Settings has a Player row. A player has their own progress, favourites, recents
and playlists. A new player starts empty, and the first player keeps the keys
from earlier builds. The page can switch, add, rename and delete players, up to
eight. Delete asks for a second tap.

New player opens initials entry after navigation completes. Tapping Initials in
the editor reopens the keyboard. Initials entry disables autocorrection, spell
checking and inline predictions. The shared Players page also serves Hot Seat
and all three game engines. Headless renders verify the editor artwork and touch
targets. The iOS UI target compiles. Keyboard presentation on a device remains
unverified because these checks run without a foreground window.

Older GPUs and two-core devices cap display updates at 30 Hz. Their CRT output
uses one pixel per point and SDR, while simulation keeps its authored tick rate.
Classic caches terrain between edits and retains animated objects and sprites.
Digging, construction, rewind, nuke undo, restore and artwork changes invalidate
the cache. Static panel artwork is reused.

Classic, Lemmings 2 and Lemmings 3 capture immutable checkpoint values before
background encoding. The shared controller orders saves and limits concurrent
autosaves. Music reuses settings and avoids unchanged pitch updates. Audio asks
for a 1,024-frame buffer at 44.1 kHz to reduce callback overhead.

A windowless host check of Just Dig reduced average simulation and DOS rendering
from 24.5 ms to 3.5 ms. Snapshot capture took about 0.005 ms instead of synchronous
encoding at 35 ms. These are Mac debug measurements, not iPad frame rates.
Muted checks cover captured digging state, sequel checkpoint replay, saved-run
ownership, authored tick timing, native artwork, cache invalidation and bitmap
camera input. Sustained first-generation iPad GPU performance and audible output
remain device validation gaps.

The mobile home page follows the Mac order: saved runs, Oh My! All Lemmings!,
Classic, Oh No, Holiday, Oh Yes, Fan, NeoLemmix, Lemmings 2, Lemmings 3 and
Collections. Settings and release notes sit beside the logo. Initials, Profiles,
Records and Playlists form the footer. Narrow screens wrap footer actions and
scroll while retaining complete action names and 44-point targets. Game Data is
under Settings; Achievements is under Records. Hot Seat setup is available from
Profiles, including before the first session, without changing session ownership
or handover timing.

Release-rate minus and plus use the desktop stone sockets and bitmap symbols.
Portrait puts their shared value between them in the transport row below skills.
Landscape retains adjacent rate buttons with counts above them. The shared renderer covers all mobile engines that expose a
release rate; L2 and L3 currently expose none and retain their own controls.
Their home entries and NeoLemmix remain visibly unavailable on iOS.

Muted, windowless checks pass 264 menu renders, 40 HUD states, six native-art HUD
states, footer caption widths, action order, rate-button placement and input
targets. Phone and iPad home and HUD exports were inspected. The iOS UI target
compiles. Physical UIKit input and gameplay with the sequel engines remain
manual validation gaps.

The app writes favourites, recents and playlists through one store. Each write is
atomic and keeps the previous copy as a backup. A file that cannot be read is kept
under a new name and the store starts empty. Tests cover the store, the legacy
import and the fan pool.

Open items: The Mac playlist file keeps revisions. The iOS store keeps one backup.

## 12 October Hot Seat increment

Profiles has a Hot Seat row. The page lists the players as tiles. A tap adds or
removes a player, and the host always stays. New player adds a profile to the
roster. Choose a game needs two players. Turns sets the house rule, Every level or
At first fail. A running session adds New Hot Seat, which asks for a second tap,
and Return to solo. Saved Hot Seats lists earlier sessions of the host.

The shared campaign keeps its progress apart from every solo player. The roster,
the turn and the rule survive a relaunch. A new session starts with the host.
Switching or deleting a player leaves sessions that need them.

A Ready page names the player who acts next. Play stays paused until Ready. The
same page returns after a relaunch and after a checkpoint restore. The Classic
HUD shows the attempt owner. A result page names the player on each button, and
the results table matches the Mac. Leaving by Library after a result passes the
turn by the house rule.

A saved level keeps its session and owner. In another session the home page
shows Resume Hot Seat run or Resume solo run instead of loading it, and the run
stays saved. Tests cover the roster, turns, results, saved sessions and the old
checkpoint format.

Open items: L2 and L3 have no iOS engine yet. A playlist or shuffle run continues
the open session and does not offer New solo or New Hot Seat. Level skips,
per-player scores and achievements have no iOS counterpart. Mid-level takeovers
stay deferred, as on the Mac. The Ready page after a return from the background
uses the existing pause page and has no device test.

## 13 October Hot Seat profile entry

The Players page always offers Hot Seat outside the initials editor. The previous
active-session-only row prevented a first session from starting. Setup initializes
its roster on entry, keeps the host selected, and returns to the originating page
with Back. Adding a guest retains the draft roster. New player is the primary
action when the device has only one profile. Choose a game becomes primary once
two players are selected. Starting, restarting, resuming or leaving a session
keeps setup visible when the local save fails.

The app and windowless audit use the same profile and Hot Seat page composer,
stone controls, bitmap fonts and portraits. Focused checks cover five screen
sizes and eleven states, including one profile, unselected guests, a ready
roster, active/saved sessions, restart confirmation, the initials editor and the
full eight-player roster. Touch targets remain at least 44 points and do not
intersect. All 55 renders and input-target checks pass, and the rendered states
were inspected. All 13 mobile roster, turn and Learning Journey checks pass.
The offscreen Mac session suite passes profile-to-session navigation, Ready
handovers, adding players and failed-save guards. Its desktop-focus check after
Retry is skipped in offscreen mode. All three Mac engines block play while the Ready page is
presented. Native L2/L3 gameplay on iOS remains unavailable. Physical UIKit taps,
keyboard-to-setup transitions and full native sequel session round trips still
need device validation.

## 13 October portrait layout follow-up

The latest Xcode device build links the two-row portrait HUD from this repository.
The layout previously fell back to the compact grid whenever UIKit reported any
reserved region. Portrait now stays active when that region lies outside the
safe area or only covers the playfield. The playfield still blocks input in that
region. Divisions and regions covering the controls, menu, minimap, status or
tick drawer retain the adaptive fallback.

Debug builds print a `[MobileHUD]` line when the layout changes, with its mode,
view bounds, safe insets, control frame and reserved regions. This provides the
runtime geometry needed to diagnose a device still showing the compact grid.
Thirteen focused layout and gesture checks pass, including both original iPad
Pro sizes and rotation. Ten muted, windowless HUD renders pass their input-target
checks; the original iPad and expanded tick-drawer states were inspected. The
iOS UI target compiles. The full unsigned Xcode project build could not resolve
packages: after reusing cached Sparkle, Xcode still required a manifest cache
outside the writable sandbox. Device inspection timed out in CoreDeviceService.
These checks do not establish the cause on the reported device: its model,
window geometry and runtime layout remain unconfirmed.

## 13 October precision hover selection

Mouse, trackpad and Pencil targeting use the Mac engines' level-space pick boxes.
Classic uses its narrow sprite box. L2 and L3 retain their native 9-by-12-pixel
half extents around their targeting centres. These boxes follow zoom and pixel
aspect. Finger taps keep their screen-space allowance and touch loupe.

Every camera change refreshes the target, including scrolling, minimap movement,
zoom and controller pan while paused. Hover retains its screen position and
recomputes the CRT input projection. Mouse-wheel and trackpad scrolling use a
scroll-only pan recognizer that can run alongside hover. Pencil contact can move
the target before release without panning or using the finger allowance.
Ready, interruption and result screens retain their existing input boundaries.

Validation: ten focused, muted, headless tests pass. They cover paused camera
movement, five zoom scales, pixel aspect, pick boundaries, empty terrain,
letterboxing, Pencil adjustment, finger panning, bitmap camera alignment and
planning assignments in all three engines. The arm64 iOS UI target compiles.
Three windowless Classic bitmap/selection captures were inspected at one fixed
simulation tick: first target, a different target after scrolling, and no target.
Logs and captures remain in ignored `.build/precision-selection-*` paths.

Native UIKit dispatch, physical Pencil hover, simultaneous trackpad hover and
scrolling, and curved CRT input still need an iPad check. L2/L3 tests cover their
shared session adapters and native pick bounds. Their iOS campaigns and renderers
remain deferred, so these checks do not establish playable sequel parity.

## 13 October in-play Hot Seat identity

Hot Seat keeps only the player’s name in a green bitmap row above the
HUD counters. Identity stays clear of terrain, notices and input targets.
It uses the attempt owner and has a full-name VoiceOver label. Solo play keeps
its existing HUD. Compact layouts reserve a second status row during Hot Seat.
Ready handovers remain paused.

All 32 windowless, muted render/target checks, 24 existing Hot Seat and layout
tests, and the unsigned arm64 iOS compilation pass. Rendered status states
were inspected. See [validation evidence](ReleaseReadiness/2.0HotSeatHUD-2026-10-13/README.md).
Physical UIKit input and VoiceOver still need device validation. L2 and L3
remain unavailable in the iOS library.
