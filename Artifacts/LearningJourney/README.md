# Oh My! All Lemmings!

503 distinct single-player levels: 317 official puzzles and 186 replay-validated library levels from 79 packs.

## Ordering

The path progresses through Fun, Intermediate, Difficult and Expert. A hard timing, coordination or planning demand cannot be cancelled by easy dimensions in a weighted average. Official levels take priority within comparable demand bands. Retail rank and campaign order do not determine placement. All Oh No! levels are interleaved with the rest of the pool.

Stages: Fun 29; Intermediate 89; Difficult 270; Expert 115. Largest upward curriculum-demand step: 55.25/1000. Transitions requiring review: 2; missing basic-skill preparation: 0.

| Stage | Steps | Teaching focus |
| --- | ---: | --- |
| Fun | 1–29 | Single skills and simple combinations |
| Intermediate | 30–118 | Skill combinations and crowd management |
| Difficult | 119–388 | Longer plans and tighter resources |
| Expert | 389–503 | Precision, complex plans and coordination |

Curriculum demand is the maximum of the unchanged evidence score, 0.85 × technique, precision, concurrency and deduction, 0.70 × solution complexity, 0.50 × constraints, and 90 × additional concepts. A combination also waits for its easiest available isolated skill lessons. These weights and the stage thresholds (180, 360, 600) are editorial estimates, not player-calibrated difficulty measurements.

Within each stage, 35-point bands allow spaced practice and small relief steps. Selection favours prepared combinations, avoids consecutive identical technique sets when comparable alternatives exist, and reduces upward component changes. Two-skill combinations require one earlier exposure per basic skill; larger combinations seek two. Exposure means a practice opportunity, not demonstrated mastery. New coordination and crowd-spacing concepts can be introduced through familiar skills.

Raw evidence scores remain unchanged and are reported separately. Their largest upward step is 291.17, with 229 decreases. The curriculum demand does not certify every component transition as smooth; all component changes and support flags are retained in transitions.json.

Oh No! has all 100 levels in the shared path. Its original largest raw-score jump was 348.77; its largest incoming raw-score jump here is 150.83. This is a diagnostic, not the sequencing objective.

The score uses validated solution techniques, solution complexity, timing perturbations, concurrent workers, constraints and a deduction proxy. It is an estimate of human difficulty, not direct measurement of insight. A winning route proves solvability; a low score does not prove that its solution is obvious. Unresolved component jumps stay visible in the report.

## Remaining transition reviews

