# Level skips

A level skip passes over one failed campaign level. Players earn skips by
playing well, and the same rules apply in Classic, Lemmings 2 and Lemmings 3.

## Earn

- Every third unassisted three-star level earns one skip.
- Each level counts once. A run that used rewind or undo does not count.
- Skips belong to one player profile. Hot Seat players keep their own balance.
- The balance comes from recorded Trolley attempts. Only spent skips are stored,
  in `ArcadeRecords.skippedLevels`.

The result screen shows **+1 SKIP** on the career card for the run that earns a
skip. The career page shows the balance and three pips. Filled pips count the
three-star levels toward the next skip. Outlined pips show the levels still needed.

## Spend

**Skip level (N)** appears on a failed result when all these conditions are true:

1. The level is part of a Classic rank, an L2 tribe or an L3 tribe.
2. The level is not the game's final Classic level or the last level of an L2 or L3 tribe.
3. The attempt owner has at least one skip.
4. Modern controls are on. Old school hides Skip with the other modern controls.
   Earned skips stay saved and return with Modern or Custom.

Playlists, shuffle, fan packs and level-browser practice never offer Skip.
They already let the player choose another level.

The result screen spends the skip first and saves the records. If the save fails,
the campaign does not move and the skip stays unspent. The game then opens the
next level. The skipped level stays unbeaten. It gives no medal, no rank or tribe
completion and no campaign pass. An L2 skip carries the whole population forward.
An L3 skip keeps the current population. Press K to skip from the keyboard.

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
- `Tests/AppIntegrationTests` (`testLevelSkipResult`): Classic zero state, solo
  skip, Hot Seat payer and handover.

The L2 and L3 result wiring shares the tested result-screen action. No automated
test drives a full L2 or L3 skip through the play windows.
