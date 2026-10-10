# Lemmings 2 native interpreter: evidence and remaining work

Status checked on 10 October 2026. All twelve tribes, 51 skills, 15 object types
and four practice maps are enabled. The strict completion gate verified all 120
winning routes and 70 carry-over variants twice, with continuous ten-level
chains for all twelve tribes. The focused runtime check passed 52 synthetic
regression checks; this does not claim a fresh pass of the full data runtime suite.
See the [completion evidence](Lemmings2Completion/README.md) for the current
route proof and validation limits. **Original-engine equivalence and release
validation remain separate work.**

## Expansion corrections

- L2 `178f–183d`: X-relative is bit `80`, Y-relative is bit `40`. Repeated
  components use record deltas and the preceding component position, not sprite
  dimensions. This fixes rails, steel and trigger placement.
- PROCESS `7dc3–7dd1`: asymmetric geometry bytes are left then right. Correcting
  Scooper's origin keeps its first mask in front of the feet and allows sustained
  digging. Original-mask tests now verify two complete cycles in both directions.
- PROCESS `3d87–3f55`: cannon and catapult loading paths, delays and launch speeds.
  Rail buttons move the mechanism and rider together; held input repeats per tick.
- PROCESS `0605–063d`, `06be–06f8`, `3d0a–3d86`: linked valves and paired teleporters.
- L2 `3f37–3fd9`: opening, holding, closing and reversing timed-trap phases.
- PROCESS `914d–93a3`, `948b`: chain swing, fan force and released-rider velocity.
- PROCESS `a7ae–a865`, `b7cb`: aimed-projectile normalization and four-pixel hook
  tips. Ropes follow the hook's path and retain anchored hook terrain.
- Fixed Swift shift precedence in fan and chain multiplication. Tests check
  numeric force as well as visible movement.
- Pointer movement updates aim without a click. Mouse release preserves position;
  pause, leaving play and loss of window focus release held controls.

## September 7: Stomper milestone

Stomper (skill 29) now uses MASKS animation 3. PROCESS 6579–65c6 increments
an eight-frame cycle, checks steel at frame 7, cuts the native mask at
`x - 8, y - 6`, then descends two pixels. An empty foot probe starts a fall.
The steel probes are `(-3, 0)` and `(3, 0)` relative to the common probe origin.
The native mask clears ten pixels across. The LM1D bank contains eight frames,
without a separate left-facing bank. Its sprite anchor follows the vertical
offsets at PROCESS 65cf without moving the collision position.

Synthetic and native-mask tests cover both directions, first and repeated
cuts, unchanged terrain before frame 7, steel, floor breakthrough, rejected
midair/repeated assignments and switching to another terrain skill. The existing
Classic 1 replay at this milestone rescued 60 in 2,878 ticks. Full original-engine
traces and assignment-rule comparisons remain required. Later work recorded
winning routes for every non-Classic level. No additional tribe was enabled by
this milestone.

[Campaign requirements](Lemmings2Coverage.md) lists missing stocked skills and
object types across all 120 levels. Regenerate it with the development tool
`Tools/Lemmings2Reference/coverage.swift`, linked against the current NxlvKit.
Jumper, airborne collision and the additional tribe mechanics received later
corrections. All twelve tribes now have complete solution chains; see the
[current completion evidence](Lemmings2Completion/README.md).

## What changed

- Medieval 7 and 8 now render. Their map words include metadata above the
  ten-bit tile index; they are not corrupt tile references.
- L2SS special object graphics now decode alongside regular tile animations.
  All 221 regular and 18 special animations across the twelve styles decode.
  Signed frame anchors, transparent skips and opaque black pixels are retained.
- The same bounds-checked pixel interpreter reads VLEMMS, MASKS and INTERN.
  The Classic player now requires the original terrain masks. It no longer
  substitutes rectangles or a circular explosion for those assets.
- Builder, basher, miner, digger and Classic exploder action phases follow the
  original routines listed below. Falling speed, the safe fall threshold,
  walking step height, floater descent and release spacing were also corrected.
- The player uses native working-sprite anchors and directional frame banks.
- Stacker and platformer now use their native INTERN masks, action phases,
  directional alignment, collision probes and continuation rules.
