# QoL roadmap: target selection and rewind

23 September 2026. This plan orders the next player-facing QoL work. It keeps
the original level rules, skill limits, timing and physics unchanged.

## Product promise

The port should remove input and recovery friction without making the puzzle
easier by default. A player should always know which lemming and skill an input
will affect. A player should also be able to inspect and recover a mistake with
clear transport controls.

## Priority order

| Priority | Milestone | Release position | Reason |
| --- | --- | --- | --- |
| P0 | Target-select polish | 1.1 exit gate | The current targeting logic needs a clear visual and a deterministic input path. |
| P1 | Rewind transport design and Classic prototype | After the 1.1 target baseline | Classic already has exact history. It can prove the interaction, visuals and audio before cross-engine work. |
| P1 | Lemmings 2 and Lemmings 3 rewind adapters | Next QoL milestone | Rewind must reach all three engines before it becomes a shared player promise. |
| P2 | Verified hints and solution playback | After rewind foundation | Hints depend on checked routes and should follow the same evidence boundary. |
| P3 | Accessibility and device validation | Alongside every milestone, release gate | The features exist, but physical controllers and complete VoiceOver journeys still need evidence. |
| P4 | Smart waiting and Hot Seat expansion | Later milestone | These improve comfort, but they do not fix the main input and recovery gaps. |

Target-select is the 1.1 product commitment. Rewind design work can start during
1.1, but the full rewind feature should not enter the 1.1 exit gate until all
three engines have the same player-facing contract.

## P0: target-select polish for 1.1

### Behaviour rules

- Use the existing per-engine eligible-candidate rules.
- Keep the existing pick radius and hit boxes.
- Keep the approaching-lemming preference as a tie-breaker only.
- Keep the Lemmings 3 tool-holder priority.
- Use the same resolved target for hover, click, keyboard and controller input.
- Keep the nearest-target behaviour when the setting is off.
- Do not pause, slow or move the game when the target changes.
- Do not make a target easier to select by extending its hit box.

The target resolver should return the selected lemming ID, the eligible state,
the candidate count and the selected skill. The renderer should use this value.
It must not run a second nearest-lemming calculation.

### Visual options for the skill indicator

| Option | Description | Benefit | Risk | Decision |
| --- | --- | --- | --- | --- |
| A. Cursor-corner badge | Draw a small native-resolution skill icon on the lower-right border of the cursor. Keep the cursor hotspot unchanged. | It stays close to the action and does not cover the lemming. | The icon may be small at 1×. | Recommended default. |
| B. Cursor-top badge | Draw the skill icon above the cursor with a one-pixel gap. | It reads as a label for the cursor. | It can overlap terrain, lemming sprites or the top edge of the window. | Use only as an accessibility or high-scale option if testing supports it. |
| C. HUD mirror | Add a larger selected-skill icon beside the existing skill count. | It is easy to read at every scale. | It does not identify the skill at the point of selection. | Keep as supporting feedback, not the main indicator. |

Use Option A with a small target glow. Reuse the native skill artwork from the
existing game controls and bitmap renderers. Render the badge at source
resolution, then scale it with nearest-neighbour filtering.

The target cue must be a soft halo around the selected lemming, not a
four-corner frame. Use two thin pixel-aligned rings and three short shimmer
arcs. Keep the outer ring low contrast and let one arc provide the readable
motion cue. The glow must sit outside the opaque sprite where possible and
must not hide the lemming's action or change the pick area.

### Visual target states

Use a small halo around the selected lemming. Keep the halo outside the opaque
sprite pixels where possible.

| State | Shape | Colour | Motion |
| --- | --- | --- | --- |
| No candidate | Cursor keeps its normal outline. The badge uses an empty tile. | Grey | None |
| Eligible target | Two thin rings and one moving shimmer arc. | Green | Low-amplitude shimmer |
| Existing assignment | Same halo with an orange tint. | Orange | One short cue only |
| Successful assignment | Keep the halo for the existing feedback interval. | Green | Use the existing 100 ms pulse |

The ring and shimmer must carry the state. Colour must not be the only signal.
Do not add a bright pulse, a large label or a halo that competes with the
lemming sprite.

The cursor badge must show the selected skill even when no lemming is eligible.
This tells the player what the next click will try to assign. The skill count
stays in the panel and remains the source for quantity information.

### Deterministic candidate selection

