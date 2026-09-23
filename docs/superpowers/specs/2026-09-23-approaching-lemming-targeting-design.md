# Approaching-lemming click targeting design

23 September 2026. Scope: 1.1 QoL. A shared fix for a misclick that hits a
turned lemming instead of the one still facing the obstacle.

**Revised 23 September 2026**, after the first implementation's whole-branch
review. Two changes from the original text below: the approaching check now
requires a facing mismatch (see "The fix"), and every input path — not only
the mouse click — must share one targeting function per engine (see "Scope
guardrails" and "Where this lands, per engine").

## Goal

Stop skill assignments from landing on the wrong lemming when two or more
lemmings sit close together near a wall. Today, a click near that spot can
pick a lemming that already turned around. A directional skill (basher,
digger, miner) then fires into open air instead of the obstacle.

## The fix

All three engines pick a click's target the same way. Each one filters
lemmings inside a small pick radius, then chooses the nearest one eligible
for the selected skill. None of them checks which way the candidates face.

Add one more tier to that choice, ahead of raw distance. Among eligible
candidates in range, prefer the nearest one still walking toward the
click — but only step in when today's plain nearest-eligible pick faces
away from the click **and** a facing-toward alternative exists. This tier
reads each engine's existing per-lemming facing field. It needs no wall or
obstacle lookup: a lemming that turned away from an obstacle no longer
walks toward it, by definition.

**Approaching** means the click's x-position sits on the side of the
lemming that matches its current facing:

- Facing left: the click's x is at or left of the lemming's x.
- Facing right: the click's x is at or right of the lemming's x.

**The facing-mismatch gate.** The first implementation applied this tier
whenever any approaching candidate beat a nearer non-approaching one, with
no further condition. That also reordered two lemmings walking the *same*
direction: a click landing one pixel behind the nearer walker's exact
position made it read as "not approaching," handing the pick to a farther
trailing lemming walking the same way — a same-direction pack has no
turned-around lemming at all, so this was never the misclick the feature
exists to fix. The rule now only overrides the plain nearest-eligible pick
when an approaching alternative faces the *opposite* direction from it.
Two lemmings walking the same direction keep today's plain nearest-pixel
behavior, whatever side of either one the click lands on.

When no candidate both approaches and faces opposite the plain pick,
targeting falls back to today's nearest-eligible rule, unchanged.

## Scope guardrails

- The pick radius stays the same size in all three engines. This only
  reorders candidates already in range. It never reaches a lemming a click
  could not already hit.
- `canAssign` eligibility rules stay the same. Approaching-preference only
  breaks a tie among candidates already eligible for the selected skill.
- Hover preview and click resolution must share one function per engine, so
  a highlighted lemming is always the one a click assigns. This already held
  for Classic and Lemmings 2's mouse path. The first implementation missed
  that Lemmings 2's keyboard/gamepad assignment and Lemmings 3's hover,
  keyboard and gamepad assignment ran their own separate, simpler
  nearest-distance calculations that never called the shared function — so a
  gamepad player got none of this fix, and Lemmings 3's on-screen hover
  highlight could disagree with what a click actually picked. Every input
  path in every engine must now call the same targeting function.

## Setting

A new toggle on `ClassicSettings` (`Sources/NxlvKit/ClassicSettings.swift`),
the settings type shared by all three engines. Default: on.

- Decode with a default-`true` fallback, matching every other toggle in
  that file, so an older settings file upgrades cleanly.
- Fold into `applyExperiencePreset(modern:)`: on under "modern defaults,"
  off under "OG settings," so a player who wants the exact original feel
  can still get it.
- Add a checkbox to the Gameplay pane in `SettingsWindow.swift`, next to
  "Modern keyboard controls." Working title: "Favor lemmings still
  approaching." Tooltip: "When a click could match more than one lemming,
  choose the one still walking toward it over one that has already turned
  away." Final copy goes through the STE lint before it ships.

Each targeting function takes the setting as an explicit argument, the same
way it already takes the click point and the selected skill. This keeps the
function a pure decision that a unit test can drive directly, instead of
one that reads global state.

## Where this lands, per engine

| Engine | Function | Change |
| --- | --- | --- |
| Classic | `PlayfieldView.lemming(at:)` ([PlayfieldView.swift:432](../../../Sources/LemmingsLocal/PlayfieldView.swift)) | Compute today's nearest-eligible pick first. If it does not approach, look for the nearest eligible candidate that both approaches and faces the opposite way. Use that candidate if one exists. Already shared by hover and click, so there is no separate call site to fix. |
| Lemmings 2 | `Lemmings2Runtime.target(slot:x:y:)` ([Lemmings2Runtime.swift:486](../../../Sources/NxlvKit/Lemmings2Runtime.swift)) | Same facing-mismatch-gated tier in the `.min(by:)` comparator, after eligibility and before the distance tiebreak. `Lemmings2Canvas.pointerTarget(slot:)` and the hover-cursor calculation both pass the setting through. Keyboard, gamepad and the cursor label all call `pointerTarget`, so fixing it there covers all three. |
| Lemmings 3 | `Lemmings3Targeting.nearest(...)`, an extracted helper (see below) | Same facing-mismatch-gated tier. The existing `tool == nil` priority stays the first tiebreak. `Lemmings3Canvas.pointerTarget` (hover, keyboard, gamepad) calls this same helper now, instead of its own separate, simpler calculation. |

## What stays untouched

- Pick-radius and hit-box sizes in every engine.
- `canAssign` eligibility rules.
- Lemmings 3's `tool == nil` priority ordering.
- Saved solutions and in-run recovery history. Both already store the
  resolved lemming ID for each assignment, not the raw click coordinates.
  A change to targeting cannot alter a past run.

## Testing

Unit tests, alongside the existing coverage for each engine's targeting
function (for example `Lemmings2RuntimeTests` already exercises
`target(slot:x:y:)` at `Tests/Lemmings2RuntimeTests/main.swift:1265`):

- Two eligible candidates, opposite facing, the nearer one facing away: the
  farther, approaching one wins.
- Two eligible candidates, same facing, the nearer one still the plain
  nearest-eligible pick: targeting keeps the nearer one, whichever side of
  it the click lands on. This is the facing-mismatch gate's own test.
- Only a facing-away eligible candidate in range: targeting falls back to
  today's nearest-eligible result.
- Setting off: targeting matches today's behavior exactly, in every case
  above.
- Lemmings 3 only: an eligible `tool == nil` candidate beats an approaching
  candidate that already holds a tool, confirming the tool tier still runs
  first.

Manual, per `Documentation/UIPrinciples.md`: with the setting on and with
it off, confirm the hover highlight and the click land on the same lemming
in all three engines, using the mouse and using the keyboard/gamepad
pointer, and confirm the OG and modern preset buttons set the toggle
correctly.
