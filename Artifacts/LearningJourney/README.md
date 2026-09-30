# Oh My! All Lemmings!

58 selected lessons from 1607 validated, deduplicated single-player candidates. 18 official levels and 40 library levels.

## Selection before ordering

The recommended journey is a selective curriculum. The complete library and original campaigns remain available separately. It has no requirement to include every official level or every validated fan level.

The first eight lessons introduce the eight basic skills once each. Later lessons need a distinct objective: change one worker’s job, split jobs between workers, plan a three-skill sequence, control spacing, coordinate work, or combine planning, timing and resource demands. A repeated tutorial is not a bridge.

One level represents each objective. Repeated assignments of the same skill collapse when detecting worker sequences. Three-skill sequences use one representative per skill set rather than every permutation. Passive levels and unassigned extra practice are omitted.

The Fun stage contains only the eight introductions. Simple combinations begin Intermediate even when their numerical demand is low. Difficult and Expert retain the existing demand boundaries. Intermediate lessons are the majority of the path. Candidates are selected for their teaching role before the existing demand model orders them. No score is altered to make the chart look smoother.

## Evidence and limits

Objectives are inferred from winning replay commands and measured profiles. They describe an observed route, not a proved necessary technique or a human difficulty rating. Geometry-specific lessons such as steel recognition and safe digging depth are not reliably detected by the current evidence. Those require authored review before claiming complete teaching coverage.

The selector retains multiplayer and port-duplicate exclusions. The generator checks each selected fan witness against its profile digest and source identity. Basic introductions, unique objectives, source coverage of the selected list and reversed-input ordering are checked.

Stages: {'Fun': 8, 'Intermediate': 35, 'Difficult': 10, 'Expert': 5}. Basic introductions: 8. Duplicate objectives: 0. Largest demand increase: 55.42/1000. Preparation gaps: 0.

## Transitions for playtesting