When more than one eligible candidate is inside the existing pick area, expose
the current candidate through the existing focus model. Add next and previous
candidate actions to keyboard and controller help if the current bindings do
not already provide them.

Candidate cycling must:

1. keep the cursor position fixed;
2. update the halo and target ID immediately;
3. use a stable order based on the resolver result and lemming ID;
4. assign only after the player clicks or activates the assign action;
5. return to normal hover resolution when the pointer moves away.

Do not show a candidate list during ordinary mouse play. Open a list only when
the player asks to cycle. This keeps the original screen clear.

### P0 implementation order

1. Extract a small target-selection result for each engine.
2. Route hover, click, keyboard and controller paths through that result.
3. Add the cursor-corner skill badge.
4. Add the restrained target halo and shimmer.
5. Add candidate cycling through existing focus and remapping paths.
6. Add settings and controls-help text only where a new action exists.
7. Test all states at 1×, 2×, CRT mode and enlarged menu settings.

### P0 exit gate

The 1.1 target feature is complete only when:

- the hover halo and the click target always match;
- the selected skill remains visible without covering the target;
- mouse, keyboard and controller input use the same target ID;
- the setting-off path matches the previous nearest-target behaviour;
- no pick radius or eligibility rule changes.

The target cue implementation uses the same glow renderer for Classic,
Lemmings 2 and Lemmings 3. Classic also keeps the established short green HDR
assignment pulse as a small target-centred flash. The sequel engines retain
their current deterministic target boundaries and do not receive a new pick
radius.
- reduced-flash mode removes added pulses but keeps the state shape;
- all three engines pass targeted tests and manual crowded-level checks;
- screenshots cover eligible, unavailable, duplicate, focused and controller states.

## P1: rewind transport

### Player-facing contract

Rewind is a transport mode, not a new game rule. It moves the current run to an
earlier recorded state. It does not assign skills, consume supplies or create a
new attempt until the player enters a new command.

Use these proposed transport actions. Confirm conflicts against the current
keyboard and controller maps before implementation.

| Action | Proposed input | Result |
| --- | --- | --- |
| Scrub backward | Hold `Z`, or use the controller rewind action | Move back through recorded states. The transport remains paused at release. |
| Stop at the current state | Release `Z` or use the controller pause action | Keep the selected historical state paused. |
| Scrub forward | Hold `.`, or use Shift + Right | Move through recorded states towards the live edge one tick at a time. |
| Step one logic tick | Shift + Left or Shift + Right | Move one deterministic tick. |
| Step one second | Controller rewind action or repeated `Z` | Move through a short time slice without replaying historical sounds. |
| Resume | Space or the normal Play action | Play from the selected state. |
| Cancel the scrub | Escape | Return to the state at which rewind started. |

When the player reaches the old live edge, normal play resumes only after an
explicit Play action. A new skill assignment or rate command from an earlier
state starts a new replay branch, as Classic history does now.

The current 1.1 slice implements the backward scrub, forward scrub, frame
stepping, origin ghost and reverse recent-effect cue for Classic. The controller
rewind modifier uses the same held transport path. The effect renderer now keeps
a short mixed ring and ducks music during transport. Lemmings 2 and Lemmings 3
now expose deterministic backward seeking through their existing input logs,
including controller hold, keyboard seek and branch truncation. Their effect
mixers now play the same short reverse tape cue and duck module music while a
held scrub is active. All three engines now show the shared compact transport
label and history-position rail. Cross-source music capture and resume
cross-fades remain open for the release gate.

The controls help must show the current time, available history and branch
behaviour. The transport must work from a keyboard, controller and visible
controls. Do not make the player hold a modifier to use single-tick stepping.

### Visual treatment

The historical state remains the primary image. The presentation adds three
small layers:

1. **Origin ghost.** Capture the frame at the start of the rewind. Draw it at
   low opacity behind the historical state. Keep it fixed so the player sees
   the point from which the scrub started.
2. **Reverse trails.** Draw two or three short, pixel-sharp trails behind
   moving lemmings. Reverse their direction and reduce their opacity towards
   the oldest trail. Use a cool bitmap palette. Do not use an HDR white flash.
3. **Transport strip.** Replace the normal speed label with a compact rewind
   state, a direction marker, a time position and a small history range line.

The origin ghost should fade when the player stops or resumes. The trails should
follow the same source-pixel discipline as the existing speed effects. The
effect must remain readable in flat and CRT modes without covering terrain,
skill counts or the target halo.

