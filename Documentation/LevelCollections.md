# Level collections

Open Collections from Play or the Level Select pack browser.
Favourites contains bookmarked levels. Recently Played contains the latest
50 distinct levels, newest first. Replaying a level moves it to the front.

## Starter playlists

Open Playlists to find curated routes for the game data you have installed.

| Playlist | Levels |
| --- | --- |
| First Shift | Classic Fun 1–3. Dig, float and block. |
| Permit to Build | Classic Fun 5 and 7, then Oh No! Tame 14. Bash and build. |
| Below Street Level | Oh No! Tame 4, 6, 10 and 17. Bash and mine. |
| Open Starter | Three project-authored levels from Ultimate Lemmix. |
| The Tame Shift | All 20 Tame levels from Oh No! More Lemmings. |
| Holiday Fun | Four Xmas levels each from 1991 and 1992, 16 Flurry levels from 1993, and 16 Frost levels from 1994. |

Holiday Fun follows release order. Its 40 puzzles cover each game's first
rank and vary in difficulty. Each preset needs every level in its route.
Starting a preset creates a resumable run with a fixed level order.

## Personal collections

The Favourite control uses the shared stone button and pixel star. An outlined
star means unsaved. A filled star means saved. Level Select and results both
provide this control. Collections use the existing level carousel and guarded
launch routes. Start opens a new attempt. Resume retains its checkpoint meaning.

Collections belong to the player taking the turn. A result bookmark belongs to
its attempt owner even when Hot Seat has queued a different player. Campaign,
fan-pack, NeoLemmix-pack, L2 and L3 levels use their typed catalogue identities.
L2 practice scenes and standalone NeoLemmix files have no catalogue route and
remain outside these collections. Collection entries grant no progress or unlocks.
Missing or changed sources remain visible and cannot start through a shortcut.

Each player's file lives under Level Collections beside the arcade records.
The playlist persistence implementation provides atomic writes, a validated
backup, invalid-file preservation, a writer lock and stale-writer rejection.
Collections do not modify playlists, saved runs or campaign namespaces.
Deleting a profile removes its collection file and backup.

Native collection checks run with `TEST_SCOPE=collections` through
`Scripts/run-app-integration-tests.sh`, using the offscreen, muted runner.
