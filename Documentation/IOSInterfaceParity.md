# iOS and Mac interface parity

The 2.0 iOS release must preserve the Mac app's artwork, navigation and shared
features across Classic, Lemmings 2 and Lemmings 3. Touch layout may adapt the
presentation, but it must not silently drop actions or bypass player-ready
boundaries. A Classic device beta does not establish three-game parity.

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
| Profiles and Hot Seat | Not ported | Rosters, turn ownership and paused Ready handovers for each engine |
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
