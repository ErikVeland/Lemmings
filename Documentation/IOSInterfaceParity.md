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
