# iOS and Mac interface parity

The 2.0 iOS release must preserve the Mac app's artwork, navigation and shared
features across Classic, Lemmings 2 and Lemmings 3. Touch layout may adapt the
presentation, but it must not silently drop actions or bypass player-ready
boundaries. A Classic device beta does not establish three-game parity.

## Current Classic port source

The 12 October source implements the Classic scope in the
[iPad feature parity plan](IPadFeatureParityPlan.md). Lemmings 2 and Lemmings 3
mobile campaigns and renderers remain owner-deferred. NeoLemmix remains a
separate engine decision. These exclusions do not establish three-game parity.

| Feature | Current source |
| --- | --- |
| Settings | Seven bitmap groups, preset and individual choices, controller mapping, legacy-key migration and accessibility preferences |
| Profiles and career | Stable profile IDs, original portraits, records, assisted boards, level and career achievements, ordered campaign trophies and level skips |
| Collections | Shared authoritative playlist store with mobile adapters; legacy favourites, recents, playlist order, run position and shuffle seed retained |
| Rewind and replay | Backward/forward step, held rewind, saved rewind history, read-only review and verified solutions, cancellable movie export with offline effect audio |
| Teaching | Progressive hints, bundled learning journey, revisit/defer progress, shared source revisions and real progression-policy analysis |
| Hot Seat | Attempt-owner records, scoped checkpoints, paused Ready pages, transactional turn saves and duplicate transition guards |
| Online | Shared Game Center IDs and score rules, iOS authentication adapter, hosted board consent, worldwide pages and verified action replay loading |
| Input | Shared command data, keyboard discovery and presses, controller remapping/aim/pan/tap/hold speed, page focus/scrolling and pointer targeting |
| Presentation | Original DOS, Mac and Amiga Classic artwork, shared CRT shaders, selection/assignment/explosion effects, failure transitions and result stars |
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

The app writes favourites, recents and playlists through one store. Each write is
atomic and keeps the previous copy as a backup. A file that cannot be read is kept
under a new name and the store starts empty. Tests cover the store, the legacy
import and the fan pool.

Open items: The Mac playlist file keeps revisions. The iOS store keeps one backup.

## 12 October Hot Seat increment

Settings has a Hot Seat row. The page lists the players as tiles. A tap adds or
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
