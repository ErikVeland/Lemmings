# Ultimate Lemmings 1.7.4 — Fresh Sessions and Correct Fan Artwork

Build: 58
Release base: v1.7.3

## Fresh sessions

New solo and Hot Seat sessions start at the first level of the chosen campaign
or playlist. A new Oh My! All Lemmings! journey starts with **Just dig!**, even
when the current player completed it before. Continue and saved sessions retain
their existing position. Previous sessions, profile achievements and scores stay
saved. Hot Seat handovers wait for the next player to choose Ready.

## Correct fan artwork

Fan levels now use Macintosh or Amiga artwork from their resolved terrain set.
This fixes **Floating Down!** drawing marble arches over its snow collision map.
Custom terrain and special pictures retain their own artwork. Switching graphics
keeps the same terrain and simulation. The HUD shows the active journey or
playlist position instead of a stale Classic campaign rank.

## Selection effects

Choose **Settings > Gameplay > Selection**:

- **None** removes the selection highlight for an old-school look.
- **Obvious** restores the game-pixel halo and overhead marker.
- **Modern** adds a steady white outline and a visible mint-green halo with a
  gentle brightness pulse. The outline stays two physical display pixels wide
  and follows the current sprite frame. The halo also works with HD effects off.

The choice applies across Classic, Lemmings 2 and Lemmings 3. Modern reuses cached
sprite masks and draws with the game frame, without a separate full-window HDR
surface or animation timer. Pausing holds the halo, and reduced motion or reduced
flashes keep it steady. It stays at standard display brightness.

## More verified levels

Six more Classic fan levels have verified winning replays since 1.7.3, bringing
the total to 2,142. Lemmings 2 and Lemmings 3 remain in Preview. NeoLemmix remains
in Beta.

## Update

Existing players can use **Check for Updates…**. The full soundtrack is included
in `UltimateLemmings-1.7.4-build58.zip`, which also supports a fresh installation.

Build 57 was withdrawn before publication. Build 58 includes the session and
terrain corrections.
