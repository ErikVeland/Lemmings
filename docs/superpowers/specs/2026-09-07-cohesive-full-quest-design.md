# Cohesive Full Quest

Date: 2026-09-07
Status: approved, not implemented
Scope: program design. Each phase gets its own spec and plan.

## Context

Full Quest chains all eight releases through three engines in one window. The
chain works. `main.swift` line 658 routes the Lemmings 3 title into
`openNativeL3()`, and both sequels attach into the shared window. The
experience does not hold together.

The app says so itself. `main.swift` line 647 badges Lemmings 3 as "PREVIEW"
while the other titles show a completion count. A player leaves the Lemmings 2
front end, with its original artwork, music, and sound, and arrives at a window
of `NSPopUpButton` controls, an "End run" button, a status label, a notice that
reads "Experimental physics, tool limits and animation mapping", and silence.
Lemmings 3 plays no sound at all. No sound player exists for it.

Three tiers exist today. Lemmings 1 and its extras are a finished port.
Lemmings 2 is a credible beta with a full front end and audio. Lemmings 3 is a
working engine inside a debug harness.

## Goal

One coherent modern experience across the three engines. The player should feel
one product that grows in ambition from 1991 to 1994, not three programs that
share a window.

## The convergence boundary

This is the rule the whole program depends on.

| Layer | Converges | Notes |
| --- | --- | --- |
| Shell | Yes | One library, briefing, results, pause, and settings |
| Camera and input | Yes | One `GameViewport`, one keymap |
| Artwork | Yes | One Macintosh 2x bank contract, one drawing path |
| Panel and HUD | Placement only | Each game keeps its own authentic panel art |
| Audio | Yes | One cue vocabulary, one music policy |
| Meta rules | Yes | Retry, nuke, save, progress, medals |
| Shared mechanics | Case by case | Only where evidence shows the difference is not original |
| Simulation | No | Physics, tick rate, and skills stay authentic per engine |

The simulations keep their own tick rates of 17, 17.5, and 23 ticks each
second. They keep their own skills. They keep their own level rules. This
program changes nothing that a replay or a test fixture depends on.

Target selection is input, not simulation, even where a runtime type holds it.
`Lemmings2Runtime.target(slot:x:y:)` picks which lemming a click means. It does
not decide what happens next. `assign` does that, and it takes an id. Replays
call `assign` with an id and never call `target`, so a change to target
selection cannot change a replay. Phase 4 may unify target selection. It may
not touch `assign`.

## Evidence rule

A difference between engines gets unified only after evidence shows the
original games did not differ. Each entry in the divergence audit carries a
verdict of "unify" or "authentic", and the reason.

Three entries exist already.

**Cursor targeting. Verdict: unify.** The three engines use three rules.
Classic `PlayfieldView.lemming(at:)` requires strict containment, does not
snap, and gives the last drawn lemming priority. Its comment argues against the
alternative. It says that picking the nearest lemming inside a radius looks
like the cursor sticks to a lemming it is not over, and that two lemmings side
by side become impossible to tell apart. `Lemmings2Runtime.target(slot:x:y:)`
does the rejected thing. It searches a box of plus or minus 9 by plus or minus
12, prefers an eligible lemming, then sorts by Manhattan distance, then by the
lowest id. `Lemmings3PlayWindow.assign(x:y:)` uses the same box with a
different anchor of `y - 8` against `y - 5`, prefers a carrier, and checks no
eligibility. Nothing in the original games explains the split between Lemmings
2 and Lemmings 3.

**Release rate. Verdict: authentic.** Classic holds `releaseRate` as mutable
state and logs a `releaseRateChanged(Int)` replay action, because the player
controls it. Lemmings 2 computes `21 - level.releaseRate` once. Lemmings 3
takes `level.releaseRate` once. Neither exposes a control, because the original
sequels removed the rate buttons. Leave this difference in place.

**Nuke. Verdict: unify.** Classic has `beginNuke()`. Lemmings 2 has `nuke()`.
Lemmings 3 has no nuke in the runtime or the window. The original Lemmings 3
panel carries a nuke button. The decoded `PAN004.RAW` shows it.

## Phases

Each phase produces its own spec and implementation plan.

### Phase 0. Foundations

