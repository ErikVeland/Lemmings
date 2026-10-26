# Level skips

A level skip passes over one unfinished or failed campaign level. Players earn skips by
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

**Skip level (N)** appears in pause menus and on eligible failed results on Mac,
iOS and tvOS, including at zero. Mac opens pause with Menu or Escape. Touch opens
it from the gameplay pause control. Resume returns to the same attempt. On Mac,
Q saves the attempt and returns to the library.
At zero, Skip stays visible and disabled. Spending requires all these conditions:

1. The level is part of a Classic rank, an L2 tribe, an L3 tribe or a Learning journey.
2. A campaign level is not the game's final Classic level or the last level of an L2 or L3 tribe.
   The last Learning lesson can be skipped back to the journey hub.
3. The attempt owner has at least one skip.

Earned skips remain available with either keyboard-control setting and either
presentation preset.

Other playlists, shuffle and fan packs outside Learning omit Skip. Mac
level-browser practice also omits it. Mobile native campaign libraries offer it
when a campaign level was selected directly.

Both screens spend the skip first and save the records. If the save fails,
the campaign does not move and the skip stays unspent. The game then opens the
next level. The skipped level stays unbeaten. It gives no medal, no rank or tribe
completion and no campaign pass. An L2 skip carries the whole population forward.
An L3 skip keeps the current population. Press K on the result screen to skip from the keyboard.

## Learning journeys

Classic and both sequel engines share the Learning pause and result actions. A skip
advances the saved journey once, records the lesson under Try later and leaves
it unsolved. Try later and Hints remain available. A journey save conflict keeps
the current screen open, returns the charged skip and preserves the current turn.
Cloud sync failure does not reverse a locally saved journey advance.

In Hot Seat, pause and results charge their attempt owner and pass the turn once under
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

On 25 October 2026, muted offscreen pause checks passed for Classic, L2 and L3.
They cover zero and owned balances, Original keyboard controls, native campaign
advancement, both Hot Seat rules, one-time spending, save-conflict refunds and
mouse/accessibility targets. Twelve compact/large pause renders cover all three
engines, zero balances and named Hot Seat payers. Representative renders were
visually inspected. The Classic campaign-flow tests also pass.

Native L2/L3 Learning result checks load each play window, complete a synthetic
losing simulation and use its production result wiring. Ordinary sequel campaign
skips now have native pause-window traversal. Complete sequel campaign-result
and native Mac Learning pause traversal remain validation gaps.

Mobile pause and result actions now read the live owner balance. L2/L3 library
skips persist campaign advancement and preserve population without awarding a
clear. Learning saves its deferred lesson and advances once. Failed checkpoint
retirement or handover restores the prepared progression and returns the charge.
Muted native campaign tests cover persistence, finale guards, rollback and save
failure. Hostless UIKit tests cover live zero/earned balances in all three engine
layouts, repeated input, both Hot Seat rules and failed-handover refunds.
Foreground gameplay and VoiceOver remain manual checks.
