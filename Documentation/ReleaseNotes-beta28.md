# Ultimate Lemmings — changes since beta 18

Cumulative notes for upgrading from beta 18 to beta 28.
Version 0.1, build 28. Universal Mac app for Intel and Apple silicon, macOS 13 or later.

## New in beta 28: consistent lettering and more reliable fan packs

- Green game-font titles and headings now establish the visual hierarchy. Supporting text and secondary actions use the blue game font.
- Skill labels share one font and scale, with space between neighbouring names. Short labels no longer grow larger than the rest of the row.
- Gameplay notices and fallback countdowns use bitmap lettering across Classic, Lemmings 2 and Lemmings 3. Search keeps the game font while you type.
- Older fan packs now resolve more Oh No! and holiday artwork slots correctly. Xmas and Christmas text styles select snow terrain.
- Imported text levels retain exact steel rectangles. Invalid or incomplete level fields fail cleanly.
- Archive members with brackets, question marks and other special characters load by their exact names. Ambiguous duplicate names fail cleanly.
- Saved fan attempts retain their original artwork rules. Retry applies the corrected rules to a new attempt.
- A stalled movie encoder stops accepting frames within a bounded wait. Finishing a failed recording reports the error without waiting on the blocked encoder queue.
- Release performance checks now measure the same asynchronous GPU path used during play and verify the number of encoded movie frames.

## New in beta 27: hints and handovers

- The final hint can offer a winning solution replay. Two separate choices protect the surprise before it opens.
- Watch at 1×, 3× or 10×, pause or replay, then return to your own paused attempt. The demonstration does not change your run, records or Hot Seat turn.
- Replays appear only when the recorded solution passes a winning replay check against the loaded level. There are routes for all 120 original levels and 103 more Classic campaign levels; other levels keep their existing hints.
- Retrying in Hot Seat waits for the incoming player to resume, across all three games. Solo retries retain their normal behaviour.
- Lemmings 2 briefings now show the incoming player before play begins. Starting the level clears held speed input.
- Lemmings 2 supports one-frame forward stepping while paused, including a final step into the result screen.
- Resume from the Lemmings 3 pause menu continues the same attempt.
- Lemmings 2 rescue targets now match the packaged game data. All five existing proof recordings were checked twice before updating their asset identities.

## New in beta 26: carry on where you stopped

- Resume is the first row on the main screen when you have a saved attempt. Click it, or press Enter, to return straight to the paused level.
- The row names the player who owns the attempt. Solo saves and Hot Seat saves stay separate.
- Resume no longer asks you to confirm, and it no longer reports success in a dialog. Starting the app shows the Resume row instead of opening a dialog.
- Leaving a level before the first tick now saves it. Classic briefings save as well.
- A resumed Classic run keeps Full Quest mode. Attempts saved by an earlier beta still open.
- Changing Hot Seat players from the results or run details screens now asks first, the same as the Hot Seat menu. Cancelling keeps the level, the attempt owner and the shared session.
- Choosing a profile cannot turn an active Hot Seat into solo play by accident. Returning to solo asks first.
- Fan packs now draw with the terrain and special pictures inside their own archives. Stock artwork remains the fallback.
- Older packs that name a picture with a single letter now load, including Supaplex Tricks and The Mon0lith.
- A saved fan attempt keeps the artwork rules it started with. Retry starts a new attempt with the corrected artwork.

## New in beta 25: controls that follow your choice

- Hold F to ramp through 2×, 3×, 5× and 10×. Release F to keep the speed you reached. Tap F to return to normal speed.
- Clicking a speed arrow now applies that speed immediately, even from 1×. Keyboard speed arrows behave the same way.
- Shift, the held Speed button and the controller trigger remain temporary boosts: release to return to your chosen speed.
- One continuous speed control, readable skill names, green shortcut letters and a rightmost Next Level button carry forward from beta 24.
- Hot Seat handovers highlight the incoming player in green and offer a retry of the previous level under that player’s profile. Begin Level stays on the right.
- Keyboard help and the frozen-level guide match the new F behaviour.
- Fix main-window ownership so a late fan-library refresh cannot use a window already released by AppKit.

## Hot Seat

