# Ultimate Lemmings — changes since beta 18

Cumulative notes for upgrading from beta 18 to beta 24.
Version 0.1, build 24. Universal Mac app for Intel and Apple silicon, macOS 13 or later.

## New in beta 24

- Hold F, the Speed button or the controller’s right trigger to ramp through 2×, 3×, 5× and 10×. Release to return to the previous speed. A quick tap still toggles fast-forward.
- The speed arrows and indicator now sit inside one continuous game-style control.
- Skill names are back beneath their counts. Green letters show keyboard selection shortcuts; B cycles the B skills, and Floater shows U beside its umbrella.
- Next Level is always the rightmost result action, after the retry choices.
- Keyboard help includes holding F. A quick double-click still stops fast-forward; holding its second press can ramp up again.

## Hot Seat

- Shared games now keep their own campaign saves, separate from each player’s solo progress. A new shared game starts at the beginning.
- The roster, shared progress and next turn survive quitting. Return to solo without losing the shared game.
- Result buttons make it clear who will retry or continue. Both players can choose another attempt after a win or loss.
- Handovers pause on a Ready screen. Holding Return cannot skip the next player’s handover.
- Active-player portraits and initials now extend to L2 and L3. Results keep the identity of the player who made the attempt.
- Changing players during a level offers a saved exit. Shared checkpoints cannot accidentally resume as solo attempts.

## Speed and keyboard controls

- Tap F, click Speed or tap the controller’s right trigger to toggle fast-forward. Mouse clicks no longer wait for a double-click decision.
- Hold F, Shift, Speed or the right trigger for a temporary boost. Release to return to the previous speed.
- Choose 2×, 3×, 5× or 10× with the speed arrows or Shift+[ / Shift+]. F or controller B immediately returns fast-forward to normal speed.
- Escape saves the active run and returns directly to the main menu.
- B cycles through Bomber, Blocker, Builder and Basher. U selects Floater; number keys still select skills directly.
- Controller remapping includes conflict swapping, reset and saved bindings. Interrupted input no longer leaves buttons held.

## Fonts, graphics and help

- Original game lettering stays in menus when switching graphics, choosing fan packs or selecting a release without its own Macintosh artwork.
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

Beta 23 passed both complete app journeys on Apple silicon and Intel under Rosetta, along with all 25 core/resource regression suites. Beta 24 retains the same engine and game assets; its release validation is recorded separately in Beta24Readiness.md.

The full audit covers 6,395 Classic and fan level identities. Compared with the previous full audit, no winning route was lost, no new load/render failure appeared, and eight additional official routes won. All 223 recorded official Classic wins and 294 fan wins were reproduced.

This remains a beta. There are still 94 fan-level load/start failures, and 5,878 levels lack verified winning routes. Full Classic/fan compatibility, physical hardware/controller testing, complete VoiceOver navigation and sustained performance validation remain open. Mid-level Hot Seat takeovers remain deferred. L2 and L3 remain previews.

The standard build uses local records. The separate Game Center build is limited to the two registered test Macs and cannot be notarised.