1. Amend the shared camera spec for artwork scale and zoom snapping. Done.
2. Build `GameViewport` and adopt it in all three engines.
3. Unify the keymap. The three maps differ today. Classic binds `z` to rewind,
   `,` and `.` to step, `n` to next, `p` to pause, and `x` to nuke. Lemmings 2
   has no step, no rewind, and no key for nuke, because nuking needs a double
   click on the panel. Lemmings 3 has `.` for step and no rewind, and `Escape`
   opens an end-run sheet where Lemmings 2 returns to the menu.
4. Write the divergence audit document. Seed it with the three entries above.

Fast forward also needs one value. Classic and Lemmings 2 use three times.
Lemmings 3 uses eight times. The data gives no reason for the difference.

### Phase 1. Coherent shell

1. One library, briefing, results, pause, and settings chrome for all three.
2. A real Lemmings 3 front end from the 32 unused files in `FRONT/`.
3. Show the five decoded `.FLI` movies, which `FLICMovie.swift` already reads.
4. Remove the "PREVIEW" badge and the experimental-physics notice.

### Phase 2. Presentation parity

1. The authentic Lemmings 3 panel from `PAN00X.RAW`, the cursor from
   `POINTER.RAW`, and the font from `FONT.DEL`.
2. The widescreen gutter for level name, time, counts, and tool inventory.
3. The shared minimap in the gutter for all three engines.
4. Adopt the Macintosh 2x sets for Lemmings 2 and Lemmings 3.

The panel formats are already proven. `.DIN` is a `u16` length table and `.DEL`
holds the records end to end. The sums match on all 14 files. `PAN00X.RAW` uses
the mode-X four-plane layout that `Lemmings3Sprites.swift` already reads.

### Phase 3. Audio

1. A Lemmings 3 sound bank from `AUDIO/SFX001.IND` and `SFX001.RAW`.
2. Bind cues to runtime events, as `Lemmings2SoundPlayer` does.
3. One cue vocabulary across the three engines.
4. One music policy, including the adaptive mixer.

### Phase 4. Rules coherence

1. Apply each "unify" verdict from the audit.
2. One targeting rule for all three.
3. Nuke in Lemmings 3, wired to the panel button that already exists.
4. Consistent retry, pause, and step.
5. Shared save slots. Lemmings 3 uses one `UserDefaults` value for each tribe
   today.

### Phase 5. Modern quality of life

1. Rewind in all three engines.
2. Consistent progress, medals, and achievements.

Rewind is the largest item and stays last. Classic logs discrete commands and
replays them forward. Lemmings 2 cannot work that way, because `setAim` and
`setFan` carry continuous pointer state for each tick. A discrete log cannot
rebuild that. Lemmings 3 is closer to classic and ports cleanly.

## Dependencies

The Macintosh 2x sets for Lemmings 2 and Lemmings 3 are in progress outside
this plan. The plan assumes they follow the `ClassicMacArtwork` contract. That
contract holds RGBA frames with origins, palettes, and object sequences. The
simulation stays at 1x and the artwork multiplies. If the sets differ, only the
adapter changes. The architecture does not.

Phase 2 artwork adoption cannot start before the sets arrive. Every other item
in every phase can proceed without them.

## Testing

Each phase adds a harness under `Tests/` and a script under `Scripts/`, as the
repository already does for each area.

Run these as a regression pass after each phase: `run-unified-game-tests.sh`,
`run-playfield-draw-tests.sh`, `run-lemmings2-runtime-tests.sh`,
`run-lemmings3-runtime-tests.sh`, and `run-classic-dos-replay-tests.sh`.

The replay tests are the guard on the convergence boundary. If a change breaks
a replay, the change reached the simulation and the program says it must not.

Golden screenshot tests need new reference images after Phase 0, because square
pixels change the Lemmings 2 output and the scale divisor changes the Lemmings
3 output.

## Risks

| Risk | Response |
| --- | --- |
| A coherence change reaches a simulation | Replay tests fail. The convergence boundary makes this a defect, not a tradeoff |
| A unified mechanic erases original behavior | The evidence rule. Release rate is the first case it caught |
| Macintosh sets arrive in a different format | Only the adapter changes. Phase 2 artwork is the sole item that waits |
| Removing the preview label overstates readiness | Phase 1 removes the label only after Phase 1 gives Lemmings 3 a real front end. Solution coverage claims stay separate |
| The program stalls halfway and leaves a mixed experience | Each phase ends in a shippable state. No phase depends on a later one |
