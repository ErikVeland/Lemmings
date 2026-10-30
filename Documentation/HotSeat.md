# Hot Seat

Two or more players take turns on one Mac. Each attempt keeps its own player,
scores, records and achievements. The shared campaign has a separate save from
all solo profiles.

## Start or resume shared play

Open **Hot Seat** from the Ultimate Lemmings menu or Player Profiles.

1. Select the player tiles to add or remove players. Number keys 1–8 do the same.
2. To add a player who has no profile, select **+ New player** (or press N).
   After **Add player**, the new player joins the roster and the page returns.
3. Select **Choose a game**.

With only one profile, **+ New player** is the primary action. **Choose a game**
is available when the roster has at least two players. The host stays in the roster.

The previous shared campaign, roster and next turn return when available.
Otherwise, the host and one other profile form the first roster. **New Hot Seat**
starts the shared campaign again from the beginning with the same players, then
returns to the library. The home screen refreshes the player badge and Resume
action for the selected session. A new session cannot resume the previous one's attempt.
The previous campaign stays in **Saved Hot Seats**, with its roster, next turn
and house rule. Resume it there, then choose a game or its saved attempt.
Saved Hot Seats lists every retained shared campaign on the device, including
synced campaigns whose roster does not include the selected solo player.
Resuming selects that campaign's host and restores its existing turn. Separate
campaigns with the same players remain separate; mobile and TV rows include
their saved dates. Older Mac saves that retain only a session pointer remain
available when another campaign starts.

Changing players during a level first offers **Save and return to library**.
The current attempt keeps its owner. Player changes take effect from the library,
so an old result cannot restart a shared attempt inside a solo campaign.

Shared campaign progress, the roster and the next turn survive quitting.
**Return to solo** returns to the host's solo saves and keeps the shared campaign
for later. Opening Hot Seat again resumes that shared campaign.

## Results and handovers

| Result | Primary action | Other choices |
| --- | --- | --- |
| Loss | Retry as the next player | Retry as the current player; Skip as the current player, when they own a skip; Back to library |
| Clear, Every level | Next level as the next player | Retry as either player |
| Clear, At first fail | Next level as the current player | Retry as either player |

A skip is paid by the player who failed, and the next level passes to the next
player. See [Level skips](LevelSkips.md). Buttons name the player who will act. Enter uses the primary action. R retries
as the current player. **Every level** is the default house rule. **At first fail**
lets a winner keep playing. The rule survives quitting and returning to solo.

After a handover, the game waits behind a page naming the next player. That
player chooses **Ready** before play can continue. Held Return does not dismiss
this page. Controller navigation selects Ready, and Back does not skip it.
A failed records save blocks the handover and level advancement.

Classic, L2 and L3 playfields show the active attempt owner. Selecting the next
player does not rename an attempt already in progress. Shared checkpoints can
only resume in their matching shared campaign. Solo recovery cannot load them.
A player/session mismatch preserves the run and asks you to resume its session.
It does not report changed game rules or offer to discard that valid run.

## Previous-player ghosts

When another player retries the same level, their live attempt includes a silent
ghost of each earlier player's latest completed turn, including losses. Each
player has a distinct translucent colour. The current player's own earlier
attempt is excluded. Ghosts use the shipped sprites and stay behind live lemmings.
They add no input targets, skill effects, labels or sound.

On Mac, **Ghosts on/off** in Hot Seat setup sets visibility before play. The
same control beside the gameplay menu and **⌘G** toggle ghosts before or during
an attempt, including while paused. The local choice survives relaunching.
Hiding ghosts preserves their turns. Showing them again seeks to the current
game tick. This control leaves the separate Classic solution ghost unchanged.

Ghosts follow simulation time through speed changes, paused steps and rewind.
They disappear at the end of their recorded turn and return when rewound.
Each ghost owns its engine and terrain, so its bridges and tunnels can differ
from the live level. The overlay cannot affect collisions, skills or records.

Classic, NeoLemmix, Lemmings 2 and Lemmings 3 share the archive and playback.
Ghosts are scoped to the Hot Seat session, level conditions and exact starting
state. They survive relaunching that session. New sessions and solo play start
without these ghosts. Removed players are excluded. A different starting
population or changed level data does not reuse an incompatible turn.
Ready handovers keep their existing pause and explicit Ready action.
L2 ghosts show the primary lemming sprite. Separate equipment, projectiles and
blast particles are omitted. L3 uses the same provisional animation mapping as
the live renderer.

Watch replay and saved replay movies include the ghosts visible during that
attempt. Existing movies keep their recorded pixels. Leaderboard action replays
remain individual runs. The Classic solution ghost is separate.

### iOS and tvOS

iPhone, iPad and Apple TV show the same ghosts in a Hot Seat session. The
mobile Hot Seat roster gives the session ID and the player order, so the roster
colours match the Mac order. Each completed turn, including a loss, replaces
that player's ghost when the result is saved. A retry or the next player's turn
loads the ghosts again for the new owner. The Ready handover stays paused until
the player selects Ready. **Review** on the result page keeps the ghosts that
the attempt showed. The solution replay shows no Hot Seat ghosts.

Mobile engine limits:

- Classic, L2, L3 and supported NeoLemmix sessions draw ghosts. NeoLemmix uses
  the shared action archive and native sprite tinting, including queued spawn
  interval changes. Older NeoLemmix checkpoints with only a mid-level state
  cannot reconstruct a complete turn and create no ghost recording.
- L2 ghosts show the primary lemming sprite, as on Mac. Equipment,
  projectiles, countdowns and blast particles are omitted.
