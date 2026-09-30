# Oh My! All Lemmings!

1609 distinct single-player levels: 317 official puzzles and 1292 replay-validated library levels from 294 packs.

## Ordering

The path progresses through Fun, Intermediate, Difficult and Expert. A hard timing, coordination or planning demand cannot be cancelled by easy dimensions in a weighted average. Official levels take priority within comparable demand bands. Retail rank and campaign order do not determine placement. All Oh No! levels are interleaved with the rest of the pool.

Stages: Fun 84; Intermediate 292; Difficult 930; Expert 303. Largest upward curriculum-demand step: 48.00/1000. Transitions requiring review: 2; missing basic-skill preparation: 0.

| Stage | Steps | Teaching focus |
| --- | ---: | --- |
| Fun | 1–84 | Single skills and simple combinations |
| Intermediate | 85–376 | Skill combinations and crowd management |
| Difficult | 377–1306 | Longer plans and tighter resources |
| Expert | 1307–1609 | Precision, complex plans and coordination |

Curriculum demand is the maximum of the unchanged evidence score, 0.85 × technique, precision, concurrency and deduction, 0.70 × solution complexity, 0.50 × constraints, and 90 × additional concepts. A combination also waits for its easiest available isolated skill lessons. These weights and the stage thresholds (180, 360, 600) are editorial estimates, not player-calibrated difficulty measurements.

Within each stage, 35-point bands allow spaced practice and small relief steps. Selection favours prepared combinations, avoids consecutive identical technique sets when comparable alternatives exist, and reduces upward component changes. Two-skill combinations require one earlier exposure per basic skill; larger combinations seek two. Exposure means a practice opportunity, not demonstrated mastery. New coordination and crowd-spacing concepts can be introduced through familiar skills.

Raw evidence scores remain unchanged and are reported separately. Their largest upward step is 96.34, with 726 decreases. The curriculum demand does not certify every component transition as smooth; all component changes and support flags are retained in transitions.json.

Oh No! has all 100 levels in the shared path. Its original largest raw-score jump was 348.77; its largest incoming raw-score jump here is 56.40. This is a diagnostic, not the sequencing objective.

The score uses validated solution techniques, solution complexity, timing perturbations, concurrent workers, constraints and a deduction proxy. It is an estimate of human difficulty, not direct measurement of insight. A winning route proves solvability; a low score does not prove that its solution is obvious. Unresolved component jumps stay visible in the report.

## Remaining transition reviews

- Step 80, **Cliff Climber Lemming** (Fun): new execution-demand high rises by 176.7/1000. Check timing forgiveness with a novice before calling this transition smooth.
- Step 1439, **I've lost that Lemming feeling** (Expert): new execution-demand high rises by 0.0/1000. Check timing forgiveness with a novice before calling this transition smooth.

## Fan evidence

The full Classic corpus contains 6,374 entries. Additional routes are proposed from matching terrain, similar terrain and bounded reactive skill policies. Each accepted route is replayed against the complete candidate simulation, checked for a winning result, and analysed with timing perturbations. Source fingerprints and initial-state hashes must match. Blank/hands-free fan entries are excluded from bridges. Fan copies of official puzzles are excluded using a gameplay signature that ignores names and viewport positions, includes resources, objects and rendered masks, and is independent of the release variant. Duplicate official and fan initial states are excluded. Competitive two-player levels are excluded. Unsolved candidates retain low confidence and are not passed off as measured bridges.

The bounded search is not a complete solver. Failure to find a route does not imply that a level is impossible. The chosen fan count is an outcome of evidence and deduplication, not a quota.

## Validation

The generator checks reversed-input determinism, distinct single-player official coverage and the exact replay digest for every selected fan level. See validation.json for the current test and build results. Human insight, stage calibration and novice frustration still need playtesting.

## Saved progress

Solved and parked levels remain saved by identity. Opening the main path rebuilds the remaining order when an older curriculum version is active. The old run remains in saved runs. Try later remains free and grants no win. It is a recovery action, not evidence that a difficulty gap is filled.

## Reproduce

1. Run `zsh Scripts/expand-learning-evidence.sh` against the built app resources. This snapshots and compiles the simulation sources, then searches and validates fan routes offline.
2. Run `python3 Tools/DifficultyDiagnostics/learning_report.py collect .build/learning-evidence/output`.
3. Run `zsh Scripts/generate-learning-journey.sh`.
4. Run `python3 Tools/DifficultyDiagnostics/learning_report.py report`.

The committed supplemental profiles and winning fan replays allow the playlist to be regenerated without rerunning the search. The generation tool checks full official coverage and reversed-input determinism.

## Full order