- The original menu, font and in-game panel replace the developer button strips.
  Eleven front-end banks decode. The original intro, talisman award and ending
  scripts now run, and practice is connected.
- A separate twelve-tribe campaign model now applies original medal rules,
  best-survivor carry-over, unlocks, autosave and eight manual save slots.
- Local app builds embed the game assets and music. Launching no longer needs
  a folder picker or the source checkout. Embedded progress survives app moves.
- Progress version 3 excludes results made with the old terrain physics.
  Earlier preferences are retained, not deleted. A run's level-file SHA-256
  must match the selected campaign level before its result can be recorded.

## Original-code evidence

The local DOS release contains relocatable overlays with symbol names.
`Tools/Lemmings2Reference/rko.py` reads their headers and can disassemble a
bounded range with Capstone. It is a development tool only. The Swift player
neither loads nor executes these overlays. No original code or game assets
are included in the new source or replay fixture.

Offsets below are relative to the overlay code segment, before relocation.

| Overlay and offset | Observed rule implemented |
| --- | --- |
| VGA, `0269–026e` | Swap the map word's bytes and mask the tile number with `03ff`. Preserve the upper bits separately. |
| VGA, `2a09–2a4e` | Interpret both command nibbles independently: 1–7 copy pixels, 8–15 skip 0–7. A low zero ends a row. This includes E1, which the earlier reader rejected. |
| PROCESS, `5b97–5c08` | Digger uses MASKS animation 7 on frames 8 and 0 of a 16-frame cycle, then descends one pixel. |
| PROCESS, `5c15–5cb0` | Builder places INTERN animation 13 on frame 9. Frame 0 moves two pixels forward and one up. Twelve bricks take 192 ticks. The left-facing brick is offset four pixels left. |
| PROCESS, `5cb1–5dbb` | Basher has a 32-frame cycle. Cutting occurs on frames 2–5 and 18–21; movement occurs on 11–15 and 27–31. MASKS animation 5 contains separate directional masks. |
| PROCESS, `5dbc–5e68` | Miner cuts with MASKS animation 2 on frames 1 and 2. It moves on frames 3 and 15 and descends again on frame 0 of a 24-frame cycle. |
| PROCESS, `824a–8291`, `5fcc–6033` | Classic exploder has a 75-tick countdown, followed by an animation. Frame 15 applies MASKS animation 8; the lemming is removed after the particle interval. |
| PROCESS, `7419–7487`, `3754–3762`, `7572–7581` | Ordinary falls move three pixels per tick. Falls of up to 64 pixels resume walking; falls of 65–99 pixels stun; longer falls are fatal. |
| PROCESS, `4fe4–4fef`, `548b–5496`, `721c`, `3736–3753`, `37c7–37d5`, `8552–8605` | Jumper, Hopper and Shimmier jump body collisions check Rock Climber, Climber, then Slider before reflection. Rock Climber requires seven clear pixels behind the head. A Slider catching from Jumper or Shimmier jump steps back and turns; Hopper keeps its direction. |
| PROCESS, `85be–8605`, `7401–7418`, `4e31–4e69`, `3cdf–3d0b` | Assigning Rock Climber sets flag `0200` without changing state. Entry from Walking or climbing transfer scans the rear column at `x − direction`, from foot minus one through foot minus seven. A solid pixel causes one backward step and a turn, retaining the previous state and phase. Clear entry selects state `2a` and clears byte `22`. |
| PROCESS, `4e7f–4f10` | Walking can step up four pixels, not six. |
| PROCESS, `4e0a–4e50`, `88dc–88e7`, `3b67–3b87` | Walking uses byte `22` as a turn marker. A second blocked step enters state `107` after two pixels in the current direction: the step at `4e7f` stored by `4e12`, then the step at `4e48`. Its initializer changes state and sprite without moving. State `107` rises one pixel per tick until the foot is clear, restores one pixel, then resumes walking. Successful walking clears the marker; Runner keeps its separate turn routine. |
| PROCESS, `0997–09f8`, `0710–0749` | Classic blockers paint a three-column field in four-pixel cells. The shared update tail changes direction after each skill update and preserves the active skill. |
| PROCESS, `4c94–4cbf` | Kayaking checks for a dry shore before solid contact. A dry solid bank uses the nine-pixel exit step; a solid contact inside water uses the one-pixel step. |
| PROCESS, `aa68–aab8`, `b08d–b2f1` | Thrown stones sweep along the major axis and test offsets `(2,0)`, `(4,2)`, `(2,4)` and `(0,2)` from each new origin. Collision stamps INTERN animation 7 at the returned origin. The first three vertical-path probes share the horizontal reverse-step branch at `b1c5`; the fourth uses `b2da`. Focused checks preserve these branches and the zero-distance case. |
| PROCESS, `5e69–5ef5` | The floater has an opening sequence with an upward tug, then descends two pixels per tick. |
| L2, `14eb–14f6`; PROCESS, `00ed–0200`, `023b` | Release interval is `21 - setting`. Classic waits 20 ticks, plays ten entrance frames, then counts down to its first release. With setting zero, release ticks are 51, 72, 93, and so on. |
| L2, `034b`, `0480`, `04a0`, `04b8`, `0694–069c` | Initialize the countdown to 15 and decrement once per simulation tick, including each extra fast-forward step. One displayed second is fifteen ticks. |
| PROCESS, `8390–83d6`, `6b41–6bc5` | Stacker alternates its two INTERN 3 masks at phases 7 and 23, rises at 11 and 27, turns at 12 and 28, and stops after twelve half-cycles. |
| PROCESS, `8404–845c`, `6c06–6cdf` | Platformer uses INTERN 4, a 22-frame lead-in and a repeating 16-frame brick cycle. Fresh work and continuation from the platformer shrug have different initial counters. |

