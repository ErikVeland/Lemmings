# Target selection

This record preserves the 23 September 2026 targeting decision for Classic,
Lemmings 2 and Lemmings 3. See the [overview](Overview.md) for current feature
status and [UI principles](UIPrinciples.md) for input and presentation rules.

## Selection rules

Start with the nearest eligible lemming inside the engine's pick radius.
When approaching preference is enabled, prefer an eligible lemming that walks
towards the click if the nearest candidate faces away in the opposite direction.

A left-facing lemming approaches when the click is at or left of its position.
A right-facing lemming approaches when the click is at or right of its position.
Two walkers that face the same direction retain nearest-pixel selection.
Without an eligible opposite-facing alternative, keep the nearest candidate.

When the nearest eligible candidate builds a bridge, an eligible follower can
take priority. The follower must be behind the builder, face the same direction
and approach the click. Lemmings 3 retains its separate tool-holder priority
for Use and Drop.

## Shared input paths

Each engine must use the same target selection for hover, mouse, keyboard and
controller input. A highlighted lemming must be the one that receives the
assignment. Eligibility rules still determine whether a skill can be assigned.

`ClassicSettings` stores the preference for all three engines. Older settings
files default to enabled. Modern defaults enable it, and OG settings disable it.
Targeting functions receive the preference explicitly.

Replays and recovery histories store resolved lemming IDs. They do not resolve
old click positions again, so a targeting preference cannot redirect past inputs.

## Regression cases

- Prefer an eligible approaching candidate over a nearer opposite-facing candidate.
- Prefer an eligible follower when the nearest candidate builds a bridge.
- Keep nearest-pixel selection for walkers that face the same direction.
- Keep the nearest candidate when no eligible alternative exists.
- Preserve native selection when the preference is disabled.
- Preserve Lemmings 3 tool priority for Use and Drop.
- Keep hover and assignment consistent for every supported input path.

The [original design](https://github.com/ErikVeland/Lemmings/blob/75fc1f34508d379baced019796cee48ff8ec0e27/docs/superpowers/specs/2026-09-23-approaching-lemming-targeting-design.md)
retains the implementation history.
