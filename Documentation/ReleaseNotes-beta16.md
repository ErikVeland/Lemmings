# Ultimate Lemmings — beta 16

Version 0.1, build 16. Universal Mac app for Intel and Apple silicon, macOS 13 or later.

This beta finishes the hot seat. Solo play is unchanged, and nothing new appears
on screen while you play alone.

## Changes since beta 15

### You can always see whose turn it is

- The level briefing shows the player's lemming portrait beside their initials,
  before the level starts.
- A small badge in the top right of the level shows the same portrait and
  initials while you play. It is deliberately quiet.
- Both appear only in a hot seat. Solo play shows neither.

### Clearer result buttons

- After a loss: **Retry as [next initials]**. Losing gives up the seat.
- After a clear: **Retry as [your initials]**. Winning keeps the seat, so another
  attempt at the same level is still yours to improve.
- After a clear: **Next level: [next initials]** names the player who receives
  the Mac.
- A plain **Retry** remains, so the current player can always take the level
  again without passing the turn.

### Hot seat and solo no longer disagree

- Removing the player whose turn it is no longer leaves the turn with them.
- A roster that falls below two players ends the hot seat instead of leaving a
  session with nobody to pass to.
- The turn shown on screen now follows the game every frame. Ending a hot seat
  during a level, or passing the turn, can no longer leave the previous player's
  name on screen.
- The Hot Seat page lays out around the number of profiles. Two players no longer
  leave a gap in the middle, and eight no longer push the buttons off the screen.

## Tester focus

1. Play solo. Confirm no portrait, no badge and no extra buttons appear anywhere.
2. Start a hot seat with two players, then three. Check the briefing portrait,
   the in-level badge and the result buttons after both a win and a loss.
3. During a level, open Hot Seat and select **Play solo**. The badge must clear
   at once, not at the next level.
4. Remove the player whose turn it is. Play must continue with a real player.
5. Open the Hot Seat page with two profiles and with eight. Check that nothing is
   cut off and that no large gap appears.
6. Quit and reopen. The turn setting must survive. The roster must not.

Report the game, rank and level, player, Mac model, macOS version, display mode
and exact steps.

## Known limits

- The in-level badge is on the classic playfield. Lemmings 2 and Lemmings 3 play
  in their own windows and do not show it yet.
- Campaign progress in a hot seat still belongs to the host, so the players stay
  on the same level. Records, statistics and achievements stay separate.
- This is a test beta, not a 1.0 release. 214 core campaign routes remain
  unverified. NeoLemmix compatibility is partial. Sustained 10x performance is
  not established.
- The package is for private testing under the project's game-data policy.

See [hot seat](HotSeat.md) and [beta testing](BetaTesting.md) for details.
