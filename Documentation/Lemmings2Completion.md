# Lemmings 2 completion work

Requested outcome: all twelve tribes and all 120 campaign levels playable,
with working skills, objects, controls, audio, progression and ending.
All campaign content is enabled in the native beta. Full walkthrough coverage
and original-engine equivalence are not claimed.

## Current work

The local universal app and signed beta 8 archive include the twelve-tribe
expansion. Apple notarization, ticket validation and the extracted ZIP
Gatekeeper check passed. See [release verification](Beta8Readiness.md).

- Added the tribe digging tools, Jumper, Runner, Hopper and blast Bomber.
- Added native trap, launcher and trampoline state and multiple entrances.
- Added Swimmer, Kayaker, Parachuter, Ballooner, Icarus Wings and Hang Glider.
- Added Attractor, Filler, Sand Pourer, Glue Pourer, Planter and Rock Climber.
- Added Bazooka and Mortar projectile motion, aimed rope terrain and Diver.
- Added Shimmier, Roller, Jet Pack, Twister, Skater, Slider, Magic Carpet,
  Surfer, Thrower, Spearer and Magno Booter. Ice includes ordinary slipping.
- Added hanging and climbing transfer states, plus native thrown-object terrain.
- Added Pole Vaulter, Skier, Archer and Superlem, plus chains, moving cannons,
  catapults, timed traps, valve switches and paired teleporters.
- All 120 campaign levels load and advance through a 180-tick smoke check.
  All twelve tribes are now enabled by the native constructor.
- Corrected the object loader's X/Y relative flags and repeated-part steps.
  Corrected fixed-point fan multiplication and asymmetric sprite origins.
- Practice offers all 51 skills across the four original training maps and cannot
  write campaign results. Pointer aim and held-control release are connected.
- Roper now follows a moving hook with native aiming tables, collision tips
  and anchored hook terrain. Ski landings retain horizontal momentum.
- Added fan press/drag/release input, terrain particles, native beam and flame
  effects, balloon and parachute graphics, and tribe attraction animations.
- Classic 1 retains its 60-rescue replay at tick 3074. Cavelem 1 completes with one rescue
  at tick 1632 after the object-placement correction. Cavelem 3 retains its
  one-rescue replay at tick 555. Cavelem 2 now completes at tick 1337 with three Stompers and two Scoopers
  after correcting its mask origin.
- Fixed native object tile replacement, including five buried exits. All 120
  campaign exits now pass isolated rescue checks. Exit animations use the
  original tribe artwork and frame counts.
- Added the original assignment permissions, including Roller and Skier skill
  changes and Shimmier assignment while hanging.
- Corrected Skier ground probes, Roller slope history, and Jet Pack axis
  reflections. Camera movement now updates the pointer aim.
- Sixty-four recorded completions cover all twelve tribes. The fixtures use 60
  entrants, except for the one-survivor Cavelem and Circus carry-over checks.
  The [coverage table](Lemmings2Coverage.md) lists the exact levels. Inputs use
  one pointer within the visible map bounds and restart fan holds when changing
  skills, matching the app controls.
- Twelve schedules across all 120 levels passed 5,445,815 full-duration
  simulation ticks and exercised all 51 skills. These schedules use the app's
  pointer bounds, single-pointer input and fan reset rules.
- All 22 beta suites pass, with the runtime and original script suites also
  passing under Rosetta for Intel. All 106 eligible replay checks at one or
  thirty entrants pass.
- Synthetic and original-data mechanics checks cover the new work. Full
  campaign completion is not yet verified. Complete movement paths
  still require broader comparison.
- Corrected ordinary Climber cadence, wall contact and top transfers, plus
  Rock Climber overhang handling. Classic 1 still saves all 60 after adjusting
  its final three assignment times.
- Corrected Shimmier roof-edge and obstruction transfers in both directions,
  including transitions to Climber, Rock Climber and Slider. Native clearance
  tests distinguish Jumper/Hopper, Shimmier and Diver. Outdoor 7 has a new
  successful replay under these rules (one rescued at tick 3990).
- Corrected non-Classic nuke timing, skill-specific sound selection, original
  explosion particles, blast flashes and the visible bomb countdown.
- Live app checks cover practice portraits, all-skill grid selection, keyboard
  navigation, pause, skill assignment, practice resume and campaign navigation.
  The rebuilt app also passes live intro/skip/gameplay, walker rendering and
  talisman navigation checks.
  Long briefing titles now fit above the population count and timer.
- Empty skill slots no longer fail native level loading.
- The original eight-scene introduction runs through a native GAL data
  interpreter, with original palettes, captions, viewport effects and sound
  callbacks. All 3902 script updates pass regression checks.
- The original ark departure movie decodes all 100 frames. Both the retry
  result and five-page ark credits use their original GAL scripts. Ending
  input tests include early clicks; rendered captions and credits were checked.
- The ark ending requires a golden talisman and at least thirty survivors
  from every tribe. Other completed campaigns remain available for replay.
- Added the original talisman assembly, medal colours and award fanfare.
- Extracted the original sixteen walker images from the reference drawing
  layout. The app reads image data and selects poses by position and direction;
  it does not include or run the original executable renderer.

A successful decode or synthetic fixture is not proof that a campaign level
is completable. The BETA label describes the available implementation; it does
not certify all 120 walkthroughs or exact original-engine behaviour.

## Further verification

- Broaden advanced movement and complete-level solution checks.
- Verify object trigger ordering and complete their visual effects.
- Verify complete solutions across all 120 campaign levels.
- Verify survivor carry-over, medals, save/load, final talisman and ending.
- Continue live front-end checks on supported macOS versions.
- Verify original sound events and complete player-facing rendering.
