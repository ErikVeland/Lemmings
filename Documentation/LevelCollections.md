# Level collections

Open Collections from the home screen or the Level Select pack browser.
Favourites contains bookmarked levels. Recently Played contains the latest
50 distinct levels, newest first. Replaying a level moves it to the front.

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
