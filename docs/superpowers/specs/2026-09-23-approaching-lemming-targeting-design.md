# Approaching-lemming click targeting design

23 September 2026. Scope: 1.1 QoL. A shared fix for a misclick that hits a
turned lemming instead of the one still facing the obstacle.

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
click. Fall back to today's nearest-eligible candidate only when no
candidate walks toward the click. This tier reads each engine's
existing per-lemming facing field. It needs no wall or obstacle lookup: a
lemming that turned away from an obstacle no longer walks toward it, by
definition.

**Approaching** means the click's x-position sits on the side of the
lemming that matches its current facing:

- Facing left: the click's x is at or left of the lemming's x.
- Facing right: the click's x is at or right of the lemming's x.

When no approaching candidate exists, targeting falls back to today's
nearest-eligible rule, unchanged.

## Scope guardrails

- The pick radius stays the same size in all three engines. This only
  reorders candidates already in range. It never reaches a lemming a click
  could not already hit.
- `canAssign` eligibility rules stay the same. Approaching-preference only
  breaks a tie among candidates already eligible for the selected skill.
- Hover preview and click resolution share one function per engine already,
  so a highlighted lemming is always the one a click assigns.

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
| Classic | `PlayfieldView.lemming(at:)` ([PlayfieldView.swift:432](../../../Sources/LemmingsLocal/PlayfieldView.swift)) | Among the eligible, in-range candidates already sorted by distance, return the nearest approaching one. If none approaches, return today's nearest-eligible result. |
| Lemmings 2 | `Lemmings2Runtime.target(slot:x:y:)` ([Lemmings2Runtime.swift:486](../../../Sources/NxlvKit/Lemmings2Runtime.swift)) | Add an approaching tier to the `.min(by:)` comparator, after eligibility and before the distance tiebreak. |
| Lemmings 3 | `Lemmings3PlayWindow.assign(x:y:)` ([Lemmings3PlayWindow.swift:463](../../../Sources/LemmingsLocal/Lemmings3PlayWindow.swift)) | Same comparator change. The existing `tool == nil` priority stays the first tiebreak. Approaching slots in before distance. |

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

- Two eligible candidates, equal distance, opposite facing: the approaching
  one wins.
- Only a facing-away eligible candidate in range: targeting falls back to
  today's nearest-eligible result.
- Setting off: targeting matches today's behavior exactly, in every case
  above.

Manual, per `Documentation/UIPrinciples.md`: with the setting on and with
it off, confirm the hover highlight and the click land on the same lemming
in all three engines, and confirm the OG and modern preset buttons set the
toggle correctly.
