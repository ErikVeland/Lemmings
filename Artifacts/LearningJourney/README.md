# Oh My! All Lemmings!

504 distinct single-player levels: 317 official puzzles and 187 replay-validated library levels from 79 packs.

## Ordering

The path progresses through Fun, Intermediate, Difficult and Expert. A hard timing, coordination or planning demand cannot be cancelled by easy dimensions in a weighted average. Official levels take priority within comparable demand bands. Retail rank and campaign order do not determine placement. All Oh No! levels are interleaved with the rest of the pool.

Stages: Fun 30; Intermediate 89; Difficult 270; Expert 115. Largest upward curriculum-demand step: 55.25/1000. Transitions requiring review: 2; missing basic-skill preparation: 0.

| Stage | Steps | Teaching focus |
| --- | ---: | --- |
| Fun | 1–30 | Single skills and simple combinations |
| Intermediate | 31–119 | Skill combinations and crowd management |
| Difficult | 120–389 | Longer plans and tighter resources |
| Expert | 390–504 | Precision, complex plans and coordination |

Curriculum demand is the maximum of the unchanged evidence score, 0.85 × technique, precision, concurrency and deduction, 0.70 × solution complexity, 0.50 × constraints, and 90 × additional concepts. A combination also waits for its easiest available isolated skill lessons. These weights and the stage thresholds (180, 360, 600) are editorial estimates, not player-calibrated difficulty measurements.

Within each stage, 35-point bands allow spaced practice and small relief steps. Selection favours prepared combinations, avoids consecutive identical technique sets when comparable alternatives exist, and reduces upward component changes. Two-skill combinations require one earlier exposure per basic skill; larger combinations seek two. Exposure means a practice opportunity, not demonstrated mastery. New coordination and crowd-spacing concepts can be introduced through familiar skills.

Raw evidence scores remain unchanged and are reported separately. Their largest upward step is 291.17, with 230 decreases. The curriculum demand does not certify every component transition as smooth; all component changes and support flags are retained in transitions.json.

Oh No! has all 100 levels in the shared path. Its original largest raw-score jump was 348.77; its largest incoming raw-score jump here is 150.83. This is a diagnostic, not the sequencing objective.

The score uses validated solution techniques, solution complexity, timing perturbations, concurrent workers, constraints and a deduction proxy. It is an estimate of human difficulty, not direct measurement of insight. A winning route proves solvability; a low score does not prove that its solution is obvious. Unresolved component jumps stay visible in the report.

## Remaining transition reviews