| Step | Stage | Level | Pack / rank | Raw score | Demand | Support |
| ---: | --- | --- | --- | ---: | ---: | --- |
| 1 | Fun | Just dig! | Lemmings / Fun | 44.74 | 55.25 |  |
| 2 | Fun | PRACTICE: FLOATER | Mikepak07 / fan:lldb-12 | 44.47 | 55.25 |  |
| 3 | Fun | PRACTICE: DIGGER | Mikepak07 / fan:lldb-12 | 45.89 | 57.68 |  |
| 4 | Fun | Only Float is Survive | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 43.13 | 55.25 |  |
| 5 | Fun | Cellbash | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 48.61 | 58.00 |  |
| 6 | Fun | Floating Down! | Holiday cLemmings Frost / fan:lldb-535 | 43.46 | 55.25 |  |
| 7 | Fun | Climin' Death Mountain | TWPAK00 / fan:lldb-302 | 50.79 | 58.13 |  |
| 8 | Fun | Float Or Die | TWPAK00 / fan:lldb-302 | 46.53 | 55.25 |  |
| 9 | Fun | Mienrs <--- lol, typo | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 46.86 | 61.42 |  |
| 10 | Fun | Diggin' to a better world | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 46.97 | 61.84 |  |
| 11 | Fun | Blow Down! | Lemmings Plus DOS Project Mild / fan:lldb-551 | 52.98 | 61.23 |  |
| 12 | Fun | Climbing in life... | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 52.11 | 61.29 |  |
| 13 | Fun | Float to safety | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 50.61 | 69.91 |  |
| 14 | Fun | You need bashers this time | Lemmings / Fun | 67.67 | 88.11 |  |
| 15 | Fun | Up Up UP They Go | Van Clan Tame / fan:lldb-88 | 65.20 | 103.44 |  |
| 16 | Fun | Surprise Package? | Holiday Lemmings 1994 / Hail | 32.93 | 113.20 |  |
| 17 | Fun | Fallout Boys | MazuLems 03 / fan:lldb-246 | 47.18 | 110.50 |  |
| 18 | Fun | ssam1221 wild 1.dat 5 | ssam1221s Lemmings Wild / fan:lldb-514 | 38.91 | 110.50 |  |
| 19 | Fun | Armageddon!! | KillerMasters Lemmings 1 Wicked / fan:lldb-508 | 42.45 | 110.50 |  |
| 20 | Fun | Let's block and blow | Lemmings / Fun | 67.41 | 110.92 |  |
| 21 | Fun | Crush & Crash 3 | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 60.56 | 108.16 |  |
| 22 | Fun | Take a Bow | weirdy01 version 2 / fan:lldb-133 | 67.78 | 111.46 |  |
| 23 | Fun | The Broken Stair | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 69.01 | 113.58 |  |
| 24 | Fun | Just Climb Mountain! | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 67.43 | 118.49 |  |
| 25 | Fun | Digging Only | joem7 / fan:lldb-322 | 62.54 | 121.74 |  |
| 26 | Fun | The Wall Trilogy Part 1 | TWPAK03 / fan:lldb-305 | 68.31 | 121.88 |  |
| 27 | Fun | Step By Step Guide To Building | Van Clan Tame / fan:lldb-88 | 71.46 | 131.07 |  |
| 28 | Fun | Law Abiding Lemizen | ssam1221s Lemmings Wild / fan:lldb-514 | 80.93 | 129.13 |  |
| 29 | Fun | Nuclear War on the dance floor | joem7 / fan:lldb-322 | 71.68 | 138.05 |  |
| 30 | Fun | Bash This! | Van Clan Tame / fan:lldb-88 | 73.91 | 136.96 |  |
| 31 | Fun | Block and Dig | brickpk2 / fan:lldb-559 | 116.75 | 138.05 |  |
| 32 | Fun | Let's get out of here! | Anatol00 / fan:lldb-3 | 56.66 | 144.50 |  |
| 33 | Fun | Lemmings Lemmings everywhere | Lemmings / Fun | 71.79 | 144.50 |  |
| 34 | Fun | Holiday Mining | Holiday Lemmings 1993 / Flurry | 71.37 | 144.50 |  |
| 35 | Fun | Use your feet to climb | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 76.63 | 149.69 |  |
| 36 | Fun | Fun 25.lvl | Amiga Fun Budget / fan:lldb-568 | 71.79 | 144.50 |  |
| 37 | Fun | The Best of website is...... | KillerMasters Lemmings 1 Wild / fan:lldb-507 | 78.01 | 149.88 |  |
| 38 | Fun | Something Wrong.... | ssam1221s Lemmings Tame / fan:lldb-512 | 74.23 | 165.75 |  |
| 39 | Fun | Frostbite | Van Clan Tame / fan:lldb-99 | 69.26 | 170.00 |  |
| 40 | Fun | Citizen Lemming | Oh No! More Lemmings / Tame | 80.86 | 144.50 |  |
| 41 | Fun | Everyone turn left (Part two) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 86.77 | 164.32 |  |
| 42 | Fun | Block 'n load | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 82.33 | 146.75 |  |
| 43 | Fun | Wombat Hollow | Van Clan Tame / fan:lldb-517 | 84.51 | 165.75 |  |
| 44 | Fun | Bomberman | Van Clan Tame / fan:lldb-517 | 85.36 | 165.75 |  |
| 45 | Fun | Just Like Blockwork | Van Clan Tame / fan:lldb-517 | 86.56 | 165.75 |  |
| 46 | Fun | World Wide Web | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 89.74 | 165.75 |  |
| 47 | Fun | Pollution | JM01 / fan:lldb-327 | 80.99 | 170.00 |  |
| 48 | Fun | Safety Blast | Lemmings Plus DOS Project Medi / fan:lldb-553 | 82.87 | 165.75 |  |
| 49 | Fun | Tailor-made for blockers (rm) | LEMREMAKE / fan:lldb-465 | 80.25 | 173.75 |  |
| 50 | Fun | Pillars apart | CRISFN10 / fan:lldb-274 | 84.66 | 173.76 |  |
| 51 | Fun | Guard! | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 95.27 | 165.75 |  |
| 52 | Fun | Walking Bombers | cLemmings Fun / fan:lldb-526 | 93.53 | 165.75 |  |
| 53 | Fun | Retreat!!! | Ji Hoons Lemmings Remake Sky / fan:lldb-548 | 99.28 | 165.75 |  |
| 54 | Fun | Bomber Rainbow | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 95.91 | 165.75 |  |
| 55 | Fun | Making Snowlemmings | Oh No More cLemmings Tame / fan:lldb-530 | 105.23 | 165.75 |  |
| 56 | Fun | The Staircase | Lemmings Plus DOS Project Mild / fan:lldb-551 | 103.55 | 165.75 |  |
| 57 | Fun | The COVOX Level | Save the Lemmings / fan:lldb-584 | 95.46 | 165.75 |  |
| 58 | Fun | Bridge Away! | Save the Lemmings / fan:lldb-584 | 99.83 | 165.75 |  |
| 59 | Fun | Down and Out Lemmings (remake) | LEMREMAKE / fan:lldb-465 | 106.99 | 165.75 |  |
| 60 | Fun | Chain reaction | PSP Special 11 26 of 36 / fan:lldb-217 | 103.77 | 165.75 |  |
| 61 | Fun | Room with no exit | Genesis Fun / fan:lldb-488 | 109.85 | 165.75 |  |
| 62 | Fun | Training 03 - Let's Bomb! | JEFFPCK6 / fan:lldb-240 | 106.32 | 165.75 |  |
| 63 | Fun | All the 7`s ........ | CRISFN09 / fan:lldb-273 | 102.32 | 165.75 |  |
| 64 | Fun | Lemmings For Presidents! | Oh No! More Lemmings / Tame | 114.93 | 147.32 |  |
| 65 | Fun | 347 MY 5H0R75 | s370pak1 / fan:lldb-355 | 110.74 | 165.75 |  |
| 66 | Fun | Get Up There | Van Clan Wild / fan:lldb-519 | 113.66 | 165.75 |  |
| 67 | Fun | Bomb Box! | ANTHPCK3 / fan:lldb-223 | 110.55 | 165.75 |  |
| 68 | Fun | Everyone turn left | Genesis Tricky / fan:lldb-489 | 112.57 | 165.75 |  |
| 69 | Fun | Who Will Explode? | CALEPCK1 / fan:lldb-326 | 110.41 | 165.75 |  |
| 70 | Fun | PRACTICE: CLIMBER | Mikepak07 / fan:lldb-12 | 113.61 | 169.00 |  |
| 71 | Fun | Land Mines | Van Clan Wild / fan:lldb-519 | 109.84 | 165.75 |  |
| 72 | Fun | Get a little extra help | Oh No! More Lemmings / Tame | 120.08 | 170.39 |  |
| 73 | Fun | Invisible Terrain | JMGM02 / fan:lldb-455 | 112.71 | 165.75 |  |
| 74 | Fun | We are now at LEMCON TWO | JM08 / fan:lldb-334 | 113.35 | 170.00 |  |
| 75 | Fun | What happened to the terrain? | JMGM02 / fan:lldb-455 | 110.65 | 170.00 |  |
| 76 | Fun | A task for blockers and bombers | Lemmings / Fun | 129.82 | 173.50 |  |
| 77 | Fun | Build a Bridge | JM04 / fan:lldb-330 | 124.58 | 165.65 |  |
| 78 | Fun | Lemmings in a Box | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 122.57 | 171.63 |  |
| 79 | Fun | Floating Lemming Flurry | Holiday Lemmings 1993 / Flurry | 146.74 | 170.46 |  |
| 80 | Fun | Cliff Climber Lemming | Lemmings Plus DOS Project Mild / fan:lldb-551 | 138.92 | 170.00 | Review |
| 81 | Fun | Thunder-Lemmings are go! | Oh No! More Lemmings / Tame | 151.62 | 151.62 |  |
| 82 | Fun | Bomboozal | Lemmings / Taxing | 83.79 | 179.28 |  |
| 83 | Fun | Uncontrolled explosions | joem8 / fan:lldb-323 | 114.23 | 175.22 |  |
| 84 | Fun | PRACTICE: EXPLODER | Mikepak07 / fan:lldb-12 | 117.50 | 176.47 |  |
| 85 | Intermediate | Pea Soup | Lemmings / Mayhem | 98.34 | 202.99 |  |
| 86 | Intermediate | Under The Bridge | TimpackE / fan:lldb-103 | 97.72 | 195.50 |  |
| 87 | Intermediate | Blockers can block others | Deceits Lemmings Extras / fan:lldb-546 | 116.08 | 192.50 |  |
| 88 | Intermediate | Xplosive | JM03 / fan:lldb-329 | 117.90 | 196.23 |  |
| 89 | Intermediate | RISKY DAY! | Lemmy556 More levels / fan:lldb-68 | 126.52 | 196.35 |  |
| 90 | Intermediate | Lack of builders | MARSHY06 / fan:lldb-350 | 128.60 | 204.47 |  |
| 91 | Intermediate | Easily done | joem7 / fan:lldb-322 | 127.27 | 208.00 |  |
| 92 | Intermediate | Like an overflowing wave | Genesis Present / fan:lldb-492 | 122.26 | 205.13 |  |
| 93 | Intermediate | At Home in a Cave | Holiday Lemmings 1993 / Flurry | 142.14 | 196.20 |  |
| 94 | Intermediate | Lemming Snowfall | Holiday Lemmings 1993 / Flurry | 141.84 | 187.00 |  |
| 95 | Intermediate | It'll be Comin' Round the Mtn. | Oh No More cLemmings Tame / fan:lldb-530 | 135.12 | 182.75 |  |
| 96 | Intermediate | Alternate Route | Lemmings The Official Companion / fan:lldb-585 | 138.48 | 202.49 |  |
| 97 | Intermediate | Lost something? | Lemmings / Tricky | 148.88 | 180.00 |  |
| 98 | Intermediate | Not as complicated as it looks | Lemmings / Fun | 149.97 | 209.58 |  |
| 99 | Intermediate | Tricky 28.lvl | Amiga Tricky Budget / fan:lldb-569 | 149.33 | 180.00 |  |
| 100 | Intermediate | The Undiscovered Country | Holiday Lemmings 1993 / Blizzard | 159.71 | 204.53 |  |
| 101 | Intermediate | Jungle!! | CRISFN01 / fan:lldb-265 | 158.46 | 189.70 |  |
| 102 | Intermediate | 5 miles if you love Lemmings | Genesis Fun / fan:lldb-488 | 154.07 | 204.53 |  |
| 103 | Intermediate | Custom built for Lemmings | Oh No! More Lemmings / Tame | 166.54 | 189.12 |  |
| 104 | Intermediate | Division Bell | Holiday Lemmings 1994 / Frost | 96.03 | 212.84 |  |
| 105 | Intermediate | You Spin Me Right Round | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 98.08 | 211.70 |  |
| 106 | Intermediate | Training 06 - Let's Dig! | JEFFPCK6 / fan:lldb-240 | 92.09 | 221.36 |  |
| 107 | Intermediate | Not the obvious route | ANTHPCK2 / fan:lldb-222 | 95.12 | 225.55 |  |
| 108 | Intermediate | Jingle Lemming | Xmas Lemmings 1992 / Xmas | 109.70 | 233.75 |  |
| 109 | Intermediate | Christmas South of the Equator | Holiday Lemmings 1993 / Flurry | 124.08 | 233.75 |  |
| 110 | Intermediate | Heading on in... | Lemmings Plus DOS Project Mild / fan:lldb-551 | 125.43 | 221.00 |  |
| 111 | Intermediate | Block first, Explode second | PSP Special 1 10 of 36 / fan:lldb-216 | 119.96 | 221.00 |  |
| 112 | Intermediate | Honey, I Saved The Lemmings | Oh No! More Lemmings / Tame | 132.06 | 233.75 |  |
| 113 | Intermediate | Create & Remove Collection | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 124.89 | 221.00 |  |
| 114 | Intermediate | Test map | Orig Extra Levels / fan:lldb-407 | 122.60 | 221.00 |  |
| 115 | Intermediate | Intsy-Wintsy...Lemming? | Oh No! More Lemmings / Tame | 132.74 | 233.75 |  |
| 116 | Intermediate | On the Outside | JM06 / fan:lldb-332 | 135.59 | 221.00 |  |
| 117 | Intermediate | Wish you had them? | Lemmings Plus DOS Project Mild / fan:lldb-551 | 136.42 | 221.00 |  |
| 118 | Intermediate | Bomb The Bubbles | TWPAK00 / fan:lldb-302 | 131.43 | 233.75 |  |
| 119 | Intermediate | Crush & Crash 1 | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 144.00 | 218.34 |  |
| 120 | Intermediate | Bomb and Bash | brickpk1 / fan:lldb-558 | 141.88 | 221.00 |  |
| 121 | Intermediate | Follow The Yellow Brick Road | Van Clan Tame / fan:lldb-517 | 142.82 | 221.00 |  |
| 122 | Intermediate | Be RiGhT bAcK! | Oh No More cLemmings Tame / fan:lldb-530 | 141.70 | 221.00 |  |
| 123 | Intermediate | With Lemmings on Top | cLemmings Fun / fan:lldb-526 | 143.95 | 221.00 |  |
| 124 | Intermediate | Winter Lemmingland | Lemmings The Official Companion / fan:lldb-585 | 134.63 | 230.39 |  |
| 125 | Intermediate | Lemming sanctuary in sight | Lemmings / Tricky | 146.54 | 221.00 |  |
| 126 | Intermediate | BashintheDirectionoftheArrows | PSP Special 1 10 of 36 / fan:lldb-216 | 147.08 | 221.00 |  |
| 127 | Intermediate | Over or Under | cLemmings Fun / fan:lldb-526 | 145.52 | 221.00 |  |
| 128 | Intermediate | One of Many Illusions | Oh No More cLemmings Wicked / fan:lldb-533 | 137.51 | 238.81 |  |
| 129 | Intermediate | Float and Bomb | brickpk1 / fan:lldb-558 | 147.55 | 221.00 |  |
| 130 | Intermediate | Avoid the Fall ! | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 146.65 | 221.00 |  |
| 131 | Intermediate | 100% Pure Woven Lemming | EMPACK / fan:lldb-230 | 149.22 | 221.00 |  |
| 132 | Intermediate | Dying Not Reccomended | Lemmings Plus DOS Project Mild / fan:lldb-551 | 144.67 | 221.00 |  |
| 133 | Intermediate | Tricky 08.lvl | Amiga Tricky Budget / fan:lldb-569 | 148.92 | 221.00 |  |
| 134 | Intermediate | Not so Fast! | cLemmings Fun / fan:lldb-526 | 141.50 | 221.00 |  |
| 135 | Intermediate | Builders will help you here | Lemmings / Fun | 155.98 | 221.00 |  |
| 136 | Intermediate | Amnesia | joe04 / fan:lldb-131 | 154.83 | 221.00 |  |
| 137 | Intermediate | Bomb and Block | brickpk1 / fan:lldb-558 | 152.85 | 221.00 |  |
| 138 | Intermediate | Merry Lemmings | Van Clan Tame / fan:lldb-99 | 149.84 | 220.42 |  |
| 139 | Intermediate | Fun 08.lvl | Amiga Fun Budget / fan:lldb-568 | 153.08 | 212.50 |  |
| 140 | Intermediate | Value each moment | Genesis Taxing / fan:lldb-490 | 161.34 | 221.00 |  |
| 141 | Intermediate | Lake in the Cavern | CPs Level Pack / fan:lldb-472 | 162.54 | 221.00 |  |
| 142 | Intermediate | Down The Wall | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 156.34 | 221.00 |  |
| 143 | Intermediate | Bridge Across, Mine Through | PSP Special 1 10 of 36 / fan:lldb-216 | 153.06 | 221.00 |  |
| 144 | Intermediate | Rising to Paradise | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 156.33 | 221.00 |  |
| 145 | Intermediate | King of the castle | Lemmings / Taxing | 170.33 | 221.00 |  |
| 146 | Intermediate | A toe | Level Design Game 03 / fan:lldb-432 | 165.07 | 232.39 |  |
| 147 | Intermediate | King of the castle (part two) | Conway Challenges 1 / fan:lldb-263 | 171.50 | 221.00 |  |
| 148 | Intermediate | Let's go to the moon! | Genesis Tricky / fan:lldb-489 | 165.90 | 221.00 |  |
| 149 | Intermediate | Beyond Crystal Diggers | joem7 / fan:lldb-322 | 161.70 | 242.14 |  |
| 150 | Intermediate | Block and Bash | brickpk2 / fan:lldb-559 | 176.96 | 221.00 |  |
| 151 | Intermediate | Welcome Back! | KillerMasters Lemmings 2 Tame / fan:lldb-510 | 175.54 | 221.00 |  |
| 152 | Intermediate | All with 6 ! (Except builder!) | Mikepak02 / fan:lldb-7 | 178.83 | 221.00 |  |
| 153 | Intermediate | The metal walkway | ANTHPCK1 / fan:lldb-221 | 173.54 | 221.00 |  |
| 154 | Intermediate | 1 way says the wall | joem4 / fan:lldb-468 | 179.74 | 225.39 |  |
| 155 | Intermediate | It is impossible to do? | CRISFN04 / fan:lldb-268 | 175.15 | 221.00 |  |
| 156 | Intermediate | Taxing 23.lvl | Amiga Taxing Budget / fan:lldb-570 | 172.88 | 221.00 |  |
| 157 | Intermediate | Slanted Bashers | Van Clan Tame / fan:lldb-517 | 173.28 | 221.00 |  |
| 158 | Intermediate | Anticlimacticism | cLemmings Tricky / fan:lldb-527 | 173.52 | 221.00 |  |
| 159 | Intermediate | What an AWESOME level | Lemmings / Taxing | 184.84 | 221.00 |  |
| 160 | Intermediate | Looks easy but its not | JMGM01 / fan:lldb-454 | 175.94 | 237.70 |  |
| 161 | Intermediate | Taxing 15.lvl | Amiga Taxing Book Club / fan:lldb-570 | 184.84 | 221.00 |  |
| 162 | Intermediate | Don't leave any Lemmings | Genesis Tricky / fan:lldb-489 | 188.53 | 221.00 |  |
| 163 | Intermediate | Float and Block | brickpk1 / fan:lldb-558 | 182.90 | 221.00 |  |
| 164 | Intermediate | Symmetry | EMPACK / fan:lldb-230 | 182.91 | 221.00 |  |
| 165 | Intermediate | Climb and Block | brickpk1 / fan:lldb-558 | 183.45 | 232.83 |  |
| 166 | Intermediate | Mind the step..... | Lemmings / Mayhem | 199.18 | 210.70 |  |
| 167 | Intermediate | You Live and Lem | Lemmings / Fun | 202.83 | 228.08 |  |
| 168 | Intermediate | Mayhem 28.lvl | Amiga Mayhem Budget / fan:lldb-571 | 199.18 | 210.70 |  |
| 169 | Intermediate | You Want Me To Go Where??? | Van Clan Tame / fan:lldb-517 | 196.67 | 221.00 |  |
| 170 | Intermediate | A Trap is a trap. | Genesis Present / fan:lldb-492 | 194.92 | 221.00 |  |
| 171 | Intermediate | Fun 21.lvl | Amiga Fun Budget / fan:lldb-568 | 202.83 | 228.08 |  |
| 172 | Intermediate | Climb and Build | brickpk1 / fan:lldb-558 | 193.57 | 236.75 |  |
| 173 | Intermediate | That, Though, Is a Lemming | Holiday cLemmings Frost / fan:lldb-535 | 206.61 | 221.00 |  |
| 174 | Intermediate | Where are we heading? | MARSHY08 / fan:lldb-352 | 238.49 | 238.49 |  |
| 175 | Intermediate | Quickly now | PSP Special 27 36 / fan:lldb-218 | 233.91 | 244.62 |  |
| 176 | Intermediate | BOMB!!!!!!!!! | Lemmy556 My little levels / fan:lldb-65 | 165.92 | 250.72 |  |
| 177 | Intermediate | An "l" to serch | The lemming google pack / fan:lldb-179 | 168.55 | 266.12 |  |
| 178 | Intermediate | Choose Your Solution | SeverSet1 / fan:lldb-183 | 162.68 | 265.73 |  |
| 179 | Intermediate | BLEEEEEEEEEGGGGGGH!!! | ISteve01 / fan:lldb-20 | 173.62 | 260.91 |  |
| 180 | Intermediate | 4 Pixels (or so) from Victory | ISteve03 / fan:lldb-21 | 164.20 | 270.80 |  |
| 181 | Intermediate | 32 Lemmings Below Zero | Holiday Lemmings 1993 / Flurry | 181.88 | 263.56 |  |
| 182 | Intermediate | Turn around young lemmings! | Lemmings / Tricky | 180.25 | 277.23 |  |
| 183 | Intermediate | The Great Lemming Road | Oh No More cLemmings Tame / fan:lldb-530 | 178.83 | 261.13 |  |
| 184 | Intermediate | Just When You Think You Know! | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 176.13 | 270.00 |  |
| 185 | Intermediate | Tricky Hit | Lemmings Plus DOS Project Mild / fan:lldb-551 | 180.97 | 276.25 |  |
| 186 | Intermediate | With a little creativity... | Lemmings Plus DOS Project Mild / fan:lldb-551 | 178.32 | 276.25 |  |
| 187 | Intermediate | Terrorist Attack | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 176.46 | 274.25 |  |
| 188 | Intermediate | Take good care of my Lemmings | Lemmings / Fun | 190.08 | 276.25 |  |
| 189 | Intermediate | Careless clicking costs lives | Lemmings / Tricky | 190.58 | 276.25 |  |
| 190 | Intermediate | On The Other Side | Lemmings Plus DOS Project Mild / fan:lldb-551 | 189.00 | 276.25 |  |
| 191 | Intermediate | We want to escape! | KillerMasters Lemmings 2 Tame / fan:lldb-510 | 186.99 | 276.25 |  |
| 192 | Intermediate | Fun 19.lvl | Amiga Fun Budget / fan:lldb-568 | 190.08 | 276.25 |  |
| 193 | Intermediate | Subterranean Exit | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 187.14 | 259.83 |  |
| 194 | Intermediate | If only they could fly | Lemmings / Fun | 198.34 | 270.56 |  |
| 195 | Intermediate | LemEdit generated Level | ssam1221s Lemmings Tame / fan:lldb-512 | 193.01 | 276.25 |  |
| 196 | Intermediate | Treasonal winter | CRISFN01 / fan:lldb-265 | 201.49 | 276.25 |  |
| 197 | Intermediate | Gather round and break away | PSP Special 27 36 / fan:lldb-218 | 196.52 | 276.25 |  |
| 198 | Intermediate | Fun 28.lvl | Amiga Fun Budget / fan:lldb-568 | 198.34 | 270.56 |  |
| 199 | Intermediate | Lemm Of All Trades | TWPAK12 / fan:lldb-314 | 195.52 | 273.00 |  |
| 200 | Intermediate | Some words(Finnish) | Lemmy556 More levels / fan:lldb-68 | 192.16 | 272.00 |  |
| 201 | Intermediate | Just a Minute (Part Two) | Lemmings / Mayhem | 212.30 | 262.32 |  |
| 202 | Intermediate | Let's go camping. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 211.40 | 275.93 |  |
| 203 | Intermediate | Steel Block Party | Holiday Lemmings 1994 / Hail | 204.01 | 273.99 |  |
| 204 | Intermediate | The Steel Mines of Kessel | Lemmings / Mayhem | 212.48 | 273.01 |  |
| 205 | Intermediate | The gauntlet | Giga pack 08 / fan:lldb-170 | 203.81 | 262.02 |  |
| 206 | Intermediate | Build and Bash | brickpk2 / fan:lldb-559 | 205.60 | 247.58 |  |
| 207 | Intermediate | The waterfall | CRISFN01 / fan:lldb-265 | 203.93 | 269.98 |  |
| 208 | Intermediate | Crematory Chamber | cLemmings Fun / fan:lldb-526 | 203.01 | 276.25 |  |
| 209 | Intermediate | Follow the leader... | Lemmings / Taxing | 215.15 | 276.25 |  |
| 210 | Intermediate | The abyss | CRISFN03 / fan:lldb-267 | 205.16 | 276.25 |  |
| 211 | Intermediate | Taxing 25.lvl | Amiga Taxing Budget / fan:lldb-570 | 215.15 | 276.25 |  |
| 212 | Intermediate | Houston,we got a problem ! | LEVIPAK3 / fan:lldb-367 | 214.72 | 261.13 |  |
| 213 | Intermediate | I Love Gold | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 206.05 | 276.25 |  |
| 214 | Intermediate | Be careful! | CRISFN01 / fan:lldb-265 | 219.51 | 276.25 |  |
| 215 | Intermediate | Level 01.lvl | Amiga Demo / fan:lldb-581 | 213.86 | 276.25 |  |
| 216 | Intermediate | King of Lemmings | Genesis Present / fan:lldb-492 | 210.10 | 277.56 |  |
| 217 | Intermediate | The Art Gallery | Lemmings / Taxing | 226.89 | 276.25 |  |
| 218 | Intermediate | Balance Beam | MARSHY05 / fan:lldb-349 | 226.08 | 276.25 |  |
| 219 | Intermediate | Lemming Barbeque | cLemmings Mayhem / fan:lldb-529 | 225.00 | 276.25 |  |
| 220 | Intermediate | The Flagpole | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 222.41 | 276.25 |  |
| 221 | Intermediate | Mayhem 02.lvl | Amiga Mayhem Budget / fan:lldb-576 | 220.55 | 276.25 |  |
| 222 | Intermediate | Impassable | JM12 / fan:lldb-338 | 225.76 | 276.25 |  |
| 223 | Intermediate | Salvage boat | Genesis Tricky / fan:lldb-489 | 227.35 | 279.37 |  |
| 224 | Intermediate | Tea time in the ball country | Genesis Fun / fan:lldb-488 | 234.81 | 276.25 |  |
| 225 | Intermediate | Guess The Game | TWPAK10 / fan:lldb-312 | 239.31 | 276.25 |  |
| 226 | Intermediate | No Salvation I | Lemmings Plus DOS Project Mild / fan:lldb-551 | 244.24 | 276.25 |  |
| 227 | Intermediate | Just four in each room | CRISFN09 / fan:lldb-273 | 244.60 | 276.25 |  |
| 228 | Intermediate | No Problemming! | Oh No! More Lemmings / Crazy | 260.16 | 276.25 |  |
| 229 | Intermediate | Satan Loves You | TWPAK01 / fan:lldb-303 | 252.03 | 276.25 |  |
| 230 | Intermediate | A to B | PSP Special 11 26 of 36 / fan:lldb-217 | 253.00 | 279.08 |  |
| 231 | Intermediate | Tightrope City | Lemmings / Tricky | 264.39 | 275.42 |  |
| 232 | Intermediate | Many Lemmings make level work | Oh No! More Lemmings / Crazy | 149.29 | 303.69 |  |
| 233 | Intermediate | Chains of Command | Holiday Lemmings 1994 / Frost | 160.98 | 296.56 |  |
| 234 | Intermediate | Look familiar? LOOK AGAIN! | GARJEN00 / fan:lldb-280 | 160.56 | 291.00 |  |
| 235 | Intermediate | Dr. Lemminglittle | Conway06 / fan:lldb-567 | 154.56 | 291.39 |  |
| 236 | Intermediate | Tricky 22.lvl | Amiga Tricky Budget / fan:lldb-569 | 183.36 | 281.11 |  |
| 237 | Intermediate | Float and Dig | brickpk1 / fan:lldb-558 | 173.52 | 293.04 |  |
| 238 | Intermediate | Get up, up, up! | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 176.99 | 302.06 |  |
| 239 | Intermediate | Lemming Snowjourn | Holiday Lemmings 1993 / Flurry | 189.31 | 306.00 |  |
| 240 | Intermediate | Dude, where's my exit? | Ji Hoons Lemmings Remake Earth / fan:lldb-549 | 189.79 | 291.39 |  |
| 241 | Intermediate | The lemming paradox | LEVIPAK3 / fan:lldb-367 | 190.98 | 301.75 |  |
| 242 | Intermediate | Clouds of Lemmings | Holiday Lemmings 1993 / Flurry | 209.58 | 302.56 |  |
| 243 | Intermediate | Underground Exit | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 204.62 | 284.39 |  |
| 244 | Intermediate | Climb and Bash | brickpk1 / fan:lldb-558 | 210.10 | 297.04 |  |
| 245 | Intermediate | Death Row | Lemmings Plus DOS Project PSYCHO / fan:lldb-555 | 203.89 | 294.84 |  |
| 246 | Intermediate | Hard to Swallow | Oh No More cLemmings Crazy / fan:lldb-531 | 202.41 | 297.40 |  |
| 247 | Intermediate | Underground Exit | Pieuw02 / fan:lldb-394 | 209.03 | 301.36 |  |
| 248 | Intermediate | Hot Dungeon | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 202.73 | 291.39 |  |
| 249 | Intermediate | Float and Build | brickpk1 / fan:lldb-558 | 209.53 | 297.50 |  |
| 250 | Intermediate | Six Feet Under | Lemmings Plus DOS Project Medi / fan:lldb-553 | 215.31 | 298.56 |  |
| 251 | Intermediate | Iron Industry | Pieuw01 / fan:lldb-393 | 211.88 | 303.58 |  |
| 252 | Intermediate | Episode X - The Phantom Exit | MazuLems 01 / fan:lldb-244 | 207.50 | 301.05 |  |
| 253 | Intermediate | Turn around and look. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 218.50 | 306.00 |  |
| 254 | Intermediate | The crystal caverns | CRISFN11 / fan:lldb-275 | 227.92 | 295.68 |  |
| 255 | Intermediate | Freedom of the Lemmings | Deceits Lemmings Fun / fan:lldb-522 | 229.32 | 281.15 |  |
| 256 | Intermediate | Pink pyramid | CRISFN14 / fan:lldb-278 | 232.42 | 296.48 |  |
| 257 | Intermediate | Watch your step (Part two). | Genesis Present / fan:lldb-492 | 224.33 | 296.16 |  |
| 258 | Intermediate | It's...... FACE?? | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 224.02 | 301.05 |  |
| 259 | Intermediate | Make a choice | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 222.48 | 311.75 |  |
| 260 | Intermediate | Smile if you love lemmings | Lemmings / Fun | 234.36 | 308.71 |  |
| 261 | Intermediate | The Emerald Grotto | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 234.43 | 286.90 |  |
| 262 | Intermediate | Take a running jump..... | Lemmings / Taxing | 244.56 | 301.05 |  |
| 263 | Intermediate | Have a Pleasant Journey ! | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 237.49 | 285.92 |  |
| 264 | Intermediate | Fun For The Whole Family! | TWPAK08 / fan:lldb-310 | 239.87 | 284.67 |  |
| 265 | Intermediate | Lava lemmings | CRISFN08 / fan:lldb-272 | 236.83 | 294.76 |  |
| 266 | Intermediate | Lemming Friendly | Oh No! More Lemmings / Crazy | 253.66 | 281.05 |  |
| 267 | Intermediate | Yo-yo Lem-lem | Holiday Lemmings 1993 / Flurry | 246.94 | 308.30 |  |
| 268 | Intermediate | Snow Way! | TWPAK04 / fan:lldb-306 | 248.82 | 308.00 |  |
| 269 | Intermediate | Taxing 24.lvl | Amiga Taxing Budget / fan:lldb-570 | 245.36 | 301.05 |  |
| 270 | Intermediate | Lemmings' death | CRISFN10 / fan:lldb-274 | 250.24 | 307.47 |  |
| 271 | Intermediate | Fun 09.lvl | Amiga Fun Budget / fan:lldb-568 | 247.06 | 308.51 |  |
| 272 | Intermediate | Ice Ice Lemming | Oh No! More Lemmings / Crazy | 262.47 | 303.83 |  |
| 273 | Intermediate | The great escape | Conway07 / fan:lldb-256 | 258.85 | 303.58 |  |
| 274 | Intermediate | Toy Train | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 261.02 | 305.20 |  |
| 275 | Intermediate | Go out for a walk? | Genesis Tricky / fan:lldb-489 | 265.14 | 313.07 |  |
| 276 | Intermediate | The Strange Relict of Rhodes | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 289.26 | 294.92 |  |
| 277 | Intermediate | What comes down must go up. | QBeez06 / fan:lldb-414 | 281.85 | 307.71 |  |
| 278 | Intermediate | Starry Level | EMPACK / fan:lldb-230 | 281.82 | 301.05 |  |
| 279 | Intermediate | ============Pipeline============ | TWPAK01 / fan:lldb-303 | 284.24 | 300.58 |  |
| 280 | Intermediate | The Iron Puzzle | TimballistoPack1 / fan:lldb-354 | 297.58 | 297.58 |  |
| 281 | Intermediate | Only floaters can survive this | Lemmings / Fun | 121.12 | 322.05 |  |
| 282 | Intermediate | Climb to victory | PSP Special 1 10 of 36 / fan:lldb-216 | 120.02 | 326.71 |  |
| 283 | Intermediate | Egypt Fall | Anatol00 / fan:lldb-3 | 125.77 | 324.53 |  |
| 284 | Intermediate | New weird pancake factory.... | Many more levels / fan:lldb-69 | 149.08 | 315.55 |  |
| 285 | Intermediate | Stop Block | TWPAK00 / fan:lldb-302 | 155.15 | 330.83 |  |
| 286 | Intermediate | Lemming Express | Oh No! More Lemmings / Crazy | 182.04 | 317.75 |  |
| 287 | Intermediate | The Lemmyrinth | MazuLems 02 / fan:lldb-245 | 173.39 | 337.85 |  |
| 288 | Intermediate | Last Lemming To Lemmingcentral | Oh No! More Lemmings / Wicked | 190.08 | 341.00 |  |
| 289 | Intermediate | Bash and Dig | brickpk2 / fan:lldb-559 | 185.79 | 316.40 |  |
| 290 | Intermediate | Back With Ye! | ISteve02 / fan:lldb-23 | 181.09 | 331.50 |  |
| 291 | Intermediate | Expansion & compression | CRISFN09 / fan:lldb-273 | 191.37 | 338.47 |  |
| 292 | Intermediate | Down And Out Lemmings | Oh No! More Lemmings / Tame | 215.08 | 326.20 |  |
| 293 | Intermediate | Float and Bash | brickpk1 / fan:lldb-558 | 205.81 | 316.58 |  |
| 294 | Intermediate | Gone With The Lemming | Oh No! More Lemmings / Tame | 216.33 | 347.20 |  |
| 295 | Intermediate | We may not fall down | LEVIPAK1 / fan:lldb-365 | 211.38 | 333.07 |  |
| 296 | Intermediate | Lemstart by one side | CRISFN11 / fan:lldb-275 | 213.79 | 338.76 |  |
| 297 | Intermediate | Balance Beam | Genesis Present / fan:lldb-492 | 211.56 | 343.58 |  |
| 298 | Intermediate | Lemming Tracks in the Snow! | Holiday Lemmings 1993 / Flurry | 239.12 | 331.50 |  |
| 299 | Intermediate | I am A.T. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 232.62 | 331.74 |  |
| 300 | Intermediate | Bitter Lemming | Lemmings / Tricky | 239.79 | 336.00 |  |
| 301 | Intermediate | Down, Down, down in the ground | beta / fan:lldb-371 | 229.93 | 319.31 |  |
| 302 | Intermediate | The pit of doom | CRISFN13 / fan:lldb-277 | 231.09 | 318.17 |  |
| 303 | Intermediate | Maniacal Lemmings | cLemmings Tricky / fan:lldb-527 | 240.54 | 316.81 |  |
| 304 | Intermediate | Lovely jubilee | Genesis Tricky / fan:lldb-489 | 232.93 | 325.23 |  |
| 305 | Intermediate | Not so simple ! | Mikepak05 / fan:lldb-10 | 234.74 | 328.88 |  |
| 306 | Intermediate | Walk through here but cautiously | Genesis Taxing / fan:lldb-490 | 234.98 | 335.77 |  |
| 307 | Intermediate | Above The Pepsi Max.ini | grams88 / fan:lldb-416 | 230.57 | 330.88 |  |
| 308 | Intermediate | Save the Lemmings with Floaters | PSP Special 1 10 of 36 / fan:lldb-216 | 232.61 | 328.18 |  |
| 309 | Intermediate | Lemming Hotel | Oh No! More Lemmings / Wild | 242.86 | 337.12 |  |
| 310 | Intermediate | A Giant Leap for Lemmingkind | MARTPCK1 / fan:lldb-495 | 251.70 | 315.51 |  |
| 311 | Intermediate | All 2 easy | JANNPCK1 / fan:lldb-231 | 245.21 | 336.86 |  |
| 312 | Intermediate | Fun 22.lvl | Amiga Fun Budget / fan:lldb-573 | 247.21 | 345.72 |  |
| 313 | Intermediate | Take a little rest. | Genesis Fun / fan:lldb-488 | 248.99 | 317.75 |  |
| 314 | Intermediate | Farewell, My Lemming | Lemmings Plus DOS Project Mild / fan:lldb-551 | 249.36 | 331.50 |  |
| 315 | Intermediate | Execution Machine | cLemmings Mayhem / fan:lldb-529 | 244.88 | 345.04 |  |
| 316 | Intermediate | Easy when you know how | Lemmings / Fun | 256.86 | 331.50 |  |
| 317 | Intermediate | Twice the same? | geooPk1 / fan:lldb-2 | 258.97 | 315.92 |  |
| 318 | Intermediate | No Salvation II | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 249.22 | 331.50 |  |
| 319 | Intermediate | Dead Lemmings Tell no Tales | cLemmings Tricky / fan:lldb-527 | 262.48 | 324.95 |  |
| 320 | Intermediate | Use your brain better. | Genesis Present / fan:lldb-492 | 258.27 | 336.25 |  |
| 321 | Intermediate | It's Lemmorama! | cLemmings Fun / fan:lldb-526 | 263.75 | 331.50 |  |
| 322 | Intermediate | The Sword | Neato / fan:lldb-427 | 263.10 | 331.58 |  |
| 323 | Intermediate | Lucky Charm | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 256.84 | 331.50 |  |
| 324 | Intermediate | The Curse of Devil | Mad00 / fan:lldb-55 | 259.27 | 330.08 |  |
| 325 | Intermediate | Rising to Heaven | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 258.22 | 332.69 |  |
| 326 | Intermediate | The blocked exit | CRISFN08 / fan:lldb-272 | 256.06 | 348.46 |  |
| 327 | Intermediate | Meeting Adjourned | Oh No! More Lemmings / Wild | 269.12 | 331.50 |  |
| 328 | Intermediate | It`s a trade off | Oh No! More Lemmings / Crazy | 272.03 | 346.74 |  |
| 329 | Intermediate | We are now at LEMCON ONE | Lemmings / Fun | 273.12 | 337.32 |  |
| 330 | Intermediate | The Nifty Fifty | ISteve04 / fan:lldb-24 | 269.76 | 317.13 |  |
| 331 | Intermediate | Bridge over the iced water | JANNPCK1 / fan:lldb-231 | 272.80 | 330.68 |  |
| 332 | Intermediate | Falling Away From Everything... | Lemmings Plus DOS Project Mild / fan:lldb-551 | 266.95 | 331.50 |  |
| 333 | Intermediate | Cloud-Covered Stalactite | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 277.10 | 317.75 |  |
| 334 | Intermediate | This should be a doddle (remake) | LEMREMAKE / fan:lldb-465 | 278.56 | 340.01 |  |
| 335 | Intermediate | Fun 20.lvl | Amiga Fun Budget / fan:lldb-568 | 275.22 | 337.32 |  |
| 336 | Intermediate | Affect of gravity | CRISFN12 / fan:lldb-276 | 272.38 | 344.16 |  |
| 337 | Intermediate | Out of BASHERS??? | CRISFN03 / fan:lldb-267 | 269.37 | 348.30 |  |
| 338 | Intermediate | Lock up your Lemmings | Lemmings / Fun | 283.85 | 319.20 |  |
| 339 | Intermediate | Call in the bomb squad | Lemmings / Taxing | 288.44 | 331.50 |  |
| 340 | Intermediate | No Salvation III | Lemmings Plus DOS Project Medi / fan:lldb-553 | 288.03 | 331.50 |  |
| 341 | Intermediate | Taxing 27.lvl | Amiga Taxing Budget / fan:lldb-570 | 290.54 | 331.50 |  |
| 342 | Intermediate | Compression Method X | Yawg05 / fan:lldb-110 | 285.12 | 330.87 |  |
| 343 | Intermediate | The Freedom Man | Ron Stards Rodents / fan:lldb-471 | 287.87 | 344.81 |  |
| 344 | Intermediate | Loop the loop! | unfinisd / fan:lldb-423 | 283.83 | 331.13 |  |
| 345 | Intermediate | Solid bricks | CRISFN05 / fan:lldb-269 | 289.35 | 340.01 |  |
| 346 | Intermediate | A TOWERING PROBLEM | Oh No! More Lemmings / Wicked | 304.89 | 331.13 |  |
| 347 | Intermediate | The Long Way Around | Holiday Lemmings 1993 / Flurry | 305.15 | 349.33 |  |
| 348 | Intermediate | Rainbow Island | Lemmings / Tricky | 301.05 | 331.50 |  |
| 349 | Intermediate | Snow Lev 5 | ANTHPCK4 / fan:lldb-224 | 301.25 | 331.50 |  |
| 350 | Intermediate | Tricky 29.lvl | Amiga Tricky Budget / fan:lldb-569 | 301.11 | 331.50 |  |
| 351 | Intermediate | Time to get up! | Lemmings / Mayhem | 319.74 | 331.50 |  |
| 352 | Intermediate | 5 lemmings under freezing | CRISFN06 / fan:lldb-270 | 313.30 | 339.08 |  |
| 353 | Intermediate | How do you get up there? | JM10 / fan:lldb-336 | 320.08 | 331.50 |  |
| 354 | Intermediate | Darkness of the royal family | Genesis Present / fan:lldb-492 | 332.59 | 332.59 |  |
| 355 | Intermediate | Dangerous balcony | Genesis Mayhem / fan:lldb-491 | 322.74 | 349.50 |  |
| 356 | Intermediate | A Block from Home | Holiday Lemmings 1993 / Flurry | 348.40 | 348.40 |  |
| 357 | Intermediate | Take a break! | QBeez05 / fan:lldb-166 | 345.98 | 345.98 |  |
| 358 | Intermediate | Downwardly Mobile Lemmings | Oh No! More Lemmings / Tame | 160.51 | 350.62 |  |
| 359 | Intermediate | New Lemmings On The Block | Oh No! More Lemmings / Tame | 161.16 | 350.62 |  |
| 360 | Intermediate | Through the Crystal Caverns | cLemmings Fun / fan:lldb-526 | 184.79 | 350.62 |  |
| 361 | Intermediate | Another "g" to serch | The lemming google pack / fan:lldb-179 | 188.38 | 350.62 |  |
| 362 | Intermediate | Luvly Jubly | Lemmings / Tricky | 205.59 | 350.30 |  |
| 363 | Intermediate | Sacrifice | ssam1221s Lemmings Tame / fan:lldb-512 | 202.74 | 356.94 |  |
| 364 | Intermediate | Use The Pen!!! | Lemmings Plus DOS Project Danger / fan:lldb-554 | 250.14 | 359.29 |  |
| 365 | Intermediate | PiPeLiNe PaRaLLeL | Deceits Lemmings Tricky / fan:lldb-523 | 268.47 | 353.65 |  |
| 366 | Intermediate | Some Kind Of Lemming | Lemmings Plus DOS Project Danger / fan:lldb-554 | 274.50 | 358.79 |  |
| 367 | Intermediate | Lemming Head | Oh No! More Lemmings / Wild | 297.54 | 357.48 |  |
| 368 | Intermediate | Going up....... | Lemmings / Mayhem | 292.20 | 355.38 |  |
| 369 | Intermediate | Take new Lemmings! | Lemmy556 More levels / fan:lldb-68 | 289.56 | 359.99 |  |
| 370 | Intermediate | Tunneling under | ANTHPCK5 / fan:lldb-225 | 300.59 | 352.68 |  |
| 371 | Intermediate | Mayhem 23.lvl | Amiga Mayhem Budget / fan:lldb-571 | 294.30 | 355.38 |  |
| 372 | Intermediate | Livin` On The Edge | Lemmings / Taxing | 318.94 | 351.32 |  |
| 373 | Intermediate | The end | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 327.93 | 351.22 |  |
| 374 | Intermediate | A long way to go | Giga pack 09 / fan:lldb-171 | 322.32 | 359.18 |  |
| 375 | Intermediate | Taxing 12.lvl | Amiga Taxing Budget / fan:lldb-570 | 321.04 | 351.32 |  |
| 376 | Intermediate | Romeo n Juliet | Deceits Lemmings Fun / fan:lldb-522 | 359.25 | 359.25 |  |
| 377 | Difficult | Stairway To Nowhere | Timpack11 / fan:lldb-98 | 134.12 | 362.58 |  |
| 378 | Difficult | Helled cavern! | CRISFN14 / fan:lldb-278 | 129.20 | 364.66 |  |
| 379 | Difficult | Climbers can climb the wall | Deceits Lemmings Extras / fan:lldb-546 | 133.34 | 369.08 |  |
| 380 | Difficult | Floaters can land safely | Deceits Lemmings Extras / fan:lldb-546 | 134.25 | 372.57 |  |
| 381 | Difficult | Miners Can Mine Diagonally | Deceits Lemmings Extras / fan:lldb-546 | 136.08 | 371.53 |  |
| 382 | Difficult | Inferno can wait (we hope!!!!) | ssam1221s Lemmings Tame / fan:lldb-512 | 136.80 | 380.93 |  |
| 383 | Difficult | Blow two lemmings | CRISFN04 / fan:lldb-268 | 132.17 | 383.61 |  |
| 384 | Difficult | Lemmings traps | CRISFN08 / fan:lldb-272 | 177.67 | 380.14 |  |
| 385 | Difficult | Exit for Hell! | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 193.67 | 367.41 |  |
| 386 | Difficult | A block in the way | JM18 / fan:lldb-344 | 218.52 | 366.95 |  |
| 387 | Difficult | Clear the pillars | brickpk3 / fan:lldb-560 | 221.10 | 368.90 |  |
| 388 | Difficult | The Mountain Peaks | Oh No More cLemmings Tame / fan:lldb-530 | 217.16 | 360.00 |  |
| 389 | Difficult | Confusion | joem7 / fan:lldb-322 | 215.13 | 360.00 |  |
| 390 | Difficult | Downtown Lemmings | Deceits Lemmings Extras / fan:lldb-546 | 220.17 | 365.06 |  |
| 391 | Difficult | 2001, A lemmings odyssee | hubbart2 / fan:lldb-174 | 219.81 | 372.52 |  |
| 392 | Difficult | Ismo rock | Lemmy556 Superpack / fan:lldb-593 | 213.86 | 378.34 |  |
| 393 | Difficult | The Boiler Room | Lemmings / Mayhem | 230.65 | 362.40 |  |
| 394 | Difficult | Lemmings to the aid | CRISFN02 / fan:lldb-266 | 231.68 | 365.50 |  |
| 395 | Difficult | Crush & Crash 2 | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 232.58 | 365.58 |  |
| 396 | Difficult | Bomb and Dig | brickpk1 / fan:lldb-558 | 232.87 | 373.22 |  |
| 397 | Difficult | Backward Train | Pieuw01 / fan:lldb-393 | 224.24 | 377.76 |  |
| 398 | Difficult | If at first you don`t succeed.. | Lemmings / Taxing | 238.73 | 381.21 |  |
| 399 | Difficult | Dangerzone | Oh No! More Lemmings / Tame | 240.43 | 377.08 |  |
| 400 | Difficult | The Boiler Room (part two) | Conway Challenges 2 / fan:lldb-264 | 232.70 | 362.40 |  |
| 401 | Difficult | Lemmings in the Tub | Oh No More cLemmings Tame / fan:lldb-530 | 241.67 | 360.00 |  |
| 402 | Difficult | Lemming toast | PSP Special 11 26 of 36 / fan:lldb-217 | 237.46 | 367.82 |  |
| 403 | Difficult | De-fusing a time bomb | Snow remakes 01 / fan:lldb-144 | 235.29 | 375.46 |  |
| 404 | Difficult | Flow Control | Oh No! More Lemmings / Havoc | 249.06 | 361.82 |  |
| 405 | Difficult | Climb and fall. Fall and climb. | Genesis Mayhem / fan:lldb-491 | 247.87 | 362.79 |  |
| 406 | Difficult | Flood zone | CRISFN05 / fan:lldb-269 | 249.53 | 361.02 |  |
| 407 | Difficult | A Recurring Impediment(part 2) | cLemmings Taxing / fan:lldb-528 | 248.32 | 362.28 |  |
| 408 | Difficult | Anxiety | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 261.73 | 371.60 |  |
| 409 | Difficult | Peak of Performance | Holiday Lemmings 1994 / Hail | 262.66 | 367.98 |  |
| 410 | Difficult | The Wrath of Lem | Holiday Lemmings 1993 / Blizzard | 260.08 | 371.17 |  |
| 411 | Difficult | Egypt's Trap | KillerMasters Lemmings 2 Tame / fan:lldb-510 | 258.99 | 360.00 |  |
| 412 | Difficult | Morning View | JM12 / fan:lldb-338 | 259.82 | 360.00 |  |
| 413 | Difficult | A Recurring Impediment(part 1) | cLemmings Tricky / fan:lldb-527 | 253.87 | 360.00 |  |
| 414 | Difficult | SNOW JOKE | Oh No! More Lemmings / Wild | 266.41 | 365.28 |  |
| 415 | Difficult | Two heads are better... | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 265.30 | 374.91 |  |
| 416 | Difficult | Get the otherside, boy! | CRISFN03 / fan:lldb-267 | 267.95 | 360.00 |  |
| 417 | Difficult | Tricky 21.lvl | Amiga Tricky Book Club / fan:lldb-577 | 268.96 | 360.00 |  |
| 418 | Difficult | Whether You Lem It Or Not | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 259.14 | 360.00 |  |
| 419 | Difficult | Konbanwa Lemming san | Lemmings / Fun | 271.56 | 360.00 |  |
| 420 | Difficult | Quote: "That`s a good level" | Oh No! More Lemmings / Crazy | 271.74 | 364.06 |  |
| 421 | Difficult | Train your body | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 269.76 | 360.53 |  |
| 422 | Difficult | Try anything once. | Genesis Present / fan:lldb-492 | 274.57 | 360.00 |  |
| 423 | Difficult | Powerslave | JannPck3 / fan:lldb-233 | 273.92 | 360.00 |  |
| 424 | Difficult | Follow the Arrow | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 264.91 | 360.00 |  |
| 425 | Difficult | The Final Frontier | Holiday Lemmings 1993 / Blizzard | 275.78 | 374.49 |  |
| 426 | Difficult | Umbrella Land. | Genesis Taxing / fan:lldb-490 | 276.90 | 360.00 |  |
| 427 | Difficult | Frantic Lemmings | cLemmings Fun / fan:lldb-526 | 274.59 | 369.63 |  |
| 428 | Difficult | Get down on it. | AdamPack01 / fan:lldb-81 | 276.25 | 360.00 |  |
| 429 | Difficult | The Wormery | PSP Special 11 26 of 36 / fan:lldb-217 | 279.09 | 373.10 |  |
| 430 | Difficult | The Brick | MazuLems 02 / fan:lldb-245 | 285.48 | 377.58 |  |
| 431 | Difficult | Doomed | JANNPCK3 / fan:lldb-494 | 288.60 | 375.90 |  |
| 432 | Difficult | Only a minute now... | ANTHPCK2 / fan:lldb-222 | 279.06 | 379.92 |  |
| 433 | Difficult | The Deadly Climb | Lemmings Plus DOS Project Danger / fan:lldb-554 | 279.42 | 375.15 |  |
| 434 | Difficult | Lake Antofagasta | CRISFN05 / fan:lldb-269 | 300.37 | 360.00 |  |
| 435 | Difficult | Exploration Brigade | cLemmings Tricky / fan:lldb-527 | 298.54 | 360.00 |  |
| 436 | Difficult | The roman souvenirs | CRISFN12 / fan:lldb-276 | 296.75 | 361.56 |  |
| 437 | Difficult | Having fun yet? Good. | ISteve01 / fan:lldb-20 | 298.94 | 367.08 |  |
| 438 | Difficult | The creepy crates | CRISFN06 / fan:lldb-270 | 302.96 | 360.00 |  |
| 439 | Difficult | Snowy cross | CRISFN15 / fan:lldb-279 | 302.98 | 360.40 |  |
| 440 | Difficult | A hot road! | CRISFN12 / fan:lldb-276 | 302.41 | 373.83 |  |
| 441 | Difficult | Lemmings at Tiffany's | Jazzem / fan:lldb-453 | 295.10 | 363.03 |  |
| 442 | Difficult | Perfectionism | Lemmings Plus DOS Project PSYCHO / fan:lldb-555 | 293.99 | 374.66 |  |
| 443 | Difficult | Level Under Construction | MazuLems 03 / fan:lldb-246 | 296.02 | 379.96 |  |
| 444 | Difficult | The Lonely Pole | Lemmings Plus DOS Project Medi / fan:lldb-553 | 294.87 | 371.76 |  |
| 445 | Difficult | Hunting Lemmings | cLemmings Taxing / fan:lldb-528 | 307.78 | 360.00 |  |
| 446 | Difficult | Anticlimacticism II | cLemmings Tricky / fan:lldb-527 | 306.30 | 360.00 |  |
| 447 | Difficult | Forests of Witchery | JannPck3 / fan:lldb-233 | 304.58 | 361.80 |  |
| 448 | Difficult | Only a way can be! | CRISFN12 / fan:lldb-276 | 306.26 | 381.13 |  |
| 449 | Difficult | It's Tasting Time! | ssam1221s Lemmings Wild / fan:lldb-514 | 299.84 | 382.78 |  |
| 450 | Difficult | Backdraft | Lemmings Plus DOS Project Danger / fan:lldb-554 | 304.14 | 382.20 |  |
| 451 | Difficult | V For Vendetta | Van Clan Tame / fan:lldb-88 | 303.71 | 383.00 |  |
| 452 | Difficult | Barrel o' Laughs | ClamSpam03 / fan:lldb-73 | 301.19 | 371.17 |  |
| 453 | Difficult | Tribute to M.C.Escher | Lemmings / Taxing | 320.79 | 372.57 |  |
| 454 | Difficult | IT IS ONE WAY!! | CRISFN13 / fan:lldb-277 | 321.93 | 360.00 |  |
| 455 | Difficult | Simple Enough | cLemmings Tricky / fan:lldb-527 | 317.64 | 360.00 |  |
| 456 | Difficult | Dont mess with me | JM14 / fan:lldb-340 | 328.49 | 360.00 |  |
| 457 | Difficult | The Crossing | Pieuws Lemmings 2007 Insane / fan:lldb-545 | 324.40 | 365.84 |  |
| 458 | Difficult | Electric circuit | Genesis Present / fan:lldb-492 | 320.15 | 378.99 |  |
| 459 | Difficult | On Stair Duty | cLemmings Tricky / fan:lldb-527 | 319.52 | 383.65 |  |
| 460 | Difficult | Down, along, up. In that order | Lemmings / Mayhem | 331.74 | 381.98 |  |
| 461 | Difficult | The Warehouse | Pieuws Lemmings 2007 Insane / fan:lldb-545 | 334.49 | 360.00 |  |
| 462 | Difficult | The big U-Turn | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 333.34 | 370.20 |  |
| 463 | Difficult | Lets go to hell | LARSPACK / fan:lldb-243 | 335.85 | 368.34 |  |
| 464 | Difficult | Mayhem 05.lvl | Amiga Mayhem Budget / fan:lldb-571 | 331.74 | 381.98 |  |
| 465 | Difficult | Quarantine Break! | Ji Hoons Lemmings Remake Earth / fan:lldb-549 | 326.94 | 384.50 |  |
| 466 | Difficult | The Endless basher | Giga pack 04 / fan:lldb-165 | 339.99 | 360.00 |  |
| 467 | Difficult | Livin' Large! | Deceits Lemmings Fun / fan:lldb-522 | 341.02 | 380.90 |  |
| 468 | Difficult | Bash, mine & dig | CRISFN13 / fan:lldb-277 | 344.60 | 373.13 |  |
| 469 | Difficult | Down the Stairwell | cLemmings Taxing / fan:lldb-528 | 363.06 | 363.06 |  |
| 470 | Difficult | The hot spot! | ANTHPCK7 / fan:lldb-227 | 359.94 | 364.08 |  |
| 471 | Difficult | Exodus! | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 378.92 | 378.92 |  |
| 472 | Difficult | Underwater Operation | JOHNPACK / fan:lldb-242 | 378.40 | 378.40 |  |
| 473 | Difficult | Mutual Dependency | Level Design Game 06 / fan:lldb-435 | 139.92 | 397.84 |  |
| 474 | Difficult | Climbing Will Help, Now | Holiday cLemmings Frost / fan:lldb-535 | 142.48 | 404.21 |  |
| 475 | Difficult | Ghostly Hall | Lemmings Plus DOS Project Medi / fan:lldb-553 | 140.06 | 409.71 |  |
| 476 | Difficult | Float to safety | JM01 / fan:lldb-327 | 146.19 | 409.02 |  |
| 477 | Difficult | Bridge In A Fridge | TWPAK00 / fan:lldb-302 | 146.28 | 409.35 |  |
| 478 | Difficult | Just Float | TimpackE / fan:lldb-103 | 146.51 | 410.24 |  |
| 479 | Difficult | Which Exit? | beta / fan:lldb-371 | 141.96 | 408.35 |  |
| 480 | Difficult | Not as easy as it looks | PSP Special 11 26 of 36 / fan:lldb-217 | 144.06 | 417.05 |  |
| 481 | Difficult | Training 07 - Let's Mine! | JEFFPCK6 / fan:lldb-240 | 145.52 | 415.92 |  |
| 482 | Difficult | Build Block | KillerMasters Lemmings 1 Wicked / fan:lldb-508 | 150.39 | 413.96 |  |
| 483 | Difficult | Happy Holidays Mr Lemming! | Xmas Lemmings 1992 / Xmas | 179.60 | 404.15 |  |
| 484 | Difficult | The Crossroads | Lemmings / Mayhem | 180.36 | 417.92 |  |
| 485 | Difficult | Lemming Come Back! | MARTPCK2 / fan:lldb-496 | 172.33 | 391.77 |  |
| 486 | Difficult | Abombination | Ji Hoons Lemmings Remake Earth / fan:lldb-549 | 174.71 | 403.19 |  |
| 487 | Difficult | Mount. Bashmore | ANTHPCK1 / fan:lldb-221 | 177.33 | 411.37 |  |
| 488 | Difficult | Get It Right | Van Clan Wild / fan:lldb-519 | 171.31 | 404.92 |  |
| 489 | Difficult | Ready, Aim, Fire!!! | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 174.12 | 415.73 |  |
| 490 | Difficult | Now use miners and climbers | Lemmings / Fun | 194.62 | 408.85 |  |
| 491 | Difficult | The Lemming net | CRISFN14 / fan:lldb-278 | 189.04 | 409.06 |  |
| 492 | Difficult | 2 Minutes before midnight | Holiday Lemmings 1994 / Frost | 202.25 | 393.73 |  |
| 493 | Difficult | Down The Drain | TWPAK01 / fan:lldb-303 | 203.18 | 397.30 |  |
| 494 | Difficult | Fun 04.lvl | Amiga Fun Budget / fan:lldb-568 | 196.72 | 408.85 |  |
| 495 | Difficult | PRACTICE: BASHER | Mikepak07 / fan:lldb-12 | 200.27 | 403.75 |  |
| 496 | Difficult | Mayhem 04.lvl | Amiga Mayhem Budget / fan:lldb-571 | 196.58 | 417.92 |  |
| 497 | Difficult | It's Lemmingentry Watson | Lemmings / Tricky | 216.70 | 400.45 |  |
| 498 | Difficult | Lemming Excavation | Lemmings The Official Companion / fan:lldb-585 | 213.14 | 388.75 |  |
| 499 | Difficult | Land of Destruction | joem1 / fan:lldb-317 | 206.99 | 395.69 |  |
| 500 | Difficult | through the tunnel of fun. | CALEPCK1 / fan:lldb-326 | 208.33 | 403.75 |  |
| 501 | Difficult | The Cells | Lemmings Plus DOS Project Mild / fan:lldb-551 | 207.56 | 403.75 |  |
| 502 | Difficult | Field athletics | Genesis Present / fan:lldb-492 | 213.33 | 403.75 |  |
| 503 | Difficult | Lemming Efficiancy Plan | Level Design Game 01 / fan:lldb-430 | 218.81 | 405.44 |  |
| 504 | Difficult | Lemmings: Fireworks Simulator | TWPAK06 / fan:lldb-308 | 209.54 | 417.47 |  |
| 505 | Difficult | Another great escape | Conway10 / fan:lldb-259 | 219.71 | 389.92 |  |
| 506 | Difficult | Not here and neither there | CRISFN07 / fan:lldb-271 | 219.59 | 408.29 |  |
| 507 | Difficult | Use more blockers | GM00 / fan:lldb-448 | 210.10 | 417.92 |  |
| 508 | Difficult | With Compliments | Oh No! More Lemmings / Tame | 231.34 | 397.63 |  |
| 509 | Difficult | Keeping On Track | Lemmings Plus DOS Project Danger / fan:lldb-554 | 229.85 | 403.75 |  |
| 510 | Difficult | Be cruel with your workers | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 226.73 | 392.46 |  |
| 511 | Difficult | The long way round | GARJEN01 / fan:lldb-281 | 227.38 | 417.61 |  |
| 512 | Difficult | YOUR LEM A SPLODE | Ji Hoons Lemmings Remake Sky / fan:lldb-548 | 222.20 | 395.65 |  |
| 513 | Difficult | Dying Dream | Nepster01 / fan:lldb-219 | 228.62 | 395.97 |  |
| 514 | Difficult | Three different missions | JM18 / fan:lldb-344 | 227.94 | 403.52 |  |
| 515 | Difficult | The Olivine Grotto | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 225.60 | 404.28 |  |
| 516 | Difficult | Not as simple as it looks | GARJEN01 / fan:lldb-281 | 231.40 | 408.74 |  |
| 517 | Difficult | Eeny, meeny, miny... OH! | GARJEN05 / fan:lldb-285 | 223.92 | 417.03 |  |
| 518 | Difficult | Ice Station Lemming | Oh No! More Lemmings / Wild | 243.02 | 388.29 |  |
| 519 | Difficult | worra lorra lemmings | Lemmings / Fun | 240.62 | 412.58 |  |
| 520 | Difficult | Climbing to the Top! | Holiday Lemmings 1993 / Flurry | 240.38 | 417.92 |  |
| 521 | Difficult | Get Together | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 236.24 | 403.75 |  |
| 522 | Difficult | Fix the road, quick! | Genesis Present / fan:lldb-492 | 245.24 | 403.75 |  |
| 523 | Difficult | Under the volcano | hubbart7 / fan:lldb-182 | 244.67 | 388.75 |  |
| 524 | Difficult | Down Under | Van Clan Crazy / fan:lldb-518 | 246.62 | 416.00 |  |
| 525 | Difficult | Electric Circuit | MARSHY06 / fan:lldb-350 | 244.25 | 407.20 |  |
| 526 | Difficult | Fun 29.lvl | Amiga Fun Budget / fan:lldb-568 | 240.62 | 412.58 |  |
| 527 | Difficult | Pillars in the way | CRISFN07 / fan:lldb-271 | 251.41 | 403.75 |  |
| 528 | Difficult | One more.... | ssam1221s Lemmings Tame / fan:lldb-512 | 257.55 | 403.75 |  |
| 529 | Difficult | The trip there and back again.. | New Year Lemmings 1991 92 / fan:lldb-557 | 252.82 | 392.26 |  |
| 530 | Difficult | Up And Down | TWPAK00 / fan:lldb-302 | 252.19 | 395.64 |  |
| 531 | Difficult | Lets Bash That Guy! | TWPAK02 / fan:lldb-304 | 253.37 | 400.73 |  |
| 532 | Difficult | No Use For A Terrain | TWPAK09 / fan:lldb-311 | 255.93 | 397.10 |  |
| 533 | Difficult | Beam me up,Scotty | LEVIPAK4 / fan:lldb-368 | 253.70 | 385.13 |  |
| 534 | Difficult | One Way to Freedom | Orig Extra Levels / fan:lldb-407 | 264.72 | 389.72 |  |
| 535 | Difficult | Sticks to exit | JM12 / fan:lldb-338 | 263.23 | 388.86 |  |
| 536 | Difficult | The Magician's Secret | ISteve02 / fan:lldb-23 | 256.74 | 397.98 |  |
| 537 | Difficult | Inside volcano Villarrica | CRISFN12 / fan:lldb-276 | 254.93 | 404.44 |  |
| 538 | Difficult | Walking With the Letters | cLemmings Mayhem / fan:lldb-529 | 266.43 | 389.90 |  |
| 539 | Difficult | Oblivion | Lemmings Plus DOS Project PSYCHO / fan:lldb-555 | 266.79 | 394.53 |  |
| 540 | Difficult | No justice for the hero | PSP Special 27 36 / fan:lldb-218 | 258.09 | 408.70 |  |
| 541 | Difficult | Have a Pleasant Journey ! | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 268.04 | 395.76 |  |
| 542 | Difficult | The Chosen One | ssam1221s Lemmings Crazy / fan:lldb-513 | 263.70 | 411.12 |  |
| 543 | Difficult | You going to Lemming Master | KillerMasters Lemmings 1 Havoc / fan:lldb-509 | 271.51 | 410.62 |  |
| 544 | Difficult | a quick warm up | Professional Lemmings / fan:lldb-592 | 262.97 | 419.23 |  |
| 545 | Difficult | Spiral staircase | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 278.68 | 415.89 |  |
| 546 | Difficult | No Justice for Heroes | Pieuws Lemmings 2007 Insane / fan:lldb-545 | 277.93 | 385.17 |  |
| 547 | Difficult | The Quarantine | Lemmings Plus DOS Project Mild / fan:lldb-551 | 281.65 | 386.75 |  |
| 548 | Difficult | Hole in One | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 282.49 | 386.75 |  |
| 549 | Difficult | Crying Over Spilt Lemming | Lemmings Plus DOS Project Mild / fan:lldb-551 | 276.86 | 403.20 |  |
| 550 | Difficult | Stairway to Infinity | Lemmings Plus DOS Project Mild / fan:lldb-551 | 273.23 | 404.63 |  |
| 551 | Difficult | The Digfest | Oh No More cLemmings Crazy / fan:lldb-531 | 273.07 | 402.98 |  |
| 552 | Difficult | Have an ice day | Oh No! More Lemmings / Havoc | 284.08 | 385.65 |  |
| 553 | Difficult | gronklems -1.dat 1 | Gronklems 1 / fan:lldb-386 | 276.82 | 408.13 |  |
| 554 | Difficult | Acrophobia | Genesis Present / fan:lldb-492 | 275.67 | 409.06 |  |
| 555 | Difficult | Swallowing Lemmings | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 274.62 | 417.99 |  |
| 556 | Difficult | Maybe not such a doddle | Holiday Lemmings 1994 / Frost | 289.29 | 386.75 |  |
| 557 | Difficult | Let's be careful out there | Lemmings / Fun | 288.66 | 386.75 |  |
| 558 | Difficult | Break On Through | Holiday Lemmings 1994 / Hail | 292.72 | 394.38 |  |
| 559 | Difficult | LOoK BeFoRe YoU LeAp! | Oh No! More Lemmings / Havoc | 296.68 | 395.44 |  |
| 560 | Difficult | The North Poles | Xmas Lemmings 1992 / Xmas | 292.83 | 408.89 |  |
| 561 | Difficult | Lemming Reunification | Holiday Lemmings 1994 / Frost | 289.34 | 417.92 |  |
| 562 | Difficult | Wall in permanent edification | CRISFN09 / fan:lldb-273 | 286.76 | 385.51 |  |
| 563 | Difficult | An "o" to serch | The lemming google pack / fan:lldb-179 | 293.09 | 395.67 |  |
| 564 | Difficult | Get Back | Van Clan Wild / fan:lldb-519 | 293.27 | 403.82 |  |
| 565 | Difficult | Fun 27.lvl | Amiga Fun Budget / fan:lldb-568 | 288.66 | 386.75 |  |
| 566 | Difficult | A Glorious Battle | cLemmings Taxing / fan:lldb-528 | 293.32 | 409.56 |  |
| 567 | Difficult | It's not impossible | JM12 / fan:lldb-338 | 288.66 | 419.52 |  |
| 568 | Difficult | Be sure to be a builder. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 302.66 | 388.98 |  |
| 569 | Difficult | This should be a doddle! | Lemmings / Tricky | 299.58 | 386.75 |  |
| 570 | Difficult | Lemmings in the attic | Lemmings / Tricky | 309.71 | 386.75 |  |
| 571 | Difficult | Watch your step | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 308.23 | 416.39 |  |
| 572 | Difficult | The big brick wall | CRISFN12 / fan:lldb-276 | 302.31 | 388.97 |  |
| 573 | Difficult | I have a very cunning plan | Conway07 / fan:lldb-256 | 306.78 | 386.75 |  |
| 574 | Difficult | Fortissimo | cLemmings Tricky / fan:lldb-527 | 308.15 | 386.75 |  |
| 575 | Difficult | Tricky 01.lvl | Amiga Tricky Budget / fan:lldb-569 | 303.50 | 386.75 |  |
| 576 | Difficult | In The Style Of... | Lemmings Plus DOS Project Mild / fan:lldb-551 | 301.13 | 400.44 |  |
| 577 | Difficult | Dolly Dimple | Oh No! More Lemmings / Crazy | 312.59 | 391.76 |  |
| 578 | Difficult | Rent-a-Lemming | Oh No! More Lemmings / Tame | 319.26 | 408.13 |  |
| 579 | Difficult | Higgledy Piggledy | Oh No! More Lemmings / Wild | 316.87 | 416.03 |  |
| 580 | Difficult | Curse of the Pharaohs | Lemmings / Mayhem | 314.49 | 413.48 |  |
| 581 | Difficult | Leftovers are not always a waste | Genesis Mayhem / fan:lldb-491 | 312.78 | 390.60 |  |
| 582 | Difficult | Ornamental Discoveries | cLemmings Mayhem / fan:lldb-529 | 310.72 | 393.30 |  |
| 583 | Difficult | Whoa, man! | CRISFN03 / fan:lldb-267 | 314.34 | 401.11 |  |
| 584 | Difficult | Let's review what they can do | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 318.42 | 413.68 |  |
| 585 | Difficult | Mayhem 09.lvl | Amiga Mayhem Budget / fan:lldb-571 | 314.55 | 413.48 |  |
| 586 | Difficult | Rock Desert | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 318.51 | 402.98 |  |
| 587 | Difficult | Lemming hell | CRISFN02 / fan:lldb-266 | 312.69 | 419.90 |  |
| 588 | Difficult | Impossbile... NOT!! | JM16 / fan:lldb-342 | 312.70 | 415.11 |  |
| 589 | Difficult | Eye of the Lemming | Lemmings Plus DOS Project Medi / fan:lldb-553 | 309.99 | 418.92 |  |
| 590 | Difficult | Perseverance | Lemmings / Taxing | 320.77 | 402.67 |  |
| 591 | Difficult | The Lemming Learning Curve | Oh No! More Lemmings / Wicked | 325.11 | 386.75 |  |
| 592 | Difficult | Presents of Mind II | Holiday Lemmings 1993 / Blizzard | 321.70 | 406.61 |  |
| 593 | Difficult | Steel Works | Lemmings / Mayhem | 333.15 | 401.72 |  |
| 594 | Difficult | Bewildered Lemmings | JEFFPCK7 / fan:lldb-241 | 329.96 | 386.75 |  |
| 595 | Difficult | Step Up! | Lemmings Plus DOS Project Medi / fan:lldb-553 | 331.54 | 400.06 |  |
| 596 | Difficult | The basin | Gronklems 1 / fan:lldb-384 | 323.30 | 388.02 |  |
| 597 | Difficult | Stunt Double | GARJEN01 / fan:lldb-281 | 331.99 | 403.33 |  |
| 598 | Difficult | An Unwelcome Sight | cLemmings Mayhem / fan:lldb-529 | 326.12 | 388.98 |  |
| 599 | Difficult | A sunny day | CRISFN09 / fan:lldb-273 | 323.54 | 403.78 |  |
| 600 | Difficult | Mary Poppins` land | Lemmings / Taxing | 338.28 | 396.82 |  |
| 601 | Difficult | Descending Pillar Scenario | JANNPCK4 / fan:lldb-234 | 334.15 | 389.82 |  |
| 602 | Difficult | Steel Works (part two) | Conway Challenges 1 / fan:lldb-263 | 335.49 | 401.72 |  |
| 603 | Difficult | Notch what you think it is! | PSP Special 27 36 / fan:lldb-218 | 328.43 | 409.44 |  |
| 604 | Difficult | The Great Lemming Caper | Lemmings / Mayhem | 342.90 | 386.75 |  |
| 605 | Difficult | Triple Trouble | Lemmings / Taxing | 341.86 | 386.75 |  |
| 606 | Difficult | The exit has been blocked | joem4 / fan:lldb-468 | 340.67 | 387.11 |  |
| 607 | Difficult | Taxing 16.lvl | Amiga Taxing Budget / fan:lldb-570 | 338.55 | 397.86 |  |
| 608 | Difficult | The bridge is breaking down. | Genesis Taxing / fan:lldb-490 | 341.32 | 399.79 |  |
| 609 | Difficult | Is So Easy! | ISteve02 / fan:lldb-23 | 343.86 | 412.44 |  |
| 610 | Difficult | Chameleon garden | CRISFN15 / fan:lldb-279 | 344.33 | 411.97 |  |
| 611 | Difficult | Let's climb trough now... | Leviathans Other Levels / fan:lldb-457 | 335.92 | 415.77 |  |
| 612 | Difficult | Lemmingsense | Lemmings Plus DOS Project Medi / fan:lldb-553 | 338.62 | 405.90 |  |
| 613 | Difficult | Old roman room | CRISFN10 / fan:lldb-274 | 334.54 | 417.63 |  |
| 614 | Difficult | Poles Apart | Lemmings / Mayhem | 349.15 | 414.93 |  |
| 615 | Difficult | Taxing 26.lvl | Amiga Taxing Budget / fan:lldb-570 | 346.62 | 386.75 |  |
| 616 | Difficult | Sparkle & Glitter | AkseliPack01 / fan:lldb-220 | 343.64 | 417.92 |  |
| 617 | Difficult | Watch right or left (Part two) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 357.49 | 387.91 |  |
| 618 | Difficult | Lemmy in the cold, cold ground | Holiday Lemmings 1994 / Hail | 359.03 | 414.75 |  |
| 619 | Difficult | Dinosaur bones | CRISFN15 / fan:lldb-279 | 353.71 | 386.75 |  |
| 620 | Difficult | Mayhem 07.lvl | Amiga Mayhem Budget / fan:lldb-571 | 351.25 | 414.93 |  |
| 621 | Difficult | Worra load of old blocks! | Oh No! More Lemmings / Crazy | 363.16 | 407.75 |  |
| 622 | Difficult | No added colours or Lemmings | Lemmings / Mayhem | 364.20 | 416.59 |  |
| 623 | Difficult | My stupid idea! | Lemmy556 More levels / fan:lldb-68 | 363.36 | 386.75 |  |
| 624 | Difficult | Antigravity hall | CRISFN15 / fan:lldb-279 | 370.44 | 386.75 |  |
| 625 | Difficult | Two ways to difficult | CRISFN13 / fan:lldb-277 | 370.49 | 404.60 |  |
| 626 | Difficult | Impossible ? | Mikepak02 / fan:lldb-7 | 370.43 | 406.80 |  |
| 627 | Difficult | Two good friends | PSP Special 11 26 of 36 / fan:lldb-217 | 362.14 | 406.41 |  |
| 628 | Difficult | Scaling the Heights | Oh No! More Lemmings / Havoc | 372.17 | 403.50 |  |
| 629 | Difficult | Mayhem 20.lvl | Amiga Mayhem Budget / fan:lldb-571 | 366.30 | 416.59 |  |
| 630 | Difficult | No world without you | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 382.47 | 386.75 |  |
| 631 | Difficult | You Take the High Road | Oh No! More Lemmings / Wild | 383.35 | 412.58 |  |
| 632 | Difficult | Which one are you trying to get? | Genesis Present / fan:lldb-492 | 402.72 | 402.72 |  |
| 633 | Difficult | Four Lemmings and a Funeral | MazuLems 03 / fan:lldb-246 | 402.14 | 402.14 |  |
| 634 | Difficult | No added colors or Lemmings | Genesis Mayhem / fan:lldb-491 | 417.08 | 417.08 |  |
| 635 | Difficult | Diet Lemmingaid | Lemmings / Tricky | 144.50 | 422.94 |  |
| 636 | Difficult | Intro to MCMarshy01.dat | MARSHY01 / fan:lldb-345 | 140.79 | 422.68 |  |
| 637 | Difficult | We all fall down | Lemmings / Fun | 157.63 | 453.02 |  |
| 638 | Difficult | Only climbers can do this | MARSHY01 / fan:lldb-345 | 149.82 | 422.98 |  |
| 639 | Difficult | Fun 13.lvl | Amiga Fun Budget / fan:lldb-568 | 152.63 | 425.70 |  |
| 640 | Difficult | Climbing all the way | ANTHPCK1 / fan:lldb-221 | 152.90 | 425.01 |  |
| 641 | Difficult | Tailor-made for floaters | MARSHY01 / fan:lldb-345 | 154.99 | 429.86 |  |
| 642 | Difficult | Take Your Time... | Lemmings Plus DOS Project Mild / fan:lldb-551 | 152.20 | 425.46 |  |
| 643 | Difficult | Training 02 - Let's Float! | JEFFPCK6 / fan:lldb-240 | 150.00 | 433.14 |  |
| 644 | Difficult | Tricky 02.lvl | Amiga Tricky Budget / fan:lldb-569 | 157.60 | 435.04 |  |
| 645 | Difficult | Where are you heading? | Genesis Present / fan:lldb-492 | 156.48 | 440.53 |  |
| 646 | Difficult | The Impossible Gap | MARSHY07 / fan:lldb-351 | 150.28 | 440.36 |  |
| 647 | Difficult | Classic lems find new home(Lem3) | Lemmy556 My little levels 2 / fan:lldb-66 | 160.73 | 441.23 |  |
| 648 | Difficult | Taxing 30.lvl | Amiga Taxing Budget / fan:lldb-570 | 161.55 | 444.39 |  |
| 649 | Difficult | Speed Freaks | Ji Hoons Lemmings Remake Earth / fan:lldb-549 | 160.10 | 442.74 |  |
| 650 | Difficult | Mayhem 11.lvl | Amiga Mayhem Budget / fan:lldb-571 | 165.06 | 453.74 |  |
| 651 | Difficult | Use your brain to climb | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 159.59 | 452.61 |  |
| 652 | Difficult | Ski Jump! | Holiday Lemmings 1994 / Frost | 170.09 | 450.25 |  |
| 653 | Difficult | Separate Ways | Holiday Lemmings 1994 / Frost | 182.16 | 434.92 |  |
| 654 | Difficult | The Box. | isupck02 / fan:lldb-353 | 182.04 | 434.45 |  |
| 655 | Difficult | Weave Your Lemmings | TWPAK09 / fan:lldb-311 | 180.38 | 428.07 |  |
| 656 | Difficult | Rules to fall | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 208.05 | 435.48 |  |
| 657 | Difficult | Exit below... | JM15 / fan:lldb-341 | 202.06 | 437.31 |  |
| 658 | Difficult | Snakebitten! | QBeez02 / fan:lldb-30 | 200.43 | 447.59 |  |
| 659 | Difficult | Bad luck | Epic giga01 / fan:lldb-139 | 220.98 | 429.61 |  |
| 660 | Difficult | Roundabout Route (Lem'ka) | justdigcomp / fan:lldb-374 | 219.54 | 435.99 |  |
| 661 | Difficult | Go Behind and Look for Exit (2) | ssam1221s Lemmings Wild / fan:lldb-514 | 212.66 | 443.38 |  |
| 662 | Difficult | FunnyTopia | KillerMasters Lemmings 1 Wicked / fan:lldb-508 | 211.14 | 447.37 |  |
| 663 | Difficult | The Placement is the Key | ISteve04 / fan:lldb-24 | 212.03 | 450.97 |  |
| 664 | Difficult | PoP TiL YoU DrOp! | Oh No! More Lemmings / Wicked | 233.05 | 443.75 |  |
| 665 | Difficult | Know that ? | Mikepak10 / fan:lldb-15 | 229.39 | 447.44 |  |
| 666 | Difficult | So near, so far | PSP Special 1 10 of 36 / fan:lldb-216 | 235.50 | 434.54 |  |
| 667 | Difficult | Art Thou Bubbly Feeleth? | TWPAK05 / fan:lldb-307 | 229.63 | 442.32 |  |
| 668 | Difficult | Day by Day | JM01 / fan:lldb-327 | 234.15 | 445.23 |  |
| 669 | Difficult | Snow Lev 1 | ANTHPCK4 / fan:lldb-224 | 225.57 | 454.90 |  |
| 670 | Difficult | Lemmings Up High | Holiday Lemmings 1993 / Blizzard | 236.12 | 436.93 |  |
| 671 | Difficult | Plethora of Presents | Holiday Lemmings 1994 / Frost | 236.95 | 438.61 |  |
| 672 | Difficult | Down the line | PSP Special 11 26 of 36 / fan:lldb-217 | 236.02 | 424.38 |  |
| 673 | Difficult | Partition Casualties | cLemmings Tricky / fan:lldb-527 | 251.89 | 432.50 |  |
| 674 | Difficult | Let the Magic happen ! | Pieuws Lemmings 2007 Insane / fan:lldb-545 | 250.70 | 424.27 |  |
| 675 | Difficult | Chameleon fall | CRISFN03 / fan:lldb-267 | 241.93 | 443.38 |  |
| 676 | Difficult | Undercover Lemming | Oh No! More Lemmings / Tame | 252.68 | 439.63 |  |
| 677 | Difficult | Steps | Lemmings Plus DOS Project Danger / fan:lldb-554 | 253.89 | 439.60 |  |
| 678 | Difficult | Back of the net! | PSP Special 11 26 of 36 / fan:lldb-217 | 257.48 | 421.74 |  |
| 679 | Difficult | Only One Shot | Van Clan Wild / fan:lldb-519 | 253.51 | 425.88 |  |
| 680 | Difficult | The wall of death | ANTHPCK5 / fan:lldb-225 | 264.37 | 437.30 |  |
| 681 | Difficult | Let you down | JM05 / fan:lldb-331 | 254.99 | 444.89 |  |
| 682 | Difficult | The Land of the Bizarre | Holiday Lemmings 1994 / Frost | 271.80 | 442.26 |  |
| 683 | Difficult | Looks a Bit Nippy Out There | Oh No! More Lemmings / Havoc | 271.14 | 441.48 |  |
| 684 | Difficult | Digging Tasks | Holiday cLemmings Frost / fan:lldb-535 | 271.18 | 421.25 |  |
| 685 | Difficult | Only two minutes | MARSHY03 / fan:lldb-347 | 262.71 | 449.31 |  |
| 686 | Difficult | Christmas at Damocles' | Ron Stards Rodents / fan:lldb-471 | 264.43 | 445.42 |  |
| 687 | Difficult | Monkey Magic | Deceits Lemmings Tricky / fan:lldb-523 | 262.75 | 447.60 |  |
| 688 | Difficult | Excavation Station | TWPAK00 / fan:lldb-302 | 265.20 | 421.90 |  |
| 689 | Difficult | The Yetilem's Lair | ssam1221s Lemmings Wild / fan:lldb-514 | 268.65 | 453.30 |  |
| 690 | Difficult | Price to play the game | JM14 / fan:lldb-340 | 280.97 | 434.93 |  |
| 691 | Difficult | The run around | PSP Special 11 26 of 36 / fan:lldb-217 | 280.81 | 446.49 |  |
| 692 | Difficult | You Live and Lem (remake) | LEMREMAKE / fan:lldb-465 | 270.98 | 450.00 |  |
| 693 | Difficult | Let's Go! | Lemmings Plus DOS Project Mild / fan:lldb-551 | 277.22 | 446.61 |  |
| 694 | Difficult | Time to Go Down | SeverSet2 / fan:lldb-184 | 283.60 | 433.68 |  |
| 695 | Difficult | X Marks Nothing | Pieuw02 / fan:lldb-394 | 285.36 | 448.63 |  |
| 696 | Difficult | Dig Down, Bash Across | PSP Special 1 10 of 36 / fan:lldb-216 | 283.70 | 429.10 |  |
| 697 | Difficult | Goldlemming! | Oh No More cLemmings Crazy / fan:lldb-531 | 276.21 | 450.50 |  |
| 698 | Difficult | A Single Lemming... | Holiday Lemmings 1993 / Blizzard | 296.68 | 433.25 |  |
| 699 | Difficult | The beast is waiting | CRISFN03 / fan:lldb-267 | 288.64 | 444.48 |  |
| 700 | Difficult | The Quarry | cLemmings Taxing / fan:lldb-528 | 297.78 | 428.32 |  |
| 701 | Difficult | Snow Lev 3 | ANTHPCK4 / fan:lldb-224 | 297.74 | 435.06 |  |
| 702 | Difficult | Dirt Runner | Nepster01 / fan:lldb-219 | 297.79 | 450.70 |  |
| 703 | Difficult | Suicidal Tendencies | Oh No! More Lemmings / Wicked | 318.35 | 422.75 |  |
| 704 | Difficult | Just a Minute... | Lemmings / Mayhem | 312.01 | 454.90 |  |
| 705 | Difficult | Lots of Steel crates! | Save the Lemmings / fan:lldb-584 | 310.84 | 420.49 |  |
| 706 | Difficult | Just about right | JANNPCK1 / fan:lldb-231 | 314.03 | 430.64 |  |
| 707 | Difficult | One plan is... | ANTHPCK2 / fan:lldb-222 | 319.85 | 424.68 |  |
| 708 | Difficult | Down the cliff | geooPk0 / fan:lldb-1 | 310.54 | 431.23 |  |
| 709 | Difficult | Lemming about town | Oh No! More Lemmings / Havoc | 321.74 | 426.76 |  |
| 710 | Difficult | And now, the end is near... | Oh No! More Lemmings / Crazy | 320.71 | 452.04 |  |
| 711 | Difficult | Lemming Packaging Facility | cLemmings Mayhem / fan:lldb-529 | 313.67 | 440.44 |  |
| 712 | Difficult | Just Dig! Again! | Yawg06 / fan:lldb-161 | 320.83 | 454.17 |  |
| 713 | Difficult | The Descending Pillar Scenario | Lemmings Plus DOS Project Mild / fan:lldb-551 | 315.02 | 450.00 |  |
| 714 | Difficult | Stop Right There! | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 314.82 | 450.00 |  |
| 715 | Difficult | DON`T PANIC | Oh No! More Lemmings / Crazy | 325.48 | 421.70 |  |
| 716 | Difficult | Five Alive | Oh No! More Lemmings / Wicked | 330.16 | 441.22 |  |
| 717 | Difficult | LeMming ToMato KetchUp fAcilitY | Oh No! More Lemmings / Wicked | 326.42 | 450.00 |  |
| 718 | Difficult | The Next Lemeration | Holiday Lemmings 1993 / Blizzard | 339.35 | 450.00 |  |
| 719 | Difficult | Out, away from the tune | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 340.13 | 454.58 |  |
| 720 | Difficult | The exit is blocked | ANTHPCK2 / fan:lldb-222 | 332.46 | 426.33 |  |
| 721 | Difficult | Haunted botanical garden | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 343.01 | 442.64 |  |
| 722 | Difficult | Two's Company | Deceits Lemmings Tricky / fan:lldb-523 | 343.09 | 435.82 |  |
| 723 | Difficult | Warmth of the Ice | JANNPCK1 / fan:lldb-231 | 342.96 | 432.83 |  |
| 724 | Difficult | Challenge level | Level Design Game 09 / fan:lldb-438 | 341.96 | 450.00 |  |
| 725 | Difficult | For Every Lemming, Turn, Turn... | Lemmings The Official Companion / fan:lldb-585 | 342.49 | 450.00 |  |
| 726 | Difficult | The Razor's Edge | ISteve02 / fan:lldb-23 | 342.61 | 450.00 |  |
| 727 | Difficult | The Unidentified Territory | TUT / fan:lldb-400 | 343.57 | 450.00 |  |
| 728 | Difficult | 4 to 3 | Giga pack 07 / fan:lldb-169 | 341.26 | 425.00 |  |
| 729 | Difficult | All the small things | CRISFN06 / fan:lldb-270 | 344.47 | 450.00 |  |
| 730 | Difficult | Easy? | CRISFN05 / fan:lldb-269 | 334.98 | 439.82 |  |
| 731 | Difficult | Feel the heat! | Lemmings / Taxing | 346.04 | 450.00 |  |
| 732 | Difficult | Postcard from Lemmingland | Lemmings / Tricky | 346.74 | 450.00 |  |
| 733 | Difficult | Lend a helping hand.... | Lemmings / Taxing | 353.52 | 450.00 |  |
| 734 | Difficult | Get Deeper and Down | GARJEN01 / fan:lldb-281 | 354.57 | 425.56 |  |
| 735 | Difficult | Cyborglem Lab | KillerMasters Lemmings 1 Wild / fan:lldb-507 | 354.96 | 452.84 |  |
| 736 | Difficult | A Trap is a trap | MARSHY06 / fan:lldb-350 | 347.23 | 427.57 |  |
| 737 | Difficult | A pillar runs through it | ANTHPCK3 / fan:lldb-223 | 346.92 | 450.00 |  |
| 738 | Difficult | Every Lemming for himself!!! | Lemmings / Taxing | 360.25 | 427.43 |  |
| 739 | Difficult | It's Boxing Day! | Holiday Lemmings 1994 / Frost | 357.30 | 444.75 |  |
| 740 | Difficult | with a little help from my Lem | PSP Special 11 26 of 36 / fan:lldb-217 | 359.86 | 433.18 |  |
| 741 | Difficult | Stargazing! | GARJEN01 / fan:lldb-281 | 360.80 | 445.57 |  |
| 742 | Difficult | Rip your hair out Mr. Lemming | ISteve02 / fan:lldb-23 | 359.06 | 450.00 |  |
| 743 | Difficult | Fallen | Lemmings Plus DOS Project Medi / fan:lldb-553 | 350.82 | 450.00 |  |
| 744 | Difficult | Tutankhamon | JANNPCK2 / fan:lldb-232 | 356.74 | 450.00 |  |
| 745 | Difficult | The Dukes of Lemmingsville | Lemmings Plus DOS Project Medi / fan:lldb-553 | 351.07 | 434.70 |  |
| 746 | Difficult | One walked over the lemming nest | ANTHPCK3 / fan:lldb-223 | 364.94 | 420.09 |  |
| 747 | Difficult | Taxing 07.lvl | Amiga Taxing Budget / fan:lldb-570 | 362.47 | 427.88 |  |
| 748 | Difficult | Bashing & Building | Nepster01 / fan:lldb-219 | 375.11 | 424.82 |  |
| 749 | Difficult | Dunes | Nepster01 / fan:lldb-219 | 367.72 | 450.00 |  |
| 750 | Difficult | Pass The Obstacles | JANNPCK1 / fan:lldb-231 | 369.40 | 451.66 |  |
| 751 | Difficult | Take A Dive | Lemmings Plus DOS Project Medi / fan:lldb-553 | 374.46 | 450.00 |  |
| 752 | Difficult | Planks | GeoffLems Minipack / fan:lldb-413 | 371.98 | 454.58 |  |
| 753 | Difficult | There`s madness in the method | Oh No! More Lemmings / Havoc | 391.12 | 448.24 |  |
| 754 | Difficult | The Great Wall, part two | Eymerich02 / fan:lldb-4 | 384.18 | 439.67 |  |
| 755 | Difficult | Just as You'd Expect | geoopck2 / fan:lldb-388 | 388.93 | 422.79 |  |
| 756 | Difficult | Diamond Ribs | Pieuws Lemmings 2007 Insane / fan:lldb-545 | 381.71 | 445.56 |  |
| 757 | Difficult | Everyone's a hard nut. | Genesis Present / fan:lldb-492 | 392.62 | 437.70 |  |
| 758 | Difficult | Lemming of Sorrows | JannPck3 / fan:lldb-233 | 386.00 | 450.00 |  |
| 759 | Difficult | HIGHLAND FLING | Oh No! More Lemmings / Havoc | 400.72 | 450.00 |  |
| 760 | Difficult | Chilly Lemmings | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 398.30 | 421.59 |  |
| 761 | Difficult | The Drowning Walk | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 398.46 | 450.00 |  |
| 762 | Difficult | Don't dig yet | lm set09 / fan:lldb-50 | 401.74 | 450.00 |  |
| 763 | Difficult | The way up | geooPk1 / fan:lldb-2 | 396.18 | 450.00 |  |
| 764 | Difficult | Hunt the Nessy.... | Lemmings / Taxing | 410.57 | 436.51 |  |
| 765 | Difficult | Rendezvous II | Holiday Lemmings 1994 / Hail | 410.10 | 450.50 |  |
| 766 | Difficult | Frozen Soil | JANNPCK2 / fan:lldb-232 | 416.08 | 450.00 |  |
| 767 | Difficult | The Pool | MazuLems 01 / fan:lldb-244 | 411.98 | 450.00 |  |
| 768 | Difficult | Dirty way | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 414.01 | 450.00 |  |
| 769 | Difficult | The Pool | MARTPCK1 / fan:lldb-495 | 412.18 | 450.00 |  |
| 770 | Difficult | It's not that easy, I'm afraid | ISteve01 / fan:lldb-20 | 409.16 | 450.00 |  |
| 771 | Difficult | The Unprofessional Looking Level | ISteve03 / fan:lldb-21 | 421.35 | 450.00 |  |
| 772 | Difficult | Kung-Fu Bashing | E3Levelpack F / fan:lldb-372 | 425.76 | 451.71 |  |
| 773 | Difficult | Time Gate | Nepster01 / fan:lldb-219 | 429.32 | 437.08 |  |
| 774 | Difficult | Dependency Puzzle | Level Design Game 06 / fan:lldb-435 | 154.99 | 463.87 |  |
| 775 | Difficult | Times running out hurry | joem5 / fan:lldb-320 | 154.38 | 466.89 |  |
| 776 | Difficult | Just two minutes | JM06 / fan:lldb-332 | 160.02 | 477.84 |  |
| 777 | Difficult | A Rainstorm | SeverSet2 / fan:lldb-184 | 163.10 | 484.32 |  |
| 778 | Difficult | Tailor-made for blockers | Lemmings / Fun | 188.60 | 486.10 |  |
| 779 | Difficult | Simple lemminga level | Lemmy556 More levels / fan:lldb-68 | 190.18 | 455.00 |  |
| 780 | Difficult | Over the Lune | MARSHY07 / fan:lldb-351 | 195.51 | 457.56 |  |
| 781 | Difficult | None title | Genesis Present / fan:lldb-492 | 191.70 | 467.81 |  |
| 782 | Difficult | Masterplan | weirdy01 version 2 / fan:lldb-133 | 204.41 | 473.00 |  |
| 783 | Difficult | The Buildo Station | Lemmings Plus DOS Project Danger / fan:lldb-554 | 197.27 | 477.35 |  |
| 784 | Difficult | Well, Well, Well | TWPAK13 / fan:lldb-315 | 197.38 | 482.31 |  |
| 785 | Difficult | The Grass-moving pool for you! | CRISFN14 / fan:lldb-278 | 207.69 | 455.00 |  |
| 786 | Difficult | The Killing Game Show II | New Year Lemmings 1991 92 / fan:lldb-557 | 212.72 | 486.50 |  |
| 787 | Difficult | ROCKY XI | ssam1221s Lemmings Tame / fan:lldb-512 | 238.48 | 455.00 |  |
| 788 | Difficult | Further Down The Drain | TWPAK02 / fan:lldb-304 | 231.01 | 458.97 |  |
| 789 | Difficult | Crossing one gap | CRISFN07 / fan:lldb-271 | 235.70 | 478.32 |  |
| 790 | Difficult | The race of the obstacles | CRISFN12 / fan:lldb-276 | 236.50 | 478.73 |  |
| 791 | Difficult | Lonely Day | JM13 / fan:lldb-339 | 237.18 | 459.00 |  |
| 792 | Difficult | Life, the Universe, & Everything | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 237.43 | 459.00 |  |
| 793 | Difficult | Twins | Genesis Mayhem / fan:lldb-491 | 231.03 | 456.54 |  |
| 794 | Difficult | Maybe would be a doddle! | CRISFN11 / fan:lldb-275 | 228.88 | 478.65 |  |
| 795 | Difficult | Up, Down or Round and Round | Oh No! More Lemmings / Wicked | 242.67 | 456.73 |  |
| 796 | Difficult | Is this a circus? | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 239.53 | 480.77 |  |
| 797 | Difficult | ****ing Word!! | KillerMasters Lemmings 1 Wicked / fan:lldb-508 | 239.69 | 462.74 |  |
| 798 | Difficult | Time is getting on | JM10 / fan:lldb-336 | 247.75 | 480.08 |  |
| 799 | Difficult | The Pipeline | Lemmings The Official Companion / fan:lldb-585 | 249.66 | 482.04 |  |
| 800 | Difficult | Die the Death of the Damned | Lemmings Plus DOS Project Danger / fan:lldb-554 | 249.65 | 485.30 |  |
| 801 | Difficult | Genome Project | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 251.74 | 459.00 |  |
| 802 | Difficult | Tightrope | JM01 / fan:lldb-327 | 242.35 | 471.75 |  |
| 803 | Difficult | Dr Lemminggood | Oh No! More Lemmings / Wild | 252.87 | 459.00 |  |
| 804 | Difficult | A Giant Leap for Lemkind | ccexplores test levels / fan:lldb-447 | 253.21 | 473.96 |  |
| 805 | Difficult | Easy Does It | weirdy01 version 2 / fan:lldb-133 | 248.24 | 487.06 |  |
| 806 | Difficult | Fast Drop | SeverSet1 / fan:lldb-183 | 243.73 | 489.32 |  |
| 807 | Difficult | The Voyage Home... | Holiday Lemmings 1993 / Blizzard | 257.20 | 459.25 |  |
| 808 | Difficult | Turn around young lemmings! (rm) | LEMREMAKE / fan:lldb-465 | 261.77 | 457.62 |  |
| 809 | Difficult | Digger Conversions | Lemmings The Official Companion / fan:lldb-585 | 262.26 | 470.88 |  |
| 810 | Difficult | Walk Right | JM09 / fan:lldb-335 | 263.62 | 459.00 |  |
| 811 | Difficult | Lemmings on Stilts | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 257.42 | 459.00 |  |
| 812 | Difficult | Lemming in the attic | Genesis Tricky / fan:lldb-489 | 260.70 | 459.00 |  |
| 813 | Difficult | The Stairs to Lemminghood | cLemmings Fun / fan:lldb-526 | 258.14 | 459.00 |  |
| 814 | Difficult | Say your prayers, Lemmings! | CRISFN10 / fan:lldb-274 | 263.89 | 481.77 |  |
| 815 | Difficult | Warning: One Minute | JM14 / fan:lldb-340 | 254.17 | 488.25 |  |
| 816 | Difficult | Lemmingdelica | Oh No! More Lemmings / Wild | 267.48 | 459.00 |  |
| 817 | Difficult | Traffic Policemen are Comming ! | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 265.28 | 459.00 |  |
| 818 | Difficult | Tour de Lemming | cLemmings Fun / fan:lldb-526 | 276.20 | 459.00 |  |
| 819 | Difficult | Confirm Me | Level Design Game 02 / fan:lldb-431 | 273.25 | 455.93 |  |
| 820 | Difficult | Oh no! Level 6 more difficult! | Mikepak13 / fan:lldb-18 | 268.40 | 463.12 |  |
| 821 | Difficult | Go Behind and Look for Exit | ssam1221s Lemmings Tame / fan:lldb-512 | 279.82 | 467.40 |  |
| 822 | Difficult | Acid rendezvous | CRISFN15 / fan:lldb-279 | 275.42 | 463.33 |  |
| 823 | Difficult | InTeRnEt l33tSpEaK | QBeez04 / fan:lldb-49 | 274.02 | 466.68 |  |
| 824 | Difficult | Lemming Crystaliers | cLemmings Fun / fan:lldb-526 | 279.37 | 459.00 |  |
| 825 | Difficult | Lower Threshold | JANNPCK4 / fan:lldb-234 | 270.60 | 478.14 |  |
| 826 | Difficult | Blowtorches are fun! | m 91 1 / fan:lldb-362 | 280.79 | 459.00 |  |
| 827 | Difficult | Unwilling Funambulist | Pieuw01 / fan:lldb-393 | 279.46 | 475.52 |  |
| 828 | Difficult | Circuit bent | Level Design Game 02 / fan:lldb-431 | 272.22 | 481.68 |  |
| 829 | Difficult | No time for a detour | Genesis Present / fan:lldb-492 | 277.39 | 479.65 |  |
| 830 | Difficult | Roman pillars | CRISFN15 / fan:lldb-279 | 271.57 | 484.80 |  |
| 831 | Difficult | Quest for Kieran | Holiday Lemmings 1994 / Frost | 288.50 | 459.00 |  |
| 832 | Difficult | No choice but to follow them | Genesis Taxing / fan:lldb-490 | 285.13 | 459.00 |  |
| 833 | Difficult | Libra (Part two) | Genesis Present / fan:lldb-492 | 291.91 | 459.00 |  |
| 834 | Difficult | Watch right or left! | Genesis Taxing / fan:lldb-490 | 291.04 | 459.00 |  |
| 835 | Difficult | Don't look Downwards ! | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 283.01 | 459.00 |  |
| 836 | Difficult | Blind Diggin' II | JEFFPCK7 / fan:lldb-241 | 282.73 | 459.40 |  |
| 837 | Difficult | Broken bridge!! | CRISFN09 / fan:lldb-273 | 283.27 | 467.75 |  |
| 838 | Difficult | Pharaoh's Tomb | QBeez01 / fan:lldb-29 | 283.95 | 472.61 |  |
| 839 | Difficult | Ellipsis | cLemmings Fun / fan:lldb-526 | 282.74 | 459.00 |  |
| 840 | Difficult | Build and Dig | brickpk2 / fan:lldb-559 | 290.08 | 459.00 |  |
| 841 | Difficult | Mind your step | joem1 / fan:lldb-317 | 288.93 | 484.50 |  |
| 842 | Difficult | Under construction | Genesis Fun / fan:lldb-488 | 281.94 | 486.10 |  |
| 843 | Difficult | CindyLand | Holiday Lemmings 1994 / Frost | 298.86 | 459.00 |  |
| 844 | Difficult | As long as you try your best | Lemmings / Fun | 296.53 | 475.90 |  |
| 845 | Difficult | Two Pathways | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 299.66 | 459.00 |  |
| 846 | Difficult | Carnivorous Crystals | cLemmings Tricky / fan:lldb-527 | 297.50 | 459.00 |  |
| 847 | Difficult | Heaven Can Wait II | Save the Lemmings / fan:lldb-584 | 292.74 | 459.00 |  |
| 848 | Difficult | Tailor-made for builders | ANTHPCK3 / fan:lldb-223 | 293.65 | 459.00 |  |
| 849 | Difficult | Acid exit | CRISFN01 / fan:lldb-265 | 292.96 | 459.00 |  |
| 850 | Difficult | The Trickster | cLemmings Tricky / fan:lldb-527 | 299.22 | 459.00 |  |
| 851 | Difficult | Lemming road | Lemmings platinum Careful Part 1 / fan:lldb-188 | 291.98 | 459.00 |  |
| 852 | Difficult | So much with my lemmings | Deceits Lemmings Fun / fan:lldb-522 | 301.26 | 459.00 |  |
| 853 | Difficult | Make him act before Falling | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 294.04 | 459.00 |  |
| 854 | Difficult | Someone Spiked The Lemmings | TWPAK09 / fan:lldb-311 | 299.89 | 459.00 |  |
| 855 | Difficult | The Splatathon | cLemmings Mayhem / fan:lldb-529 | 301.28 | 459.00 |  |
| 856 | Difficult | Mount Highpick | CRISFN08 / fan:lldb-272 | 295.39 | 459.00 |  |
| 857 | Difficult | Something weighing on your mind? | DOS Taxing Book Club / fan:lldb-580 | 292.35 | 459.00 |  |
| 858 | Difficult | Up, up, and away! | Holiday Lemmings 1994 / Hail | 305.48 | 459.00 |  |
| 859 | Difficult | Steel Ice Span | Holiday Lemmings 1994 / Hail | 308.87 | 459.00 |  |
| 860 | Difficult | With a twist of lemming please | Lemmings / Mayhem | 304.53 | 473.41 |  |
| 861 | Difficult | Here is Mr.Lemming's house | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 311.52 | 470.06 |  |
| 862 | Difficult | Two ponds | Genesis Mayhem / fan:lldb-491 | 307.66 | 459.00 |  |
| 863 | Difficult | Where Lemming lies bleeding | JANNPCK2 / fan:lldb-232 | 317.42 | 459.00 |  |
| 864 | Difficult | Over the wall | Genesis Mayhem / fan:lldb-491 | 312.72 | 459.00 |  |
| 865 | Difficult | Got anything....Lemmingy??? | Oh No! More Lemmings / Wild | 322.96 | 459.00 |  |
| 866 | Difficult | Bridge Delay! | Lemmings The Official Companion / fan:lldb-585 | 323.64 | 459.00 |  |
| 867 | Difficult | Got Climbers? | JM08 / fan:lldb-334 | 318.74 | 459.00 |  |
| 868 | Difficult | Welcome to Hell | Levelpak001 / fan:lldb-389 | 316.59 | 459.00 |  |
| 869 | Difficult | Cold war | Snow remakes 01 / fan:lldb-144 | 323.83 | 462.04 |  |
| 870 | Difficult | General wooden contraption no.73 | Level Design Game 05 / fan:lldb-434 | 322.88 | 456.22 |  |
| 871 | Difficult | Desert by Night | JANNPCK1 / fan:lldb-231 | 323.97 | 474.02 |  |
| 872 | Difficult | Time, Time, Time! | Oh No More cLemmings Crazy / fan:lldb-531 | 320.17 | 463.67 |  |
| 873 | Difficult | How do I Turn Back ? | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 316.41 | 470.29 |  |
| 874 | Difficult | Twin lava towers | CRISFN15 / fan:lldb-279 | 318.82 | 465.92 |  |
| 875 | Difficult | Take a Rest - Tea Time | KillerMasters Lemmings 1 Wicked / fan:lldb-508 | 322.36 | 456.11 |  |
| 876 | Difficult | Taxing 08.lvl | Amiga Taxing Budget / fan:lldb-575 | 316.84 | 459.00 |  |
| 877 | Difficult | Figure it out | JM01 / fan:lldb-327 | 314.60 | 460.60 |  |
| 878 | Difficult | Down the tube | Oh No! More Lemmings / Wicked | 327.06 | 459.00 |  |
| 879 | Difficult | A job for Miners | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 317.08 | 484.50 |  |
| 880 | Difficult | No Salvation IV | Lemmings Plus DOS Project Danger / fan:lldb-554 | 319.99 | 466.56 |  |
| 881 | Difficult | Lemmings on a Plane | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 319.86 | 473.80 |  |
| 882 | Difficult | Head East or West? | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 317.53 | 482.90 |  |
| 883 | Difficult | How on Earth? | Oh No! More Lemmings / Wicked | 327.66 | 459.00 |  |
| 884 | Difficult | 24 hour Lemathon | Oh No! More Lemmings / Crazy | 328.41 | 459.75 |  |
| 885 | Difficult | Inside the bone | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 330.59 | 456.65 |  |
| 886 | Difficult | Evacuating a coal mine | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 331.06 | 456.32 |  |
| 887 | Difficult | Sculpture Maze | TWPAK10 / fan:lldb-312 | 331.65 | 464.52 |  |
| 888 | Difficult | How do we get down there? | Save the Lemmings / fan:lldb-584 | 334.86 | 459.00 |  |
| 889 | Difficult | Grassy Path | Pieuw02 / fan:lldb-394 | 331.45 | 459.00 |  |
| 890 | Difficult | Stars | SeverSet2 / fan:lldb-184 | 335.04 | 468.56 |  |
| 891 | Difficult | Another beacon... | hubbart4 / fan:lldb-176 | 325.17 | 486.10 |  |
| 892 | Difficult | This Corrosion | Oh No! More Lemmings / Wicked | 342.84 | 459.00 |  |
| 893 | Difficult | Presents of Mind | Holiday Lemmings 1993 / Flurry | 337.94 | 459.00 |  |
| 894 | Difficult | Metal Lands | Lemmings Plus DOS Project Danger / fan:lldb-554 | 338.35 | 459.00 |  |
| 895 | Difficult | Regards on way | CRISFN10 / fan:lldb-274 | 337.09 | 459.00 |  |
| 896 | Difficult | Pole Jumping | JANNPCK1 / fan:lldb-231 | 337.16 | 459.00 |  |
| 897 | Difficult | The Glade of Disbelief | AkseliPack01 / fan:lldb-220 | 337.04 | 466.35 |  |
| 898 | Difficult | The platform panic | lm set13 / fan:lldb-59 | 341.03 | 484.50 |  |
| 899 | Difficult | In the life of a Lemming | Lemmings Plus DOS Project Danger / fan:lldb-554 | 342.16 | 459.00 |  |
| 900 | Difficult | The Joke's on You! | ISteve04 / fan:lldb-24 | 332.96 | 484.06 |  |
| 901 | Difficult | Marshmallow Land | Holiday Lemmings 1993 / Flurry | 346.80 | 459.00 |  |
| 902 | Difficult | Kindness That Can Kill | Kindness / fan:lldb-458 | 347.03 | 459.00 |  |
| 903 | Difficult | Now you're stuck ( part 2 ) | Mikes Lemmix Pack / fan:lldb-591 | 339.02 | 459.94 |  |
| 904 | Difficult | Walk the web rope | Lemmings / Taxing | 350.04 | 459.82 |  |
| 905 | Difficult | The Chasm | JANNPCK2 / fan:lldb-232 | 349.72 | 459.00 |  |
| 906 | Difficult | Between angels and falls | CRISFN14 / fan:lldb-278 | 349.20 | 459.00 |  |
| 907 | Difficult | The Crystal Coves | Mikes Lemmix Pack / fan:lldb-591 | 349.87 | 459.00 |  |
| 908 | Difficult | Crystal cave | LARSPACK / fan:lldb-243 | 349.67 | 455.19 |  |
| 909 | Difficult | Taxing 20.lvl | Amiga Taxing Budget / fan:lldb-570 | 350.36 | 459.82 |  |
| 910 | Difficult | Dark Valley | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 340.68 | 481.60 |  |
| 911 | Difficult | Cave quest | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 355.21 | 479.08 |  |
| 912 | Difficult | Get up there!! | CRISFN08 / fan:lldb-272 | 352.70 | 459.00 |  |
| 913 | Difficult | Konnichiwa Lemming san | Genesis Tricky / fan:lldb-489 | 362.58 | 459.00 |  |
| 914 | Difficult | Ice Battle! | Deceits Lemmings Tricky / fan:lldb-523 | 357.48 | 459.00 |  |
| 915 | Difficult | Fall and no life. | Genesis Taxing / fan:lldb-490 | 356.56 | 472.32 |  |
| 916 | Difficult | No time for a spa | Ron Stards Rodents / fan:lldb-471 | 353.30 | 480.64 |  |
| 917 | Difficult | Short way, or not? | CRISFN05 / fan:lldb-269 | 359.11 | 484.15 |  |
| 918 | Difficult | One Step Off | geoopck2 / fan:lldb-388 | 357.26 | 476.35 |  |
| 919 | Difficult | Walk the web rope (part two) | Conway Challenges 1 / fan:lldb-263 | 352.96 | 459.82 |  |
| 920 | Difficult | Grassy Path | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 363.17 | 459.00 |  |
| 921 | Difficult | Deepest Forest | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 364.12 | 459.00 |  |
| 922 | Difficult | Blocked by one way system | joem3 / fan:lldb-319 | 359.21 | 463.06 |  |
| 923 | Difficult | Lemming Anatomy Experimentations | cLemmings Mayhem / fan:lldb-529 | 354.15 | 476.68 |  |
| 924 | Difficult | The Box | Lemmings Plus DOS Project Medi / fan:lldb-553 | 355.56 | 484.90 |  |
| 925 | Difficult | It`s hero time! | Lemmings / Mayhem | 373.02 | 484.04 |  |
| 926 | Difficult | Not so fast! | JannPck3 / fan:lldb-233 | 371.17 | 459.00 |  |
| 927 | Difficult | Release is the word | PSP Special 11 26 of 36 / fan:lldb-217 | 367.46 | 458.98 |  |
| 928 | Difficult | Broken Symmetry | Nepster01 / fan:lldb-219 | 371.03 | 471.13 |  |
| 929 | Difficult | Below Freezing Point | TimpackD / fan:lldb-102 | 377.87 | 470.90 |  |
| 930 | Difficult | Mayhem 03.lvl | Amiga Mayhem Budget / fan:lldb-571 | 373.02 | 484.04 |  |
| 931 | Difficult | A Towering Proposition | ISteve03 / fan:lldb-21 | 374.42 | 476.38 |  |
| 932 | Difficult | The Hiking Tour | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 374.73 | 482.90 |  |
| 933 | Difficult | Work hard and Die | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 368.80 | 489.58 |  |
| 934 | Difficult | Come on over to my place | Lemmings / Taxing | 380.13 | 471.13 |  |
| 935 | Difficult | Through the graveyard | DOS Tricky Book Club / fan:lldb-579 | 382.12 | 461.27 |  |
| 936 | Difficult | Keep all enemies out. | Genesis Taxing / fan:lldb-490 | 389.69 | 461.43 |  |
| 937 | Difficult | Industry "Hanger" | CRISFN02 / fan:lldb-266 | 390.40 | 466.82 |  |
| 938 | Difficult | Taxing 22.lvl | Amiga Taxing Budget / fan:lldb-570 | 388.01 | 471.13 |  |
| 939 | Difficult | Stay Following the Arrow | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 387.84 | 480.86 |  |
| 940 | Difficult | The Hiking Tour | Pieuw01 / fan:lldb-393 | 381.61 | 482.90 |  |
| 941 | Difficult | ICE SPY | Oh No! More Lemmings / Wild | 398.26 | 474.61 |  |
| 942 | Difficult | Latitudal lemmings | ANTHPCK5 / fan:lldb-225 | 396.03 | 457.54 |  |
| 943 | Difficult | Playing with Fire | GARJEN01 / fan:lldb-281 | 395.28 | 479.08 |  |
| 944 | Difficult | Classical Lemmings | cLemmings Taxing / fan:lldb-528 | 390.53 | 486.53 |  |
| 945 | Difficult | Two different worlds | Genesis Mayhem / fan:lldb-491 | 388.45 | 486.98 |  |
| 946 | Difficult | Temple of Love | Oh No! More Lemmings / Wicked | 408.92 | 467.60 |  |
| 947 | Difficult | Don't let them  being greedy | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 401.44 | 469.12 |  |
| 948 | Difficult | Walk like an Egyptian | hubbart2 / fan:lldb-174 | 411.59 | 462.45 |  |
| 949 | Difficult | Toys in the Arctic | Ron Stards Rodents / fan:lldb-471 | 405.38 | 483.72 |  |
| 950 | Difficult | Can You Dig It? | MazuLems 01 / fan:lldb-244 | 417.98 | 459.00 |  |
| 951 | Difficult | Evil Sandglass | Pieuw02 / fan:lldb-394 | 419.42 | 477.06 |  |
| 952 | Difficult | Sink beneath the line | CRISFN04 / fan:lldb-268 | 419.73 | 463.32 |  |
| 953 | Difficult | The case of the floating dots | Gronklems 0 / fan:lldb-193 | 409.99 | 484.32 |  |
| 954 | Difficult | Move on in two separate groups. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 421.14 | 462.97 |  |
| 955 | Difficult | The Lemconricdion | Lemmings platinum Careful Part 2 / fan:lldb-189 | 424.13 | 477.06 |  |
| 956 | Difficult | Two Stragglers | Pieuw01 / fan:lldb-393 | 455.87 | 473.51 |  |
| 957 | Difficult | Reachable Heights | Mikes Lemmix Pack / fan:lldb-591 | 451.17 | 484.50 |  |
| 958 | Difficult | Everyone turn Left! | Genesis Present / fan:lldb-492 | 162.76 | 499.10 |  |
| 959 | Difficult | Poles to exit | CRISFN02 / fan:lldb-266 | 164.04 | 498.71 |  |
| 960 | Difficult | Ozone friendly Lemmings | Lemmings / Tricky | 194.92 | 495.84 |  |
| 961 | Difficult | Just dig! (part two) | Conway Challenges 1 / fan:lldb-263 | 203.45 | 495.84 |  |
| 962 | Difficult | To The Death! | epic02 / fan:lldb-105 | 200.02 | 494.00 |  |
| 963 | Difficult | Owned! | SeverSet1 / fan:lldb-183 | 233.04 | 498.88 |  |
| 964 | Difficult | Chain Reaction | TWPAK01 / fan:lldb-303 | 237.63 | 518.74 |  |
| 965 | Difficult | Go and Roll(?) | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 230.15 | 518.74 |  |
| 966 | Difficult | Block hero | Lemmy556 My little levels / fan:lldb-65 | 243.10 | 498.88 |  |
| 967 | Difficult | Stop and Go | Level Design Game 05 / fan:lldb-434 | 240.66 | 491.26 |  |
| 968 | Difficult | Slow Esthetics | Deceits Lemmings Taxing / fan:lldb-524 | 256.63 | 492.77 |  |
| 969 | Difficult | Splitting Hairs | Level Design Game 01 / fan:lldb-430 | 251.86 | 510.53 |  |
| 970 | Difficult | Pink Lemming | cLemmings Fun / fan:lldb-526 | 252.67 | 510.53 |  |
| 971 | Difficult | All or Nothing | Lemmings / Mayhem | 265.22 | 495.84 |  |
| 972 | Difficult | The Crossing (Part II) | Pieuws Lemmings 2007 Insane / fan:lldb-545 | 269.12 | 492.45 |  |
| 973 | Difficult | One Must Die... | JEFFPCK4 / fan:lldb-238 | 267.79 | 510.53 |  |
| 974 | Difficult | Do or fire | Lemmy556 My little levels / fan:lldb-65 | 264.94 | 510.53 |  |
| 975 | Difficult | The Funeral | MATTPCK2 / fan:lldb-249 | 269.10 | 510.53 |  |
| 976 | Difficult | Loner Lemming | Ji Hoons Lemmings Remake Sky / fan:lldb-548 | 259.58 | 507.53 |  |
| 977 | Difficult | Oh no! Level 10 more difficult! | Mikepak13 / fan:lldb-18 | 274.39 | 494.23 |  |
| 978 | Difficult | Libra | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 287.44 | 508.18 |  |
| 979 | Difficult | Speed run challenge! | CSTame2 / fan:lldb-84 | 294.06 | 491.90 |  |
| 980 | Difficult | JackLemmings | Save the Lemmings / fan:lldb-584 | 287.05 | 514.25 |  |
| 981 | Difficult | Frozen Lemmings | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 286.80 | 514.25 |  |
| 982 | Difficult | Check Your Hints! | Holiday Lemmings 1993 / Blizzard | 297.28 | 510.53 |  |
| 983 | Difficult | Break on through... | Holiday Lemmings 1993 / Blizzard | 297.68 | 518.74 |  |
| 984 | Difficult | Untitled - Rocky teeth cave ? | LARSPACK / fan:lldb-243 | 290.29 | 514.25 |  |
| 985 | Difficult | Almost Nearly Virtual Reality | Oh No! More Lemmings / Wicked | 305.60 | 514.25 |  |
| 986 | Difficult | Breakfast at Lemming's | cLemmings Fun / fan:lldb-526 | 302.94 | 514.25 |  |
| 987 | Difficult | Deep Forest | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 299.53 | 514.25 |  |
| 988 | Difficult | Lemmings Air Strike!!! | KillerMasters Lemmings 2 Tame / fan:lldb-510 | 307.89 | 514.25 |  |
| 989 | Difficult | Across The Ditch | Lemmings Plus DOS Project Mild / fan:lldb-551 | 297.95 | 514.25 |  |
| 990 | Difficult | Broken Pipe? | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 307.02 | 514.25 |  |
| 991 | Difficult | (Also they are ninjas.) | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 297.95 | 514.25 |  |
| 992 | Difficult | What exit? | JM11 / fan:lldb-337 | 300.59 | 510.53 |  |
| 993 | Difficult | ROCKY VI | Oh No! More Lemmings / Crazy | 310.79 | 496.93 |  |
| 994 | Difficult | Return to the Fold | Pieuw01 / fan:lldb-393 | 304.09 | 491.37 |  |
| 995 | Difficult | The Lemming Factory | twbestof / fan:lldb-316 | 303.20 | 497.20 |  |
| 996 | Difficult | Lava reef | CRISFN01 / fan:lldb-265 | 311.76 | 514.25 |  |
| 997 | Difficult | Level 01.lvl | Amiga Magazine Demo / fan:lldb-594 | 309.45 | 514.25 |  |
| 998 | Difficult | Keep Step | Genesis Tricky / fan:lldb-489 | 311.39 | 514.25 |  |
| 999 | Difficult | Leap of Faith | Lemmings Plus DOS Project Medi / fan:lldb-553 | 310.67 | 514.25 |  |
| 1000 | Difficult | Hide And Seek | TWPAK02 / fan:lldb-304 | 303.69 | 508.82 |  |
| 1001 | Difficult | Through the liquidizer part two | Conway07 / fan:lldb-256 | 302.42 | 510.53 |  |
| 1002 | Difficult | The Chain with no name | Oh No! More Lemmings / Wild | 315.68 | 514.25 |  |
| 1003 | Difficult | Ready....Aim....DIG!!!! | EMPACK / fan:lldb-230 | 317.04 | 514.25 |  |
| 1004 | Difficult | Patchwork Stairs | cLemmings Tricky / fan:lldb-527 | 323.52 | 514.25 |  |
| 1005 | Difficult | The ancient pile of Lemmings | CRISFN13 / fan:lldb-277 | 323.28 | 514.25 |  |
| 1006 | Difficult | Two minutes to make it | JM11 / fan:lldb-337 | 313.53 | 499.25 |  |
| 1007 | Difficult | Where do you see Lemmings? | Genesis Tricky / fan:lldb-489 | 324.18 | 514.25 |  |
| 1008 | Difficult | The Good, The Bad, and The Ugly | cLemmings Tricky / fan:lldb-527 | 321.09 | 495.84 |  |
| 1009 | Difficult | Floating-Point Error | JANNPCK1 / fan:lldb-231 | 315.06 | 510.53 |  |
| 1010 | Difficult | PRACTICE: MINER | Mikepak07 / fan:lldb-12 | 318.27 | 518.74 |  |
| 1011 | Difficult | Oh No! It`s the 4TH DIMENSION! | Oh No! More Lemmings / Wicked | 332.18 | 514.25 |  |
| 1012 | Difficult | PoP YoR ToP!!! | Oh No! More Lemmings / Wild | 329.66 | 514.25 |  |
| 1013 | Difficult | Mutiny On The Bounty | Oh No! More Lemmings / Wild | 329.91 | 514.25 |  |
| 1014 | Difficult | Wrong points of view | PSP Special 27 36 / fan:lldb-218 | 334.03 | 514.25 |  |
| 1015 | Difficult | Scrambled Lemmings | cLemmings Tricky / fan:lldb-527 | 326.41 | 514.25 |  |
| 1016 | Difficult | Somebody swich on a light! | Conway06 / fan:lldb-567 | 333.90 | 514.25 |  |
| 1017 | Difficult | Take Us All Home... | Lemmings Plus DOS Project Medi / fan:lldb-553 | 330.31 | 514.25 |  |
| 1018 | Difficult | Just For Fun | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 337.12 | 514.25 |  |
| 1019 | Difficult | The builders yard | ANTHPCK1 / fan:lldb-221 | 329.58 | 514.25 |  |
| 1020 | Difficult | Congratulations! | Lemmings The Official Companion / fan:lldb-585 | 327.87 | 514.25 |  |
| 1021 | Difficult | Star Trek | cLemmings Mayhem / fan:lldb-529 | 332.72 | 492.08 |  |
| 1022 | Difficult | Just a Bit of Lemmings | Oh No More cLemmings Tame / fan:lldb-530 | 330.18 | 494.18 |  |
| 1023 | Difficult | We are now at lemcom one | Genesis Fun / fan:lldb-488 | 333.36 | 514.25 |  |
| 1024 | Difficult | FloatinLightatLemmingHeadHeight | PSP Special 27 36 / fan:lldb-218 | 329.93 | 508.56 |  |
| 1025 | Difficult | A Problemming for diggers | ANTHPCK1 / fan:lldb-221 | 339.15 | 514.25 |  |
| 1026 | Difficult | Worm your way now... | ANTHPCK2 / fan:lldb-222 | 329.25 | 496.62 |  |
| 1027 | Difficult | Santus Lemmingus | Holiday Lemmings 1993 / Blizzard | 345.95 | 493.03 |  |
| 1028 | Difficult | Jump the Crack | Oh No More cLemmings Crazy / fan:lldb-531 | 342.57 | 504.48 |  |
| 1029 | Difficult | Meeting Spot | Lemmings Plus DOS Project PSYCHO / fan:lldb-555 | 344.71 | 514.25 |  |
| 1030 | Difficult | The lemsnow caper | CRISFN03 / fan:lldb-267 | 348.02 | 514.25 |  |
| 1031 | Difficult | Taproot | cLemmings Mayhem / fan:lldb-529 | 348.98 | 514.25 |  |
| 1032 | Difficult | Taxing 20.lvl | Amiga Taxing Book Club / fan:lldb-578 | 347.09 | 514.25 |  |
| 1033 | Difficult | Lemmings Present:Icecube Madness | TWPAK09 / fan:lldb-311 | 339.83 | 518.50 |  |
| 1034 | Difficult | Stray sheep | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 352.12 | 516.96 |  |
| 1035 | Difficult | Snakefood | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 354.51 | 514.25 |  |
| 1036 | Difficult | M.C.Escher's "Relativity" | cLemmings Taxing / fan:lldb-528 | 352.29 | 514.25 |  |
| 1037 | Difficult | Flatline | JM07 / fan:lldb-333 | 353.54 | 495.50 |  |
| 1038 | Difficult | Don't leave my Lemmings. | Genesis Present / fan:lldb-492 | 350.83 | 514.25 |  |
| 1039 | Difficult | Next Floor, please! | JANNPCK4 / fan:lldb-234 | 350.33 | 514.25 |  |
| 1040 | Difficult | Temporary peace | Genesis Taxing / fan:lldb-490 | 352.78 | 514.25 |  |
| 1041 | Difficult | Deja Vu | cLemmings Tricky / fan:lldb-527 | 353.26 | 514.25 |  |
| 1042 | Difficult | Back home | hubbart7 / fan:lldb-182 | 347.50 | 510.53 |  |
| 1043 | Difficult | On the Antarctic Coast | Oh No! More Lemmings / Crazy | 362.75 | 514.25 |  |
| 1044 | Difficult | Inroducing SUPERLEMMING | Oh No! More Lemmings / Wicked | 366.73 | 509.60 |  |
| 1045 | Difficult | Welcome to the party, pal! | Oh No! More Lemmings / Havoc | 366.96 | 514.25 |  |
| 1046 | Difficult | Lemmings-preying iron plate | Genesis Present / fan:lldb-492 | 359.35 | 514.25 |  |
| 1047 | Difficult | GO FOR IT! | Master System Remakes / fan:lldb-80 | 357.91 | 514.25 |  |
| 1048 | Difficult | The Invisible Bridge | JM12 / fan:lldb-338 | 358.54 | 514.25 |  |
| 1049 | Difficult | Which Way Do We Go? | Lemmings The Official Companion / fan:lldb-585 | 365.22 | 514.25 |  |
| 1050 | Difficult | The abyss 2 | CRISFN04 / fan:lldb-268 | 360.08 | 514.25 |  |
| 1051 | Difficult | Warm-up exercise | LARSPACK / fan:lldb-243 | 358.49 | 514.25 |  |
| 1052 | Difficult | Underground city | Genesis Present / fan:lldb-492 | 358.78 | 514.25 |  |
| 1053 | Difficult | Puffy Want More! | cLemmings Tricky / fan:lldb-527 | 369.42 | 514.25 |  |
| 1054 | Difficult | Two islands and two lakes | bigqtwo / fan:lldb-417 | 368.68 | 514.25 |  |
| 1055 | Difficult | Double Diamond | CALEPCK2 / fan:lldb-228 | 359.72 | 497.75 |  |
| 1056 | Difficult | Finding a place to stay | geooPk0 / fan:lldb-1 | 367.38 | 496.40 |  |
| 1057 | Difficult | C for ur self | joem4 / fan:lldb-468 | 372.14 | 514.25 |  |
| 1058 | Difficult | Lemming Polishing Co. | cLemmings Fun / fan:lldb-526 | 363.73 | 514.25 |  |
| 1059 | Difficult | Natural life | Genesis Present / fan:lldb-492 | 362.26 | 514.25 |  |
| 1060 | Difficult | Bullshit-lemmings | hubbart5 / fan:lldb-177 | 376.15 | 514.25 |  |
| 1061 | Difficult | Lemming Distillation | cLemmings Taxing / fan:lldb-528 | 377.35 | 514.25 |  |
| 1062 | Difficult | Doom-Box | brickpk3 / fan:lldb-560 | 374.36 | 514.25 |  |
| 1063 | Difficult | Precarious oasis | Genesis Present / fan:lldb-492 | 377.69 | 514.25 |  |
| 1064 | Difficult | Pitfall | Genesis Present / fan:lldb-492 | 377.00 | 514.25 |  |
| 1065 | Difficult | Watch your fingertip! | Genesis Taxing / fan:lldb-490 | 378.46 | 514.25 |  |
| 1066 | Difficult | Lemmings on a Thread | Pieuw02 / fan:lldb-394 | 378.05 | 492.13 |  |
| 1067 | Difficult | Loud and Clear | ANTHPCK3 / fan:lldb-223 | 375.47 | 502.60 |  |
| 1068 | Difficult | Lemming Language | Oh No More cLemmings Crazy / fan:lldb-531 | 368.64 | 522.82 |  |
| 1069 | Difficult | For Mr. Dodochacalo & Mr. Pieuw | AkseliPack01 / fan:lldb-220 | 379.80 | 514.25 |  |
| 1070 | Difficult | Lighting up The Sky | cLemmings Ultimate Edition Simple / fan:lldb-564 | 383.36 | 514.25 |  |
| 1071 | Difficult | If my name isn't Shadow Box..... | QBeez04 / fan:lldb-49 | 379.03 | 514.25 |  |
| 1072 | Difficult | Hell World | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 382.08 | 514.25 |  |
| 1073 | Difficult | Escape the wolfs claw! | LEVIPAK1 / fan:lldb-365 | 384.79 | 514.25 |  |
| 1074 | Difficult | A whole new year of lemmings!!! | New Year Lemmings 1991 92 / fan:lldb-557 | 377.04 | 511.37 |  |
| 1075 | Difficult | You Just Lost The Game!!! | Lemmings Plus DOS Project Mild / fan:lldb-551 | 376.37 | 513.10 |  |
| 1076 | Difficult | NO PROBLEM | Oh No! More Lemmings / Crazy | 388.48 | 490.03 |  |
| 1077 | Difficult | One man does all the hard work | PSP Special 11 26 of 36 / fan:lldb-217 | 390.19 | 514.25 |  |
| 1078 | Difficult | A twisted Platform | ANTHPCK2 / fan:lldb-222 | 388.36 | 514.25 |  |
| 1079 | Difficult | IceTown | Save the Lemmings / fan:lldb-584 | 386.86 | 514.25 |  |
| 1080 | Difficult | Best be careful out there | joem4 / fan:lldb-468 | 386.85 | 514.25 |  |
| 1081 | Difficult | Antiprolemmingterralationness | cLemmings Tricky / fan:lldb-527 | 385.45 | 514.25 |  |
| 1082 | Difficult | Buried under the blizzard | CRISFN12 / fan:lldb-276 | 381.83 | 518.03 |  |
| 1083 | Difficult | This is a typical Splatt level | New Year Lemmings 1991 92 / fan:lldb-557 | 380.51 | 514.25 |  |
| 1084 | Difficult | Achtung Lemming | MazuLems 01 / fan:lldb-244 | 392.59 | 514.25 |  |
| 1085 | Difficult | Some bubble ways get hard! | CRISFN12 / fan:lldb-276 | 383.13 | 514.25 |  |
| 1086 | Difficult | We All Die Someday | Lemmings Plus DOS Project Mild / fan:lldb-551 | 384.48 | 514.25 |  |
| 1087 | Difficult | DIGGING FOR VICTORY | Oh No! More Lemmings / Crazy | 396.34 | 492.20 |  |
| 1088 | Difficult | Cascade | Lemmings / Tricky | 407.80 | 515.82 |  |
| 1089 | Difficult | Lets move | JM11 / fan:lldb-337 | 403.08 | 514.25 |  |
| 1090 | Difficult | Party Time! | JM14 / fan:lldb-340 | 404.94 | 514.25 |  |
| 1091 | Difficult | Three steps to heaven | PSP Special 11 26 of 36 / fan:lldb-217 | 407.78 | 514.25 |  |
| 1092 | Difficult | Broken Bridges | lm set10 / fan:lldb-51 | 400.04 | 514.25 |  |
| 1093 | Difficult | Tricky 25.lvl | Amiga Tricky Budget / fan:lldb-569 | 407.21 | 515.82 |  |
| 1094 | Difficult | Someone must make an effort! | CRISFN05 / fan:lldb-269 | 402.68 | 514.25 |  |
| 1095 | Difficult | Tank! | GeoffLems Minipack / fan:lldb-413 | 403.06 | 492.94 |  |
| 1096 | Difficult | Let's get together. | Genesis Mayhem / fan:lldb-491 | 406.41 | 514.25 |  |
| 1097 | Difficult | Jump down! | Genesis Taxing / fan:lldb-490 | 401.98 | 514.25 |  |
| 1098 | Difficult | Sci-Fi Stereo | CRISFN09 / fan:lldb-273 | 400.11 | 514.25 |  |
| 1099 | Difficult | ROCKY ROAD | Oh No! More Lemmings / Wicked | 413.29 | 521.98 |  |
| 1100 | Difficult | Up on the Rooftops | Holiday Lemmings 1994 / Frost | 412.84 | 514.25 |  |
| 1101 | Difficult | Six Ways to Success (I Guess) | MazuLems 03 / fan:lldb-246 | 416.81 | 514.25 |  |
| 1102 | Difficult | Lem up! | cLemmings Mayhem / fan:lldb-529 | 418.06 | 492.83 |  |
| 1103 | Difficult | Geros Segros! | JANNPCK2 / fan:lldb-232 | 412.08 | 514.25 |  |
| 1104 | Difficult | LoTs moRe wHeRe TheY caMe fRom | Oh No! More Lemmings / Wicked | 423.90 | 514.25 |  |
| 1105 | Difficult | Sir Edmund Hilemming | Holiday Lemmings 1994 / Hail | 423.19 | 514.25 |  |
| 1106 | Difficult | Pipe dreams | CRISFN09 / fan:lldb-273 | 423.71 | 514.25 |  |
| 1107 | Difficult | Creativity Beyond Lemmings . . . | Oh No More cLemmings Wild / fan:lldb-532 | 424.28 | 495.47 |  |
| 1108 | Difficult | This is not a prison | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 416.03 | 514.25 |  |
| 1109 | Difficult | This Is... | Lemmings Plus DOS Project Medi / fan:lldb-553 | 423.95 | 514.25 |  |
| 1110 | Difficult | Lemming in a Cone | MazuLems 02 / fan:lldb-245 | 415.29 | 506.83 |  |
| 1111 | Difficult | The gate trap Lemmings. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 425.62 | 503.58 |  |
| 1112 | Difficult | The Cascade: Part II | Modlvls / fan:lldb-357 | 422.21 | 515.82 |  |
| 1113 | Difficult | Arch-Nemesis | GARJEN03 / fan:lldb-283 | 423.19 | 514.25 |  |
| 1114 | Difficult | Lemmings Everywhere | cLemmings Fun / fan:lldb-526 | 415.67 | 514.25 |  |
| 1115 | Difficult | Don't settle for anything less | Conway Challenges 1 / fan:lldb-263 | 425.93 | 515.82 |  |
| 1116 | Difficult | Nostalgia for a Misspent Youth | weirdy04 version 2 / fan:lldb-136 | 418.25 | 514.25 |  |
| 1117 | Difficult | The Stack | Oh No! More Lemmings / Crazy | 429.63 | 490.04 |  |
| 1118 | Difficult | Be more than just a number | Oh No! More Lemmings / Havoc | 435.18 | 514.25 |  |
| 1119 | Difficult | Pillar talking | PSP Special 1 10 of 36 / fan:lldb-216 | 435.75 | 514.25 |  |
| 1120 | Difficult | The China Syndrome | MazuLems 01 / fan:lldb-244 | 428.68 | 514.25 |  |
| 1121 | Difficult | Private room available | Genesis Present / fan:lldb-492 | 437.00 | 514.25 |  |
| 1122 | Difficult | Forest of ilussion | CRISFN08 / fan:lldb-272 | 429.10 | 514.25 |  |
| 1123 | Difficult | The Lemming Funhouse | Oh No! More Lemmings / Wicked | 448.11 | 518.74 |  |
| 1124 | Difficult | Dad's Ugly Green Chair Level | TWPAK13 / fan:lldb-315 | 446.05 | 496.66 |  |
| 1125 | Difficult | Going Under | Lemmings Plus DOS Project Medi / fan:lldb-553 | 443.29 | 514.25 |  |
| 1126 | Difficult | Path Integral Formalism | cLemmings Taxing / fan:lldb-528 | 441.57 | 514.25 |  |
| 1127 | Difficult | Emerald Mountain | KillerMasters Lemmings 1 Havoc / fan:lldb-509 | 441.85 | 504.03 |  |
| 1128 | Difficult | Meet & Greet | MazuLems 03 / fan:lldb-246 | 453.19 | 490.48 |  |
| 1129 | Difficult | Doomed | JannPck3 / fan:lldb-233 | 445.78 | 510.00 |  |
| 1130 | Difficult | Ten Green Lemmings | cLemmings Taxing / fan:lldb-528 | 453.55 | 510.00 |  |
| 1131 | Difficult | The Quartet | cLemmings Taxing / fan:lldb-528 | 450.98 | 514.25 |  |
| 1132 | Difficult | Oh No!  Squish. | Lemmings The Official Companion / fan:lldb-585 | 450.92 | 514.25 |  |
| 1133 | Difficult | No One Here But Us Three | TWPAK01 / fan:lldb-303 | 451.13 | 509.61 |  |
| 1134 | Difficult | Three-way Call | GARJEN01 / fan:lldb-281 | 456.87 | 514.25 |  |
| 1135 | Difficult | Di-Lemm-A | cLemmings Mayhem / fan:lldb-529 | 489.95 | 514.25 |  |
| 1136 | Difficult | Mine Your Own Bussiness | TWPAK00 / fan:lldb-302 | 197.94 | 539.75 |  |
| 1137 | Difficult | The Lucky 4 | Level Design Game 01 / fan:lldb-430 | 250.40 | 539.75 |  |
| 1138 | Difficult | Merry Christmaze | Holiday Lemmings 1994 / Hail | 286.14 | 552.13 |  |
| 1139 | Difficult | Challenge Solution Simon | Level Design Game 01 / fan:lldb-430 | 293.35 | 539.75 |  |
| 1140 | Difficult | Doomsday | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 321.34 | 536.48 |  |
| 1141 | Difficult | the rediscovery | hubbart / fan:lldb-173 | 315.76 | 539.75 |  |
| 1142 | Difficult | Born a blocker, die a blocker | PSP Special 27 36 / fan:lldb-218 | 326.91 | 533.30 |  |
| 1143 | Difficult | On The Pier | Lemmings Plus DOS Project Mild / fan:lldb-551 | 343.61 | 552.13 |  |
| 1144 | Difficult | Tribute to M.C.Escher (remake) | LEMREMAKE / fan:lldb-465 | 357.34 | 529.56 |  |
| 1145 | Difficult | One way digging to freedom | Lemmings / Tricky | 368.42 | 549.40 |  |
| 1146 | Difficult | No Salvation V | Lemmings Plus DOS Project PSYCHO / fan:lldb-555 | 365.43 | 540.00 |  |
| 1147 | Difficult | 5 Ways To Get Through | Van Clan Wild / fan:lldb-519 | 374.16 | 540.00 |  |
| 1148 | Difficult | Level 02.lvl | Amiga Demo / fan:lldb-581 | 366.88 | 549.40 |  |
| 1149 | Difficult | It's upwards, but where? | CRISFN03 / fan:lldb-267 | 373.59 | 558.61 |  |
| 1150 | Difficult | Tricky 20.lvl | Amiga Tricky Budget / fan:lldb-569 | 368.98 | 549.40 |  |
| 1151 | Difficult | An Unfriendly Gesture | cLemmings Taxing / fan:lldb-528 | 379.18 | 540.00 |  |
| 1152 | Difficult | Climb and Float | brickpk1 / fan:lldb-558 | 372.72 | 554.90 |  |
| 1153 | Difficult | Clumps | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 377.22 | 552.13 |  |
| 1154 | Difficult | Snow mining | CRISFN11 / fan:lldb-275 | 376.06 | 552.13 |  |
| 1155 | Difficult | A ladder would be handy | Lemmings / Tricky | 394.92 | 540.00 |  |
| 1156 | Difficult | ohnomoreclemmings crazy 1.dat 9 | Oh No More cLemmings Crazy / fan:lldb-531 | 389.41 | 542.08 |  |
| 1157 | Difficult | Tricky 03.lvl | Amiga Tricky Budget / fan:lldb-569 | 394.92 | 540.00 |  |
| 1158 | Difficult | Save 'em First... | JEFFPCK7 / fan:lldb-241 | 392.18 | 544.00 |  |
| 1159 | Difficult | Cordial Acceptance | cLemmings Tricky / fan:lldb-527 | 387.63 | 540.00 |  |
| 1160 | Difficult | Inside Outside | Lemmings Plus DOS Project Danger / fan:lldb-554 | 387.05 | 548.83 |  |
| 1161 | Difficult | Keep your hair on | JM14 / fan:lldb-340 | 408.07 | 540.00 |  |
| 1162 | Difficult | Down in the dumps | ANTHPCK3 / fan:lldb-223 | 405.91 | 540.00 |  |
| 1163 | Difficult | Just 17 | PSP Special 1 10 of 36 / fan:lldb-216 | 408.10 | 540.00 |  |
| 1164 | Difficult | A ladder would be handy (Part2) | JM01 / fan:lldb-327 | 403.50 | 540.00 |  |
| 1165 | Difficult | FlameBungee | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 403.07 | 554.90 |  |
| 1166 | Difficult | Excavations in the Cubic Cave | Mikes Lemmix Pack / fan:lldb-591 | 399.03 | 556.98 |  |
| 1167 | Difficult | Happy New Year! | Holiday Lemmings 1994 / Frost | 415.14 | 529.82 |  |
| 1168 | Difficult | SPAM,SPAM,SPAM,EGG AND LEMMING | Oh No! More Lemmings / Wicked | 414.48 | 540.00 |  |
| 1169 | Difficult | How do I dig up the way? | Lemmings / Taxing | 419.20 | 540.00 |  |
| 1170 | Difficult | Lem- me- in. | ANTHPCK5 / fan:lldb-225 | 409.64 | 540.00 |  |
| 1171 | Difficult | NULL | 1tseug / fan:lldb-35 | 411.29 | 540.00 |  |
| 1172 | Difficult | Lemming Productions Present... | Oh No! More Lemmings / Tame | 424.90 | 540.00 |  |
| 1173 | Difficult | Taxing 29.lvl | Amiga Taxing Budget / fan:lldb-570 | 419.20 | 540.00 |  |
| 1174 | Difficult | Cascading exit | Epic giga01 / fan:lldb-139 | 426.16 | 540.00 |  |
| 1175 | Difficult | Miner under Control | Pieuws Lemmings 2007 Insane / fan:lldb-545 | 427.17 | 540.00 |  |
| 1176 | Difficult | Pachelbel's "Canon in Splat" | cLemmings Taxing / fan:lldb-528 | 420.93 | 540.00 |  |
| 1177 | Difficult | Wild Lemmings | Oh No More cLemmings Wild / fan:lldb-532 | 427.11 | 526.88 |  |
| 1178 | Difficult | Crystal Clear Lemmings | MazuLems 01 / fan:lldb-244 | 424.43 | 541.11 |  |
| 1179 | Difficult | Splunk n' country | Epic Giga03 / fan:lldb-141 | 434.15 | 546.48 |  |
| 1180 | Difficult | Lucky Four | cLemmings Taxing / fan:lldb-528 | 433.60 | 544.00 |  |
| 1181 | Difficult | Have a nice day! | Lemmings / Mayhem | 449.58 | 540.00 |  |
| 1182 | Difficult | The hunt is on! | QBeez03 / fan:lldb-33 | 453.53 | 540.00 |  |
| 1183 | Difficult | Tricky 14.lvl | Amiga Tricky Budget / fan:lldb-574 | 448.99 | 538.33 |  |
| 1184 | Difficult | The quick and the dead | ANTHPCK5 / fan:lldb-225 | 448.75 | 558.96 |  |
| 1185 | Difficult | Just a random heap of junk! | Nepster01 / fan:lldb-219 | 454.46 | 556.53 |  |
| 1186 | Difficult | Salvation or Damnation? | Yawg03 / fan:lldb-107 | 463.56 | 552.13 |  |
| 1187 | Difficult | Faithful Friends | GARJEN09 / fan:lldb-289 | 480.18 | 533.06 |  |
| 1188 | Difficult | Lemmings' Ark | Genesis Mayhem / fan:lldb-491 | 475.88 | 555.11 |  |
| 1189 | Difficult | Wallace and Gromit's Lem 'n Go | Lemmings platinum Dangerous Part 1 / fan:lldb-190 | 473.60 | 551.40 |  |
| 1190 | Difficult | Watch Ye Step! | ISteve01 / fan:lldb-20 | 484.85 | 540.00 |  |
| 1191 | Difficult | be happy | extreme / fan:lldb-53 | 479.78 | 552.13 |  |
| 1192 | Difficult | Marooned | Ron Stards Rodents / fan:lldb-471 | 496.02 | 555.11 |  |
| 1193 | Difficult | Virus Rush | KillerMasters Lemmings 2 Tame / fan:lldb-510 | 298.46 | 569.50 |  |
| 1194 | Difficult | A Beast of a level | Lemmings / Fun | 325.32 | 564.18 |  |
| 1195 | Difficult | A Dangerous Mining Operation | cLemmings Fun / fan:lldb-526 | 321.14 | 569.50 |  |
| 1196 | Difficult | Down With The Lemmings | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 325.75 | 569.50 |  |
| 1197 | Difficult | Grassy Dreams | cLemmings Fun / fan:lldb-526 | 319.46 | 569.50 |  |
| 1198 | Difficult | Brick plot | CRISFN01 / fan:lldb-265 | 335.98 | 569.50 |  |
| 1199 | Difficult | Let's come to the party | CRISFN05 / fan:lldb-269 | 329.22 | 578.00 |  |
| 1200 | Difficult | Take A Shortcut! | Lemmings Plus DOS Project Mild / fan:lldb-551 | 343.29 | 569.50 |  |
| 1201 | Difficult | Huff and Puff | cLemmings Fun / fan:lldb-526 | 346.63 | 569.50 |  |
| 1202 | Difficult | It's a strange land! | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 346.62 | 569.50 |  |
| 1203 | Difficult | Force Field | Lemmings Plus DOS Project Medi / fan:lldb-553 | 344.02 | 574.03 |  |
| 1204 | Difficult | And the rock cried out... | JANNPCK2 / fan:lldb-232 | 356.87 | 569.50 |  |
| 1205 | Difficult | A Snowplow Would Be Handy | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 360.21 | 569.50 |  |
| 1206 | Difficult | Breakthrough | Lemmings Plus DOS Project Danger / fan:lldb-554 | 354.93 | 590.11 |  |
| 1207 | Difficult | Let me get out of here! | Genesis Present / fan:lldb-492 | 365.97 | 569.50 |  |
| 1208 | Difficult | Bubbling lagoon | CRISFN14 / fan:lldb-278 | 381.05 | 569.50 |  |
| 1209 | Difficult | Lemmings Now Looked Up | Deceits Lemmings Fun / fan:lldb-522 | 378.01 | 569.50 |  |
| 1210 | Difficult | Armageddon! | CRISFN07 / fan:lldb-271 | 382.23 | 569.50 |  |
| 1211 | Difficult | Animal or Vegetable? | Save the Lemmings / fan:lldb-584 | 382.46 | 569.50 |  |
| 1212 | Difficult | Dark dawn | Genesis Fun / fan:lldb-488 | 376.69 | 569.50 |  |
| 1213 | Difficult | Time waits for no Lemming | Oh No! More Lemmings / Crazy | 397.45 | 569.50 |  |
| 1214 | Difficult | Lemming Rhythms | Oh No! More Lemmings / Wild | 394.96 | 581.48 |  |
| 1215 | Difficult | Palm ground | CRISFN11 / fan:lldb-275 | 388.17 | 569.50 |  |
| 1216 | Difficult | Pillars of character | Dehodson / fan:lldb-419 | 394.41 | 569.50 |  |
| 1217 | Difficult | Old MacDonald Had a Farm... | Lemmings The Official Companion / fan:lldb-585 | 392.59 | 569.50 |  |
| 1218 | Difficult | Wood piece | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 394.64 | 569.50 |  |
| 1219 | Difficult | Saviour | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 387.46 | 569.50 |  |
| 1220 | Difficult | To Life, and Lots of Presents | Holiday cLemmings Frost / fan:lldb-535 | 396.12 | 569.50 |  |
| 1221 | Difficult | The Three Cs | cLemmings Tricky / fan:lldb-527 | 404.38 | 569.50 |  |
| 1222 | Difficult | Green Stars | JEFFPCK3 / fan:lldb-237 | 401.13 | 583.08 |  |
| 1223 | Difficult | Grounded! | Lemmings Plus DOS Project Danger / fan:lldb-554 | 394.64 | 580.58 |  |
| 1224 | Difficult | Seeing double! | PSP Special 11 26 of 36 / fan:lldb-217 | 407.26 | 560.48 |  |
| 1225 | Difficult | The Lake of Fire | JANNPCK1 / fan:lldb-231 | 414.05 | 569.50 |  |
| 1226 | Difficult | Level 05.lvl | Amiga Demo / fan:lldb-581 | 415.14 | 569.50 |  |
| 1227 | Difficult | Lemmings search for treasure. | Genesis Taxing / fan:lldb-490 | 413.77 | 569.50 |  |
| 1228 | Difficult | Taxing 15.lvl | Amiga Taxing Budget / fan:lldb-575 | 416.22 | 569.50 |  |
| 1229 | Difficult | Save Thy Lemmings | JANNPCK1 / fan:lldb-231 | 409.65 | 569.50 |  |
| 1230 | Difficult | In an Anthill | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 411.22 | 578.00 |  |
| 1231 | Difficult | Ecsape From Nightmare | ssam1221s Lemmings Havoc / fan:lldb-563 | 412.33 | 560.51 |  |
| 1232 | Difficult | Lemmings standing on the earth | Genesis Present / fan:lldb-492 | 413.77 | 569.50 |  |
| 1233 | Difficult | Lemming Playground | Nepster01 / fan:lldb-219 | 406.42 | 585.56 |  |
| 1234 | Difficult | The Landing Trail | Pieuw01 / fan:lldb-393 | 420.05 | 569.50 |  |
| 1235 | Difficult | With A Quirk Or Two... | Lemmings Plus DOS Project Danger / fan:lldb-554 | 417.72 | 569.50 |  |
| 1236 | Difficult | Snowed In! | Lemmings Plus DOS Project PSYCHO / fan:lldb-555 | 424.86 | 569.50 |  |
| 1237 | Difficult | Tomorrow Ends Today | Eymerich02 / fan:lldb-4 | 417.17 | 569.50 |  |
| 1238 | Difficult | Anticlimacticism V | cLemmings Tricky / fan:lldb-527 | 428.95 | 569.50 |  |
| 1239 | Difficult | Lemming Bubbles | Oh No More cLemmings Crazy / fan:lldb-531 | 426.01 | 569.50 |  |
| 1240 | Difficult | Taxing 01.lvl | Amiga Taxing Budget / fan:lldb-575 | 428.27 | 569.50 |  |
| 1241 | Difficult | INCONCEIVABLE! (Steve) | justdigcomp / fan:lldb-374 | 427.27 | 569.50 |  |
| 1242 | Difficult | Be careful when you build! | CRISFN14 / fan:lldb-278 | 426.27 | 569.50 |  |
| 1243 | Difficult | The Flood | PSP Special 11 26 of 36 / fan:lldb-217 | 419.79 | 574.03 |  |
| 1244 | Difficult | This might be a doddle! | Insulfrog LVL PK 1 / fan:lldb-373 | 430.58 | 569.50 |  |
| 1245 | Difficult | Steps | Insulfrog LVL PK 1 / fan:lldb-373 | 420.67 | 569.50 |  |
| 1246 | Difficult | Water processing plant | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 431.98 | 569.50 |  |
| 1247 | Difficult | Lemmings at the Wall | Oh No More cLemmings Crazy / fan:lldb-531 | 432.94 | 569.50 |  |
| 1248 | Difficult | Could be easier... | JANNPCK2 / fan:lldb-232 | 436.94 | 569.50 |  |
| 1249 | Difficult | Flugtag! | ISteve02 / fan:lldb-23 | 433.29 | 569.50 |  |
| 1250 | Difficult | Botanical reserch | Lemmings platinum Dangerous Part 2 / fan:lldb-191 | 433.44 | 569.50 |  |
| 1251 | Difficult | Bubble cavern | CRISFN15 / fan:lldb-279 | 430.90 | 569.50 |  |
| 1252 | Difficult | X marks the spot | Lemmings / Taxing | 443.60 | 592.94 |  |
| 1253 | Difficult | Mayhem 15.lvl | Amiga Mayhem Budget / fan:lldb-576 | 433.68 | 569.50 |  |
| 1254 | Difficult | Just a minute (Part Three) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 446.95 | 569.50 |  |
| 1255 | Difficult | Final Impediment 2 | Conway13 / fan:lldb-262 | 445.95 | 569.50 |  |
| 1256 | Difficult | Circular Wavelength | Lemmings Plus DOS Project Danger / fan:lldb-554 | 438.73 | 569.50 |  |
| 1257 | Difficult | It`s the price you have to pay | Oh No! More Lemmings / Havoc | 452.11 | 569.50 |  |
| 1258 | Difficult | Through the Block | Pieuw01 / fan:lldb-393 | 449.83 | 569.50 |  |
| 1259 | Difficult | Pure Agony | Braden12 First Levelpack from OpenSea Facebook / fan:lldb-586 | 443.75 | 569.50 |  |
| 1260 | Difficult | Beat the Clock | cLemmings Mayhem / fan:lldb-529 | 452.28 | 569.50 |  |
| 1261 | Difficult | Mayhem 01.lvl | Amiga Mayhem Budget / fan:lldb-576 | 449.52 | 569.50 |  |
| 1262 | Difficult | Frostlemm | Oh No More cLemmings Tame / fan:lldb-530 | 442.77 | 569.50 |  |
| 1263 | Difficult | Taxing 14.lvl | Amiga Taxing Budget / fan:lldb-575 | 453.47 | 569.50 |  |
| 1264 | Difficult | Lemmings of Bodom | JANNPCK2 / fan:lldb-232 | 445.09 | 582.90 |  |
| 1265 | Difficult | Taxing 17.lvl | Amiga Taxing Budget / fan:lldb-570 | 443.60 | 592.94 |  |
| 1266 | Difficult | The Picard Maneuver part 1 | mobius2 / fan:lldb-205 | 458.70 | 569.50 |  |
| 1267 | Difficult | Lets Go Sledding!! | Lemmings The Official Companion / fan:lldb-585 | 460.68 | 569.50 |  |
| 1268 | Difficult | Rock crystal!! | CRISFN03 / fan:lldb-267 | 458.14 | 569.50 |  |
| 1269 | Difficult | Crystal point | PSP Special 1 10 of 36 / fan:lldb-216 | 457.04 | 569.50 |  |
| 1270 | Difficult | Once a Lemming, Always a Lemming | cLemmings Taxing / fan:lldb-528 | 460.87 | 569.50 |  |
| 1271 | Difficult | Tropical sunshine | CRISFN13 / fan:lldb-277 | 456.81 | 569.50 |  |
| 1272 | Difficult | Careful with traps | CRISFN15 / fan:lldb-279 | 465.08 | 572.60 |  |
| 1273 | Difficult | Juanjos Just dig! | justdigcomp / fan:lldb-374 | 464.80 | 569.50 |  |
| 1274 | Difficult | Fire Fun | cLemmings Taxing / fan:lldb-528 | 455.19 | 592.01 |  |
| 1275 | Difficult | Lemming Graveyard | cLemmings Taxing / fan:lldb-528 | 469.06 | 569.50 |  |
| 1276 | Difficult | Cranial Stress | cLemmings Tricky / fan:lldb-527 | 470.13 | 569.50 |  |
| 1277 | Difficult | The big U-Turn | Pieuw01 / fan:lldb-393 | 465.30 | 569.50 |  |
| 1278 | Difficult | Chemical dissease | CRISFN07 / fan:lldb-271 | 466.49 | 569.50 |  |
| 1279 | Difficult | Emmings!  (No L) | Holiday Lemmings 1994 / Hail | 479.42 | 569.50 |  |
| 1280 | Difficult | Evil whisper | Genesis Present / fan:lldb-492 | 480.63 | 569.50 |  |
| 1281 | Difficult | Through the Block | Pieuws Lemmings 2007 Insane / fan:lldb-545 | 492.99 | 569.50 |  |
| 1282 | Difficult | Lightspeed Lemming | Lemmings Plus DOS Project PSYCHO / fan:lldb-555 | 487.28 | 569.50 |  |
| 1283 | Difficult | Were ready for landing | Giga pack 04 / fan:lldb-165 | 484.57 | 564.18 |  |
| 1284 | Difficult | The Three Musketeers | cLemmings Mayhem / fan:lldb-529 | 489.99 | 594.50 |  |
| 1285 | Difficult | No hurry, Relax. | Genesis Mayhem / fan:lldb-491 | 504.00 | 569.50 |  |
| 1286 | Difficult | Now we're cooking on gas | lm set05 / fan:lldb-45 | 505.96 | 569.50 |  |
| 1287 | Difficult | Pillars of the Earth | cLemmings Mayhem / fan:lldb-529 | 502.65 | 569.50 |  |
| 1288 | Difficult | Bubble underground | CRISFN06 / fan:lldb-270 | 507.09 | 570.98 |  |
| 1289 | Difficult | Not as Easy as It Looks | cLemmings Tricky / fan:lldb-527 | 506.29 | 569.50 |  |
| 1290 | Difficult | Simply Smashing | Epic Giga03 / fan:lldb-141 | 514.30 | 569.50 |  |
| 1291 | Difficult | End of quarantine | Ron Stards Rodents / fan:lldb-471 | 551.11 | 577.12 |  |
| 1292 | Difficult | Why do you all look the same? | AkseliPack01 / fan:lldb-220 | 561.94 | 569.50 |  |
| 1293 | Difficult | With A Little Help From... | Yawg02 / fan:lldb-85 | 297.60 | 598.88 |  |
| 1294 | Difficult | Compression Method 1 | Lemmings / Taxing | 318.21 | 598.88 |  |
| 1295 | Difficult | Hard when you don't know how | MARSHY02 / fan:lldb-346 | 317.22 | 598.88 |  |
| 1296 | Difficult | Again & Again | JM03 / fan:lldb-329 | 321.01 | 598.88 |  |
| 1297 | Difficult | Puzzle Time.ini | grams88 / fan:lldb-416 | 327.09 | 598.88 |  |
| 1298 | Difficult | Take care, Sweetie | Oh No! More Lemmings / Wild | 338.92 | 598.88 |  |
| 1299 | Difficult | Lemming City | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 407.06 | 598.00 |  |
| 1300 | Difficult | Patience | Lemmings / Fun | 421.98 | 595.98 |  |
| 1301 | Difficult | Need I re-MINED you? | CSTame1 / fan:lldb-83 | 420.33 | 598.88 |  |
| 1302 | Difficult | Go Thataway! | Holiday Lemmings 1994 / Hail | 441.67 | 598.88 |  |
| 1303 | Difficult | Tricky 05.lvl | Amiga Tricky Budget / fan:lldb-574 | 442.38 | 595.98 |  |
| 1304 | Difficult | Science from the 4th dimension | Mikes Lemmix Pack / fan:lldb-591 | 455.36 | 595.48 |  |
| 1305 | Difficult | Fall and no life (Part Two) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 513.76 | 595.48 |  |
| 1306 | Difficult | Four Play | Holiday Lemmings 1994 / Frost | 550.15 | 598.88 |  |
| 1307 | Expert | Lemming Net | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 243.13 | 622.46 |  |
| 1308 | Expert | It`s all a matter of timing | Oh No! More Lemmings / Havoc | 299.52 | 603.50 |  |
| 1309 | Expert | Going down to... | CRISFN01 / fan:lldb-265 | 298.38 | 622.46 |  |
| 1310 | Expert | We All Fall Up | TWPAK05 / fan:lldb-307 | 315.62 | 629.00 |  |
| 1311 | Expert | Climbing the Mountain | cLemmings Fun / fan:lldb-526 | 330.23 | 611.46 |  |
| 1312 | Expert | The Prison! | Lemmings / Taxing | 349.20 | 623.68 |  |
| 1313 | Expert | Zigzag World | Pieuws Lemmings 2007 Awkward / fan:lldb-543 | 346.65 | 613.18 |  |
| 1314 | Expert | Taxing 05.lvl | Amiga Taxing Budget / fan:lldb-570 | 351.30 | 623.68 |  |
| 1315 | Expert | Lemmings of the West | Oh No More cLemmings Tame / fan:lldb-530 | 345.83 | 624.75 |  |
| 1316 | Expert | Who`s That Lemming | Oh No! More Lemmings / Tame | 373.34 | 606.82 |  |
| 1317 | Expert | Tricky 13.lvl | Amiga Tricky Budget / fan:lldb-574 | 378.14 | 624.75 |  |
| 1318 | Expert | The Thin Red Line (Colorblind) | ISteve01 / fan:lldb-20 | 369.12 | 610.90 |  |
| 1319 | Expert | SUNSOFT Special | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 389.00 | 600.61 |  |
| 1320 | Expert | The lemming water faculty | Giga pack 07 / fan:lldb-169 | 392.50 | 623.48 |  |
| 1321 | Expert | A Tribute to Flagpole Sitting | ISteve02 / fan:lldb-23 | 388.17 | 624.75 |  |
| 1322 | Expert | Googly-Pops Has Lost One Eye | TWPAK10 / fan:lldb-312 | 382.86 | 622.46 |  |
| 1323 | Expert | The Prima Publishing Level | Lemmings The Official Companion / fan:lldb-585 | 393.70 | 624.75 |  |
| 1324 | Expert | Oh snap, it's a lemmings level | Ji Hoons Lemmings Remake Sky / fan:lldb-548 | 390.80 | 625.10 |  |
| 1325 | Expert | Mayhem 25.lvl | Amiga Mayhem Budget / fan:lldb-576 | 405.04 | 624.75 |  |
| 1326 | Expert | The Snowy Ages | Holiday cLemmings Frost / fan:lldb-535 | 403.37 | 624.75 |  |
| 1327 | Expert | Upsidedown World | Lemmings / Taxing | 423.24 | 611.11 |  |
| 1328 | Expert | Overheat | Ji Hoons Lemmings Remake Earth / fan:lldb-549 | 415.98 | 621.40 |  |
| 1329 | Expert | KEEP ON TRUCKING | Oh No! More Lemmings / Crazy | 434.90 | 624.75 |  |
| 1330 | Expert | A trapdoor above the rest. | ANTHPCK3 / fan:lldb-223 | 427.67 | 624.75 |  |
| 1331 | Expert | Taxing 13.lvl | Amiga Taxing Budget / fan:lldb-570 | 426.05 | 611.11 |  |
| 1332 | Expert | Just A Quicky | Oh No! More Lemmings / Wild | 439.03 | 611.11 |  |
| 1333 | Expert | The Search for Lem | Holiday Lemmings 1993 / Blizzard | 443.10 | 624.75 |  |
| 1334 | Expert | Not as easy as it looks | CRISFN04 / fan:lldb-268 | 439.78 | 624.75 |  |
| 1335 | Expert | Dangerous Fire Pit | epic03 / fan:lldb-129 | 445.55 | 624.75 |  |
| 1336 | Expert | Thanx level ... | LARSPACK / fan:lldb-243 | 439.75 | 607.60 |  |
| 1337 | Expert | Meet the Nessy Again | Deceits Lemmings Tricky / fan:lldb-523 | 436.87 | 619.30 |  |
| 1338 | Expert | Upsidedown Islands | lm set04 / fan:lldb-44 | 453.81 | 619.53 |  |
| 1339 | Expert | Lemming Entertainment Center | Lemmings Plus DOS Project Medi / fan:lldb-553 | 449.54 | 624.75 |  |
| 1340 | Expert | Lemming eater | Genesis Mayhem / fan:lldb-491 | 450.38 | 624.75 |  |
| 1341 | Expert | The Road to Boneland | lm set10 / fan:lldb-51 | 448.80 | 624.75 |  |
| 1342 | Expert | Wild World of Lemmings! | Lemmings The Official Companion / fan:lldb-585 | 454.01 | 624.75 |  |
| 1343 | Expert | Don't bash the wall | JM10 / fan:lldb-336 | 444.42 | 629.00 |  |
| 1344 | Expert | Polar Expedition | Holiday Lemmings 1994 / Hail | 467.57 | 624.75 |  |
| 1345 | Expert | INTIMIDATING(ish) | Master System Remakes / fan:lldb-80 | 462.74 | 624.75 |  |
| 1346 | Expert | The Mad Freezer | Oh No More cLemmings Crazy / fan:lldb-531 | 457.75 | 624.75 |  |
| 1347 | Expert | As long as we try our best | joem4 / fan:lldb-468 | 473.77 | 605.51 |  |
| 1348 | Expert | The Power Of Three.... | Van Clan Wild / fan:lldb-519 | 468.65 | 624.75 |  |
| 1349 | Expert | The Other Side. | Genesis Mayhem / fan:lldb-491 | 472.79 | 624.75 |  |
| 1350 | Expert | Getting There... | Lemmings Plus DOS Project Medi / fan:lldb-553 | 478.83 | 624.75 |  |
| 1351 | Expert | Tailor-made for... wait | wade / fan:lldb-359 | 477.44 | 624.75 |  |
| 1352 | Expert | It's easy ! | Mikepak00 / fan:lldb-5 | 468.93 | 624.75 |  |
| 1353 | Expert | Lunch time | Genesis Taxing / fan:lldb-490 | 473.06 | 624.75 |  |
| 1354 | Expert | All's fair in Love and War | cLemmings Mayhem / fan:lldb-529 | 470.06 | 624.75 |  |
| 1355 | Expert | Who can do the rest? | lm set04 / fan:lldb-44 | 480.82 | 624.75 |  |
| 1356 | Expert | It looks pretty simple | lm set13 / fan:lldb-59 | 479.09 | 624.75 |  |
| 1357 | Expert | Snow Lev 2 | ANTHPCK4 / fan:lldb-224 | 471.18 | 624.75 |  |
| 1358 | Expert | Tubular Lemmings | Oh No! More Lemmings / Havoc | 481.59 | 602.03 |  |
| 1359 | Expert | THE SILENCE OF THE LEMMINGS | Oh No! More Lemmings / Wild | 481.37 | 624.75 |  |
| 1360 | Expert | LmSO4 - Lemmingic Acid | JOHNPACK / fan:lldb-242 | 488.35 | 624.75 |  |
| 1361 | Expert | Constructive criticism. | isupck02 / fan:lldb-353 | 486.76 | 624.75 |  |
| 1362 | Expert | Unimatrix zero | LEVIPAK4 / fan:lldb-368 | 485.56 | 624.75 |  |
| 1363 | Expert | C'mon everybody body | Giga pack 08 / fan:lldb-170 | 484.29 | 607.81 |  |
| 1364 | Expert | Where Lemmings Dare | Oh No! More Lemmings / Havoc | 497.36 | 624.75 |  |
| 1365 | Expert | Pleasure to Meet You | cLemmings Taxing / fan:lldb-528 | 487.69 | 620.18 |  |
| 1366 | Expert | Catch-22 | ISteve01 / fan:lldb-20 | 507.81 | 601.34 |  |
| 1367 | Expert | Lucy 26 Degree | Deceits Lemmings Extras / fan:lldb-546 | 509.73 | 624.75 |  |
| 1368 | Expert | Warrior of Ice | JannPck3 / fan:lldb-233 | 501.33 | 624.75 |  |
| 1369 | Expert | The Abyss | Van Clan Havoc / fan:lldb-521 | 507.07 | 624.75 |  |
| 1370 | Expert | Final impediment | Genesis Present / fan:lldb-492 | 519.41 | 624.75 |  |
| 1371 | Expert | There`s a method in the madness | geooPk0 / fan:lldb-1 | 540.26 | 624.75 |  |
| 1372 | Expert | Follow Me | geooPk1 / fan:lldb-2 | 548.76 | 624.90 |  |
| 1373 | Expert | Multi-Task Lemmings | ISteve02 / fan:lldb-23 | 572.74 | 624.75 |  |
| 1374 | Expert | Stuck | MARSHY04 / fan:lldb-348 | 222.92 | 651.67 |  |
| 1375 | Expert | Back in Hell | JMGM01 / fan:lldb-454 | 239.66 | 637.50 |  |
| 1376 | Expert | Nuclear Bomb | GARJEN03 / fan:lldb-283 | 260.05 | 637.06 |  |
| 1377 | Expert | Don't be desesperate ! | Mikepak10 / fan:lldb-15 | 324.22 | 637.50 |  |
| 1378 | Expert | Circular Dependency | Level Design Game 06 / fan:lldb-435 | 355.53 | 637.50 |  |
| 1379 | Expert | I Love Lemmings | JEFFPCK3 / fan:lldb-237 | 357.13 | 642.40 |  |
| 1380 | Expert | Save Me | Lemmings / Mayhem | 393.27 | 646.46 |  |
| 1381 | Expert | Husky Lemmings | Pieuws Lemmings 2007 Insane / fan:lldb-545 | 405.19 | 663.60 |  |
| 1382 | Expert | Mayhem 26.lvl | Amiga Mayhem Budget / fan:lldb-576 | 401.54 | 663.38 |  |
| 1383 | Expert | Variety Day | Lemmings Plus DOS Project PSYCHO / fan:lldb-555 | 413.72 | 630.00 |  |
| 1384 | Expert | Icy Poles | JEFFPCK1 / fan:lldb-235 | 419.26 | 645.88 |  |
| 1385 | Expert | Roman rendezvous | ANTHPCK1 / fan:lldb-221 | 425.53 | 646.72 |  |
| 1386 | Expert | Crazy stairs | Giga pack 07 / fan:lldb-169 | 417.88 | 658.51 |  |
| 1387 | Expert | End With a BANG! | cLemmings Taxing / fan:lldb-528 | 417.42 | 663.00 |  |
| 1388 | Expert | There's a lot of them about | Lemmings / Tricky | 446.37 | 663.00 |  |
| 1389 | Expert | It`s a tight fit! | Oh No! More Lemmings / Wild | 442.87 | 656.96 |  |
| 1390 | Expert | It's A Thin Line! | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 439.26 | 631.32 |  |
| 1391 | Expert | >>>>wAy Up YoNdEr<<<< | ISteve01 / fan:lldb-20 | 452.48 | 663.00 |  |
| 1392 | Expert | Tricky 10.lvl | Amiga Tricky Budget / fan:lldb-569 | 450.92 | 663.00 |  |
| 1393 | Expert | The snow is bad | CRISFN10 / fan:lldb-274 | 456.93 | 663.00 |  |
| 1394 | Expert | Not just a pretty Lemming | Oh No! More Lemmings / Tame | 468.85 | 630.00 |  |
| 1395 | Expert | Counterlogical | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 461.97 | 663.96 |  |
| 1396 | Expert | Lair Of The Fallen Lemming | Ji Hoons Lemmings Remake Hell / fan:lldb-550 | 478.79 | 630.00 |  |
| 1397 | Expert | Creature Discomforts | Oh No! More Lemmings / Havoc | 517.87 | 655.94 |  |
| 1398 | Expert | ONWARD AND UPWARD | Oh No! More Lemmings / Wild | 507.97 | 658.48 |  |
| 1399 | Expert | Tension sheet,good idea | LEVIPAK2 / fan:lldb-366 | 520.87 | 630.00 |  |
| 1400 | Expert | Death In All Directions | Lemmings Plus DOS Project Danger / fan:lldb-554 | 543.99 | 630.00 |  |
| 1401 | Expert | Your time is up! | ssam1221s Lemmings Wild / fan:lldb-514 | 544.55 | 630.48 |  |
| 1402 | Expert | Fearsome Rain | Pieuw02 / fan:lldb-394 | 554.11 | 641.80 |  |
| 1403 | Expert | If only this were Lemmings 3... | CSTame1 / fan:lldb-83 | 264.58 | 669.01 |  |
| 1404 | Expert | This Trick again | Pieuws Lemmings 2007 Insane / fan:lldb-545 | 360.92 | 669.01 |  |
| 1405 | Expert | And now this... | Oh No! More Lemmings / Tame | 396.84 | 673.32 |  |
| 1406 | Expert | LEMMINGS | fishthekiller99 / fan:lldb-71 | 398.04 | 674.08 |  |
| 1407 | Expert | I have a cunning plan | Lemmings / Tricky | 416.66 | 672.48 |  |
| 1408 | Expert | Tricky 26.lvl | Amiga Tricky Budget / fan:lldb-569 | 418.76 | 672.48 |  |
| 1409 | Expert | LEMMINGS IS KILLING | Oh No More cLemmings Crazy / fan:lldb-531 | 430.03 | 692.33 |  |
| 1410 | Expert | Lemmings in a situation | Oh No! More Lemmings / Havoc | 457.29 | 680.30 |  |
| 1411 | Expert | LemEdit generated Level | fullglitch / fan:lldb-422 | 468.86 | 685.58 |  |
| 1412 | Expert | Snuggle up to a Lemming | Oh No! More Lemmings / Tame | 480.11 | 673.32 |  |
| 1413 | Expert | The T Level | Lemmings Plus DOS Project Medi / fan:lldb-553 | 486.69 | 680.00 |  |
| 1414 | Expert | Anticlimacticism III | cLemmings Tricky / fan:lldb-527 | 483.09 | 680.00 |  |
| 1415 | Expert | Oogilemming! | Holiday Lemmings 1993 / Blizzard | 497.20 | 680.00 |  |
| 1416 | Expert | Origins and Lemmings | Lemmings / Fun | 501.55 | 667.72 |  |
| 1417 | Expert | In the Cave | KillerMasters Lemmings 1 Crazy / fan:lldb-506 | 495.05 | 680.00 |  |
| 1418 | Expert | The bubble ploters | CRISFN03 / fan:lldb-267 | 518.76 | 670.40 |  |
| 1419 | Expert | Ice cavern | CRISFN15 / fan:lldb-279 | 510.88 | 665.68 |  |
| 1420 | Expert | Do it the easy way! | joem8 / fan:lldb-323 | 510.02 | 680.00 |  |
| 1421 | Expert | Lemming Extravaganza | cLemmings Taxing / fan:lldb-528 | 515.78 | 680.00 |  |
| 1422 | Expert | A wee bit of magic | Snow remakes 01 / fan:lldb-144 | 516.59 | 680.00 |  |
| 1423 | Expert | The freezing cold | joem4 / fan:lldb-468 | 525.16 | 680.00 |  |
| 1424 | Expert | Clinging on for Dear Life | cLemmings Tricky / fan:lldb-527 | 521.67 | 689.28 |  |
| 1425 | Expert | Level 03.lvl | Amiga Demo / fan:lldb-581 | 538.00 | 680.00 |  |
| 1426 | Expert | Watch right and left! | Genesis Taxing / fan:lldb-490 | 533.74 | 680.00 |  |
| 1427 | Expert | Upset Lemming | geooPk1 / fan:lldb-2 | 545.32 | 680.00 |  |
| 1428 | Expert | The lemming bedroom | ANTHPCK3 / fan:lldb-223 | 545.82 | 680.00 |  |
| 1429 | Expert | Level 02.lvl | Amiga Magazine Demo / fan:lldb-594 | 539.88 | 680.00 |  |
| 1430 | Expert | Consider Everything... | Lemmings Plus DOS Project Medi / fan:lldb-553 | 544.49 | 691.40 |  |
| 1431 | Expert | Two Minute Warning | MazuLems 01 / fan:lldb-244 | 542.75 | 680.00 |  |
| 1432 | Expert | We need a blow torch NOW! | GARJEN01 / fan:lldb-281 | 536.76 | 679.48 |  |
| 1433 | Expert | Get the Point? | Holiday Lemmings 1994 / Hail | 553.20 | 688.50 |  |
| 1434 | Expert | Awaiting the Winter Frost | JannPck3 / fan:lldb-233 | 548.15 | 669.94 |  |
| 1435 | Expert | The Dark Cave behind CliffTown | Pieuws Lemmings 2007 Insane / fan:lldb-545 | 576.68 | 680.00 |  |
| 1436 | Expert | Heaven can wait (we hope!!!!) | Lemmings / Taxing | 281.82 | 722.50 |  |
| 1437 | Expert | Lemmings Get Lost in Afterlife | ssam1221s Lemmings Wicked / fan:lldb-515 | 273.42 | 722.50 |  |
| 1438 | Expert | Taxing 03.lvl | Amiga Taxing Budget / fan:lldb-570 | 283.92 | 722.50 |  |
| 1439 | Expert | I've lost that Lemming feeling | Lemmings / Fun | 356.12 | 700.00 | Review |
| 1440 | Expert | Nightmare on Lem street | Lemmings / Fun | 365.98 | 700.00 |  |
| 1441 | Expert | They just keep on coming | Lemmings / Tricky | 361.83 | 700.00 |  |
| 1442 | Expert | Christmas Bonus | Xmas Lemmings 1991 / Xmas | 364.92 | 700.00 |  |
| 1443 | Expert | All the 6`s ........ | Lemmings / Tricky | 374.38 | 700.00 |  |
| 1444 | Expert | These walls | JMGM02 / fan:lldb-455 | 371.57 | 700.00 |  |
| 1445 | Expert | And a Happy New Year! | Holiday Lemmings 1994 / Hail | 382.54 | 700.00 |  |
| 1446 | Expert | Merry Christmas Mr Lemming | Xmas Lemmings 1991 / Xmas | 385.80 | 700.00 |  |
| 1447 | Expert | Lemmingology | Lemmings / Tricky | 381.74 | 700.00 |  |
| 1448 | Expert | Lemming's Night | Oh No More cLemmings Tame / fan:lldb-530 | 383.07 | 700.00 |  |
| 1449 | Expert | Lemmings...The Motion Picture | Holiday Lemmings 1993 / Blizzard | 398.87 | 700.00 |  |
| 1450 | Expert | Last one out is a rotten egg! | Lemmings / Mayhem | 398.22 | 700.00 |  |
| 1451 | Expert | One way or another | Lemmings / Mayhem | 397.09 | 700.00 |  |
| 1452 | Expert | Let's get it Started | Deceits Lemmings Extras / fan:lldb-546 | 389.70 | 700.00 |  |
| 1453 | Expert | Chain Reaction | Ji Hoons Lemmings Remake Earth / fan:lldb-549 | 394.45 | 700.00 |  |
| 1454 | Expert | The searing heat!!! | ANTHPCK1 / fan:lldb-221 | 405.15 | 700.00 |  |
| 1455 | Expert | Mayhem 08.lvl | Amiga Mayhem Budget / fan:lldb-571 | 400.32 | 700.00 |  |
| 1456 | Expert | The Far Side | Lemmings / Mayhem | 417.09 | 700.00 |  |
| 1457 | Expert | Lemming Drops | Lemmings / Tricky | 418.77 | 700.00 |  |
| 1458 | Expert | The Island of the Wicker people | Lemmings / Tricky | 413.26 | 700.00 |  |
| 1459 | Expert | -->  Wrong Way!  --> | ISteve02 / fan:lldb-23 | 414.12 | 700.00 |  |
| 1460 | Expert | Feel the pain | joem5 / fan:lldb-320 | 411.24 | 700.00 |  |
| 1461 | Expert | Stairway to Heaven | MazuLems 01 / fan:lldb-244 | 423.42 | 700.00 |  |
| 1462 | Expert | Tricky 27.lvl | Amiga Tricky Budget / fan:lldb-569 | 415.36 | 700.00 |  |
| 1463 | Expert | Quickie... | Pieuws Lemmings 2007 Artful / fan:lldb-544 | 415.84 | 700.00 |  |
| 1464 | Expert | A Lemming Holiday | Xmas Lemmings 1992 / Xmas | 426.15 | 700.00 |  |
| 1465 | Expert | Here's one I prepared earlier | Lemmings / Tricky | 426.91 | 700.00 |  |
| 1466 | Expert | DO NOT ENTER | QBeez03 / fan:lldb-33 | 422.09 | 700.00 |  |
| 1467 | Expert | Izzie Wizzie lemmings get busy | Lemmings / Taxing | 434.67 | 700.00 |  |
| 1468 | Expert | Simple warm-up | geooPk0 / fan:lldb-1 | 426.32 | 700.00 |  |
| 1469 | Expert | Tricky 04.lvl | Amiga Tricky Budget / fan:lldb-569 | 429.01 | 700.00 |  |
| 1470 | Expert | Anticimacticism IV | cLemmings Tricky / fan:lldb-527 | 438.53 | 700.00 |  |
| 1471 | Expert | From The Boundary Line part two | Conway Challenges 1 / fan:lldb-263 | 444.11 | 700.00 |  |
| 1472 | Expert | Stepping Stones | Lemmings / Mayhem | 457.22 | 700.00 |  |
| 1473 | Expert | POOR WEE CREATURES! | Lemmings / Taxing | 460.80 | 700.00 |  |
| 1474 | Expert | Day tripper | Giga pack 01 / fan:lldb-160 | 452.93 | 700.00 |  |
| 1475 | Expert | Taxing 28.lvl | Amiga Taxing Budget / fan:lldb-570 | 461.25 | 700.00 |  |
| 1476 | Expert | Do the Lemmys way! | Lemmy556 My little levels / fan:lldb-65 | 457.22 | 700.00 |  |
| 1477 | Expert | The Swamp | TimpackB / fan:lldb-100 | 462.15 | 700.00 |  |
| 1478 | Expert | Up, Down, Round & Round! | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 459.37 | 700.00 |  |
| 1479 | Expert | Pipeline Problem | Lemmings Plus DOS Project Danger / fan:lldb-554 | 469.06 | 700.00 |  |
| 1480 | Expert | Poor Construction | ssam1221s Lemmings Wild / fan:lldb-514 | 468.07 | 700.00 |  |
| 1481 | Expert | Don't let your eyes deceive you | Lemmings / Fun | 488.66 | 700.00 |  |
| 1482 | Expert | The Needs of the Many... | Holiday Lemmings 1993 / Blizzard | 479.80 | 700.00 |  |
| 1483 | Expert | The Great Pillar | CPs Level Pack / fan:lldb-472 | 480.69 | 700.00 |  |
| 1484 | Expert | City Of The Damned | Van Clan Crazy / fan:lldb-518 | 479.29 | 700.00 |  |
| 1485 | Expert | Nowhere Near.... | Master System Remakes / fan:lldb-80 | 488.67 | 700.00 |  |
| 1486 | Expert | Let's Play Gyrodrop | KillerMasters Lemmings 1 Crazy / fan:lldb-506 | 483.53 | 700.00 |  |
| 1487 | Expert | Welcome to Night-City! | Mikepak08 / fan:lldb-13 | 480.13 | 700.00 |  |
| 1488 | Expert | Fun 15.lvl | Amiga Fun Budget / fan:lldb-568 | 495.68 | 700.00 |  |
| 1489 | Expert | Pipework | Insulfrog LVL PK 1 / fan:lldb-373 | 490.35 | 700.00 |  |
| 1490 | Expert | In And Out | TimpackD / fan:lldb-102 | 503.74 | 700.00 |  |
| 1491 | Expert | Catch more floaters. | Genesis Fun / fan:lldb-488 | 497.54 | 700.00 |  |
| 1492 | Expert | Prepare to be Mindblown | Oh No More cLemmings Crazy / fan:lldb-531 | 494.16 | 700.00 |  |
| 1493 | Expert | The ascending pillar scenario | Lemmings / Taxing | 506.15 | 700.00 |  |
| 1494 | Expert | Mission Lempossible II | joe04 / fan:lldb-131 | 513.70 | 700.00 |  |
| 1495 | Expert | Taxing 11.lvl | Amiga Taxing Budget / fan:lldb-570 | 508.25 | 700.00 |  |
| 1496 | Expert | The Only Way is Up | MazuLems 02 / fan:lldb-245 | 509.21 | 700.00 |  |
| 1497 | Expert | flag test map | Orig Extra Levels / fan:lldb-407 | 516.37 | 700.00 |  |
| 1498 | Expert | The magnificent severn | doggycharly random lvls / fan:lldb-78 | 508.02 | 720.00 |  |
| 1499 | Expert | From The Boundary Line | Lemmings / Tricky | 518.09 | 700.00 |  |
| 1500 | Expert | An Exit Isn't Just For Christmas | TWPAK10 / fan:lldb-312 | 519.80 | 700.00 |  |
| 1501 | Expert | The Lemming Tower | cLemmings Fun / fan:lldb-526 | 526.31 | 700.00 |  |
| 1502 | Expert | Chilean coliseum II | CRISFN14 / fan:lldb-278 | 524.09 | 700.00 |  |
| 1503 | Expert | -Teen Ninety-Four | Holiday cLemmings Frost / fan:lldb-535 | 524.82 | 700.00 |  |
| 1504 | Expert | The Peaks | Oh No More cLemmings Crazy / fan:lldb-531 | 518.42 | 700.00 |  |
| 1505 | Expert | Bubbles in the Lemms | Oh No More cLemmings Tame / fan:lldb-530 | 523.96 | 700.00 |  |
| 1506 | Expert | Tricky 23.lvl | Amiga Tricky Budget / fan:lldb-569 | 518.09 | 700.00 |  |
| 1507 | Expert | Watch out, there`s traps about | Lemmings / Taxing | 537.81 | 700.00 |  |
| 1508 | Expert | The Crankshaft | Lemmings / Tricky | 537.25 | 700.00 |  |
| 1509 | Expert | Been there, seen it, done it | Lemmings / Tricky | 536.62 | 700.00 |  |
| 1510 | Expert | Rendezvous at the Mountain | Lemmings / Mayhem | 536.15 | 700.00 |  |
| 1511 | Expert | Tricky 07.lvl | Amiga Tricky Budget / fan:lldb-569 | 538.72 | 700.00 |  |
| 1512 | Expert | Tricky 30.lvl | Amiga Tricky Budget / fan:lldb-569 | 537.25 | 700.00 |  |
| 1513 | Expert | Through the thicket | geooPk0 / fan:lldb-1 | 538.53 | 700.00 |  |
| 1514 | Expert | Taxing 02.lvl | Amiga Taxing Budget / fan:lldb-570 | 537.81 | 700.00 |  |
| 1515 | Expert | Devil's Right Hand | Nepster01 / fan:lldb-219 | 533.39 | 700.00 |  |
| 1516 | Expert | Proffesional Preferences | Oh No More cLemmings Crazy / fan:lldb-531 | 537.34 | 700.00 |  |
| 1517 | Expert | How do I dig out a path? | Genesis Taxing / fan:lldb-490 | 539.38 | 700.00 |  |
| 1518 | Expert | More 'No Builder Problems' | geooPk1 / fan:lldb-2 | 543.21 | 700.00 |  |
| 1519 | Expert | One Step At A Time | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 539.22 | 700.00 |  |
| 1520 | Expert | Rhapsody | ISteve01 / fan:lldb-20 | 535.26 | 720.00 |  |
| 1521 | Expert | Pillars of Hercules | Lemmings / Mayhem | 554.17 | 700.00 |  |
| 1522 | Expert | The Incinerator | cLemmings Taxing / fan:lldb-528 | 548.37 | 700.00 |  |
| 1523 | Expert | Chill out! | Oh No! More Lemmings / Wicked | 558.37 | 700.00 |  |
| 1524 | Expert | The bricks of death | CRISFN08 / fan:lldb-272 | 559.56 | 700.00 |  |
| 1525 | Expert | Mastermined | MazuLems 02 / fan:lldb-245 | 552.58 | 700.00 |  |
| 1526 | Expert | Lemming In Zest | GeoffLems Minipack / fan:lldb-413 | 558.54 | 700.00 |  |
| 1527 | Expert | Chilean coliseum I | CRISFN06 / fan:lldb-270 | 549.73 | 700.00 |  |
| 1528 | Expert | The Fast Food Kitchen... | Lemmings / Mayhem | 562.66 | 700.00 |  |
| 1529 | Expert | Please remain calm | Giga pack 04 / fan:lldb-165 | 561.03 | 700.00 |  |
| 1530 | Expert | Again, Your time is up! | ssam1221s Lemmings Wild / fan:lldb-514 | 564.06 | 700.00 |  |
| 1531 | Expert | The snow palace | Mikepak10 / fan:lldb-15 | 554.54 | 700.00 |  |
| 1532 | Expert | The Green Mile | Van Clan Tame / fan:lldb-99 | 561.42 | 700.00 |  |
| 1533 | Expert | Travelling Lemmings | Nepster01 / fan:lldb-219 | 575.09 | 700.00 |  |
| 1534 | Expert | Mayhem 29.lvl | Amiga Mayhem Budget / fan:lldb-576 | 590.57 | 700.00 |  |
| 1535 | Expert | The Barbarous Bars | Pieuws Lemmings 2007 Insane / fan:lldb-545 | 582.63 | 700.00 |  |
| 1536 | Expert | The Dirty Work | cLemmings Tricky / fan:lldb-527 | 582.50 | 700.00 |  |
| 1537 | Expert | Labyrinth of Despair | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 582.48 | 722.50 |  |
| 1538 | Expert | Lemmingology (Part 2) | JM01 / fan:lldb-327 | 626.98 | 700.00 |  |
| 1539 | Expert | Lemming Athletics | cLemmings Fun / fan:lldb-526 | 449.98 | 748.00 |  |
| 1540 | Expert | AAAAAARRRRRRGGGGGGHHHHHH!!!!!! | Oh No! More Lemmings / Havoc | 477.17 | 748.00 |  |
| 1541 | Expert | Lemmings to next floor | CRISFN07 / fan:lldb-271 | 469.18 | 756.50 |  |
| 1542 | Expert | Impossible mission | joem2 / fan:lldb-318 | 480.26 | 748.00 |  |
| 1543 | Expert | Up and Over | cLemmings Tricky / fan:lldb-527 | 519.84 | 735.25 |  |
| 1544 | Expert | First-come, First-serve | cLemmings Taxing / fan:lldb-528 | 519.77 | 760.75 |  |
| 1545 | Expert | volando en la loca busqueda | doggycharly random lvls / fan:lldb-78 | 554.49 | 735.25 |  |
| 1546 | Expert | The Golden Gate | TimpackC / fan:lldb-101 | 555.49 | 765.00 |  |
| 1547 | Expert | Dual Lemmings | cLemmings Tricky / fan:lldb-527 | 545.78 | 756.50 |  |
| 1548 | Expert | It Came Upon a Lemnight Clear | Holiday Lemmings 1993 / Blizzard | 557.79 | 735.25 |  |
| 1549 | Expert | Trading and Cooperating | geooPk1 / fan:lldb-2 | 572.36 | 735.25 |  |
| 1550 | Expert | Zygoptera | AkseliPack01 / fan:lldb-220 | 567.97 | 735.25 |  |
| 1551 | Expert | Waste High! | ANTHPCK5 / fan:lldb-225 | 578.72 | 735.25 |  |
| 1552 | Expert | A group of entrances | Genesis Mayhem / fan:lldb-491 | 586.03 | 735.25 |  |
| 1553 | Expert | Three Birds With One Stone | Lemmings Plus DOS Project PSYCHO / fan:lldb-555 | 581.95 | 735.25 |  |
| 1554 | Expert | The Crystalline Fortress | Mikes Lemmix Pack / fan:lldb-591 | 576.28 | 739.50 |  |
| 1555 | Expert | Head for the Hills! | Holiday Lemmings 1993 / Flurry | 270.77 | 781.15 |  |
| 1556 | Expert | Now get out of that! | Oh No! More Lemmings / Havoc | 293.69 | 785.88 |  |
| 1557 | Expert | The Loser's Loop | ISteve03 / fan:lldb-21 | 354.55 | 785.88 |  |
| 1558 | Expert | The Traffic Light Of Lemmland | TWPAK09 / fan:lldb-311 | 380.39 | 781.15 |  |
| 1559 | Expert | (Un)pleasant side effect | geooPkG / fan:lldb-108 | 391.63 | 785.88 |  |
| 1560 | Expert | Oh no! More challenges! | CSTame1 / fan:lldb-83 | 405.59 | 785.88 |  |
| 1561 | Expert | The race against cliches | Oh No! More Lemmings / Havoc | 433.13 | 776.14 |  |
| 1562 | Expert | Firestorm | GARJEN04 / fan:lldb-284 | 431.34 | 773.50 |  |
| 1563 | Expert | Objects? What Objects? | TWPAK10 / fan:lldb-312 | 493.87 | 781.15 |  |
| 1564 | Expert | Me, Myself And Ice | TWPAK06 / fan:lldb-308 | 514.13 | 790.50 |  |
| 1565 | Expert | MENACING !! | Lemmings / Tricky | 565.10 | 803.25 |  |
| 1566 | Expert | The house of Lem | Conway10 / fan:lldb-259 | 572.66 | 782.00 |  |
| 1567 | Expert | And then there were four.... | Lemmings / Mayhem | 569.32 | 816.00 |  |
| 1568 | Expert | Synchronised Lemming | Oh No! More Lemmings / Havoc | 565.10 | 816.00 |  |
| 1569 | Expert | Pedantic Lemmings | AkseliPack01 / fan:lldb-220 | 581.17 | 810.00 |  |
| 1570 | Expert | Mayhem 18.lvl | Amiga Mayhem Budget / fan:lldb-571 | 572.62 | 816.00 |  |
| 1571 | Expert | Have you seen this level before? | lm set13 / fan:lldb-59 | 587.18 | 810.00 |  |
| 1572 | Expert | A Magician Would Be Handy | Lemmings Plus DOS Project Wimpy / fan:lldb-552 | 596.43 | 811.75 |  |
| 1573 | Expert | Tower of Ice | lm set13 / fan:lldb-59 | 650.98 | 810.00 |  |
| 1574 | Expert | Build The Way | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 251.14 | 850.00 |  |
| 1575 | Expert | Climb and Dig | brickpk1 / fan:lldb-558 | 332.86 | 850.00 |  |
| 1576 | Expert | Celestial Lemmings | TWPAK01 / fan:lldb-303 | 344.42 | 850.00 |  |
| 1577 | Expert | Snow Lev 4 | ANTHPCK4 / fan:lldb-224 | 362.82 | 850.00 |  |
| 1578 | Expert | Climb and Bomb | brickpk1 / fan:lldb-558 | 366.31 | 850.00 |  |
| 1579 | Expert | Us and them | joe02 / fan:lldb-127 | 370.86 | 850.00 |  |
| 1580 | Expert | Warming Up | ssam1221s Lemmings Tame / fan:lldb-512 | 394.02 | 843.48 |  |
| 1581 | Expert | Betcha can't save just one! | ISteve02 / fan:lldb-23 | 391.56 | 843.48 |  |
| 1582 | Expert | The Plight of Icarus | ISteve03 / fan:lldb-21 | 393.99 | 850.00 |  |
| 1583 | Expert | Steel blocks are not perfect... | ssam1221s Lemmings Wicked / fan:lldb-515 | 407.68 | 850.00 |  |
| 1584 | Expert | Keep your hair on Mr. Lemming | Lemmings / Fun | 427.47 | 850.00 |  |
| 1585 | Expert | A BeastII of a level | Lemmings / Mayhem | 450.37 | 850.00 |  |
| 1586 | Expert | Don't do anything too hasty | Lemmings / Fun | 442.35 | 850.00 |  |
| 1587 | Expert | Happy New Year II! | Holiday Lemmings 1994 / Frost | 441.86 | 843.48 |  |
| 1588 | Expert | Lemmintaschen? | Holiday Lemmings 1994 / Hail | 474.65 | 843.48 |  |
| 1589 | Expert | Oscillating Lemmings | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 466.96 | 850.00 |  |
| 1590 | Expert | It is very complicated | Insulfrog LVL PK 1 / fan:lldb-373 | 478.39 | 850.00 |  |
| 1591 | Expert | Tailor-made for Athletes | JEFFPCK1 / fan:lldb-235 | 479.06 | 850.00 |  |
| 1592 | Expert | The Awesome level returns! | Mikes Lemmix Pack / fan:lldb-591 | 506.07 | 850.00 |  |
| 1593 | Expert | Turn baby Turn. | ANTHPCK3 / fan:lldb-223 | 538.00 | 850.00 |  |
| 1594 | Expert | Sudenly lemming | Lemmings platinum Careful Part 1 / fan:lldb-188 | 543.92 | 850.00 |  |
| 1595 | Expert | This is a doddle | JM09 / fan:lldb-335 | 543.20 | 850.00 |  |
| 1596 | Expert | Across The Gap | Oh No! More Lemmings / Crazy | 555.35 | 850.00 |  |
| 1597 | Expert | Swallowing method 1 | Lemmings platinum Fragle part 2 / fan:lldb-181 | 553.79 | 850.00 |  |
| 1598 | Expert | It Takes Two To Tango | Van Clan Tame / fan:lldb-99 | 576.36 | 850.00 |  |
| 1599 | Expert | Make a Best - Click Time | KillerMasters Lemmings 1 Havoc / fan:lldb-509 | 583.69 | 850.00 |  |
| 1600 | Expert | Floaters Away! | cLemmings Tricky / fan:lldb-527 | 589.55 | 850.00 |  |
| 1601 | Expert | Be Careful... | Lemmings Plus DOS Project Mild / fan:lldb-551 | 583.08 | 850.00 |  |
| 1602 | Expert | Wall of Wisdom | Lemmings Plus DOS Project Danger / fan:lldb-554 | 606.61 | 850.00 |  |
| 1603 | Expert | The Shaft (Part 2) | ISteve04 / fan:lldb-24 | 605.45 | 850.00 |  |
| 1604 | Expert | And then there were another four | Conway Challenges 2 / fan:lldb-264 | 600.18 | 850.00 |  |
| 1605 | Expert | Hold them back | CPs Level Pack / fan:lldb-472 | 625.39 | 850.00 |  |
| 1606 | Expert | Free Lemmings | Oh No More cLemmings Tame / fan:lldb-530 | 620.59 | 850.00 |  |
| 1607 | Expert | The Graveyard | Lemmings Plus DOS Project Mild / fan:lldb-551 | 633.39 | 850.00 |  |
| 1608 | Expert | Double Lemmings | KillerMasters Lemmings 2 Tame / fan:lldb-510 | 631.46 | 850.00 |  |
| 1609 | Expert | Remember where you find them! | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 659.90 | 850.00 |  |