Respect the accessibility settings:

- Reduce added motion removes reverse trails but keeps the transport state and
  the position marker.
- Reduce added flashes removes transient brightness changes.
- Mute and volume settings apply to rewind audio.

### Rewind controls

For the Classic engine, hold `Z` to scrub backwards and hold `.` to scrub
forward. Release the key to leave the run paused at the chosen tick. `Shift` +
Left/Right steps one tick backward or forward, and Space remains play/pause.
The controller rewind modifier uses the same held transport path, ghost and
reversed-effects cue. Lemmings 2 and Lemmings 3 use the same LT+B held action
and provide a two-second `Z` seek. Their deterministic state adapters,
cancel-to-origin path, visual transport cue and held `.` forward scrub are now
available. Shifted frame navigation, cross-source music capture and resume
cross-fades remain open.

### Audio treatment

Use a short rolling PCM buffer of the mixed game output. During rewind, read the
buffer backwards at a rate that follows the scrub speed. Duck normal music and
effects while the scrub is active.

On stop or resume, cross-fade back to the audio state for the selected tick. Do
not replay every historical event as a burst. Do not duplicate a sound when the
player steps over the same tick more than once.

If the rolling buffer does not contain enough audio, continue with a short
low-volume tape-scrub texture. Do not loop an obvious audio fragment. The
fallback must still respect mute, volume and interruption pause.

### Rewind implementation order

1. Define a shared transport contract in the app layer.
2. Adapt `ClassicDOSRewind` to expose the history range, exact state and branch
   status required by that contract.
3. Build the transport controls and visual state for Classic.
4. Add the origin ghost and reverse trails using the existing presentation
   surfaces.
5. Add the rolling audio buffer and reverse scrub playback.
6. Add Lemmings 2 history using its recorded input and checkpoint model. **Done
   for deterministic backward seek and branch truncation.**
7. Add Lemmings 3 history using its recorded input and checkpoint model. **Done
   for deterministic backward seek and branch truncation.**
8. Run cross-engine branch, pause, retry, save and result-page checks, then
   align the remaining transport actions. **Cancel-to-origin and the shared
   visual transport cue are implemented.**

Do not place rewind controls in `NxlvKit` views. Keep engine state and seek
contracts in `NxlvKit`. Keep cursor, transport, audio and visual effects in
`LemmingsLocal`.

### P1 exit gate

Rewind is ready for a player release only when:

- all three engines support the same visible transport actions;
- every selected state reproduces the same deterministic simulation state;
- cancel returns to the exact rewind origin;
- a new command from the past creates the expected branch;
- save and restore keep the selected state paused;
- replay, records, achievements and Game Center keep their existing assisted
  run rules;
- the origin ghost, reverse trails and audio scrub remain subtle at normal use;
- reduced-motion, reduced-flash, mute and volume settings work;
- manual keyboard, controller and mouse checks pass.

## P2: hints and solution playback

After rewind has a shared contract, extend checked hints to L2 and L3. Use the
same three tiers as Classic. Keep general coaching visibly separate from a
route-backed hint. Classic checked solution replay now has pause, speed, back
one second and one-tick forward controls. Its backward and forward seek paths
now have deterministic state checks and keep the replay canvas on the replaced
session.

Add a short solution playback action that starts from the current level and
allows pause, step, speed and rewind. Do not expose a route as verified until
the current engine fingerprint and outcome checks pass.

## P3: accessibility and device evidence

Run physical Xbox, PlayStation and Switch-layout controller checks. Run complete
VoiceOver journeys through menus, target selection, rewind and result pages.
Record the macOS version, device, input path and exceptions in the release
readiness record.

## P4: later comfort work

Consider smart fast-forward to the next meaningful event after telemetry shows
that 10× speed still leaves long waits. Consider mid-level Hot Seat takeovers
only after shared attempt ownership and record attribution are defined.

Keep both features outside the 1.1 exit gate.

## Design references

- [UI principles](../../../Documentation/UIPrinciples.md)
- [Targeting design](../specs/2026-09-23-approaching-lemming-targeting-design.md)
- [Targeting implementation plan](2026-09-23-approaching-lemming-targeting.md)
- [Save and rewind integrity](../../../Documentation/SaveRecovery.md)
- [Cross-game QoL parity](../../../Documentation/ReleaseReadiness/CrossGameParity.md)