- 13. Thunder-Lemmings are go!: New component high: executionPrecision.
- 46. Lemmings to the aid: New component high: concurrencyBurden.
- 52. Three-way Call: New component high: constraintPressure.
- 54. It`s all a matter of timing: New component high: concurrencyBurden.
- 55. Lemming Net: New component high: executionPrecision.
- 57. Counterlogical: New component high: solutionComplexity.

A support flag remains a review request. An absent flag is not proof that a novice will find a solution obvious.

## Reproduce

Run `zsh Scripts/generate-learning-journey.sh`, then `python3 Tools/DifficultyDiagnostics/learning_report.py report`. The generator exports the eligible pool, selects distinct objectives with `curate_learning.py`, and builds the ordered journey. `curriculum.json` records the reason for every selection.

Solved and parked levels stay saved by identity. A new curriculum version rebuilds the remaining order. Removing a level from this recommendation does not remove it from the library.

## Full order

| Step | Stage | Level | Source | Lesson purpose |
| ---: | --- | --- | --- | --- |
| 1 | Fun | Just dig! | Lemmings | First assignment of the digger skill. |
| 2 | Fun | Only Float is Survive | KillerMasters Lemmings 1 Tame | First assignment of the floater skill. |
| 3 | Fun | Cellbash | Ji Hoons Lemmings Remake Heaven | First assignment of the basher skill. |
| 4 | Fun | Mienrs <--- lol, typo | Ji Hoons Lemmings Remake Heaven | First assignment of the miner skill. |
| 5 | Fun | Climin' Death Mountain | TWPAK00 | First assignment of the climber skill. |
| 6 | Fun | Blow Down! | Lemmings Plus DOS Project Mild | First assignment of the bomber skill. |
| 7 | Fun | The Broken Stair | KillerMasters Lemmings 1 Tame | First assignment of the builder skill. |
| 8 | Fun | Nuclear War on the dance floor | joem7 | First assignment of the blocker skill. |
| 9 | Intermediate | Block and Dig | brickpk2 | Assign blocker and digger to separate workers without changing their skills. |
| 10 | Intermediate | Lemmings For Presidents! | Oh No! More Lemmings | Assign basher and miner to separate workers without changing their skills. |
| 11 | Intermediate | A task for blockers and bombers | Lemmings | Change the same worker from blocker to bomber in a winning route. |
| 12 | Intermediate | Build a Bridge | JM04 | Assign blocker and builder to separate workers without changing their skills. |
| 13 | Intermediate | Thunder-Lemmings are go! | Oh No! More Lemmings | Assign basher and builder to separate workers without changing their skills. |
| 14 | Intermediate | Floating Lemming Flurry | Holiday Lemmings 1993 | Change the same worker from floater to basher in a winning route. |
| 15 | Intermediate | Blockers can block others | Deceits Lemmings Extras | Change the release rate while preparing a route. |
| 16 | Intermediate | Lemming Snowfall | Holiday Lemmings 1993 | Change the same worker from basher to builder in a winning route. |
| 17 | Intermediate | At Home in a Cave | Holiday Lemmings 1993 | Change the same worker from digger to basher in a winning route. |
| 18 | Intermediate | It'll be Comin' Round the Mtn. | Oh No More cLemmings Tame | Change the same worker from miner to builder in a winning route. |
| 19 | Intermediate | Not as complicated as it looks | Lemmings | Change the same worker from builder to basher in a winning route. |
| 20 | Intermediate | The Undiscovered Country | Holiday Lemmings 1993 | Assign digger and miner to separate workers without changing their skills. |
| 21 | Intermediate | Test map | Orig Extra Levels | Change a worker’s job and control the flow of followers. |
| 22 | Intermediate | Builders will help you here | Lemmings | Manage two working regions in one route. |
| 23 | Intermediate | Fun 08.lvl | Amiga Fun Budget | Reuse a worker by returning to an earlier job after a different assignment. |
| 24 | Intermediate | Merry Lemmings | Van Clan Tame | Change the same worker from blocker to miner in a winning route. |
| 25 | Intermediate | Mind the step..... | Lemmings | Plan a three-skill sequence on one worker: basher, builder, digger. |
| 26 | Intermediate | An "l" to serch | The lemming google pack | Change the same worker from builder to climber in a winning route. |
| 27 | Intermediate | 4 Pixels (or so) from Victory | ISteve03 | Give a permanent skill to one worker while other workers modify the route. |
| 28 | Intermediate | The Great Lemming Road | Oh No More cLemmings Tame | Plan a three-skill sequence on one worker: basher, builder, miner. |
| 29 | Intermediate | Lemm Of All Trades | TWPAK12 | Plan a three-skill sequence on one worker: builder, climber, floater. |
| 30 | Intermediate | Gather round and break away | PSP Special 27 36 | Use a blocker while two terrain-changing skills prepare the route. |
| 31 | Intermediate | Let's go camping. | Oh Yes! More Lemmings! | Change the same worker from digger to builder in a winning route. |
| 32 | Intermediate | No Salvation I | Lemmings Plus DOS Project Mild | Change a worker’s job while managing another working region. |
| 33 | Intermediate | Many Lemmings make level work | Oh No! More Lemmings | Assign bomber and builder to separate workers without changing their skills. |
| 34 | Intermediate | Float and Dig | brickpk1 | Change the same worker from miner to floater in a winning route. |
| 35 | Intermediate | Underground Exit | Pieuw02 | Complete a short route with higher measured resource pressure. |
| 36 | Intermediate | Iron Industry | Pieuw01 | Plan a three-skill sequence on one worker: basher, digger, miner. |
| 37 | Intermediate | The crystal caverns | CRISFN11 | Change the same worker from basher to digger in a winning route. |
| 38 | Intermediate | Make a choice | Pieuws Lemmings 2007 Awkward | Change the same worker from climber to bomber in a winning route. |
| 39 | Intermediate | The Lemmyrinth | MazuLems 02 | Change the same worker from climber to builder in a winning route. |
| 40 | Intermediate | Down And Out Lemmings | Oh No! More Lemmings | Plan a three-skill sequence on one worker: blocker, digger, miner. |
| 41 | Intermediate | Save the Lemmings with Floaters | PSP Special 1 10 of 36 | Change the same worker from climber to floater in a winning route. |
| 42 | Intermediate | Above The Pepsi Max.ini | grams88 | Change the same worker from builder to floater in a winning route. |
| 43 | Intermediate | Out of BASHERS??? | CRISFN03 | Change the same worker from builder to miner in a winning route. |
| 44 | Difficult | The Mountain Peaks | Oh No More cLemmings Tame | Organise a route using four familiar skills. |
| 45 | Difficult | Dangerzone | Oh No! More Lemmings | Manage several changes of job on one worker. |
| 46 | Difficult | Lemmings to the aid | CRISFN02 | Manage a route with higher measured coordination demands. |
| 47 | Difficult | Flow Control | Oh No! More Lemmings | Combine timing-sensitive assignments with release-rate control. |
| 48 | Difficult | Lets Bash That Guy! | TWPAK02 | Combine four skills under high measured resource pressure. |
| 49 | Difficult | One walked over the lemming nest | ANTHPCK3 | Combine a long single-worker sequence with a restricted skill budget. |
| 50 | Difficult | Two Pathways | Lemmings Plus DOS Project Wimpy | Combine measured timing pressure with concurrent work. |
| 51 | Difficult | Below Freezing Point | TimpackD | Control crowd spacing through a route that uses five skills. |
| 52 | Difficult | Three-way Call | GARJEN01 | Combine a high resource pressure with work across several regions. |
| 53 | Difficult | Lemmings' Ark | Genesis Mayhem | Use five distinct skills in one worker’s sequence. |
| 54 | Expert | It`s all a matter of timing | Oh No! More Lemmings | Apply the learned techniques across highly concurrent work. |
| 55 | Expert | Lemming Net | Lemmings Plus DOS Project Wimpy | Apply familiar skills with demanding assignment timing. |
| 56 | Expert | KEEP ON TRUCKING | Oh No! More Lemmings | Combine a complex multi-skill route with high resource pressure. |
| 57 | Expert | Counterlogical | Lemmings Plus DOS Project Wimpy | Carry permanent skills through a complex construction sequence. |
| 58 | Expert | Consider Everything... | Lemmings Plus DOS Project Medi | Combine long worker sequences, crowd spacing and concurrent work. |