- Shared games now keep their own campaign saves, separate from each player’s solo progress. A new shared game starts at the beginning.
- The roster, shared progress and next turn survive quitting. Return to solo without losing the shared game.
- Next Level is always the rightmost result button. Result buttons make it clear who will retry or continue. Both players can choose another attempt after a win or loss.
- Handovers pause on a Ready screen. Holding Return cannot skip the next player’s handover.
- Active-player portraits and initials now extend to L2 and L3. Results keep the identity of the player who made the attempt.
- Changing players during a level offers a saved exit. Shared checkpoints cannot accidentally resume as solo attempts.

## Speed and keyboard controls

- Tap F, click Speed or tap the controller’s right trigger to toggle fast-forward. Mouse clicks no longer wait for a double-click decision.
- Hold F to increase speed and release to keep it. Hold Shift, Speed or the right trigger for a temporary boost; release to return to your chosen speed.
- Apply 2×, 3×, 5× or 10× with the speed arrows or Shift+[ / Shift+]. F or controller B immediately returns fast-forward to normal speed.
- Escape saves the active run and returns directly to the main menu.
- B cycles through Bomber, Blocker, Builder and Basher. U selects Floater; number keys still select skills directly.
- Controller remapping includes conflict swapping, reset and saved bindings. Interrupted input no longer leaves buttons held.

## Fonts, graphics and help

- Original game lettering stays in menus when switching graphics, choosing fan packs or selecting a release without its own Macintosh artwork.
- Skill names sit beneath their counts, with active shortcut letters in green. Floater shows U beside its umbrella.
- Settings, selectors, keyboard help and speed controls use game artwork. Focus and selection have distinct visible states.
- The keyboard guide freezes the current level and places commands over the playfield. The full command list remains available, and help follows the enabled controls.
- Results and achievements show their state visually, with less repeated explanatory text. Pause changes to Play; reversible actions show their undo state.
- UI size offers 100%, 125% and 150%. Large windows no longer magnify the 100% setting again, and enlarged pages scroll.
- More menu and panel controls have accessible names and keyboard navigation. This is not yet full VoiceOver support.

## More accurate skill targeting

- Green means a nearby lemming can accept the selected skill. Clicking selects the nearest eligible lemming, including in crowds.
- A small targeting allowance helps at sprite edges and when a green target moves between frames.
- Grey means no eligible target. Successful assignments briefly pulse bright green, with HDR brightness where available.
- An already assigned skill gives a brief orange cue. An eligible neighbour takes priority, and reduced-flash settings are respected.

## Classic campaigns, hints and music

- Full Quest joins the Classic releases into a 13-stage, 292-level progression through their difficulty ranks.
- The progress field works with both original and Macintosh panel artwork.
- i or F1 opens level goals and tiered hints. All 120 original hint decks now match the shipping engine.
- Rescue targets have been replayed and refreshed for the current engine. All earlier certificates remain, with five additional full-rescue proofs.
- Seasonal music selection keeps Xmas and Holiday games with their Christmas soundtracks and avoids Christmas tracks in regular campaign pools.
- Fan-level loading handles numeric graphics slots and Xmas styles more reliably. A failed load returns to the level list instead of retaining the previous level.
- Saved-run recovery preserves fan queues and attempt identity, restores paused, and handles corrupt or stale save files more safely.

## Validation and remaining limits

The latest full Classic/fan audit covers 6,395 level identities. It reproduces
223 official Classic wins and 382 fan wins, including all 120 original levels.
There are 23 fan load/start failures and 5,790 identities without a verified
winning route. These are compatibility and route-coverage limits, not a claim
that those levels cannot be completed.

Lemmings 2 has 64 recorded campaign completions out of 120 levels. Many routes
rescue only one lemming, and no complete ten-level tribe chain is verified.
Lemmings 3 has 16 recorded completions out of 90 levels. Both remain previews.

A local M4 Pro performance run verified all 5,932 recorded movie frames. Requested
10× speed reached about 6.9–9.1× across the measured display modes. Sustained 10×,
physical Intel/minimum-macOS testing, controller hardware and full VoiceOver
navigation remain open. Mid-level Hot Seat takeovers remain deferred.

Beta 28 package checks are recorded in Beta28Readiness.md. The standard build
uses local records. Game Center requires the separate development build for
registered test Macs.