- Step 20, **Thunder-Lemmings are go!** (Fun): new execution-demand high rises by 176.7/1000. Check timing forgiveness with a novice before calling this transition smooth.
- Step 479, **Head for the Hills!** (Expert): new execution-demand high rises by 214.4/1000. Check timing forgiveness with a novice before calling this transition smooth.

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
| 2 | Fun | Only Float is Survive | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 46.84 | 55.25 |  |
| 3 | Fun | PRACTICE: DIGGER | Mikepak07 / fan:lldb-12 | 45.89 | 57.68 |  |
| 4 | Fun | Float Or Die | TWPAK00 / fan:lldb-302 | 46.53 | 55.25 |  |
| 5 | Fun | Climin' Death Mountain | TWPAK00 / fan:lldb-302 | 50.79 | 58.13 |  |
| 6 | Fun | Mienrs <--- lol, typo | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 46.86 | 61.42 |  |
| 7 | Fun | Climbing in life... | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 52.11 | 61.29 |  |
| 8 | Fun | You need bashers this time | Lemmings / Fun | 67.67 | 88.11 |  |
| 9 | Fun | Up Up UP They Go | Van Clan Tame / fan:lldb-88 | 65.20 | 103.44 |  |
| 10 | Fun | Surprise Package? | Holiday Lemmings 1994 / Hail | 32.93 | 113.20 |  |
| 11 | Fun | Let's block and blow | Lemmings / Fun | 67.41 | 110.92 |  |
| 12 | Fun | Crush & Crash 3 | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 60.56 | 108.16 |  |
| 13 | Fun | Just Climb Mountain! | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 67.43 | 118.49 |  |
| 14 | Fun | Digging Only | joem7 / fan:lldb-322 | 62.54 | 121.74 |  |
| 15 | Fun | The Wall Trilogy Part 1 | TWPAK03 / fan:lldb-305 | 68.31 | 121.88 |  |
| 16 | Fun | Step By Step Guide To Building | Van Clan Tame / fan:lldb-88 | 71.46 | 131.07 |  |
| 17 | Fun | Bash This! | Van Clan Tame / fan:lldb-88 | 73.91 | 136.96 |  |
| 18 | Fun | Lemmings For Presidents! | Oh No! More Lemmings / Tame | 114.93 | 147.32 |  |
| 19 | Fun | Holiday Mining | Holiday Lemmings 1993 / Flurry | 71.37 | 144.50 |  |
| 20 | Fun | Thunder-Lemmings are go! | Oh No! More Lemmings / Tame | 151.62 | 151.62 | Review |
| 21 | Fun | Citizen Lemming | Oh No! More Lemmings / Tame | 80.86 | 144.50 |  |
| 22 | Fun | Everyone turn left (Part two) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 86.77 | 164.32 |  |
| 23 | Fun | Lemmings Lemmings everywhere | Lemmings / Fun | 71.79 | 144.50 |  |
| 24 | Fun | Get a little extra help | Oh No! More Lemmings / Tame | 120.08 | 170.39 |  |
| 25 | Fun | Floating Lemming Flurry | Holiday Lemmings 1993 / Flurry | 146.74 | 170.46 |  |
| 26 | Fun | Fun 25.lvl | Amiga Fun Budget / fan:lldb-568 | 71.79 | 144.50 |  |
| 27 | Fun | Frostbite | Van Clan Tame / fan:lldb-99 | 69.26 | 170.00 |  |
| 28 | Fun | Floating Down! | Holiday cLemmings Frost / fan:lldb-535 | 81.34 | 170.47 |  |
| 29 | Fun | Pollution | JM01 / fan:lldb-327 | 80.99 | 170.00 |  |
| 30 | Fun | Bomboozal | Lemmings / Taxing | 83.79 | 179.28 |  |
| 31 | Intermediate | Lost something? | Lemmings / Tricky | 148.88 | 180.00 |  |
| 32 | Intermediate | Lemming Snowfall | Holiday Lemmings 1993 / Flurry | 141.84 | 187.00 |  |
| 33 | Intermediate | At Home in a Cave | Holiday Lemmings 1993 / Flurry | 142.14 | 196.20 |  |
| 34 | Intermediate | Pea Soup | Lemmings / Mayhem | 98.34 | 202.99 |  |
| 35 | Intermediate | Custom built for Lemmings | Oh No! More Lemmings / Tame | 166.54 | 189.12 |  |
| 36 | Intermediate | The Undiscovered Country | Holiday Lemmings 1993 / Blizzard | 159.71 | 204.53 |  |
| 37 | Intermediate | Not as complicated as it looks | Lemmings / Fun | 149.97 | 209.58 |  |
| 38 | Intermediate | Tricky 28.lvl | Amiga Tricky Budget / fan:lldb-569 | 149.33 | 180.00 |  |
| 39 | Intermediate | Alternate Route | Lemmings The Official Companion / fan:lldb-585 | 138.48 | 202.49 |  |
| 40 | Intermediate | 5 miles if you love Lemmings | Genesis Fun / fan:lldb-488 | 154.07 | 204.53 |  |
| 41 | Intermediate | Jingle Lemming | Xmas Lemmings 1992 / Xmas | 109.70 | 233.75 |  |
| 42 | Intermediate | Division Bell | Holiday Lemmings 1994 / Frost | 96.03 | 212.84 |  |
| 43 | Intermediate | Lemming sanctuary in sight | Lemmings / Tricky | 146.54 | 221.00 |  |
| 44 | Intermediate | Mind the step..... | Lemmings / Mayhem | 199.18 | 210.70 |  |
| 45 | Intermediate | King of the castle | Lemmings / Taxing | 170.33 | 221.00 |  |
| 46 | Intermediate | Christmas South of the Equator | Holiday Lemmings 1993 / Flurry | 124.08 | 233.75 |  |
| 47 | Intermediate | Intsy-Wintsy...Lemming? | Oh No! More Lemmings / Tame | 132.74 | 233.75 |  |
| 48 | Intermediate | Honey, I Saved The Lemmings | Oh No! More Lemmings / Tame | 132.06 | 233.75 |  |
| 49 | Intermediate | What an AWESOME level | Lemmings / Taxing | 184.84 | 221.00 |  |
| 50 | Intermediate | You Live and Lem | Lemmings / Fun | 202.83 | 228.08 |  |
| 51 | Intermediate | Builders will help you here | Lemmings / Fun | 155.98 | 221.00 |  |
| 52 | Intermediate | Mayhem 28.lvl | Amiga Mayhem Budget / fan:lldb-571 | 199.18 | 210.70 |  |
| 53 | Intermediate | Fun 08.lvl | Amiga Fun Budget / fan:lldb-568 | 153.08 | 212.50 |  |
| 54 | Intermediate | King of the castle (part two) | Conway Challenges 1 / fan:lldb-263 | 171.50 | 221.00 |  |
| 55 | Intermediate | Fun 21.lvl | Amiga Fun Budget / fan:lldb-568 | 202.83 | 228.08 |  |
| 56 | Intermediate | Tricky 08.lvl | Amiga Tricky Budget / fan:lldb-569 | 148.92 | 221.00 |  |
| 57 | Intermediate | Taxing 23.lvl | Amiga Taxing Budget / fan:lldb-570 | 172.88 | 221.00 |  |
| 58 | Intermediate | Taxing 15.lvl | Amiga Taxing Book Club / fan:lldb-570 | 184.84 | 221.00 |  |
| 59 | Intermediate | Take good care of my Lemmings | Lemmings / Fun | 190.08 | 276.25 |  |
| 60 | Intermediate | Just a Minute (Part Two) | Lemmings / Mayhem | 212.30 | 262.32 |  |
| 61 | Intermediate | Let's go camping. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 211.40 | 275.93 |  |
| 62 | Intermediate | 32 Lemmings Below Zero | Holiday Lemmings 1993 / Flurry | 181.88 | 263.56 |  |
| 63 | Intermediate | If only they could fly | Lemmings / Fun | 198.34 | 270.56 |  |
| 64 | Intermediate | Careless clicking costs lives | Lemmings / Tricky | 190.58 | 276.25 |  |
| 65 | Intermediate | No Problemming! | Oh No! More Lemmings / Crazy | 260.16 | 276.25 |  |
| 66 | Intermediate | The Art Gallery | Lemmings / Taxing | 226.89 | 276.25 |  |
| 67 | Intermediate | Turn around young lemmings! | Lemmings / Tricky | 180.25 | 277.23 |  |
| 68 | Intermediate | Steel Block Party | Holiday Lemmings 1994 / Hail | 204.01 | 273.99 |  |
| 69 | Intermediate | Follow the leader... | Lemmings / Taxing | 215.15 | 276.25 |  |
| 70 | Intermediate | Choose Your Solution | SeverSet1 / fan:lldb-183 | 162.68 | 265.73 |  |
| 71 | Intermediate | Fun 19.lvl | Amiga Fun Budget / fan:lldb-568 | 190.08 | 276.25 |  |
| 72 | Intermediate | Fun 28.lvl | Amiga Fun Budget / fan:lldb-568 | 198.34 | 270.56 |  |
| 73 | Intermediate | Lemm Of All Trades | TWPAK12 / fan:lldb-314 | 195.52 | 273.00 |  |
| 74 | Intermediate | Taxing 25.lvl | Amiga Taxing Budget / fan:lldb-570 | 215.15 | 276.25 |  |
| 75 | Intermediate | Lemming Friendly | Oh No! More Lemmings / Crazy | 253.66 | 281.05 |  |
| 76 | Intermediate | Chains of Command | Holiday Lemmings 1994 / Frost | 160.98 | 296.56 |  |
| 77 | Intermediate | Many Lemmings make level work | Oh No! More Lemmings / Crazy | 149.29 | 303.69 |  |
| 78 | Intermediate | Take a running jump..... | Lemmings / Taxing | 244.56 | 301.05 |  |
| 79 | Intermediate | Lemming Snowjourn | Holiday Lemmings 1993 / Flurry | 189.31 | 306.00 |  |
| 80 | Intermediate | Turn around and look. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 218.50 | 306.00 |  |
| 81 | Intermediate | Yo-yo Lem-lem | Holiday Lemmings 1993 / Flurry | 246.94 | 308.30 |  |
| 82 | Intermediate | Ice Ice Lemming | Oh No! More Lemmings / Crazy | 262.47 | 303.83 |  |
| 83 | Intermediate | Smile if you love lemmings | Lemmings / Fun | 234.36 | 308.71 |  |
| 84 | Intermediate | Taxing 24.lvl | Amiga Taxing Budget / fan:lldb-570 | 245.36 | 301.05 |  |
| 85 | Intermediate | Tricky 22.lvl | Amiga Tricky Budget / fan:lldb-569 | 183.36 | 281.11 |  |
| 86 | Intermediate | Float and Dig | brickpk1 / fan:lldb-558 | 173.52 | 293.04 |  |
| 87 | Intermediate | The Iron Puzzle | TimballistoPack1 / fan:lldb-354 | 297.58 | 297.58 |  |
| 88 | Intermediate | Fun 09.lvl | Amiga Fun Budget / fan:lldb-568 | 247.06 | 308.51 |  |
| 89 | Intermediate | Only floaters can survive this | Lemmings / Fun | 121.12 | 322.05 |  |
| 90 | Intermediate | Lemming Express | Oh No! More Lemmings / Crazy | 182.04 | 317.75 |  |
| 91 | Intermediate | I am A.T. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 232.62 | 331.74 |  |
| 92 | Intermediate | Meeting Adjourned | Oh No! More Lemmings / Wild | 269.12 | 331.50 |  |
| 93 | Intermediate | Lock up your Lemmings | Lemmings / Fun | 283.85 | 319.20 |  |
| 94 | Intermediate | Easy when you know how | Lemmings / Fun | 256.86 | 331.50 |  |
| 95 | Intermediate | Gone With The Lemming | Oh No! More Lemmings / Tame | 216.33 | 347.20 |  |
| 96 | Intermediate | Bitter Lemming | Lemmings / Tricky | 239.79 | 336.00 |  |
| 97 | Intermediate | A TOWERING PROBLEM | Oh No! More Lemmings / Wicked | 304.89 | 331.13 |  |
| 98 | Intermediate | Lemming Hotel | Oh No! More Lemmings / Wild | 242.86 | 337.12 |  |
| 99 | Intermediate | We are now at LEMCON ONE | Lemmings / Fun | 273.12 | 337.32 |  |
| 100 | Intermediate | Time to get up! | Lemmings / Mayhem | 319.74 | 331.50 |  |
| 101 | Intermediate | It`s a trade off | Oh No! More Lemmings / Crazy | 272.03 | 346.74 |  |
| 102 | Intermediate | A Block from Home | Holiday Lemmings 1993 / Flurry | 348.40 | 348.40 |  |
| 103 | Intermediate | Egypt Fall | Anatol00 / fan:lldb-3 | 125.77 | 324.53 |  |
| 104 | Intermediate | Diggin' to a better world | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 121.63 | 324.01 |  |
| 105 | Intermediate | PRACTICE: FLOATER | Mikepak07 / fan:lldb-12 | 121.89 | 325.03 |  |
| 106 | Intermediate | Climb to victory | PSP Special 1 10 of 36 / fan:lldb-216 | 120.02 | 326.71 |  |
| 107 | Intermediate | Float to safety | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 124.82 | 336.28 |  |
| 108 | Intermediate | The Curse of Devil | Mad00 / fan:lldb-55 | 259.27 | 330.08 |  |
| 109 | Intermediate | Save the Lemmings with Floaters | PSP Special 1 10 of 36 / fan:lldb-216 | 232.61 | 328.18 |  |
| 110 | Intermediate | How do you get up there? | JM10 / fan:lldb-336 | 320.08 | 331.50 |  |
| 111 | Intermediate | Fun 20.lvl | Amiga Fun Budget / fan:lldb-568 | 275.22 | 337.32 |  |
| 112 | Intermediate | Downwardly Mobile Lemmings | Oh No! More Lemmings / Tame | 160.51 | 350.62 |  |
| 113 | Intermediate | Luvly Jubly | Lemmings / Tricky | 205.59 | 350.30 |  |
| 114 | Intermediate | New Lemmings On The Block | Oh No! More Lemmings / Tame | 161.16 | 350.62 |  |
| 115 | Intermediate | Livin` On The Edge | Lemmings / Taxing | 318.94 | 351.32 |  |
| 116 | Intermediate | Going up....... | Lemmings / Mayhem | 292.20 | 355.38 |  |
| 117 | Intermediate | A long way to go | Giga pack 09 / fan:lldb-171 | 322.32 | 359.18 |  |
| 118 | Intermediate | Taxing 12.lvl | Amiga Taxing Budget / fan:lldb-570 | 321.04 | 351.32 |  |
| 119 | Intermediate | Mayhem 23.lvl | Amiga Mayhem Budget / fan:lldb-571 | 294.30 | 355.38 |  |
| 120 | Difficult | The Boiler Room | Lemmings / Mayhem | 230.65 | 362.40 |  |
| 121 | Difficult | Flow Control | Oh No! More Lemmings / Havoc | 249.06 | 361.82 |  |
| 122 | Difficult | The Wrath of Lem | Holiday Lemmings 1993 / Blizzard | 260.08 | 371.17 |  |
| 123 | Difficult | SNOW JOKE | Oh No! More Lemmings / Wild | 266.41 | 365.28 |  |
| 124 | Difficult | Anxiety | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 261.73 | 371.60 |  |
| 125 | Difficult | Train your body | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 269.76 | 360.53 |  |
| 126 | Difficult | Two heads are better... | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 265.30 | 374.91 |  |
| 127 | Difficult | If at first you don`t succeed.. | Lemmings / Taxing | 238.73 | 381.21 |  |
| 128 | Difficult | Tribute to M.C.Escher | Lemmings / Taxing | 320.79 | 372.57 |  |
| 129 | Difficult | Dangerzone | Oh No! More Lemmings / Tame | 240.43 | 377.08 |  |
| 130 | Difficult | Exodus! | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 378.92 | 378.92 |  |
| 131 | Difficult | Stairway To Nowhere | Timpack11 / fan:lldb-98 | 134.12 | 362.58 |  |
| 132 | Difficult | Climbers can climb the wall | Deceits Lemmings Extras / fan:lldb-546 | 133.34 | 369.08 |  |
| 133 | Difficult | Floaters can land safely | Deceits Lemmings Extras / fan:lldb-546 | 134.25 | 372.57 |  |
| 134 | Difficult | Miners Can Mine Diagonally | Deceits Lemmings Extras / fan:lldb-546 | 136.08 | 371.53 |  |
| 135 | Difficult | Exit for Hell! | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 193.67 | 367.41 |  |
| 136 | Difficult | Crush & Crash 2 | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 232.58 | 365.58 |  |
| 137 | Difficult | De-fusing a time bomb | Snow remakes 01 / fan:lldb-144 | 235.29 | 375.46 |  |
| 138 | Difficult | The Boiler Room (part two) | Conway Challenges 2 / fan:lldb-264 | 232.70 | 362.40 |  |
| 139 | Difficult | V For Vendetta | Van Clan Tame / fan:lldb-88 | 303.71 | 383.00 |  |
| 140 | Difficult | 2 Minutes before midnight | Holiday Lemmings 1994 / Frost | 202.25 | 393.73 |  |
| 141 | Difficult | Happy Holidays Mr Lemming! | Xmas Lemmings 1992 / Xmas | 179.60 | 404.15 |  |
| 142 | Difficult | It's Lemmingentry Watson | Lemmings / Tricky | 216.70 | 400.45 |  |
| 143 | Difficult | Now use miners and climbers | Lemmings / Fun | 194.62 | 408.85 |  |
| 144 | Difficult | Ice Station Lemming | Oh No! More Lemmings / Wild | 243.02 | 388.29 |  |
| 145 | Difficult | Have an ice day | Oh No! More Lemmings / Havoc | 284.08 | 385.65 |  |
| 146 | Difficult | The Great Lemming Caper | Lemmings / Mayhem | 342.90 | 386.75 |  |
| 147 | Difficult | The Lemming Learning Curve | Oh No! More Lemmings / Wicked | 325.11 | 386.75 |  |
| 148 | Difficult | Dolly Dimple | Oh No! More Lemmings / Crazy | 312.59 | 391.76 |  |
| 149 | Difficult | Let's be careful out there | Lemmings / Fun | 288.66 | 386.75 |  |
| 150 | Difficult | Lemmings in the attic | Lemmings / Tricky | 309.71 | 386.75 |  |
| 151 | Difficult | With Compliments | Oh No! More Lemmings / Tame | 231.34 | 397.63 |  |
| 152 | Difficult | No world without you | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 382.47 | 386.75 |  |
| 153 | Difficult | Watch right or left (Part two) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 357.49 | 387.91 |  |
| 154 | Difficult | LOoK BeFoRe YoU LeAp! | Oh No! More Lemmings / Havoc | 296.68 | 395.44 |  |
| 155 | Difficult | Mary Poppins` land | Lemmings / Taxing | 338.28 | 396.82 |  |
| 156 | Difficult | Triple Trouble | Lemmings / Taxing | 341.86 | 386.75 |  |
| 157 | Difficult | Rent-a-Lemming | Oh No! More Lemmings / Tame | 319.26 | 408.13 |  |
| 158 | Difficult | Presents of Mind II | Holiday Lemmings 1993 / Blizzard | 321.70 | 406.61 |  |
| 159 | Difficult | Higgledy Piggledy | Oh No! More Lemmings / Wild | 316.87 | 416.03 |  |
| 160 | Difficult | The Crossroads | Lemmings / Mayhem | 180.36 | 417.92 |  |
| 161 | Difficult | Climbing to the Top! | Holiday Lemmings 1993 / Flurry | 240.38 | 417.92 |  |
| 162 | Difficult | Lemming Reunification | Holiday Lemmings 1994 / Frost | 289.34 | 417.92 |  |
| 163 | Difficult | Perseverance | Lemmings / Taxing | 320.77 | 402.67 |  |
| 164 | Difficult | The North Poles | Xmas Lemmings 1992 / Xmas | 292.83 | 408.89 |  |
| 165 | Difficult | Worra load of old blocks! | Oh No! More Lemmings / Crazy | 363.16 | 407.75 |  |
| 166 | Difficult | Poles Apart | Lemmings / Mayhem | 349.15 | 414.93 |  |
| 167 | Difficult | Lemmy in the cold, cold ground | Holiday Lemmings 1994 / Hail | 359.03 | 414.75 |  |
| 168 | Difficult | You Take the High Road | Oh No! More Lemmings / Wild | 383.35 | 412.58 |  |
| 169 | Difficult | Climbing Will Help, Now | Holiday cLemmings Frost / fan:lldb-535 | 142.48 | 404.21 |  |
| 170 | Difficult | Float to safety | JM01 / fan:lldb-327 | 146.19 | 409.02 |  |
| 171 | Difficult | Bridge In A Fridge | TWPAK00 / fan:lldb-302 | 146.28 | 409.35 |  |
| 172 | Difficult | Just Float | TimpackE / fan:lldb-103 | 146.51 | 410.24 |  |
| 173 | Difficult | Which Exit? | beta / fan:lldb-371 | 141.96 | 408.35 |  |
| 174 | Difficult | Training 07 - Let's Mine! | JEFFPCK6 / fan:lldb-240 | 145.52 | 415.92 |  |
| 175 | Difficult | Build Block | KillerMasters Lemmings 1 Wicked / fan:lldb-508 | 150.39 | 413.96 |  |
| 176 | Difficult | Fun 04.lvl | Amiga Fun Budget / fan:lldb-568 | 196.72 | 408.85 |  |
| 177 | Difficult | Fun 27.lvl | Amiga Fun Budget / fan:lldb-568 | 288.66 | 386.75 |  |
| 178 | Difficult | Taxing 26.lvl | Amiga Taxing Budget / fan:lldb-570 | 346.62 | 386.75 |  |
| 179 | Difficult | In The Style Of... | Lemmings Plus DOS Project Mild / fan:lldb-551 | 301.13 | 400.44 |  |
| 180 | Difficult | Taxing 16.lvl | Amiga Taxing Budget / fan:lldb-570 | 338.55 | 397.86 |  |
| 181 | Difficult | Have a Pleasant Journey ! | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 268.04 | 395.76 |  |
| 182 | Difficult | Mayhem 07.lvl | Amiga Mayhem Budget / fan:lldb-571 | 351.25 | 414.93 |  |
| 183 | Difficult | gronklems -1.dat 1 | Gronklems 1 / fan:lldb-386 | 276.82 | 408.13 |  |
| 184 | Difficult | Mayhem 04.lvl | Amiga Mayhem Budget / fan:lldb-571 | 196.58 | 417.92 |  |
| 185 | Difficult | You going to Lemming Master | KillerMasters Lemmings 1 Havoc / fan:lldb-509 | 271.51 | 410.62 |  |
| 186 | Difficult | Diet Lemmingaid | Lemmings / Tricky | 144.50 | 422.94 |  |
| 187 | Difficult | Separate Ways | Holiday Lemmings 1994 / Frost | 182.16 | 434.92 |  |
| 188 | Difficult | Rules to fall | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 208.05 | 435.48 |  |
| 189 | Difficult | DON`T PANIC | Oh No! More Lemmings / Crazy | 325.48 | 421.70 |  |
| 190 | Difficult | Lemmings Up High | Holiday Lemmings 1993 / Blizzard | 236.12 | 436.93 |  |
| 191 | Difficult | Plethora of Presents | Holiday Lemmings 1994 / Frost | 236.95 | 438.61 |  |
| 192 | Difficult | We all fall down | Lemmings / Fun | 157.63 | 453.02 |  |
| 193 | Difficult | PoP TiL YoU DrOp! | Oh No! More Lemmings / Wicked | 233.05 | 443.75 |  |
| 194 | Difficult | A Single Lemming... | Holiday Lemmings 1993 / Blizzard | 296.68 | 433.25 |  |
| 195 | Difficult | Ski Jump! | Holiday Lemmings 1994 / Frost | 170.09 | 450.25 |  |
| 196 | Difficult | Looks a Bit Nippy Out There | Oh No! More Lemmings / Havoc | 271.14 | 441.48 |  |
| 197 | Difficult | Every Lemming for himself!!! | Lemmings / Taxing | 360.25 | 427.43 |  |
| 198 | Difficult | Lemming about town | Oh No! More Lemmings / Havoc | 321.74 | 426.76 |  |
| 199 | Difficult | Haunted botanical garden | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 343.01 | 442.64 |  |
| 200 | Difficult | Five Alive | Oh No! More Lemmings / Wicked | 330.16 | 441.22 |  |
| 201 | Difficult | It's Boxing Day! | Holiday Lemmings 1994 / Frost | 357.30 | 444.75 |  |
| 202 | Difficult | And now, the end is near... | Oh No! More Lemmings / Crazy | 320.71 | 452.04 |  |
| 203 | Difficult | LeMming ToMato KetchUp fAcilitY | Oh No! More Lemmings / Wicked | 326.42 | 450.00 |  |
| 204 | Difficult | Undercover Lemming | Oh No! More Lemmings / Tame | 252.68 | 439.63 |  |
| 205 | Difficult | Hunt the Nessy.... | Lemmings / Taxing | 410.57 | 436.51 |  |
| 206 | Difficult | Postcard from Lemmingland | Lemmings / Tricky | 346.74 | 450.00 |  |
| 207 | Difficult | Just a Minute... | Lemmings / Mayhem | 312.01 | 454.90 |  |
| 208 | Difficult | There`s madness in the method | Oh No! More Lemmings / Havoc | 391.12 | 448.24 |  |
| 209 | Difficult | Intro to MCMarshy01.dat | MARSHY01 / fan:lldb-345 | 140.79 | 422.68 |  |
| 210 | Difficult | Rendezvous II | Holiday Lemmings 1994 / Hail | 410.10 | 450.50 |  |
| 211 | Difficult | Only climbers can do this | MARSHY01 / fan:lldb-345 | 149.82 | 422.98 |  |
| 212 | Difficult | Fun 13.lvl | Amiga Fun Budget / fan:lldb-568 | 152.63 | 425.70 |  |
| 213 | Difficult | Climbing all the way | ANTHPCK1 / fan:lldb-221 | 152.90 | 425.01 |  |
| 214 | Difficult | Tailor-made for floaters | MARSHY01 / fan:lldb-345 | 154.99 | 429.86 |  |
| 215 | Difficult | Weave Your Lemmings | TWPAK09 / fan:lldb-311 | 180.38 | 428.07 |  |
| 216 | Difficult | Training 02 - Let's Float! | JEFFPCK6 / fan:lldb-240 | 150.00 | 433.14 |  |
| 217 | Difficult | Tricky 02.lvl | Amiga Tricky Budget / fan:lldb-569 | 157.60 | 435.04 |  |
| 218 | Difficult | The Impossible Gap | MARSHY07 / fan:lldb-351 | 150.28 | 440.36 |  |
| 219 | Difficult | The Box. | isupck02 / fan:lldb-353 | 182.04 | 434.45 |  |
| 220 | Difficult | Classic lems find new home(Lem3) | Lemmy556 My little levels 2 / fan:lldb-66 | 160.73 | 441.23 |  |
| 221 | Difficult | Taxing 30.lvl | Amiga Taxing Budget / fan:lldb-570 | 161.55 | 444.39 |  |
| 222 | Difficult | Speed Freaks | Ji Hoons Lemmings Remake Earth / fan:lldb-549 | 160.10 | 442.74 |  |
| 223 | Difficult | Mayhem 11.lvl | Amiga Mayhem Budget / fan:lldb-571 | 165.06 | 453.74 |  |
| 224 | Difficult | FunnyTopia | KillerMasters Lemmings 1 Wicked / fan:lldb-508 | 211.14 | 447.37 |  |
| 225 | Difficult | Day by Day | JM01 / fan:lldb-327 | 234.15 | 445.23 |  |
| 226 | Difficult | Taxing 07.lvl | Amiga Taxing Budget / fan:lldb-570 | 362.47 | 427.88 |  |
| 227 | Difficult | Excavation Station | TWPAK00 / fan:lldb-302 | 265.20 | 421.90 |  |
| 228 | Difficult | Dig Down, Bash Across | PSP Special 1 10 of 36 / fan:lldb-216 | 283.70 | 429.10 |  |
| 229 | Difficult | Bashing & Building | Nepster01 / fan:lldb-219 | 375.11 | 424.82 |  |
| 230 | Difficult | Cyborglem Lab | KillerMasters Lemmings 1 Wild / fan:lldb-507 | 354.96 | 452.84 |  |
| 231 | Difficult | Dirt Runner | Nepster01 / fan:lldb-219 | 297.79 | 450.70 |  |
| 232 | Difficult | Snow Lev 1 | ANTHPCK4 / fan:lldb-224 | 225.57 | 454.90 |  |
| 233 | Difficult | Got anything....Lemmingy??? | Oh No! More Lemmings / Wild | 322.96 | 459.00 |  |
| 234 | Difficult | Lemmingdelica | Oh No! More Lemmings / Wild | 267.48 | 459.00 |  |
| 235 | Difficult | Dr Lemminggood | Oh No! More Lemmings / Wild | 252.87 | 459.00 |  |
| 236 | Difficult | Presents of Mind | Holiday Lemmings 1993 / Flurry | 337.94 | 459.00 |  |
| 237 | Difficult | Down the tube | Oh No! More Lemmings / Wicked | 327.06 | 459.00 |  |
| 238 | Difficult | Quest for Kieran | Holiday Lemmings 1994 / Frost | 288.50 | 459.00 |  |
| 239 | Difficult | Up, up, and away! | Holiday Lemmings 1994 / Hail | 305.48 | 459.00 |  |
| 240 | Difficult | Steel Ice Span | Holiday Lemmings 1994 / Hail | 308.87 | 459.00 |  |
| 241 | Difficult | Up, Down or Round and Round | Oh No! More Lemmings / Wicked | 242.67 | 456.73 |  |
| 242 | Difficult | 24 hour Lemathon | Oh No! More Lemmings / Crazy | 328.41 | 459.75 |  |
| 243 | Difficult | The Voyage Home... | Holiday Lemmings 1993 / Blizzard | 257.20 | 459.25 |  |
| 244 | Difficult | Inside the bone | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 330.59 | 456.65 |  |
| 245 | Difficult | This Corrosion | Oh No! More Lemmings / Wicked | 342.84 | 459.00 |  |
| 246 | Difficult | Marshmallow Land | Holiday Lemmings 1993 / Flurry | 346.80 | 459.00 |  |
| 247 | Difficult | Tailor-made for blockers | Lemmings / Fun | 188.60 | 486.10 |  |
| 248 | Difficult | A task for blockers and bombers | Lemmings / Fun | 129.82 | 486.10 |  |
| 249 | Difficult | The Steel Mines of Kessel | Lemmings / Mayhem | 212.48 | 486.10 |  |
| 250 | Difficult | Last Lemming To Lemmingcentral | Oh No! More Lemmings / Wicked | 190.08 | 486.10 |  |
| 251 | Difficult | Clouds of Lemmings | Holiday Lemmings 1993 / Flurry | 209.58 | 486.10 |  |
| 252 | Difficult | The Final Frontier | Holiday Lemmings 1993 / Blizzard | 275.78 | 486.10 |  |
| 253 | Difficult | Spiral staircase | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 278.68 | 486.10 |  |
| 254 | Difficult | The Land of the Bizarre | Holiday Lemmings 1994 / Frost | 271.80 | 486.10 |  |
| 255 | Difficult | Is this a circus? | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 239.53 | 480.77 |  |
| 256 | Difficult | With a twist of lemming please | Lemmings / Mayhem | 304.53 | 473.41 |  |
| 257 | Difficult | Evacuating a coal mine | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 331.06 | 456.32 |  |
| 258 | Difficult | Peak of Performance | Holiday Lemmings 1994 / Hail | 262.66 | 486.10 |  |
| 259 | Difficult | Down And Out Lemmings | Oh No! More Lemmings / Tame | 215.08 | 486.10 |  |
| 260 | Difficult | Walk the web rope | Lemmings / Taxing | 350.04 | 459.82 |  |
| 261 | Difficult | Lemming Tracks in the Snow! | Holiday Lemmings 1993 / Flurry | 239.12 | 486.10 |  |
| 262 | Difficult | This should be a doddle! | Lemmings / Tricky | 299.58 | 486.10 |  |
| 263 | Difficult | Call in the bomb squad | Lemmings / Taxing | 288.44 | 486.10 |  |
| 264 | Difficult | Maybe not such a doddle | Holiday Lemmings 1994 / Frost | 289.29 | 486.10 |  |
| 265 | Difficult | CindyLand | Holiday Lemmings 1994 / Frost | 298.86 | 486.10 |  |
| 266 | Difficult | How on Earth? | Oh No! More Lemmings / Wicked | 327.66 | 486.10 |  |
| 267 | Difficult | Rainbow Island | Lemmings / Tricky | 301.05 | 486.10 |  |
| 268 | Difficult | The Long Way Around | Holiday Lemmings 1993 / Flurry | 305.15 | 486.10 |  |
| 269 | Difficult | Tightrope City | Lemmings / Tricky | 264.39 | 486.10 |  |
| 270 | Difficult | Quote: "That`s a good level" | Oh No! More Lemmings / Crazy | 271.74 | 486.10 |  |
| 271 | Difficult | Break On Through | Holiday Lemmings 1994 / Hail | 292.72 | 486.10 |  |
| 272 | Difficult | Konbanwa Lemming san | Lemmings / Fun | 271.56 | 486.10 |  |
| 273 | Difficult | worra lorra lemmings | Lemmings / Fun | 240.62 | 486.10 |  |
| 274 | Difficult | As long as you try your best | Lemmings / Fun | 296.53 | 475.90 |  |
| 275 | Difficult | Here is Mr.Lemming's house | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 311.52 | 486.10 |  |
| 276 | Difficult | Down, along, up. In that order | Lemmings / Mayhem | 331.74 | 486.10 |  |
| 277 | Difficult | Steel Works | Lemmings / Mayhem | 333.15 | 486.10 |  |
| 278 | Difficult | Lend a helping hand.... | Lemmings / Taxing | 353.52 | 486.10 |  |
| 279 | Difficult | Lemming Head | Oh No! More Lemmings / Wild | 297.54 | 486.10 |  |
| 280 | Difficult | Be sure to be a builder. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 302.66 | 486.10 |  |
| 281 | Difficult | Suicidal Tendencies | Oh No! More Lemmings / Wicked | 318.35 | 486.10 |  |
| 282 | Difficult | Watch your step | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 308.23 | 486.10 |  |
| 283 | Difficult | Feel the heat! | Lemmings / Taxing | 346.04 | 486.10 |  |
| 284 | Difficult | Scaling the Heights | Oh No! More Lemmings / Havoc | 372.17 | 486.10 |  |
| 285 | Difficult | The Next Lemeration | Holiday Lemmings 1993 / Blizzard | 339.35 | 486.10 |  |
| 286 | Difficult | It`s hero time! | Lemmings / Mayhem | 373.02 | 486.10 |  |
| 287 | Difficult | HIGHLAND FLING | Oh No! More Lemmings / Havoc | 400.72 | 486.10 |  |
| 288 | Difficult | Curse of the Pharaohs | Lemmings / Mayhem | 314.49 | 486.10 |  |
| 289 | Difficult | ICE SPY | Oh No! More Lemmings / Wild | 398.26 | 474.61 |  |
| 290 | Difficult | Out, away from the tune | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 340.13 | 486.10 |  |
| 291 | Difficult | Cave quest | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 355.21 | 486.10 |  |
| 292 | Difficult | No added colours or Lemmings | Lemmings / Mayhem | 364.20 | 486.10 |  |
| 293 | Difficult | Come on over to my place | Lemmings / Taxing | 380.13 | 486.10 |  |
| 294 | Difficult | Temple of Love | Oh No! More Lemmings / Wicked | 408.92 | 486.10 |  |
| 295 | Difficult | Move on in two separate groups. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 421.14 | 486.10 |  |
| 296 | Difficult | Turn around young lemmings! (rm) | LEMREMAKE / fan:lldb-465 | 261.77 | 457.62 |  |
| 297 | Difficult | Just two minutes | JM06 / fan:lldb-332 | 160.02 | 477.84 |  |
| 298 | Difficult | Digger Conversions | Lemmings The Official Companion / fan:lldb-585 | 262.26 | 470.88 |  |
| 299 | Difficult | Merry Lemmings | Van Clan Tame / fan:lldb-99 | 149.84 | 486.10 |  |
| 300 | Difficult | Taxing 27.lvl | Amiga Taxing Budget / fan:lldb-570 | 290.54 | 486.10 |  |
| 301 | Difficult | Tricky 29.lvl | Amiga Tricky Budget / fan:lldb-569 | 301.11 | 486.10 |  |
| 302 | Difficult | Tricky 01.lvl | Amiga Tricky Budget / fan:lldb-569 | 303.50 | 486.10 |  |
| 303 | Difficult | Walk the web rope (part two) | Conway Challenges 1 / fan:lldb-263 | 352.96 | 459.82 |  |
| 304 | Difficult | Fun 29.lvl | Amiga Fun Budget / fan:lldb-568 | 240.62 | 486.10 |  |
| 305 | Difficult | Taxing 20.lvl | Amiga Taxing Budget / fan:lldb-570 | 350.36 | 459.82 |  |
| 306 | Difficult | Steel Works (part two) | Conway Challenges 1 / fan:lldb-263 | 335.49 | 486.10 |  |
| 307 | Difficult | Mayhem 05.lvl | Amiga Mayhem Budget / fan:lldb-571 | 331.74 | 486.10 |  |
| 308 | Difficult | Maybe would be a doddle! | CRISFN11 / fan:lldb-275 | 228.88 | 478.65 |  |
| 309 | Difficult | Dying Dream | Nepster01 / fan:lldb-219 | 228.62 | 486.10 |  |
| 310 | Difficult | Mayhem 03.lvl | Amiga Mayhem Budget / fan:lldb-571 | 373.02 | 486.10 |  |
| 311 | Difficult | Dunes | Nepster01 / fan:lldb-219 | 367.72 | 486.10 |  |
| 312 | Difficult | Mayhem 09.lvl | Amiga Mayhem Budget / fan:lldb-571 | 314.55 | 486.10 |  |
| 313 | Difficult | Mayhem 20.lvl | Amiga Mayhem Budget / fan:lldb-571 | 366.30 | 486.10 |  |
| 314 | Difficult | Broken Symmetry | Nepster01 / fan:lldb-219 | 371.03 | 486.10 |  |
| 315 | Difficult | Taxing 22.lvl | Amiga Taxing Budget / fan:lldb-570 | 388.01 | 486.10 |  |
| 316 | Difficult | Time Gate | Nepster01 / fan:lldb-219 | 429.32 | 486.10 |  |
| 317 | Difficult | ROCKY VI | Oh No! More Lemmings / Crazy | 310.79 | 496.93 |  |
| 318 | Difficult | NO PROBLEM | Oh No! More Lemmings / Crazy | 388.48 | 490.03 |  |
| 319 | Difficult | Santus Lemmingus | Holiday Lemmings 1993 / Blizzard | 345.95 | 493.03 |  |
| 320 | Difficult | DIGGING FOR VICTORY | Oh No! More Lemmings / Crazy | 396.34 | 492.20 |  |
| 321 | Difficult | Mutiny On The Bounty | Oh No! More Lemmings / Wild | 329.91 | 514.25 |  |
| 322 | Difficult | Almost Nearly Virtual Reality | Oh No! More Lemmings / Wicked | 305.60 | 514.25 |  |
| 323 | Difficult | The Chain with no name | Oh No! More Lemmings / Wild | 315.68 | 514.25 |  |
| 324 | Difficult | Oh No! It`s the 4TH DIMENSION! | Oh No! More Lemmings / Wicked | 332.18 | 514.25 |  |
| 325 | Difficult | On the Antarctic Coast | Oh No! More Lemmings / Crazy | 362.75 | 514.25 |  |
| 326 | Difficult | All or Nothing | Lemmings / Mayhem | 265.22 | 495.84 |  |
| 327 | Difficult | Ozone friendly Lemmings | Lemmings / Tricky | 194.92 | 495.84 |  |
| 328 | Difficult | Break on through... | Holiday Lemmings 1993 / Blizzard | 297.68 | 518.74 |  |
| 329 | Difficult | Check Your Hints! | Holiday Lemmings 1993 / Blizzard | 297.28 | 510.53 |  |
| 330 | Difficult | The Lemming Funhouse | Oh No! More Lemmings / Wicked | 448.11 | 518.74 |  |
| 331 | Difficult | PoP YoR ToP!!! | Oh No! More Lemmings / Wild | 329.66 | 514.25 |  |
| 332 | Difficult | Up on the Rooftops | Holiday Lemmings 1994 / Frost | 412.84 | 514.25 |  |
| 333 | Difficult | The Stack | Oh No! More Lemmings / Crazy | 429.63 | 490.04 |  |
| 334 | Difficult | The gate trap Lemmings. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 425.62 | 503.58 |  |
| 335 | Difficult | Libra | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 287.44 | 508.18 |  |
| 336 | Difficult | Sir Edmund Hilemming | Holiday Lemmings 1994 / Hail | 423.19 | 514.25 |  |
| 337 | Difficult | Welcome to the party, pal! | Oh No! More Lemmings / Havoc | 366.96 | 514.25 |  |
| 338 | Difficult | LoTs moRe wHeRe TheY caMe fRom | Oh No! More Lemmings / Wicked | 423.90 | 514.25 |  |
| 339 | Difficult | Inroducing SUPERLEMMING | Oh No! More Lemmings / Wicked | 366.73 | 509.60 |  |
| 340 | Difficult | Stray sheep | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 352.12 | 516.96 |  |
| 341 | Difficult | Cascade | Lemmings / Tricky | 407.80 | 515.82 |  |
| 342 | Difficult | Be more than just a number | Oh No! More Lemmings / Havoc | 435.18 | 514.25 |  |
| 343 | Difficult | ROCKY ROAD | Oh No! More Lemmings / Wicked | 413.29 | 521.98 |  |
| 344 | Difficult | The Funeral | MATTPCK2 / fan:lldb-249 | 269.10 | 510.53 |  |
| 345 | Difficult | What exit? | JM11 / fan:lldb-337 | 300.59 | 510.53 |  |
| 346 | Difficult | Don't settle for anything less | Conway Challenges 1 / fan:lldb-263 | 425.93 | 515.82 |  |
| 347 | Difficult | The Cascade: Part II | Modlvls / fan:lldb-357 | 422.21 | 515.82 |  |
| 348 | Difficult | Tricky 25.lvl | Amiga Tricky Budget / fan:lldb-569 | 407.21 | 515.82 |  |
| 349 | Difficult | Doomsday | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 321.34 | 536.48 |  |
| 350 | Difficult | Happy New Year! | Holiday Lemmings 1994 / Frost | 415.14 | 529.82 |  |
| 351 | Difficult | SPAM,SPAM,SPAM,EGG AND LEMMING | Oh No! More Lemmings / Wicked | 414.48 | 540.00 |  |
| 352 | Difficult | A ladder would be handy | Lemmings / Tricky | 394.92 | 540.00 |  |
| 353 | Difficult | Lemming Productions Present... | Oh No! More Lemmings / Tame | 424.90 | 540.00 |  |
| 354 | Difficult | How do I dig up the way? | Lemmings / Taxing | 419.20 | 540.00 |  |
| 355 | Difficult | Have a nice day! | Lemmings / Mayhem | 449.58 | 540.00 |  |
| 356 | Difficult | One way digging to freedom | Lemmings / Tricky | 368.42 | 549.40 |  |
| 357 | Difficult | Merry Christmaze | Holiday Lemmings 1994 / Hail | 286.14 | 552.13 |  |
| 358 | Difficult | Save 'em First... | JEFFPCK7 / fan:lldb-241 | 392.18 | 544.00 |  |
| 359 | Difficult | A ladder would be handy (Part2) | JM01 / fan:lldb-327 | 403.50 | 540.00 |  |
| 360 | Difficult | Tricky 20.lvl | Amiga Tricky Budget / fan:lldb-569 | 368.98 | 549.40 |  |
| 361 | Difficult | The hunt is on! | QBeez03 / fan:lldb-33 | 453.53 | 540.00 |  |
| 362 | Difficult | Level 02.lvl | Amiga Demo / fan:lldb-581 | 366.88 | 549.40 |  |
| 363 | Difficult | Tricky 03.lvl | Amiga Tricky Budget / fan:lldb-569 | 394.92 | 540.00 |  |
| 364 | Difficult | FlameBungee | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 403.07 | 554.90 |  |
| 365 | Difficult | Taxing 29.lvl | Amiga Taxing Budget / fan:lldb-570 | 419.20 | 540.00 |  |
| 366 | Difficult | Climb and Float | brickpk1 / fan:lldb-558 | 372.72 | 554.90 |  |
| 367 | Difficult | Just a random heap of junk! | Nepster01 / fan:lldb-219 | 454.46 | 556.53 |  |
| 368 | Difficult | Splunk n' country | Epic Giga03 / fan:lldb-141 | 434.15 | 546.48 |  |
| 369 | Difficult | A Beast of a level | Lemmings / Fun | 325.32 | 564.18 |  |
| 370 | Difficult | Time waits for no Lemming | Oh No! More Lemmings / Crazy | 397.45 | 569.50 |  |
| 371 | Difficult | Water processing plant | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 431.98 | 569.50 |  |
| 372 | Difficult | Just a minute (Part Three) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 446.95 | 569.50 |  |
| 373 | Difficult | It`s the price you have to pay | Oh No! More Lemmings / Havoc | 452.11 | 569.50 |  |
| 374 | Difficult | Emmings!  (No L) | Holiday Lemmings 1994 / Hail | 479.42 | 569.50 |  |
| 375 | Difficult | Lemming Rhythms | Oh No! More Lemmings / Wild | 394.96 | 581.48 |  |
| 376 | Difficult | X marks the spot | Lemmings / Taxing | 443.60 | 592.94 |  |
| 377 | Difficult | Lemming Playground | Nepster01 / fan:lldb-219 | 406.42 | 585.56 |  |
| 378 | Difficult | Taxing 17.lvl | Amiga Taxing Budget / fan:lldb-570 | 443.60 | 592.94 |  |
| 379 | Difficult | Simply Smashing | Epic Giga03 / fan:lldb-141 | 514.30 | 569.50 |  |
| 380 | Difficult | Patience | Lemmings / Fun | 421.98 | 595.98 |  |
| 381 | Difficult | Take care, Sweetie | Oh No! More Lemmings / Wild | 338.92 | 598.88 |  |
| 382 | Difficult | Compression Method 1 | Lemmings / Taxing | 318.21 | 598.88 |  |
| 383 | Difficult | Go Thataway! | Holiday Lemmings 1994 / Hail | 441.67 | 598.88 |  |
| 384 | Difficult | Four Play | Holiday Lemmings 1994 / Frost | 550.15 | 598.88 |  |
| 385 | Difficult | Fall and no life (Part Two) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 513.76 | 595.48 |  |
| 386 | Difficult | With A Little Help From... | Yawg02 / fan:lldb-85 | 297.60 | 598.88 |  |
| 387 | Difficult | Again & Again | JM03 / fan:lldb-329 | 321.01 | 598.88 |  |
| 388 | Difficult | Hard when you don't know how | MARSHY02 / fan:lldb-346 | 317.22 | 598.88 |  |
| 389 | Difficult | Puzzle Time.ini | grams88 / fan:lldb-416 | 327.09 | 598.88 |  |
| 390 | Expert | It`s all a matter of timing | Oh No! More Lemmings / Havoc | 299.52 | 603.50 |  |
| 391 | Expert | The Search for Lem | Holiday Lemmings 1993 / Blizzard | 443.10 | 624.75 |  |
| 392 | Expert | KEEP ON TRUCKING | Oh No! More Lemmings / Crazy | 434.90 | 624.75 |  |
| 393 | Expert | Polar Expedition | Holiday Lemmings 1994 / Hail | 467.57 | 624.75 |  |
| 394 | Expert | Where Lemmings Dare | Oh No! More Lemmings / Havoc | 497.36 | 624.75 |  |
| 395 | Expert | THE SILENCE OF THE LEMMINGS | Oh No! More Lemmings / Wild | 481.37 | 624.75 |  |
| 396 | Expert | SUNSOFT Special | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 389.00 | 600.61 |  |
| 397 | Expert | Who`s That Lemming | Oh No! More Lemmings / Tame | 373.34 | 606.82 |  |
| 398 | Expert | The Prison! | Lemmings / Taxing | 349.20 | 623.68 |  |
| 399 | Expert | Tubular Lemmings | Oh No! More Lemmings / Havoc | 481.59 | 602.03 |  |
| 400 | Expert | Upsidedown World | Lemmings / Taxing | 423.24 | 611.11 |  |
| 401 | Expert | Just A Quicky | Oh No! More Lemmings / Wild | 439.03 | 611.11 |  |
| 402 | Expert | Taxing 13.lvl | Amiga Taxing Budget / fan:lldb-570 | 426.05 | 611.11 |  |
| 403 | Expert | Taxing 05.lvl | Amiga Taxing Budget / fan:lldb-570 | 351.30 | 623.68 |  |
| 404 | Expert | C'mon everybody body | Giga pack 08 / fan:lldb-170 | 484.29 | 607.81 |  |
| 405 | Expert | Don't bash the wall | JM10 / fan:lldb-336 | 444.42 | 629.00 |  |
| 406 | Expert | Not just a pretty Lemming | Oh No! More Lemmings / Tame | 468.85 | 630.00 |  |
| 407 | Expert | There's a lot of them about | Lemmings / Tricky | 446.37 | 663.00 |  |
| 408 | Expert | Save Me | Lemmings / Mayhem | 393.27 | 646.46 |  |
| 409 | Expert | It`s a tight fit! | Oh No! More Lemmings / Wild | 442.87 | 656.96 |  |
| 410 | Expert | ONWARD AND UPWARD | Oh No! More Lemmings / Wild | 507.97 | 658.48 |  |
| 411 | Expert | Creature Discomforts | Oh No! More Lemmings / Havoc | 517.87 | 655.94 |  |
| 412 | Expert | Back in Hell | JMGM01 / fan:lldb-454 | 239.66 | 637.50 |  |
| 413 | Expert | Tricky 10.lvl | Amiga Tricky Budget / fan:lldb-569 | 450.92 | 663.00 |  |
| 414 | Expert | Crazy stairs | Giga pack 07 / fan:lldb-169 | 417.88 | 658.51 |  |
| 415 | Expert | And now this... | Oh No! More Lemmings / Tame | 396.84 | 673.32 |  |
| 416 | Expert | I have a cunning plan | Lemmings / Tricky | 416.66 | 672.48 |  |
| 417 | Expert | Origins and Lemmings | Lemmings / Fun | 501.55 | 667.72 |  |
| 418 | Expert | Snuggle up to a Lemming | Oh No! More Lemmings / Tame | 480.11 | 673.32 |  |
| 419 | Expert | Oogilemming! | Holiday Lemmings 1993 / Blizzard | 497.20 | 680.00 |  |
| 420 | Expert | Lemmings in a situation | Oh No! More Lemmings / Havoc | 457.29 | 680.30 |  |
| 421 | Expert | Get the Point? | Holiday Lemmings 1994 / Hail | 553.20 | 688.50 |  |
| 422 | Expert | Tricky 26.lvl | Amiga Tricky Budget / fan:lldb-569 | 418.76 | 672.48 |  |
| 423 | Expert | The Far Side | Lemmings / Mayhem | 417.09 | 700.00 |  |
| 424 | Expert | Last one out is a rotten egg! | Lemmings / Mayhem | 398.22 | 700.00 |  |
| 425 | Expert | Christmas Bonus | Xmas Lemmings 1991 / Xmas | 364.92 | 700.00 |  |
| 426 | Expert | And a Happy New Year! | Holiday Lemmings 1994 / Hail | 382.54 | 700.00 |  |
| 427 | Expert | Merry Christmas Mr Lemming | Xmas Lemmings 1991 / Xmas | 385.80 | 700.00 |  |
| 428 | Expert | Lemmings...The Motion Picture | Holiday Lemmings 1993 / Blizzard | 398.87 | 700.00 |  |
| 429 | Expert | They just keep on coming | Lemmings / Tricky | 361.83 | 700.00 |  |
| 430 | Expert | Lemmingology | Lemmings / Tricky | 381.74 | 700.00 |  |
| 431 | Expert | All the 6`s ........ | Lemmings / Tricky | 374.38 | 700.00 |  |
| 432 | Expert | Nightmare on Lem street | Lemmings / Fun | 365.98 | 700.00 |  |
| 433 | Expert | I've lost that Lemming feeling | Lemmings / Fun | 356.12 | 700.00 |  |
| 434 | Expert | The Island of the Wicker people | Lemmings / Tricky | 413.26 | 700.00 |  |
| 435 | Expert | One way or another | Lemmings / Mayhem | 397.09 | 700.00 |  |
| 436 | Expert | Izzie Wizzie lemmings get busy | Lemmings / Taxing | 434.67 | 700.00 |  |
| 437 | Expert | Stepping Stones | Lemmings / Mayhem | 457.22 | 700.00 |  |
| 438 | Expert | POOR WEE CREATURES! | Lemmings / Taxing | 460.80 | 700.00 |  |
| 439 | Expert | Here's one I prepared earlier | Lemmings / Tricky | 426.91 | 700.00 |  |
| 440 | Expert | Lemming Drops | Lemmings / Tricky | 418.77 | 700.00 |  |
| 441 | Expert | Don't let your eyes deceive you | Lemmings / Fun | 488.66 | 700.00 |  |
| 442 | Expert | A Lemming Holiday | Xmas Lemmings 1992 / Xmas | 426.15 | 700.00 |  |
| 443 | Expert | From The Boundary Line | Lemmings / Tricky | 518.09 | 700.00 |  |
| 444 | Expert | The Needs of the Many... | Holiday Lemmings 1993 / Blizzard | 479.80 | 700.00 |  |
| 445 | Expert | Watch out, there`s traps about | Lemmings / Taxing | 537.81 | 700.00 |  |
| 446 | Expert | The ascending pillar scenario | Lemmings / Taxing | 506.15 | 700.00 |  |
| 447 | Expert | Pillars of Hercules | Lemmings / Mayhem | 554.17 | 700.00 |  |
| 448 | Expert | The Crankshaft | Lemmings / Tricky | 537.25 | 700.00 |  |
| 449 | Expert | Been there, seen it, done it | Lemmings / Tricky | 536.62 | 700.00 |  |
| 450 | Expert | Heaven can wait (we hope!!!!) | Lemmings / Taxing | 281.82 | 722.50 |  |
| 451 | Expert | The Fast Food Kitchen... | Lemmings / Mayhem | 562.66 | 700.00 |  |
| 452 | Expert | Rendezvous at the Mountain | Lemmings / Mayhem | 536.15 | 700.00 |  |
| 453 | Expert | Chill out! | Oh No! More Lemmings / Wicked | 558.37 | 700.00 |  |
| 454 | Expert | Feel the pain | joem5 / fan:lldb-320 | 411.24 | 700.00 |  |
| 455 | Expert | Let's get it Started | Deceits Lemmings Extras / fan:lldb-546 | 389.70 | 700.00 |  |
| 456 | Expert | These walls | JMGM02 / fan:lldb-455 | 371.57 | 700.00 |  |
| 457 | Expert | Tricky 27.lvl | Amiga Tricky Budget / fan:lldb-569 | 415.36 | 700.00 |  |
| 458 | Expert | Mayhem 08.lvl | Amiga Mayhem Budget / fan:lldb-571 | 400.32 | 700.00 |  |
| 459 | Expert | DO NOT ENTER | QBeez03 / fan:lldb-33 | 422.09 | 700.00 |  |
| 460 | Expert | Do the Lemmys way! | Lemmy556 My little levels / fan:lldb-65 | 457.22 | 700.00 |  |
| 461 | Expert | Taxing 28.lvl | Amiga Taxing Budget / fan:lldb-570 | 461.25 | 700.00 |  |
| 462 | Expert | From The Boundary Line part two | Conway Challenges 1 / fan:lldb-263 | 444.11 | 700.00 |  |
| 463 | Expert | Tricky 04.lvl | Amiga Tricky Budget / fan:lldb-569 | 429.01 | 700.00 |  |
| 464 | Expert | Fun 15.lvl | Amiga Fun Budget / fan:lldb-568 | 495.68 | 700.00 |  |
| 465 | Expert | In And Out | TimpackD / fan:lldb-102 | 503.74 | 700.00 |  |
| 466 | Expert | Tricky 30.lvl | Amiga Tricky Budget / fan:lldb-569 | 537.25 | 700.00 |  |
| 467 | Expert | Tricky 07.lvl | Amiga Tricky Budget / fan:lldb-569 | 538.72 | 700.00 |  |
| 468 | Expert | Lemmings Get Lost in Afterlife | ssam1221s Lemmings Wicked / fan:lldb-515 | 273.42 | 722.50 |  |
| 469 | Expert | Taxing 03.lvl | Amiga Taxing Budget / fan:lldb-570 | 283.92 | 722.50 |  |
| 470 | Expert | Travelling Lemmings | Nepster01 / fan:lldb-219 | 575.09 | 700.00 |  |
| 471 | Expert | Tricky 23.lvl | Amiga Tricky Budget / fan:lldb-569 | 518.09 | 700.00 |  |
| 472 | Expert | Devil's Right Hand | Nepster01 / fan:lldb-219 | 533.39 | 700.00 |  |
| 473 | Expert | Taxing 11.lvl | Amiga Taxing Budget / fan:lldb-570 | 508.25 | 700.00 |  |
| 474 | Expert | Taxing 02.lvl | Amiga Taxing Budget / fan:lldb-570 | 537.81 | 700.00 |  |
| 475 | Expert | flag test map | Orig Extra Levels / fan:lldb-407 | 516.37 | 700.00 |  |
| 476 | Expert | The Green Mile | Van Clan Tame / fan:lldb-99 | 561.42 | 700.00 |  |
| 477 | Expert | AAAAAARRRRRRGGGGGGHHHHHH!!!!!! | Oh No! More Lemmings / Havoc | 477.17 | 748.00 |  |
| 478 | Expert | It Came Upon a Lemnight Clear | Holiday Lemmings 1993 / Blizzard | 557.79 | 735.25 |  |
| 479 | Expert | Head for the Hills! | Holiday Lemmings 1993 / Flurry | 270.77 | 781.15 | Review |
| 480 | Expert | Now get out of that! | Oh No! More Lemmings / Havoc | 293.69 | 785.88 |  |
| 481 | Expert | The race against cliches | Oh No! More Lemmings / Havoc | 433.13 | 776.14 |  |
| 482 | Expert | MENACING !! | Lemmings / Tricky | 565.10 | 803.25 |  |
| 483 | Expert | Firestorm | GARJEN04 / fan:lldb-284 | 431.34 | 773.50 |  |
| 484 | Expert | Synchronised Lemming | Oh No! More Lemmings / Havoc | 565.10 | 816.00 |  |
| 485 | Expert | And then there were four.... | Lemmings / Mayhem | 569.32 | 816.00 |  |
| 486 | Expert | Mayhem 18.lvl | Amiga Mayhem Budget / fan:lldb-571 | 572.62 | 816.00 |  |
| 487 | Expert | Happy New Year II! | Holiday Lemmings 1994 / Frost | 441.86 | 843.48 |  |
| 488 | Expert | Lemmintaschen? | Holiday Lemmings 1994 / Hail | 474.65 | 843.48 |  |
| 489 | Expert | Keep your hair on Mr. Lemming | Lemmings / Fun | 427.47 | 850.00 |  |
| 490 | Expert | A BeastII of a level | Lemmings / Mayhem | 450.37 | 850.00 |  |
| 491 | Expert | Don't do anything too hasty | Lemmings / Fun | 442.35 | 850.00 |  |
| 492 | Expert | Across The Gap | Oh No! More Lemmings / Crazy | 555.35 | 850.00 |  |
| 493 | Expert | Tailor-made for Athletes | JEFFPCK1 / fan:lldb-235 | 479.06 | 850.00 |  |
| 494 | Expert | Swallowing method 1 | Lemmings platinum Fragle part 2 / fan:lldb-181 | 553.79 | 850.00 |  |
| 495 | Expert | Sudenly lemming | Lemmings platinum Careful Part 1 / fan:lldb-188 | 543.92 | 850.00 |  |
| 496 | Expert | Oscillating Lemmings | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 466.96 | 850.00 |  |
| 497 | Expert | It Takes Two To Tango | Van Clan Tame / fan:lldb-99 | 576.36 | 850.00 |  |
| 498 | Expert | This is a doddle | JM09 / fan:lldb-335 | 543.20 | 850.00 |  |
| 499 | Expert | Floaters Away! | cLemmings Tricky / fan:lldb-527 | 589.55 | 850.00 |  |
| 500 | Expert | Double Lemmings | KillerMasters Lemmings 2 Tame / fan:lldb-510 | 631.46 | 850.00 |  |
| 501 | Expert | Free Lemmings | Oh No More cLemmings Tame / fan:lldb-530 | 620.59 | 850.00 |  |
| 502 | Expert | Be Careful... | Lemmings Plus DOS Project Mild / fan:lldb-551 | 583.08 | 850.00 |  |
| 503 | Expert | The Graveyard | Lemmings Plus DOS Project Mild / fan:lldb-551 | 633.39 | 850.00 |  |
| 504 | Expert | Remember where you find them! | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 659.90 | 850.00 |  |