- Step 19, **Thunder-Lemmings are go!** (Fun): new execution-demand high rises by 176.7/1000. Check timing forgiveness with a novice before calling this transition smooth.
- Step 478, **Head for the Hills!** (Expert): new execution-demand high rises by 214.4/1000. Check timing forgiveness with a novice before calling this transition smooth.

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
| 12 | Fun | Just Climb Mountain! | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 67.43 | 118.49 |  |
| 13 | Fun | Digging Only | joem7 / fan:lldb-322 | 62.54 | 121.74 |  |
| 14 | Fun | The Wall Trilogy Part 1 | TWPAK03 / fan:lldb-305 | 68.31 | 121.88 |  |
| 15 | Fun | Step By Step Guide To Building | Van Clan Tame / fan:lldb-88 | 71.46 | 131.07 |  |
| 16 | Fun | Bash This! | Van Clan Tame / fan:lldb-88 | 73.91 | 136.96 |  |
| 17 | Fun | Lemmings For Presidents! | Oh No! More Lemmings / Tame | 114.93 | 147.32 |  |
| 18 | Fun | Holiday Mining | Holiday Lemmings 1993 / Flurry | 71.37 | 144.50 |  |
| 19 | Fun | Thunder-Lemmings are go! | Oh No! More Lemmings / Tame | 151.62 | 151.62 | Review |
| 20 | Fun | Citizen Lemming | Oh No! More Lemmings / Tame | 80.86 | 144.50 |  |
| 21 | Fun | Everyone turn left (Part two) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 86.77 | 164.32 |  |
| 22 | Fun | Lemmings Lemmings everywhere | Lemmings / Fun | 71.79 | 144.50 |  |
| 23 | Fun | Get a little extra help | Oh No! More Lemmings / Tame | 120.08 | 170.39 |  |
| 24 | Fun | Floating Lemming Flurry | Holiday Lemmings 1993 / Flurry | 146.74 | 170.46 |  |
| 25 | Fun | Fun 25.lvl | Amiga Fun Budget / fan:lldb-568 | 71.79 | 144.50 |  |
| 26 | Fun | Frostbite | Van Clan Tame / fan:lldb-99 | 69.26 | 170.00 |  |
| 27 | Fun | Floating Down! | Holiday cLemmings Frost / fan:lldb-535 | 81.34 | 170.47 |  |
| 28 | Fun | Pollution | JM01 / fan:lldb-327 | 80.99 | 170.00 |  |
| 29 | Fun | Bomboozal | Lemmings / Taxing | 83.79 | 179.28 |  |
| 30 | Intermediate | Lost something? | Lemmings / Tricky | 148.88 | 180.00 |  |
| 31 | Intermediate | Lemming Snowfall | Holiday Lemmings 1993 / Flurry | 141.84 | 187.00 |  |
| 32 | Intermediate | At Home in a Cave | Holiday Lemmings 1993 / Flurry | 142.14 | 196.20 |  |
| 33 | Intermediate | Pea Soup | Lemmings / Mayhem | 98.34 | 202.99 |  |
| 34 | Intermediate | Custom built for Lemmings | Oh No! More Lemmings / Tame | 166.54 | 189.12 |  |
| 35 | Intermediate | The Undiscovered Country | Holiday Lemmings 1993 / Blizzard | 159.71 | 204.53 |  |
| 36 | Intermediate | Not as complicated as it looks | Lemmings / Fun | 149.97 | 209.58 |  |
| 37 | Intermediate | Tricky 28.lvl | Amiga Tricky Budget / fan:lldb-569 | 149.33 | 180.00 |  |
| 38 | Intermediate | Alternate Route | Lemmings The Official Companion / fan:lldb-585 | 138.48 | 202.49 |  |
| 39 | Intermediate | 5 miles if you love Lemmings | Genesis Fun / fan:lldb-488 | 154.07 | 204.53 |  |
| 40 | Intermediate | Jingle Lemming | Xmas Lemmings 1992 / Xmas | 109.70 | 233.75 |  |
| 41 | Intermediate | Division Bell | Holiday Lemmings 1994 / Frost | 96.03 | 212.84 |  |
| 42 | Intermediate | Lemming sanctuary in sight | Lemmings / Tricky | 146.54 | 221.00 |  |
| 43 | Intermediate | Mind the step..... | Lemmings / Mayhem | 199.18 | 210.70 |  |
| 44 | Intermediate | King of the castle | Lemmings / Taxing | 170.33 | 221.00 |  |
| 45 | Intermediate | Christmas South of the Equator | Holiday Lemmings 1993 / Flurry | 124.08 | 233.75 |  |
| 46 | Intermediate | Intsy-Wintsy...Lemming? | Oh No! More Lemmings / Tame | 132.74 | 233.75 |  |
| 47 | Intermediate | Honey, I Saved The Lemmings | Oh No! More Lemmings / Tame | 132.06 | 233.75 |  |
| 48 | Intermediate | What an AWESOME level | Lemmings / Taxing | 184.84 | 221.00 |  |
| 49 | Intermediate | You Live and Lem | Lemmings / Fun | 202.83 | 228.08 |  |
| 50 | Intermediate | Builders will help you here | Lemmings / Fun | 155.98 | 221.00 |  |
| 51 | Intermediate | Mayhem 28.lvl | Amiga Mayhem Budget / fan:lldb-571 | 199.18 | 210.70 |  |
| 52 | Intermediate | Fun 08.lvl | Amiga Fun Budget / fan:lldb-568 | 153.08 | 212.50 |  |
| 53 | Intermediate | King of the castle (part two) | Conway Challenges 1 / fan:lldb-263 | 171.50 | 221.00 |  |
| 54 | Intermediate | Fun 21.lvl | Amiga Fun Budget / fan:lldb-568 | 202.83 | 228.08 |  |
| 55 | Intermediate | Tricky 08.lvl | Amiga Tricky Budget / fan:lldb-569 | 148.92 | 221.00 |  |
| 56 | Intermediate | Taxing 23.lvl | Amiga Taxing Budget / fan:lldb-570 | 172.88 | 221.00 |  |
| 57 | Intermediate | Taxing 15.lvl | Amiga Taxing Book Club / fan:lldb-570 | 184.84 | 221.00 |  |
| 58 | Intermediate | Take good care of my Lemmings | Lemmings / Fun | 190.08 | 276.25 |  |
| 59 | Intermediate | Just a Minute (Part Two) | Lemmings / Mayhem | 212.30 | 262.32 |  |
| 60 | Intermediate | Let's go camping. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 211.40 | 275.93 |  |
| 61 | Intermediate | 32 Lemmings Below Zero | Holiday Lemmings 1993 / Flurry | 181.88 | 263.56 |  |
| 62 | Intermediate | If only they could fly | Lemmings / Fun | 198.34 | 270.56 |  |
| 63 | Intermediate | Careless clicking costs lives | Lemmings / Tricky | 190.58 | 276.25 |  |
| 64 | Intermediate | No Problemming! | Oh No! More Lemmings / Crazy | 260.16 | 276.25 |  |
| 65 | Intermediate | The Art Gallery | Lemmings / Taxing | 226.89 | 276.25 |  |
| 66 | Intermediate | Turn around young lemmings! | Lemmings / Tricky | 180.25 | 277.23 |  |
| 67 | Intermediate | Steel Block Party | Holiday Lemmings 1994 / Hail | 204.01 | 273.99 |  |
| 68 | Intermediate | Follow the leader... | Lemmings / Taxing | 215.15 | 276.25 |  |
| 69 | Intermediate | Choose Your Solution | SeverSet1 / fan:lldb-183 | 162.68 | 265.73 |  |
| 70 | Intermediate | Fun 19.lvl | Amiga Fun Budget / fan:lldb-568 | 190.08 | 276.25 |  |
| 71 | Intermediate | Fun 28.lvl | Amiga Fun Budget / fan:lldb-568 | 198.34 | 270.56 |  |
| 72 | Intermediate | Lemm Of All Trades | TWPAK12 / fan:lldb-314 | 195.52 | 273.00 |  |
| 73 | Intermediate | Taxing 25.lvl | Amiga Taxing Budget / fan:lldb-570 | 215.15 | 276.25 |  |
| 74 | Intermediate | Lemming Friendly | Oh No! More Lemmings / Crazy | 253.66 | 281.05 |  |
| 75 | Intermediate | Chains of Command | Holiday Lemmings 1994 / Frost | 160.98 | 296.56 |  |
| 76 | Intermediate | Many Lemmings make level work | Oh No! More Lemmings / Crazy | 149.29 | 303.69 |  |
| 77 | Intermediate | Take a running jump..... | Lemmings / Taxing | 244.56 | 301.05 |  |
| 78 | Intermediate | Lemming Snowjourn | Holiday Lemmings 1993 / Flurry | 189.31 | 306.00 |  |
| 79 | Intermediate | Turn around and look. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 218.50 | 306.00 |  |
| 80 | Intermediate | Yo-yo Lem-lem | Holiday Lemmings 1993 / Flurry | 246.94 | 308.30 |  |
| 81 | Intermediate | Ice Ice Lemming | Oh No! More Lemmings / Crazy | 262.47 | 303.83 |  |
| 82 | Intermediate | Smile if you love lemmings | Lemmings / Fun | 234.36 | 308.71 |  |
| 83 | Intermediate | Taxing 24.lvl | Amiga Taxing Budget / fan:lldb-570 | 245.36 | 301.05 |  |
| 84 | Intermediate | Tricky 22.lvl | Amiga Tricky Budget / fan:lldb-569 | 183.36 | 281.11 |  |
| 85 | Intermediate | Float and Dig | brickpk1 / fan:lldb-558 | 173.52 | 293.04 |  |
| 86 | Intermediate | The Iron Puzzle | TimballistoPack1 / fan:lldb-354 | 297.58 | 297.58 |  |
| 87 | Intermediate | Fun 09.lvl | Amiga Fun Budget / fan:lldb-568 | 247.06 | 308.51 |  |
| 88 | Intermediate | Only floaters can survive this | Lemmings / Fun | 121.12 | 322.05 |  |
| 89 | Intermediate | Lemming Express | Oh No! More Lemmings / Crazy | 182.04 | 317.75 |  |
| 90 | Intermediate | I am A.T. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 232.62 | 331.74 |  |
| 91 | Intermediate | Meeting Adjourned | Oh No! More Lemmings / Wild | 269.12 | 331.50 |  |
| 92 | Intermediate | Lock up your Lemmings | Lemmings / Fun | 283.85 | 319.20 |  |
| 93 | Intermediate | Easy when you know how | Lemmings / Fun | 256.86 | 331.50 |  |
| 94 | Intermediate | Gone With The Lemming | Oh No! More Lemmings / Tame | 216.33 | 347.20 |  |
| 95 | Intermediate | Bitter Lemming | Lemmings / Tricky | 239.79 | 336.00 |  |
| 96 | Intermediate | A TOWERING PROBLEM | Oh No! More Lemmings / Wicked | 304.89 | 331.13 |  |
| 97 | Intermediate | Lemming Hotel | Oh No! More Lemmings / Wild | 242.86 | 337.12 |  |
| 98 | Intermediate | We are now at LEMCON ONE | Lemmings / Fun | 273.12 | 337.32 |  |
| 99 | Intermediate | Time to get up! | Lemmings / Mayhem | 319.74 | 331.50 |  |
| 100 | Intermediate | It`s a trade off | Oh No! More Lemmings / Crazy | 272.03 | 346.74 |  |
| 101 | Intermediate | A Block from Home | Holiday Lemmings 1993 / Flurry | 348.40 | 348.40 |  |
| 102 | Intermediate | Egypt Fall | Anatol00 / fan:lldb-3 | 125.77 | 324.53 |  |
| 103 | Intermediate | Diggin' to a better world | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 121.63 | 324.01 |  |
| 104 | Intermediate | PRACTICE: FLOATER | Mikepak07 / fan:lldb-12 | 121.89 | 325.03 |  |
| 105 | Intermediate | Climb to victory | PSP Special 1 10 of 36 / fan:lldb-216 | 120.02 | 326.71 |  |
| 106 | Intermediate | Float to safety | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 124.82 | 336.28 |  |
| 107 | Intermediate | The Curse of Devil | Mad00 / fan:lldb-55 | 259.27 | 330.08 |  |
| 108 | Intermediate | Save the Lemmings with Floaters | PSP Special 1 10 of 36 / fan:lldb-216 | 232.61 | 328.18 |  |
| 109 | Intermediate | How do you get up there? | JM10 / fan:lldb-336 | 320.08 | 331.50 |  |
| 110 | Intermediate | Fun 20.lvl | Amiga Fun Budget / fan:lldb-568 | 275.22 | 337.32 |  |
| 111 | Intermediate | Downwardly Mobile Lemmings | Oh No! More Lemmings / Tame | 160.51 | 350.62 |  |
| 112 | Intermediate | Luvly Jubly | Lemmings / Tricky | 205.59 | 350.30 |  |
| 113 | Intermediate | New Lemmings On The Block | Oh No! More Lemmings / Tame | 161.16 | 350.62 |  |
| 114 | Intermediate | Livin` On The Edge | Lemmings / Taxing | 318.94 | 351.32 |  |
| 115 | Intermediate | Going up....... | Lemmings / Mayhem | 292.20 | 355.38 |  |
| 116 | Intermediate | A long way to go | Giga pack 09 / fan:lldb-171 | 322.32 | 359.18 |  |
| 117 | Intermediate | Taxing 12.lvl | Amiga Taxing Budget / fan:lldb-570 | 321.04 | 351.32 |  |
| 118 | Intermediate | Mayhem 23.lvl | Amiga Mayhem Budget / fan:lldb-571 | 294.30 | 355.38 |  |
| 119 | Difficult | The Boiler Room | Lemmings / Mayhem | 230.65 | 362.40 |  |
| 120 | Difficult | Flow Control | Oh No! More Lemmings / Havoc | 249.06 | 361.82 |  |
| 121 | Difficult | The Wrath of Lem | Holiday Lemmings 1993 / Blizzard | 260.08 | 371.17 |  |
| 122 | Difficult | SNOW JOKE | Oh No! More Lemmings / Wild | 266.41 | 365.28 |  |
| 123 | Difficult | Anxiety | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 261.73 | 371.60 |  |
| 124 | Difficult | Train your body | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 269.76 | 360.53 |  |
| 125 | Difficult | Two heads are better... | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 265.30 | 374.91 |  |
| 126 | Difficult | If at first you don`t succeed.. | Lemmings / Taxing | 238.73 | 381.21 |  |
| 127 | Difficult | Tribute to M.C.Escher | Lemmings / Taxing | 320.79 | 372.57 |  |
| 128 | Difficult | Dangerzone | Oh No! More Lemmings / Tame | 240.43 | 377.08 |  |
| 129 | Difficult | Exodus! | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 378.92 | 378.92 |  |
| 130 | Difficult | Stairway To Nowhere | Timpack11 / fan:lldb-98 | 134.12 | 362.58 |  |
| 131 | Difficult | Climbers can climb the wall | Deceits Lemmings Extras / fan:lldb-546 | 133.34 | 369.08 |  |
| 132 | Difficult | Floaters can land safely | Deceits Lemmings Extras / fan:lldb-546 | 134.25 | 372.57 |  |
| 133 | Difficult | Miners Can Mine Diagonally | Deceits Lemmings Extras / fan:lldb-546 | 136.08 | 371.53 |  |
| 134 | Difficult | Exit for Hell! | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 193.67 | 367.41 |  |
| 135 | Difficult | Crush & Crash 2 | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 232.58 | 365.58 |  |
| 136 | Difficult | De-fusing a time bomb | Snow remakes 01 / fan:lldb-144 | 235.29 | 375.46 |  |
| 137 | Difficult | The Boiler Room (part two) | Conway Challenges 2 / fan:lldb-264 | 232.70 | 362.40 |  |
| 138 | Difficult | V For Vendetta | Van Clan Tame / fan:lldb-88 | 303.71 | 383.00 |  |
| 139 | Difficult | 2 Minutes before midnight | Holiday Lemmings 1994 / Frost | 202.25 | 393.73 |  |
| 140 | Difficult | Happy Holidays Mr Lemming! | Xmas Lemmings 1992 / Xmas | 179.60 | 404.15 |  |
| 141 | Difficult | It's Lemmingentry Watson | Lemmings / Tricky | 216.70 | 400.45 |  |
| 142 | Difficult | Now use miners and climbers | Lemmings / Fun | 194.62 | 408.85 |  |
| 143 | Difficult | Ice Station Lemming | Oh No! More Lemmings / Wild | 243.02 | 388.29 |  |
| 144 | Difficult | Have an ice day | Oh No! More Lemmings / Havoc | 284.08 | 385.65 |  |
| 145 | Difficult | The Great Lemming Caper | Lemmings / Mayhem | 342.90 | 386.75 |  |
| 146 | Difficult | The Lemming Learning Curve | Oh No! More Lemmings / Wicked | 325.11 | 386.75 |  |
| 147 | Difficult | Dolly Dimple | Oh No! More Lemmings / Crazy | 312.59 | 391.76 |  |
| 148 | Difficult | Let's be careful out there | Lemmings / Fun | 288.66 | 386.75 |  |
| 149 | Difficult | Lemmings in the attic | Lemmings / Tricky | 309.71 | 386.75 |  |
| 150 | Difficult | With Compliments | Oh No! More Lemmings / Tame | 231.34 | 397.63 |  |
| 151 | Difficult | No world without you | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 382.47 | 386.75 |  |
| 152 | Difficult | Watch right or left (Part two) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 357.49 | 387.91 |  |
| 153 | Difficult | LOoK BeFoRe YoU LeAp! | Oh No! More Lemmings / Havoc | 296.68 | 395.44 |  |
| 154 | Difficult | Mary Poppins` land | Lemmings / Taxing | 338.28 | 396.82 |  |
| 155 | Difficult | Triple Trouble | Lemmings / Taxing | 341.86 | 386.75 |  |
| 156 | Difficult | Rent-a-Lemming | Oh No! More Lemmings / Tame | 319.26 | 408.13 |  |
| 157 | Difficult | Presents of Mind II | Holiday Lemmings 1993 / Blizzard | 321.70 | 406.61 |  |
| 158 | Difficult | Higgledy Piggledy | Oh No! More Lemmings / Wild | 316.87 | 416.03 |  |
| 159 | Difficult | The Crossroads | Lemmings / Mayhem | 180.36 | 417.92 |  |
| 160 | Difficult | Climbing to the Top! | Holiday Lemmings 1993 / Flurry | 240.38 | 417.92 |  |
| 161 | Difficult | Lemming Reunification | Holiday Lemmings 1994 / Frost | 289.34 | 417.92 |  |
| 162 | Difficult | Perseverance | Lemmings / Taxing | 320.77 | 402.67 |  |
| 163 | Difficult | The North Poles | Xmas Lemmings 1992 / Xmas | 292.83 | 408.89 |  |
| 164 | Difficult | Worra load of old blocks! | Oh No! More Lemmings / Crazy | 363.16 | 407.75 |  |
| 165 | Difficult | Poles Apart | Lemmings / Mayhem | 349.15 | 414.93 |  |
| 166 | Difficult | Lemmy in the cold, cold ground | Holiday Lemmings 1994 / Hail | 359.03 | 414.75 |  |
| 167 | Difficult | You Take the High Road | Oh No! More Lemmings / Wild | 383.35 | 412.58 |  |
| 168 | Difficult | Climbing Will Help, Now | Holiday cLemmings Frost / fan:lldb-535 | 142.48 | 404.21 |  |
| 169 | Difficult | Float to safety | JM01 / fan:lldb-327 | 146.19 | 409.02 |  |
| 170 | Difficult | Bridge In A Fridge | TWPAK00 / fan:lldb-302 | 146.28 | 409.35 |  |
| 171 | Difficult | Just Float | TimpackE / fan:lldb-103 | 146.51 | 410.24 |  |
| 172 | Difficult | Which Exit? | beta / fan:lldb-371 | 141.96 | 408.35 |  |
| 173 | Difficult | Training 07 - Let's Mine! | JEFFPCK6 / fan:lldb-240 | 145.52 | 415.92 |  |
| 174 | Difficult | Build Block | KillerMasters Lemmings 1 Wicked / fan:lldb-508 | 150.39 | 413.96 |  |
| 175 | Difficult | Fun 04.lvl | Amiga Fun Budget / fan:lldb-568 | 196.72 | 408.85 |  |
| 176 | Difficult | Fun 27.lvl | Amiga Fun Budget / fan:lldb-568 | 288.66 | 386.75 |  |
| 177 | Difficult | Taxing 26.lvl | Amiga Taxing Budget / fan:lldb-570 | 346.62 | 386.75 |  |
| 178 | Difficult | In The Style Of... | Lemmings Plus DOS Project Mild / fan:lldb-551 | 301.13 | 400.44 |  |
| 179 | Difficult | Taxing 16.lvl | Amiga Taxing Budget / fan:lldb-570 | 338.55 | 397.86 |  |
| 180 | Difficult | Have a Pleasant Journey ! | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 268.04 | 395.76 |  |
| 181 | Difficult | Mayhem 07.lvl | Amiga Mayhem Budget / fan:lldb-571 | 351.25 | 414.93 |  |
| 182 | Difficult | gronklems -1.dat 1 | Gronklems 1 / fan:lldb-386 | 276.82 | 408.13 |  |
| 183 | Difficult | Mayhem 04.lvl | Amiga Mayhem Budget / fan:lldb-571 | 196.58 | 417.92 |  |
| 184 | Difficult | You going to Lemming Master | KillerMasters Lemmings 1 Havoc / fan:lldb-509 | 271.51 | 410.62 |  |
| 185 | Difficult | Diet Lemmingaid | Lemmings / Tricky | 144.50 | 422.94 |  |
| 186 | Difficult | Separate Ways | Holiday Lemmings 1994 / Frost | 182.16 | 434.92 |  |
| 187 | Difficult | Rules to fall | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 208.05 | 435.48 |  |
| 188 | Difficult | DON`T PANIC | Oh No! More Lemmings / Crazy | 325.48 | 421.70 |  |
| 189 | Difficult | Lemmings Up High | Holiday Lemmings 1993 / Blizzard | 236.12 | 436.93 |  |
| 190 | Difficult | Plethora of Presents | Holiday Lemmings 1994 / Frost | 236.95 | 438.61 |  |
| 191 | Difficult | We all fall down | Lemmings / Fun | 157.63 | 453.02 |  |
| 192 | Difficult | PoP TiL YoU DrOp! | Oh No! More Lemmings / Wicked | 233.05 | 443.75 |  |
| 193 | Difficult | A Single Lemming... | Holiday Lemmings 1993 / Blizzard | 296.68 | 433.25 |  |
| 194 | Difficult | Ski Jump! | Holiday Lemmings 1994 / Frost | 170.09 | 450.25 |  |
| 195 | Difficult | Looks a Bit Nippy Out There | Oh No! More Lemmings / Havoc | 271.14 | 441.48 |  |
| 196 | Difficult | Every Lemming for himself!!! | Lemmings / Taxing | 360.25 | 427.43 |  |
| 197 | Difficult | Lemming about town | Oh No! More Lemmings / Havoc | 321.74 | 426.76 |  |
| 198 | Difficult | Haunted botanical garden | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 343.01 | 442.64 |  |
| 199 | Difficult | Five Alive | Oh No! More Lemmings / Wicked | 330.16 | 441.22 |  |
| 200 | Difficult | It's Boxing Day! | Holiday Lemmings 1994 / Frost | 357.30 | 444.75 |  |
| 201 | Difficult | And now, the end is near... | Oh No! More Lemmings / Crazy | 320.71 | 452.04 |  |
| 202 | Difficult | LeMming ToMato KetchUp fAcilitY | Oh No! More Lemmings / Wicked | 326.42 | 450.00 |  |
| 203 | Difficult | Undercover Lemming | Oh No! More Lemmings / Tame | 252.68 | 439.63 |  |
| 204 | Difficult | Hunt the Nessy.... | Lemmings / Taxing | 410.57 | 436.51 |  |
| 205 | Difficult | Postcard from Lemmingland | Lemmings / Tricky | 346.74 | 450.00 |  |
| 206 | Difficult | Just a Minute... | Lemmings / Mayhem | 312.01 | 454.90 |  |
| 207 | Difficult | There`s madness in the method | Oh No! More Lemmings / Havoc | 391.12 | 448.24 |  |
| 208 | Difficult | Intro to MCMarshy01.dat | MARSHY01 / fan:lldb-345 | 140.79 | 422.68 |  |
| 209 | Difficult | Rendezvous II | Holiday Lemmings 1994 / Hail | 410.10 | 450.50 |  |
| 210 | Difficult | Only climbers can do this | MARSHY01 / fan:lldb-345 | 149.82 | 422.98 |  |
| 211 | Difficult | Fun 13.lvl | Amiga Fun Budget / fan:lldb-568 | 152.63 | 425.70 |  |
| 212 | Difficult | Climbing all the way | ANTHPCK1 / fan:lldb-221 | 152.90 | 425.01 |  |
| 213 | Difficult | Tailor-made for floaters | MARSHY01 / fan:lldb-345 | 154.99 | 429.86 |  |
| 214 | Difficult | Weave Your Lemmings | TWPAK09 / fan:lldb-311 | 180.38 | 428.07 |  |
| 215 | Difficult | Training 02 - Let's Float! | JEFFPCK6 / fan:lldb-240 | 150.00 | 433.14 |  |
| 216 | Difficult | Tricky 02.lvl | Amiga Tricky Budget / fan:lldb-569 | 157.60 | 435.04 |  |
| 217 | Difficult | The Impossible Gap | MARSHY07 / fan:lldb-351 | 150.28 | 440.36 |  |
| 218 | Difficult | The Box. | isupck02 / fan:lldb-353 | 182.04 | 434.45 |  |
| 219 | Difficult | Classic lems find new home(Lem3) | Lemmy556 My little levels 2 / fan:lldb-66 | 160.73 | 441.23 |  |
| 220 | Difficult | Taxing 30.lvl | Amiga Taxing Budget / fan:lldb-570 | 161.55 | 444.39 |  |
| 221 | Difficult | Speed Freaks | Ji Hoons Lemmings Remake Earth / fan:lldb-549 | 160.10 | 442.74 |  |
| 222 | Difficult | Mayhem 11.lvl | Amiga Mayhem Budget / fan:lldb-571 | 165.06 | 453.74 |  |
| 223 | Difficult | FunnyTopia | KillerMasters Lemmings 1 Wicked / fan:lldb-508 | 211.14 | 447.37 |  |
| 224 | Difficult | Day by Day | JM01 / fan:lldb-327 | 234.15 | 445.23 |  |
| 225 | Difficult | Taxing 07.lvl | Amiga Taxing Budget / fan:lldb-570 | 362.47 | 427.88 |  |
| 226 | Difficult | Excavation Station | TWPAK00 / fan:lldb-302 | 265.20 | 421.90 |  |
| 227 | Difficult | Dig Down, Bash Across | PSP Special 1 10 of 36 / fan:lldb-216 | 283.70 | 429.10 |  |
| 228 | Difficult | Bashing & Building | Nepster01 / fan:lldb-219 | 375.11 | 424.82 |  |
| 229 | Difficult | Cyborglem Lab | KillerMasters Lemmings 1 Wild / fan:lldb-507 | 354.96 | 452.84 |  |
| 230 | Difficult | Dirt Runner | Nepster01 / fan:lldb-219 | 297.79 | 450.70 |  |
| 231 | Difficult | Snow Lev 1 | ANTHPCK4 / fan:lldb-224 | 225.57 | 454.90 |  |
| 232 | Difficult | Got anything....Lemmingy??? | Oh No! More Lemmings / Wild | 322.96 | 459.00 |  |
| 233 | Difficult | Lemmingdelica | Oh No! More Lemmings / Wild | 267.48 | 459.00 |  |
| 234 | Difficult | Dr Lemminggood | Oh No! More Lemmings / Wild | 252.87 | 459.00 |  |
| 235 | Difficult | Presents of Mind | Holiday Lemmings 1993 / Flurry | 337.94 | 459.00 |  |
| 236 | Difficult | Down the tube | Oh No! More Lemmings / Wicked | 327.06 | 459.00 |  |
| 237 | Difficult | Quest for Kieran | Holiday Lemmings 1994 / Frost | 288.50 | 459.00 |  |
| 238 | Difficult | Up, up, and away! | Holiday Lemmings 1994 / Hail | 305.48 | 459.00 |  |
| 239 | Difficult | Steel Ice Span | Holiday Lemmings 1994 / Hail | 308.87 | 459.00 |  |
| 240 | Difficult | Up, Down or Round and Round | Oh No! More Lemmings / Wicked | 242.67 | 456.73 |  |
| 241 | Difficult | 24 hour Lemathon | Oh No! More Lemmings / Crazy | 328.41 | 459.75 |  |
| 242 | Difficult | The Voyage Home... | Holiday Lemmings 1993 / Blizzard | 257.20 | 459.25 |  |
| 243 | Difficult | Inside the bone | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 330.59 | 456.65 |  |
| 244 | Difficult | This Corrosion | Oh No! More Lemmings / Wicked | 342.84 | 459.00 |  |
| 245 | Difficult | Marshmallow Land | Holiday Lemmings 1993 / Flurry | 346.80 | 459.00 |  |
| 246 | Difficult | Tailor-made for blockers | Lemmings / Fun | 188.60 | 486.10 |  |
| 247 | Difficult | A task for blockers and bombers | Lemmings / Fun | 129.82 | 486.10 |  |
| 248 | Difficult | The Steel Mines of Kessel | Lemmings / Mayhem | 212.48 | 486.10 |  |
| 249 | Difficult | Last Lemming To Lemmingcentral | Oh No! More Lemmings / Wicked | 190.08 | 486.10 |  |
| 250 | Difficult | Clouds of Lemmings | Holiday Lemmings 1993 / Flurry | 209.58 | 486.10 |  |
| 251 | Difficult | The Final Frontier | Holiday Lemmings 1993 / Blizzard | 275.78 | 486.10 |  |
| 252 | Difficult | Spiral staircase | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 278.68 | 486.10 |  |
| 253 | Difficult | The Land of the Bizarre | Holiday Lemmings 1994 / Frost | 271.80 | 486.10 |  |
| 254 | Difficult | Is this a circus? | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 239.53 | 480.77 |  |
| 255 | Difficult | With a twist of lemming please | Lemmings / Mayhem | 304.53 | 473.41 |  |
| 256 | Difficult | Evacuating a coal mine | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 331.06 | 456.32 |  |
| 257 | Difficult | Peak of Performance | Holiday Lemmings 1994 / Hail | 262.66 | 486.10 |  |
| 258 | Difficult | Down And Out Lemmings | Oh No! More Lemmings / Tame | 215.08 | 486.10 |  |
| 259 | Difficult | Walk the web rope | Lemmings / Taxing | 350.04 | 459.82 |  |
| 260 | Difficult | Lemming Tracks in the Snow! | Holiday Lemmings 1993 / Flurry | 239.12 | 486.10 |  |
| 261 | Difficult | This should be a doddle! | Lemmings / Tricky | 299.58 | 486.10 |  |
| 262 | Difficult | Call in the bomb squad | Lemmings / Taxing | 288.44 | 486.10 |  |
| 263 | Difficult | Maybe not such a doddle | Holiday Lemmings 1994 / Frost | 289.29 | 486.10 |  |
| 264 | Difficult | CindyLand | Holiday Lemmings 1994 / Frost | 298.86 | 486.10 |  |
| 265 | Difficult | How on Earth? | Oh No! More Lemmings / Wicked | 327.66 | 486.10 |  |
| 266 | Difficult | Rainbow Island | Lemmings / Tricky | 301.05 | 486.10 |  |
| 267 | Difficult | The Long Way Around | Holiday Lemmings 1993 / Flurry | 305.15 | 486.10 |  |
| 268 | Difficult | Tightrope City | Lemmings / Tricky | 264.39 | 486.10 |  |
| 269 | Difficult | Quote: "That`s a good level" | Oh No! More Lemmings / Crazy | 271.74 | 486.10 |  |
| 270 | Difficult | Break On Through | Holiday Lemmings 1994 / Hail | 292.72 | 486.10 |  |
| 271 | Difficult | Konbanwa Lemming san | Lemmings / Fun | 271.56 | 486.10 |  |
| 272 | Difficult | worra lorra lemmings | Lemmings / Fun | 240.62 | 486.10 |  |
| 273 | Difficult | As long as you try your best | Lemmings / Fun | 296.53 | 475.90 |  |
| 274 | Difficult | Here is Mr.Lemming's house | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 311.52 | 486.10 |  |
| 275 | Difficult | Down, along, up. In that order | Lemmings / Mayhem | 331.74 | 486.10 |  |
| 276 | Difficult | Steel Works | Lemmings / Mayhem | 333.15 | 486.10 |  |
| 277 | Difficult | Lend a helping hand.... | Lemmings / Taxing | 353.52 | 486.10 |  |
| 278 | Difficult | Lemming Head | Oh No! More Lemmings / Wild | 297.54 | 486.10 |  |
| 279 | Difficult | Be sure to be a builder. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 302.66 | 486.10 |  |
| 280 | Difficult | Suicidal Tendencies | Oh No! More Lemmings / Wicked | 318.35 | 486.10 |  |
| 281 | Difficult | Watch your step | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 308.23 | 486.10 |  |
| 282 | Difficult | Feel the heat! | Lemmings / Taxing | 346.04 | 486.10 |  |
| 283 | Difficult | Scaling the Heights | Oh No! More Lemmings / Havoc | 372.17 | 486.10 |  |
| 284 | Difficult | The Next Lemeration | Holiday Lemmings 1993 / Blizzard | 339.35 | 486.10 |  |
| 285 | Difficult | It`s hero time! | Lemmings / Mayhem | 373.02 | 486.10 |  |
| 286 | Difficult | HIGHLAND FLING | Oh No! More Lemmings / Havoc | 400.72 | 486.10 |  |
| 287 | Difficult | Curse of the Pharaohs | Lemmings / Mayhem | 314.49 | 486.10 |  |
| 288 | Difficult | ICE SPY | Oh No! More Lemmings / Wild | 398.26 | 474.61 |  |
| 289 | Difficult | Out, away from the tune | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 340.13 | 486.10 |  |
| 290 | Difficult | Cave quest | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 355.21 | 486.10 |  |
| 291 | Difficult | No added colours or Lemmings | Lemmings / Mayhem | 364.20 | 486.10 |  |
| 292 | Difficult | Come on over to my place | Lemmings / Taxing | 380.13 | 486.10 |  |
| 293 | Difficult | Temple of Love | Oh No! More Lemmings / Wicked | 408.92 | 486.10 |  |
| 294 | Difficult | Move on in two separate groups. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 421.14 | 486.10 |  |
| 295 | Difficult | Turn around young lemmings! (rm) | LEMREMAKE / fan:lldb-465 | 261.77 | 457.62 |  |
| 296 | Difficult | Just two minutes | JM06 / fan:lldb-332 | 160.02 | 477.84 |  |
| 297 | Difficult | Digger Conversions | Lemmings The Official Companion / fan:lldb-585 | 262.26 | 470.88 |  |
| 298 | Difficult | Merry Lemmings | Van Clan Tame / fan:lldb-99 | 149.84 | 486.10 |  |
| 299 | Difficult | Taxing 27.lvl | Amiga Taxing Budget / fan:lldb-570 | 290.54 | 486.10 |  |
| 300 | Difficult | Tricky 29.lvl | Amiga Tricky Budget / fan:lldb-569 | 301.11 | 486.10 |  |
| 301 | Difficult | Tricky 01.lvl | Amiga Tricky Budget / fan:lldb-569 | 303.50 | 486.10 |  |
| 302 | Difficult | Walk the web rope (part two) | Conway Challenges 1 / fan:lldb-263 | 352.96 | 459.82 |  |
| 303 | Difficult | Fun 29.lvl | Amiga Fun Budget / fan:lldb-568 | 240.62 | 486.10 |  |
| 304 | Difficult | Taxing 20.lvl | Amiga Taxing Budget / fan:lldb-570 | 350.36 | 459.82 |  |
| 305 | Difficult | Steel Works (part two) | Conway Challenges 1 / fan:lldb-263 | 335.49 | 486.10 |  |
| 306 | Difficult | Mayhem 05.lvl | Amiga Mayhem Budget / fan:lldb-571 | 331.74 | 486.10 |  |
| 307 | Difficult | Maybe would be a doddle! | CRISFN11 / fan:lldb-275 | 228.88 | 478.65 |  |
| 308 | Difficult | Dying Dream | Nepster01 / fan:lldb-219 | 228.62 | 486.10 |  |
| 309 | Difficult | Mayhem 03.lvl | Amiga Mayhem Budget / fan:lldb-571 | 373.02 | 486.10 |  |
| 310 | Difficult | Dunes | Nepster01 / fan:lldb-219 | 367.72 | 486.10 |  |
| 311 | Difficult | Mayhem 09.lvl | Amiga Mayhem Budget / fan:lldb-571 | 314.55 | 486.10 |  |
| 312 | Difficult | Mayhem 20.lvl | Amiga Mayhem Budget / fan:lldb-571 | 366.30 | 486.10 |  |
| 313 | Difficult | Broken Symmetry | Nepster01 / fan:lldb-219 | 371.03 | 486.10 |  |
| 314 | Difficult | Taxing 22.lvl | Amiga Taxing Budget / fan:lldb-570 | 388.01 | 486.10 |  |
| 315 | Difficult | Time Gate | Nepster01 / fan:lldb-219 | 429.32 | 486.10 |  |
| 316 | Difficult | ROCKY VI | Oh No! More Lemmings / Crazy | 310.79 | 496.93 |  |
| 317 | Difficult | NO PROBLEM | Oh No! More Lemmings / Crazy | 388.48 | 490.03 |  |
| 318 | Difficult | Santus Lemmingus | Holiday Lemmings 1993 / Blizzard | 345.95 | 493.03 |  |
| 319 | Difficult | DIGGING FOR VICTORY | Oh No! More Lemmings / Crazy | 396.34 | 492.20 |  |
| 320 | Difficult | Mutiny On The Bounty | Oh No! More Lemmings / Wild | 329.91 | 514.25 |  |
| 321 | Difficult | Almost Nearly Virtual Reality | Oh No! More Lemmings / Wicked | 305.60 | 514.25 |  |
| 322 | Difficult | The Chain with no name | Oh No! More Lemmings / Wild | 315.68 | 514.25 |  |
| 323 | Difficult | Oh No! It`s the 4TH DIMENSION! | Oh No! More Lemmings / Wicked | 332.18 | 514.25 |  |
| 324 | Difficult | On the Antarctic Coast | Oh No! More Lemmings / Crazy | 362.75 | 514.25 |  |
| 325 | Difficult | All or Nothing | Lemmings / Mayhem | 265.22 | 495.84 |  |
| 326 | Difficult | Ozone friendly Lemmings | Lemmings / Tricky | 194.92 | 495.84 |  |
| 327 | Difficult | Break on through... | Holiday Lemmings 1993 / Blizzard | 297.68 | 518.74 |  |
| 328 | Difficult | Check Your Hints! | Holiday Lemmings 1993 / Blizzard | 297.28 | 510.53 |  |
| 329 | Difficult | The Lemming Funhouse | Oh No! More Lemmings / Wicked | 448.11 | 518.74 |  |
| 330 | Difficult | PoP YoR ToP!!! | Oh No! More Lemmings / Wild | 329.66 | 514.25 |  |
| 331 | Difficult | Up on the Rooftops | Holiday Lemmings 1994 / Frost | 412.84 | 514.25 |  |
| 332 | Difficult | The Stack | Oh No! More Lemmings / Crazy | 429.63 | 490.04 |  |
| 333 | Difficult | The gate trap Lemmings. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 425.62 | 503.58 |  |
| 334 | Difficult | Libra | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 287.44 | 508.18 |  |
| 335 | Difficult | Sir Edmund Hilemming | Holiday Lemmings 1994 / Hail | 423.19 | 514.25 |  |
| 336 | Difficult | Welcome to the party, pal! | Oh No! More Lemmings / Havoc | 366.96 | 514.25 |  |
| 337 | Difficult | LoTs moRe wHeRe TheY caMe fRom | Oh No! More Lemmings / Wicked | 423.90 | 514.25 |  |
| 338 | Difficult | Inroducing SUPERLEMMING | Oh No! More Lemmings / Wicked | 366.73 | 509.60 |  |
| 339 | Difficult | Stray sheep | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 352.12 | 516.96 |  |
| 340 | Difficult | Cascade | Lemmings / Tricky | 407.80 | 515.82 |  |
| 341 | Difficult | Be more than just a number | Oh No! More Lemmings / Havoc | 435.18 | 514.25 |  |
| 342 | Difficult | ROCKY ROAD | Oh No! More Lemmings / Wicked | 413.29 | 521.98 |  |
| 343 | Difficult | The Funeral | MATTPCK2 / fan:lldb-249 | 269.10 | 510.53 |  |
| 344 | Difficult | What exit? | JM11 / fan:lldb-337 | 300.59 | 510.53 |  |
| 345 | Difficult | Don't settle for anything less | Conway Challenges 1 / fan:lldb-263 | 425.93 | 515.82 |  |
| 346 | Difficult | The Cascade: Part II | Modlvls / fan:lldb-357 | 422.21 | 515.82 |  |
| 347 | Difficult | Tricky 25.lvl | Amiga Tricky Budget / fan:lldb-569 | 407.21 | 515.82 |  |
| 348 | Difficult | Doomsday | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 321.34 | 536.48 |  |
| 349 | Difficult | Happy New Year! | Holiday Lemmings 1994 / Frost | 415.14 | 529.82 |  |
| 350 | Difficult | SPAM,SPAM,SPAM,EGG AND LEMMING | Oh No! More Lemmings / Wicked | 414.48 | 540.00 |  |
| 351 | Difficult | A ladder would be handy | Lemmings / Tricky | 394.92 | 540.00 |  |
| 352 | Difficult | Lemming Productions Present... | Oh No! More Lemmings / Tame | 424.90 | 540.00 |  |
| 353 | Difficult | How do I dig up the way? | Lemmings / Taxing | 419.20 | 540.00 |  |
| 354 | Difficult | Have a nice day! | Lemmings / Mayhem | 449.58 | 540.00 |  |
| 355 | Difficult | One way digging to freedom | Lemmings / Tricky | 368.42 | 549.40 |  |
| 356 | Difficult | Merry Christmaze | Holiday Lemmings 1994 / Hail | 286.14 | 552.13 |  |
| 357 | Difficult | Save 'em First... | JEFFPCK7 / fan:lldb-241 | 392.18 | 544.00 |  |
| 358 | Difficult | A ladder would be handy (Part2) | JM01 / fan:lldb-327 | 403.50 | 540.00 |  |
| 359 | Difficult | Tricky 20.lvl | Amiga Tricky Budget / fan:lldb-569 | 368.98 | 549.40 |  |
| 360 | Difficult | The hunt is on! | QBeez03 / fan:lldb-33 | 453.53 | 540.00 |  |
| 361 | Difficult | Level 02.lvl | Amiga Demo / fan:lldb-581 | 366.88 | 549.40 |  |
| 362 | Difficult | Tricky 03.lvl | Amiga Tricky Budget / fan:lldb-569 | 394.92 | 540.00 |  |
| 363 | Difficult | FlameBungee | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 403.07 | 554.90 |  |
| 364 | Difficult | Taxing 29.lvl | Amiga Taxing Budget / fan:lldb-570 | 419.20 | 540.00 |  |
| 365 | Difficult | Climb and Float | brickpk1 / fan:lldb-558 | 372.72 | 554.90 |  |
| 366 | Difficult | Just a random heap of junk! | Nepster01 / fan:lldb-219 | 454.46 | 556.53 |  |
| 367 | Difficult | Splunk n' country | Epic Giga03 / fan:lldb-141 | 434.15 | 546.48 |  |
| 368 | Difficult | A Beast of a level | Lemmings / Fun | 325.32 | 564.18 |  |
| 369 | Difficult | Time waits for no Lemming | Oh No! More Lemmings / Crazy | 397.45 | 569.50 |  |
| 370 | Difficult | Water processing plant | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 431.98 | 569.50 |  |
| 371 | Difficult | Just a minute (Part Three) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 446.95 | 569.50 |  |
| 372 | Difficult | It`s the price you have to pay | Oh No! More Lemmings / Havoc | 452.11 | 569.50 |  |
| 373 | Difficult | Emmings!  (No L) | Holiday Lemmings 1994 / Hail | 479.42 | 569.50 |  |
| 374 | Difficult | Lemming Rhythms | Oh No! More Lemmings / Wild | 394.96 | 581.48 |  |
| 375 | Difficult | X marks the spot | Lemmings / Taxing | 443.60 | 592.94 |  |
| 376 | Difficult | Lemming Playground | Nepster01 / fan:lldb-219 | 406.42 | 585.56 |  |
| 377 | Difficult | Taxing 17.lvl | Amiga Taxing Budget / fan:lldb-570 | 443.60 | 592.94 |  |
| 378 | Difficult | Simply Smashing | Epic Giga03 / fan:lldb-141 | 514.30 | 569.50 |  |
| 379 | Difficult | Patience | Lemmings / Fun | 421.98 | 595.98 |  |
| 380 | Difficult | Take care, Sweetie | Oh No! More Lemmings / Wild | 338.92 | 598.88 |  |
| 381 | Difficult | Compression Method 1 | Lemmings / Taxing | 318.21 | 598.88 |  |
| 382 | Difficult | Go Thataway! | Holiday Lemmings 1994 / Hail | 441.67 | 598.88 |  |
| 383 | Difficult | Four Play | Holiday Lemmings 1994 / Frost | 550.15 | 598.88 |  |
| 384 | Difficult | Fall and no life (Part Two) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 513.76 | 595.48 |  |
| 385 | Difficult | With A Little Help From... | Yawg02 / fan:lldb-85 | 297.60 | 598.88 |  |
| 386 | Difficult | Again & Again | JM03 / fan:lldb-329 | 321.01 | 598.88 |  |
| 387 | Difficult | Hard when you don't know how | MARSHY02 / fan:lldb-346 | 317.22 | 598.88 |  |
| 388 | Difficult | Puzzle Time.ini | grams88 / fan:lldb-416 | 327.09 | 598.88 |  |
| 389 | Expert | It`s all a matter of timing | Oh No! More Lemmings / Havoc | 299.52 | 603.50 |  |
| 390 | Expert | The Search for Lem | Holiday Lemmings 1993 / Blizzard | 443.10 | 624.75 |  |
| 391 | Expert | KEEP ON TRUCKING | Oh No! More Lemmings / Crazy | 434.90 | 624.75 |  |
| 392 | Expert | Polar Expedition | Holiday Lemmings 1994 / Hail | 467.57 | 624.75 |  |
| 393 | Expert | Where Lemmings Dare | Oh No! More Lemmings / Havoc | 497.36 | 624.75 |  |
| 394 | Expert | THE SILENCE OF THE LEMMINGS | Oh No! More Lemmings / Wild | 481.37 | 624.75 |  |
| 395 | Expert | SUNSOFT Special | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 389.00 | 600.61 |  |
| 396 | Expert | Who`s That Lemming | Oh No! More Lemmings / Tame | 373.34 | 606.82 |  |
| 397 | Expert | The Prison! | Lemmings / Taxing | 349.20 | 623.68 |  |
| 398 | Expert | Tubular Lemmings | Oh No! More Lemmings / Havoc | 481.59 | 602.03 |  |
| 399 | Expert | Upsidedown World | Lemmings / Taxing | 423.24 | 611.11 |  |
| 400 | Expert | Just A Quicky | Oh No! More Lemmings / Wild | 439.03 | 611.11 |  |
| 401 | Expert | Taxing 13.lvl | Amiga Taxing Budget / fan:lldb-570 | 426.05 | 611.11 |  |
| 402 | Expert | Taxing 05.lvl | Amiga Taxing Budget / fan:lldb-570 | 351.30 | 623.68 |  |
| 403 | Expert | C'mon everybody body | Giga pack 08 / fan:lldb-170 | 484.29 | 607.81 |  |
| 404 | Expert | Don't bash the wall | JM10 / fan:lldb-336 | 444.42 | 629.00 |  |
| 405 | Expert | Not just a pretty Lemming | Oh No! More Lemmings / Tame | 468.85 | 630.00 |  |
| 406 | Expert | There's a lot of them about | Lemmings / Tricky | 446.37 | 663.00 |  |
| 407 | Expert | Save Me | Lemmings / Mayhem | 393.27 | 646.46 |  |
| 408 | Expert | It`s a tight fit! | Oh No! More Lemmings / Wild | 442.87 | 656.96 |  |
| 409 | Expert | ONWARD AND UPWARD | Oh No! More Lemmings / Wild | 507.97 | 658.48 |  |
| 410 | Expert | Creature Discomforts | Oh No! More Lemmings / Havoc | 517.87 | 655.94 |  |
| 411 | Expert | Back in Hell | JMGM01 / fan:lldb-454 | 239.66 | 637.50 |  |
| 412 | Expert | Tricky 10.lvl | Amiga Tricky Budget / fan:lldb-569 | 450.92 | 663.00 |  |
| 413 | Expert | Crazy stairs | Giga pack 07 / fan:lldb-169 | 417.88 | 658.51 |  |
| 414 | Expert | And now this... | Oh No! More Lemmings / Tame | 396.84 | 673.32 |  |
| 415 | Expert | I have a cunning plan | Lemmings / Tricky | 416.66 | 672.48 |  |
| 416 | Expert | Origins and Lemmings | Lemmings / Fun | 501.55 | 667.72 |  |
| 417 | Expert | Snuggle up to a Lemming | Oh No! More Lemmings / Tame | 480.11 | 673.32 |  |
| 418 | Expert | Oogilemming! | Holiday Lemmings 1993 / Blizzard | 497.20 | 680.00 |  |
| 419 | Expert | Lemmings in a situation | Oh No! More Lemmings / Havoc | 457.29 | 680.30 |  |
| 420 | Expert | Get the Point? | Holiday Lemmings 1994 / Hail | 553.20 | 688.50 |  |
| 421 | Expert | Tricky 26.lvl | Amiga Tricky Budget / fan:lldb-569 | 418.76 | 672.48 |  |
| 422 | Expert | The Far Side | Lemmings / Mayhem | 417.09 | 700.00 |  |
| 423 | Expert | Last one out is a rotten egg! | Lemmings / Mayhem | 398.22 | 700.00 |  |
| 424 | Expert | Christmas Bonus | Xmas Lemmings 1991 / Xmas | 364.92 | 700.00 |  |
| 425 | Expert | And a Happy New Year! | Holiday Lemmings 1994 / Hail | 382.54 | 700.00 |  |
| 426 | Expert | Merry Christmas Mr Lemming | Xmas Lemmings 1991 / Xmas | 385.80 | 700.00 |  |
| 427 | Expert | Lemmings...The Motion Picture | Holiday Lemmings 1993 / Blizzard | 398.87 | 700.00 |  |
| 428 | Expert | They just keep on coming | Lemmings / Tricky | 361.83 | 700.00 |  |
| 429 | Expert | Lemmingology | Lemmings / Tricky | 381.74 | 700.00 |  |
| 430 | Expert | All the 6`s ........ | Lemmings / Tricky | 374.38 | 700.00 |  |
| 431 | Expert | Nightmare on Lem street | Lemmings / Fun | 365.98 | 700.00 |  |
| 432 | Expert | I've lost that Lemming feeling | Lemmings / Fun | 356.12 | 700.00 |  |
| 433 | Expert | The Island of the Wicker people | Lemmings / Tricky | 413.26 | 700.00 |  |
| 434 | Expert | One way or another | Lemmings / Mayhem | 397.09 | 700.00 |  |
| 435 | Expert | Izzie Wizzie lemmings get busy | Lemmings / Taxing | 434.67 | 700.00 |  |
| 436 | Expert | Stepping Stones | Lemmings / Mayhem | 457.22 | 700.00 |  |
| 437 | Expert | POOR WEE CREATURES! | Lemmings / Taxing | 460.80 | 700.00 |  |
| 438 | Expert | Here's one I prepared earlier | Lemmings / Tricky | 426.91 | 700.00 |  |
| 439 | Expert | Lemming Drops | Lemmings / Tricky | 418.77 | 700.00 |  |
| 440 | Expert | Don't let your eyes deceive you | Lemmings / Fun | 488.66 | 700.00 |  |
| 441 | Expert | A Lemming Holiday | Xmas Lemmings 1992 / Xmas | 426.15 | 700.00 |  |
| 442 | Expert | From The Boundary Line | Lemmings / Tricky | 518.09 | 700.00 |  |
| 443 | Expert | The Needs of the Many... | Holiday Lemmings 1993 / Blizzard | 479.80 | 700.00 |  |
| 444 | Expert | Watch out, there`s traps about | Lemmings / Taxing | 537.81 | 700.00 |  |
| 445 | Expert | The ascending pillar scenario | Lemmings / Taxing | 506.15 | 700.00 |  |
| 446 | Expert | Pillars of Hercules | Lemmings / Mayhem | 554.17 | 700.00 |  |
| 447 | Expert | The Crankshaft | Lemmings / Tricky | 537.25 | 700.00 |  |
| 448 | Expert | Been there, seen it, done it | Lemmings / Tricky | 536.62 | 700.00 |  |
| 449 | Expert | Heaven can wait (we hope!!!!) | Lemmings / Taxing | 281.82 | 722.50 |  |
| 450 | Expert | The Fast Food Kitchen... | Lemmings / Mayhem | 562.66 | 700.00 |  |
| 451 | Expert | Rendezvous at the Mountain | Lemmings / Mayhem | 536.15 | 700.00 |  |
| 452 | Expert | Chill out! | Oh No! More Lemmings / Wicked | 558.37 | 700.00 |  |
| 453 | Expert | Feel the pain | joem5 / fan:lldb-320 | 411.24 | 700.00 |  |
| 454 | Expert | Let's get it Started | Deceits Lemmings Extras / fan:lldb-546 | 389.70 | 700.00 |  |
| 455 | Expert | These walls | JMGM02 / fan:lldb-455 | 371.57 | 700.00 |  |
| 456 | Expert | Tricky 27.lvl | Amiga Tricky Budget / fan:lldb-569 | 415.36 | 700.00 |  |
| 457 | Expert | Mayhem 08.lvl | Amiga Mayhem Budget / fan:lldb-571 | 400.32 | 700.00 |  |
| 458 | Expert | DO NOT ENTER | QBeez03 / fan:lldb-33 | 422.09 | 700.00 |  |
| 459 | Expert | Do the Lemmys way! | Lemmy556 My little levels / fan:lldb-65 | 457.22 | 700.00 |  |
| 460 | Expert | Taxing 28.lvl | Amiga Taxing Budget / fan:lldb-570 | 461.25 | 700.00 |  |
| 461 | Expert | From The Boundary Line part two | Conway Challenges 1 / fan:lldb-263 | 444.11 | 700.00 |  |
| 462 | Expert | Tricky 04.lvl | Amiga Tricky Budget / fan:lldb-569 | 429.01 | 700.00 |  |
| 463 | Expert | Fun 15.lvl | Amiga Fun Budget / fan:lldb-568 | 495.68 | 700.00 |  |
| 464 | Expert | In And Out | TimpackD / fan:lldb-102 | 503.74 | 700.00 |  |
| 465 | Expert | Tricky 30.lvl | Amiga Tricky Budget / fan:lldb-569 | 537.25 | 700.00 |  |
| 466 | Expert | Tricky 07.lvl | Amiga Tricky Budget / fan:lldb-569 | 538.72 | 700.00 |  |
| 467 | Expert | Lemmings Get Lost in Afterlife | ssam1221s Lemmings Wicked / fan:lldb-515 | 273.42 | 722.50 |  |
| 468 | Expert | Taxing 03.lvl | Amiga Taxing Budget / fan:lldb-570 | 283.92 | 722.50 |  |
| 469 | Expert | Travelling Lemmings | Nepster01 / fan:lldb-219 | 575.09 | 700.00 |  |
| 470 | Expert | Tricky 23.lvl | Amiga Tricky Budget / fan:lldb-569 | 518.09 | 700.00 |  |
| 471 | Expert | Devil's Right Hand | Nepster01 / fan:lldb-219 | 533.39 | 700.00 |  |
| 472 | Expert | Taxing 11.lvl | Amiga Taxing Budget / fan:lldb-570 | 508.25 | 700.00 |  |
| 473 | Expert | Taxing 02.lvl | Amiga Taxing Budget / fan:lldb-570 | 537.81 | 700.00 |  |
| 474 | Expert | flag test map | Orig Extra Levels / fan:lldb-407 | 516.37 | 700.00 |  |
| 475 | Expert | The Green Mile | Van Clan Tame / fan:lldb-99 | 561.42 | 700.00 |  |
| 476 | Expert | AAAAAARRRRRRGGGGGGHHHHHH!!!!!! | Oh No! More Lemmings / Havoc | 477.17 | 748.00 |  |
| 477 | Expert | It Came Upon a Lemnight Clear | Holiday Lemmings 1993 / Blizzard | 557.79 | 735.25 |  |
| 478 | Expert | Head for the Hills! | Holiday Lemmings 1993 / Flurry | 270.77 | 781.15 | Review |
| 479 | Expert | Now get out of that! | Oh No! More Lemmings / Havoc | 293.69 | 785.88 |  |
| 480 | Expert | The race against cliches | Oh No! More Lemmings / Havoc | 433.13 | 776.14 |  |
| 481 | Expert | MENACING !! | Lemmings / Tricky | 565.10 | 803.25 |  |
| 482 | Expert | Firestorm | GARJEN04 / fan:lldb-284 | 431.34 | 773.50 |  |
| 483 | Expert | Synchronised Lemming | Oh No! More Lemmings / Havoc | 565.10 | 816.00 |  |
| 484 | Expert | And then there were four.... | Lemmings / Mayhem | 569.32 | 816.00 |  |
| 485 | Expert | Mayhem 18.lvl | Amiga Mayhem Budget / fan:lldb-571 | 572.62 | 816.00 |  |
| 486 | Expert | Happy New Year II! | Holiday Lemmings 1994 / Frost | 441.86 | 843.48 |  |
| 487 | Expert | Lemmintaschen? | Holiday Lemmings 1994 / Hail | 474.65 | 843.48 |  |
| 488 | Expert | Keep your hair on Mr. Lemming | Lemmings / Fun | 427.47 | 850.00 |  |
| 489 | Expert | A BeastII of a level | Lemmings / Mayhem | 450.37 | 850.00 |  |
| 490 | Expert | Don't do anything too hasty | Lemmings / Fun | 442.35 | 850.00 |  |
| 491 | Expert | Across The Gap | Oh No! More Lemmings / Crazy | 555.35 | 850.00 |  |
| 492 | Expert | Tailor-made for Athletes | JEFFPCK1 / fan:lldb-235 | 479.06 | 850.00 |  |
| 493 | Expert | Swallowing method 1 | Lemmings platinum Fragle part 2 / fan:lldb-181 | 553.79 | 850.00 |  |
| 494 | Expert | Sudenly lemming | Lemmings platinum Careful Part 1 / fan:lldb-188 | 543.92 | 850.00 |  |
| 495 | Expert | Oscillating Lemmings | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 466.96 | 850.00 |  |
| 496 | Expert | It Takes Two To Tango | Van Clan Tame / fan:lldb-99 | 576.36 | 850.00 |  |
| 497 | Expert | This is a doddle | JM09 / fan:lldb-335 | 543.20 | 850.00 |  |
| 498 | Expert | Floaters Away! | cLemmings Tricky / fan:lldb-527 | 589.55 | 850.00 |  |
| 499 | Expert | Double Lemmings | KillerMasters Lemmings 2 Tame / fan:lldb-510 | 631.46 | 850.00 |  |
| 500 | Expert | Free Lemmings | Oh No More cLemmings Tame / fan:lldb-530 | 620.59 | 850.00 |  |
| 501 | Expert | Be Careful... | Lemmings Plus DOS Project Mild / fan:lldb-551 | 583.08 | 850.00 |  |
| 502 | Expert | The Graveyard | Lemmings Plus DOS Project Mild / fan:lldb-551 | 633.39 | 850.00 |  |
| 503 | Expert | Remember where you find them! | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 659.90 | 850.00 |  |
