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
starts the shared campaign again from the beginning with the same players.
The previous campaign stays in **Saved Hot Seats**, with its roster, next turn
and house rule. Resume it there, then choose a game or its saved attempt.

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

## Playlists and shuffle

Starting a playlist or shuffle during Hot Seat offers **New solo**, **New Hot Seat**
and **Back**. Both start actions save the current attempt first. New Hot Seat uses
the current roster and starts with the host. Back leaves the session unchanged.

Previous playlist positions stay in **Playlists** as **Resume solo** or
**Resume Hot Seat**. A playlist resumes at the start of its saved level. Campaign
attempts keep their full checkpoint. Shared playlists use the same result and
turn rules across Classic, L2 and L3. Each newly loaded shared level waits for
**Ready** before play.

## Later work

Mid-level takeovers remain deferred. They need shared-attempt attribution so a
solution completed by two people does not become one person's individual record.

## Validation

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
