# Lemmings 2 native interpreter: evidence and remaining work

Status checked on 4 September 2026. **L2 is not finished.** Classic 1 now has
an input-only replay that rescues all 60 lemmings. All 120 campaign levels and
four practice levels decode their terrain and object graphics, but the player
still enables only the ten Classic levels. It implements the eight Classic
skills plus stacker and platformer; those two additions have mechanic tests,
not completed tribe-level replays.

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
  Eleven front-end banks and nine screens decode. UI script coverage is still
  partial; intro and practice are not implemented.
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
| PROCESS, `7419–7487`, `3754–3762` | Ordinary falls move three pixels per tick. Falls greater than 64 pixels are fatal. |
| PROCESS, `4e7f–4f10` | Walking can step up four pixels, not six. |
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

`Tests/Lemmings2RuntimeTests/Fixtures/classic-01.json` contains twenty timed
skill assignments for the local `LEVEL000.DAT`. The test starts the unmodified
level with 60 lemmings and its original skill supply. It only calls normal
skill assignment and simulation ticks: no teleports, terrain patches,
population changes, forced wins or nuke.

Expected result: **60 saved, 0 lost, 2,878 ticks**, with all twenty inputs
accepted. It also checks the exact remaining skill inventory and survivor
carry-forward to Classic 2. A result from Classic 1 must be rejected when
Classic 2 is selected.

Separate tests check the original brick's six coloured pixels, the digger's
nine-pixel cut, action-frame timing, miner movement phases, exploder timing,
steel preservation, and entrance timing. Synthetic tests need no game assets.

This is a regression replay for our native interpreter, **not yet a matching
DOS replay**. In particular, its climber and blocker interactions still depend
on provisional collision behaviour. Passing it must not award a verified
original-engine achievement.

## Work still required to finish L2

1. Complete the remaining 41 stocked skills, including fan-controlled flight,
   aimed skills, projectiles and material pouring. The airborne arithmetic
   helper is not yet connected to full collision handling.
2. Implement cannons, trampolines, catapults, chains, launchers, teleports,
   switches, tubes, ice and triggered traps. Decoding their graphics does not
   implement their behaviour.
3. Match full collision and assignment rules against the original: climbing,
   blocking, steel tags, exits, object state, bounds and frame-transition order.
   The current state machine is not yet a complete 1:1 engine.
4. Verify complete solutions for Classic 2–10 and the other 110 campaign levels.
   Tests that merely load levels or touch isolated exit triggers do not count.
5. Finish the original front-end scripts: intro, practice, preferences, exact
   map hit regions, medal/talisman presentation and the final ending. Campaign
   model tests cover all twelve tribes and ending eligibility, but a state-only
   fixture is not a completed campaign or a verified ending.
6. Finish sound events for the remaining skills and objects, fan/aiming UI, particle effects, remaining sprite
   mappings, rewind and asset-quality selection across ports. Module music is
   connected; original DOS music sequencing is not. Integrate verified campaign
   completion with the all-in-one achievements only after matching replays exist.

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