- L3 ghosts use the live two-direction animation mapping.
- An L3 run saved by an earlier build can contain a facing-direction tool use
  without a recorded direction. That turn creates no ghost or action file.
  New L3 turns record the direction.
- A Classic checkpoint from before rewind history starts part-way through the
  level. That turn creates no ghost or action file.
- The legacy `TVLibraryViewController` path, used only when an app registers
  its own library sources, has no Hot Seat roster and shows no ghosts. The
  shipped Apple TV app uses the shared mobile library.

## Playlists and shuffle

Starting a playlist or shuffle during Hot Seat offers **New solo**, **New Hot Seat**
and **Back**. Both start actions save the current attempt first. New Hot Seat uses
the current roster and starts with the host. Back leaves the session unchanged.

Every new session starts at the first entry of its chosen campaign or playlist.
A new **Oh My! ALL Lemmings!** journey starts with **Just dig!**, even if a player
completed it before. Profile achievements, scores and learning history stay saved.
Continue and Resume use the saved session position. A journey from another
Hot Seat or a solo run cannot become the new session's current journey.

Home completion counts include the selected session's Journey wins as well as
its campaign wins. Matching level identities count once. Displaying those totals
does not unlock campaign levels or change the saved campaign, roster or turn.
Classic and fan rows use this union. L2 and L3 completion summaries use the same
rule while Home retains their existing logos.

Before 2.1, Mac Journey outcomes shared one history across solo and Hot Seat play.
The upgrade restores recorded outcomes for past visits in each retained Hot Seat
queue. It also checks a matching pre-upgrade backup when 2.1 has already written
an empty session history. A resume position alone cannot establish a win.
Unvisited solo wins stay outside the recovered session, and the original shared
history stays intact. This older format cannot prove which turn earned a shared
outcome. History absent from both the save and its retained backup cannot be
reconstructed. New sessions keep separate histories.

L2 playlists starting at level one have no inherited completions or skips.
If a playlist explicitly starts later in a tribe, it retains only the preceding
levels needed for that level's population. L3 playlists start without inherited
campaign completions. Neither action overwrites the saved campaign.

Previous playlist positions stay in **Playlists** as **Resume solo** or
**Resume Hot Seat**. A playlist restores its matching saved attempt, including its selected action
and camera, and stays paused. Older saved playlists without a checkpoint start
at their saved level. Campaign attempts keep their full checkpoint. Shared playlists use the same result and
turn rules across Classic, L2 and L3. Each newly loaded shared level waits for
**Ready** before play.

## Later work

Mid-level takeovers remain deferred. They need shared-attempt attribution so a
solution completed by two people does not become one person's individual record.

## Validation

- `TEST_SCOPE=profile-sessions zsh Scripts/run-app-integration-tests.sh`: the
  rendered New Hot Seat mouse target, confirmation, home Resume ownership,
  confirmed profile switching, recovery and cross-engine session boundaries.
  Repeated Solo/Hot Seat round trips keep campaign progress in separate save
  namespaces and reload the selected mode before the library becomes available.
- `Scripts/run-arcade-records-tests.sh`: roster, rotation, relaunch, shared-save
  persistence, solo namespaces, explicit Ready, keyboard repeats, controller
  focus and failed-save handovers.
- `TEST_SCOPE=hot-seat Scripts/run-app-integration-tests.sh`: Classic turn
  identity, confirmed player changes, old result actions, solo transitions and
  checkpoint scope isolation.
- Sequel app checks cover turn ownership and retry boundaries in L2 and L3.

- `TEST_SCOPE=sessions Scripts/run-app-integration-tests.sh`: session choices,
  cancellation, checkpoint preservation, saved sequence positions, rendered input
  targets and Ready after Classic, L2 and L3 launches.
- `TEST_SCOPE=learning Scripts/run-app-integration-tests.sh`: fresh solo and
  Hot Seat journeys after prior profile progress, session ownership, Holiday
  terrain in Floating Down!, graphics changes and the journey HUD position.

- `zsh Scripts/run-hot-seat-ghost-tests.sh`: muted, offscreen checks for Classic,
  L2 and L3 ghost timelines, two earlier players, latest-turn replacement,
  archive reload, current-owner exclusion, fresh sessions, solo play, deleted
  players, changed data and invalid commands. Native captures check three
  colours, multiple ghosts, unchanged input surfaces and movie-frame inclusion.
  Representative captures were inspected. A separate synthetic cursor check
  also passed for NeoLemmix. Native NeoLemmix artwork and composited CRT/HDR
  output remain unchecked for this feature. MP4 export uses the existing
  encoder; this check verifies its source frames rather than decoding a new MP4.
- The same script also runs the iOS and tvOS session checks with the shipped
  Classic, L2 and L3 data. Each mobile command log must pass action-replay
  validation and rebuild the exact final state. A second turn must draw the
  ghost, keep the same input targets and live state, and draw the ghost again
  after rewind. The checks also cover roster storage, own-turn exclusion,
  session isolation, the Records **Replay** action and Classic playback of a
  saved action file. `.build/hot-seat-ghosts/screens/mobile-*.png` holds each
  ghost frame beside the plain frame for review. The iOS and tvOS view
  controllers have no automated UI test for this feature.

Mac visibility checks also cover hiding and restoring sprites in Classic, L2
and L3, movie-frame exclusion, retained turns, saved visibility, Command-G and
its unmodified G counterpart. Offscreen captures cover both control states at
640, 900 and 1120 points and Hot Seat setup with two and eight players.