The special graphics reader follows the published
[L2 style format investigation](https://www.camanis.net/lemmings/files/docs/lemmings_2_style_file_format_l2gfx.txt).
The local banks also contain an optional zero padding byte after an odd-length
L2SS section. Pointers still omit each sprite entry's two-byte size word.

## Repeatable completion check

Run:

```sh
zsh Scripts/run-lemmings2-runtime-tests.sh
zsh Scripts/run-sequel-data-tests.sh
zsh Scripts/build-native-l2.sh
```

`Tests/Lemmings2CompletionTests/Fixtures/classic-01.json` contains twenty timed
skill assignments for the local `LEVEL000.DAT`. The test starts the unmodified
level with 60 lemmings and its original skill supply. It only calls normal
skill assignment and simulation ticks: no teleports, terrain patches,
population changes, forced wins or nuke.

Expected result: **60 saved, 0 lost, 3,074 ticks**, with all twenty inputs
accepted. It also checks the exact remaining skill inventory and survivor
carry-forward to Classic 2. A result from Classic 1 must be rejected when
Classic 2 is selected.

Separate tests check the original brick's six coloured pixels, the digger's
nine-pixel cut, action-frame timing, miner movement phases, exploder timing,
steel preservation, and entrance timing. Synthetic tests need no game assets.

This is a regression replay for our native interpreter, **not yet a matching
DOS replay**. The source-backed climber and blocker corrections listed above
do not establish complete original-engine equivalence. Passing it must not
award a verified original-engine achievement.

## Further native corrections

- L2 `18e8–19ad`: ordinary object tiles replace underlying terrain; special
  sprites remain overlays. Non-solid object tiles clear their full area. This
  fixes buried exits in Beach 2/4, Outdoor 6/8 and Sports 6.
- PROCESS `03ef`, `0752`, `3af2`: exit detection follows the skill update;
  rescue completes after the tribe animation frame count.
- PROCESS `5534–58aa`, `6984`: Roller slope history and contact probes; the
  downward probe returns the air pixel immediately above the first solid pixel.
- PROCESS `3949–3a24`: Jet Pack resolves and reflects horizontal and vertical
  collisions separately.
- PROCESS `ba2b–baa8`, `bbe0`: skill assignment permissions. The hanging
  Shimmier transition follows `8627–867a`.

## Further verification

1. Verify routes to the ark ending, which requires a golden talisman and at least
   30 survivors from each tribe. The recorded chains finish with one survivor.
2. Broaden roof-edge transfers and complete movement-path comparisons against
   the original engine.
3. Verify remaining visual effects. The original intro, award and ending scripts
   now pass their full script and rendering checks.
4. Extend live checks of the signed distribution to additional supported Macs.

## Panel, selection and sound regression fixes

- L2.RKO 3077 names the controls in physical order: pause, nuke, fan, fast forward.
  The previous player had nuke and fan swapped. The input path now preserves the
  native mouse double-click count and timestamp. Other controls and playfield
  clicks cancel an armed nuke. PROCESS 03b0 starts one 75-tick countdown per tick.
- VGA.RKO 3397 supplies palette entries 128–147. Entries 145–147 are the native
  yellow/red outline, cycled by 36f6. Copying only the first sixteen colours hid
  the selection border. POINTER.DAT contains eighteen four-plane 16×16 pointers:
  crosshair, selection box and sixteen fan directions.
- MUSIC/SBLAST.VOC has 128 offset entries and eighty Creative Voice clips. The
  PCM reader preserves each sample rate and supports continuation and silence
  blocks, including the final multi-block voice and its alignment byte.
  The sound bridge does not execute SBLAST.BIN.
- L2.RKO 4877 maps FXNumber to voice index. Verified events include assignment
  (PROCESS ba8b, sample 21), explosion (601b, sample 11), entrance cues (0102/0134,
  samples 18/10), steel (386b, sample 8), fall (049c, sample 17), water/fire/splat
  (8881/88ab/88bd, samples 37/35/27), and construction warnings (sample 33).
  Panel clicks use sample 49 and the twelve pitch values at L2.RKO 486b.
- Tests cover hit-region edges, double-click cancellation and timing, eligible
  overlap selection, staged nuking, one-shot sound delivery, all eighty clips,
  mixed audio output, mute/reset, palette cycling and malformed data.

## Presentation sound supplements

The 8 October development source adds a Yippee when each exit animation
actually completes, a trampoline bounce when the actor launches, and a trap
trigger when an ordinary or timed trap captures it. The rescue uses the bundled
Yippee recording when available, with a generated fallback for previews.
Trampoline and trap effects are short generated supplements. They stay
separate from the verified `SBLAST.VOC` indices. Original sample identities for
these added events still need evidence; no numbered clip is assigned by guess.

Every rescue keeps its own voice, including simultaneous exit completions.
Rescue layers retain normal gain and independent playheads when the spatial
pool fills. They have no crowd-dependent attenuation or repetition gate.
Player volume, mute and distance attenuation still apply. Assignment and
warning cues retain priority alongside the chorus. The original panel pitches,
construction warning and verified native sample bindings remain in use.

The final-seconds warning uses a distinct shared timer effect. Rejected skill
actions on a real target get the shared refusal cue. Fresh starts and retries
play Ready only when the visible countdown completes; Hot Seat waits for the
next player's Ready action. These cues use the current sound volume, mute,
suspension and replay capture paths.

Muted runtime, bank and spatial checks cover the new causal events, concurrent
rescues, overflow, capture, priority and repetition rules. These presentation
checks do not establish original-engine audio parity or validate additional
campaign solutions. Original sample mapping and audible listening remain
separate work. The existing talisman animation retains its own verified
fanfare callback.

## Ceiling transfers, effects and nuke corrections

- PROCESS `7401` probes the starting pixel and then decrements its counter.
  Jumper/Hopper (`7eaa`, `800d`) require ten clear pixels. Shimmier (`867b`)
  requires eleven. Diver (`845d`) has no launch headroom test.
- PROCESS `724d–73ba`, `8b19–8b4e`: Shimmier movement probes the next pixel.
  Roof-edge transfer starts three pixels behind the previous foot position.
  Climbing transfer searches five support pixels. Obstructions transfer to
  hanging or the Slider's descent pose instead of dropping immediately.
- PROCESS `0a97–0acb`: non-Classic nuke countdowns trigger a blast and remove
  the actor immediately. Classic uses its separate explosion animation.
- PROCESS `0b6b–0bba`, VGA `3b32–3be6`: the Classic blast has one flash frame,
  then 52 frames of 80 signed particle positions. The bundle extracts these
  animation bytes to `EXPLOSION.DAT`; executable overlays remain excluded.
- PROCESS `ba79–ba91`: assignment-specific effects override the generic cue.
  Jumper, Superlem, Surfer and tribe Attractors now select their native samples.
  Balloon contact plays its pop, and an Archer shot plays its firing cue.
- The Outdoor 7 replay now completes at tick 4051 after rejecting its former
  low-ceiling Shimmier assignment. Beach 1 and Highland 9 add durable full-level
  completions with exact pointer and skill inputs.

## Wall-climbing corrections

PROCESS `403e–4092` moves a Climber on four frames of an eight-frame cycle.
The actor enters at the wall pixel, checks the wall top during the other four
frames, and moves two pixels away when blocked above. The former implementation
climbed every frame and stepped straight into walking at the top.

PROCESS `7056–7146` transfers Rock Climbers to hanging at excessive overhangs.
The support position and direction now survive that transition. Tests cover
both directions, straight walls, top transfers and ceiling collisions.

The Classic 1 replay retains all 60 survivors. Its final three assignments to
lemming 9 moved 136 ticks later to match the corrected route. Completion occurs
at tick 3074. Later corrections required other route changes; the
[completion evidence](Lemmings2Completion/README.md) records the current set.

## Original introduction and ending

The native GAL interpreter runs the eight scenes selected by L2 0785–0802.
Regression checks cover all 3902 updates and the original intro sound callbacks.
Font colours add the original palette offset to each nonzero glyph pixel
(BOBS 1258–1297); viewport sprites retain the original window translation.

VGA 4c27–4d27 defines ARK.ANM run-length and previous-frame copy commands.
The decoder consumes the full file as 100 four-plane frames with no trailing
bytes. Both the retry result and five-page ending scripts pass click-through
checks. The original TOUGH message specifies a golden talisman and at least
half of each tribe; the campaign now checks both requirements. Rendered ending
pages, captions and ark frames were inspected. These are front-end checks,
not proof of completing the campaign through gameplay.

VGA 2074 selects sixteen position-dependent walker drawing routines. The asset
preparer decodes their constant pixel writes into WALKER.DAT. PROCESS 4e1f–4e2d
selects the pose from `(x - 2) & 7` and direction. Original executable code is
excluded from the app bundle.

The original AWARD.GAL also assembles existing talisman pieces and animates a
new piece, including its original fanfare callback. Empty, complete and new-piece
states were rendered and inspected. Register-selected frames and palettes retain
the original medal colours.

Circus 1 completes from 60 entrants with two rescues at tick 8100 using fourteen
recorded assignments. Its carry-over route completes Circus 2 with both
survivors at tick 1218 using eight assignments. Sports 1 completes from 60
entrants with two rescues at tick 8100
using four assignments. These fixtures supplement the existing gameplay checks.

Polar 1 rescues all 60 at tick 1829. Medieval 1 rescues two from 60 at
tick 5400 with recorded fan-assisted Icarus routes. Shadow 1 rescues one from
60 at tick 2149, crossing the upper corridor and returning to the lower exit.
The fixture collection covers all 120 levels across all twelve tribes, with
70 separate carry-over variants. All twelve ten-level chains pass the strict
[completion gate](Lemmings2Completion/README.md).

## Replay input validation

Recorded solution inputs now obey the app's single-pointer controls and camera
bounds. Changing skills releases the fan and restarts its hold time. Five
fixtures originally needed new timings or routes under these rules. The current
strict completion gate passes all 120 routes and 70 carry-over variants twice.
Highland 1 saves all 60 at tick 1941. Classic 2 and 5 have recorded routes,
and the full input suite checks fixture names against the source fingerprints.
The save-slot list validates progress before looking up tribe names, so damaged
save data cannot crash the load or save screen.

Twelve full-duration input schedules now pass 5,445,815 simulation ticks across
all 120 levels and exercise all 51 skills using those same app control rules.
