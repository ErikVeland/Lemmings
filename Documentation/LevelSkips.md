# Level skips

A level skip passes over one failed campaign level. Players earn skips by
playing well, and the same rules apply in Classic, Lemmings 2 and Lemmings 3.

## Earn

- Every third unassisted three-star level earns one skip.
- Each level counts once. A run that used rewind or undo does not count.
- Skips belong to one player profile. Hot Seat players keep their own balance.
- The balance comes from recorded Trolley attempts. Only spent skips are stored,
  in `ArcadeRecords.skippedLevels`.

The Mac gameplay badges show the Level Skip and Superzoom balances beside Zoom's
active state. Ordinary Zoom has no balance. The result's optional Rewards earned
action opens **+1 LEVEL SKIP**, the qualifying level-count change and the
three-level rule. View result returns without moving the level or changing the
Hot Seat turn. A reward never replaces the result or delays Retry or Continue.
The career page shows the balance and three pips. Filled pips count the
three-star levels toward the next skip. Outlined pips show the levels still needed.

## Spend

**Skip level (N)** appears on an eligible failed result, including at zero.
At zero, the button stays visible and disabled. Spending requires all these conditions:

1. The level is part of a Classic rank, an L2 tribe, an L3 tribe or a Learning journey.
2. A campaign level is not the game's final Classic level or the last level of an L2 or L3 tribe.
   The last Learning lesson can be skipped back to the journey hub.
3. The attempt owner has at least one skip.
4. Modern keyboard controls are on. Turning that setting off hides Skip.
   Earned skips stay saved. The Original presentation preset does not change this setting.

Other playlists, shuffle, fan packs outside Learning, and level-browser practice never offer Skip.
They already let the player choose another level.

The result screen spends the skip first and saves the records. If the save fails,
the campaign does not move and the skip stays unspent. The game then opens the
next level. The skipped level stays unbeaten. It gives no medal, no rank or tribe
completion and no campaign pass. An L2 skip carries the whole population forward.
An L3 skip keeps the current population. Press K to skip from the keyboard.

## Learning journeys

Classic and both sequel engines use the same Learning result actions. A skip
advances the saved journey once, records the lesson under Try later and leaves
it unsolved. Try later and Hints remain available. A journey save conflict keeps
the result open, returns the charged skip and preserves the current turn.
Cloud sync failure does not reverse a locally saved journey advance.

In Hot Seat, the result charges its attempt owner and passes the turn once under
both house rules. The next engine opens behind its normal paused Ready handover.
The shipped curriculum currently contains Classic lessons. Native L2/L3 fixtures
check the same callbacks and shared saved-journey flow.

## Refund

Clearing a skipped level later returns its skip and removes its skipped mark.
Any clear counts, including a clear that used rewind or undo.

## Hot Seat

The attempt owner pays, and the button names them: **Skip as ANN (1)**.
For turns, a skip counts as a loss. The next player receives the next level
behind the Ready page under both house rules.

## Validation

- `Tests/TrolleyTests`: earning, per-player balances, saving, spending once,
  refund on a pass, and the result flag for an earned skip.
- `Tests/ClassicGameFlowTests`, `Tests/Lemmings2RuntimeTests`,
  `Tests/Lemmings3RuntimeTests`: campaign moves and finale guards for each engine.
- `TEST_SCOPE=level-skips Scripts/run-app-integration-tests.sh`: campaign zero
  state, solo skip, Hot Seat payer, Classic/L2/L3 Learning losses, both house
  rules, saved revisit state, journey-save conflict refunds, paused Ready,
  compact/large renders and mouse/keyboard/accessibility targets.
- `Tests/PlayfieldDrawTests`: three resource badge rows and accessible balances.

The focused Mac suite passed offscreen with all audio muted. It includes 18
Learning result captures at compact and large sizes, six reward result captures,
nine badge states and campaign zero/owned/earned/Hot Seat states. Representative
Classic/L2/L3 losses, earned rewards and resource badges were visually inspected.

Native L2/L3 Learning checks load each play window, complete a synthetic losing
simulation and use its production result wiring. Their ordinary campaign Skip
actions still lack a complete automated play-window traversal. iOS/tvOS resource
UI and journey skips are unchanged. Foreground gameplay and VoiceOver remain
manual checks.
