# Hot Seat

Two or more players take turns on one Mac. Each attempt keeps its own player,
scores, records and achievements. The shared campaign has a separate save from
all solo profiles.

## Start or resume shared play

Add players in Player Profiles, then open **Hot Seat**. The previous shared
campaign, roster and next turn return when available. Otherwise, the host and
one other profile form the first roster. Number keys 1–8 add or remove guests.
The host stays in the roster.

Changing players during a level first offers **Save and return to library**.
The current attempt keeps its owner. Player changes take effect from the library,
so an old result cannot restart a shared attempt inside a solo campaign.

Shared campaign progress, the roster and the next turn survive quitting.
**Return to solo** returns to the host's solo saves and keeps the shared campaign
for later. Opening Hot Seat again resumes that shared campaign.

## Results and handovers

| Result | Primary action | Other choices |
| --- | --- | --- |
| Loss | Retry as the next player | Retry as the current player; Back to library |
| Clear, Every level | Next level as the next player | Retry as either player |
| Clear, At first fail | Next level as the current player | Retry as either player |

Buttons name the player who will act. Enter uses the primary action. R retries
as the current player. **Every level** is the default house rule. **At first fail**
lets a winner keep playing. The rule survives quitting and returning to solo.

After a handover, the game waits behind a page naming the next player. That
player chooses **Ready** before play can continue. Held Return does not dismiss
this page. Controller navigation selects Ready, and Back does not skip it.
A failed records save blocks the handover and level advancement.

Classic, L2 and L3 playfields show the active attempt owner. Selecting the next
player does not rename an attempt already in progress. Shared checkpoints can
only resume in their matching shared campaign. Solo recovery cannot load them.

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
