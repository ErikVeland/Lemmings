# Oh My! All Lemmings!

572 levels: all 352 official Classic levels and 220 distinct replay-validated fan levels from 85 packs.

## Ordering

The path progresses through Fun, Intermediate, Difficult and Expert. A hard timing, coordination or planning demand cannot be cancelled by easy dimensions in a weighted average. Pack origin, retail rank and campaign order do not determine placement. All Oh No! levels are interleaved with the rest of the pool.

Stages: Fun 45; Intermediate 116; Difficult 284; Expert 127. Largest upward curriculum-demand step: 55.25/1000. Transitions requiring review: 2; missing basic-skill preparation: 0.

| Stage | Steps | Teaching focus |
| --- | ---: | --- |
| Fun | 1–45 | Single skills and simple combinations |
| Intermediate | 46–161 | Skill combinations and crowd management |
| Difficult | 162–445 | Longer plans and tighter resources |
| Expert | 446–572 | Precision, complex plans and coordination |

Curriculum demand is the maximum of the unchanged evidence score, 0.85 × technique, precision, concurrency and deduction, 0.70 × solution complexity, 0.50 × constraints, and 90 × additional concepts. A combination also waits for its easiest available isolated skill lessons. These weights and the stage thresholds (180, 360, 600) are editorial estimates, not player-calibrated difficulty measurements.

Within each stage, 35-point bands allow spaced practice and small relief steps. Selection favours prepared combinations, avoids consecutive identical technique sets when comparable alternatives exist, and reduces upward component changes. Two-skill combinations require one earlier exposure per basic skill; larger combinations seek two. Exposure means a practice opportunity, not demonstrated mastery. New coordination and crowd-spacing concepts can be introduced through familiar skills.

Raw evidence scores remain unchanged and are reported separately. Their largest upward step is 291.17, with 267 decreases. The curriculum demand does not certify every component transition as smooth; all component changes and support flags are retained in transitions.json.

Oh No! has all 100 levels in the shared path. Its original largest raw-score jump was 348.77; its largest incoming raw-score jump here is 229.19. This is a diagnostic, not the sequencing objective.

The score uses validated solution techniques, solution complexity, timing perturbations, concurrent workers, constraints and a deduction proxy. It is an estimate of human difficulty, not direct measurement of insight. A winning route proves solvability; a low score does not prove that its solution is obvious. Unresolved component jumps stay visible in the report.

## Remaining transition reviews

- Step 37, **Thunder-Lemmings are go!** (Fun): new execution-demand high rises by 176.7/1000. Check timing forgiveness with a novice before calling this transition smooth.
- Step 542, **Head for the Hills!** (Expert): new execution-demand high rises by 214.4/1000. Check timing forgiveness with a novice before calling this transition smooth.

## Fan evidence

The full Classic corpus contains 6,374 entries. Additional routes are proposed from matching terrain, similar terrain and bounded reactive skill policies. Each accepted route is replayed against the complete candidate simulation, checked for a winning result, and analysed with timing perturbations. Source fingerprints and initial-state hashes must match. Blank/hands-free fan entries are excluded from bridges. Fan copies of official puzzles are excluded using a gameplay signature that ignores names and viewport positions, includes resources, objects and rendered masks, and is independent of the release variant. Duplicate fan scenarios and initial states are also excluded. Unsolved candidates retain low confidence and are not passed off as measured bridges.

The bounded search is not a complete solver. Failure to find a route does not imply that a level is impossible. The chosen fan count is an outcome of evidence and deduplication, not a quota.

## Validation

The generator checks reversed-input determinism, complete official coverage and the exact replay digest for every selected fan level. The existing 220 selected fan witnesses were previously replayed successfully against the native simulation; this revision changes their order, not their levels or solutions. See validation.json for the current test and build results. Human insight, stage calibration and novice frustration still need playtesting.

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
| 1 | Fun | Just dig ! | Genesis Fun / fan:lldb-488 | 44.74 | 55.25 |  |
| 2 | Fun | Only Float is Survive | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 46.84 | 55.25 |  |
| 3 | Fun | Just dig! | Lemmings / Fun | 44.74 | 55.25 |  |
| 4 | Fun | Float Or Die | TWPAK00 / fan:lldb-302 | 46.53 | 55.25 |  |
| 5 | Fun | Just Dig! | Oh No More cLemmings Tame / fan:lldb-530 | 45.49 | 56.17 |  |
| 6 | Fun | Only floaters can survive this | Lemmy556 My little levels 2 / fan:lldb-66 | 40.57 | 56.70 |  |
| 7 | Fun | Climin' Death Mountain | TWPAK00 / fan:lldb-302 | 50.79 | 58.13 |  |
| 8 | Fun | PRACTICE: DIGGER | Mikepak07 / fan:lldb-12 | 45.89 | 57.68 |  |
| 9 | Fun | Mienrs <--- lol, typo | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 46.86 | 61.42 |  |
| 10 | Fun | Climbing in life... | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 52.11 | 61.29 |  |
| 11 | Fun | Only Floaters Can Survive This | Oh No More cLemmings Tame / fan:lldb-530 | 50.65 | 62.58 |  |
| 12 | Fun | You Need Bashers This Time | Oh No More cLemmings Tame / fan:lldb-530 | 49.05 | 63.48 |  |
| 13 | Fun | Only floaters can survive this | Genesis Fun / fan:lldb-488 | 56.43 | 79.89 |  |
| 14 | Fun | You need bashers this time | Lemmings / Fun | 67.67 | 88.11 |  |
| 15 | Fun | Up Up UP They Go | Van Clan Tame / fan:lldb-88 | 65.20 | 103.44 |  |
| 16 | Fun | Surprise Package? | Holiday Lemmings 1994 / Hail | 32.93 | 113.20 |  |
| 17 | Fun | Let's block and blow | Lemmings / Fun | 67.41 | 110.92 |  |
| 18 | Fun | Just Climb Mountain! | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 67.43 | 118.49 |  |
| 19 | Fun | Digging Only | joem7 / fan:lldb-322 | 62.54 | 121.74 |  |
| 20 | Fun | The Wall Trilogy Part 1 | TWPAK03 / fan:lldb-305 | 68.31 | 121.88 |  |
| 21 | Fun | Step By Step Guide To Building | Van Clan Tame / fan:lldb-88 | 71.46 | 131.07 |  |
| 22 | Fun | Bash This! | Van Clan Tame / fan:lldb-88 | 73.91 | 136.96 |  |
| 23 | Fun | Test Of Skill | Oh Yes! More Lemmings! / Oh No! More Lemmings Versus | 48.52 | 144.50 |  |
| 24 | Fun | Holiday Mining | Holiday Lemmings 1993 / Flurry | 71.37 | 144.50 |  |
| 25 | Fun | Give And Take | Oh Yes! More Lemmings! / Oh No! More Lemmings Versus | 47.91 | 144.50 |  |
| 26 | Fun | Citizen Lemming | Oh No! More Lemmings / Tame | 80.86 | 144.50 |  |
| 27 | Fun | In the thick of the fray | Oh Yes! More Lemmings! / Lemmings Versus | 79.18 | 144.50 |  |
| 28 | Fun | Lemmings Lemmings everywhere | Genesis Fun / fan:lldb-488 | 71.12 | 144.50 |  |
| 29 | Fun | Lemmings For Presidents! | Oh No! More Lemmings / Tame | 114.93 | 147.32 |  |
| 30 | Fun | Fun 25.lvl | Amiga Fun / fan:lldb-568 | 71.79 | 144.50 |  |
| 31 | Fun | The Pipe Room... | Oh Yes! More Lemmings! / Lemmings Versus | 44.05 | 161.50 |  |
| 32 | Fun | Lemmings Lemmings everywhere | Lemmings / Fun | 71.79 | 144.50 |  |
| 33 | Fun | I Want It All | Oh Yes! More Lemmings! / Oh No! More Lemmings Versus | 121.01 | 148.75 |  |
| 34 | Fun | Match Of The Day | Oh Yes! More Lemmings! / Oh No! More Lemmings Versus | 83.57 | 158.98 |  |
| 35 | Fun | Everyone turn left (Part two) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 86.77 | 164.32 |  |
| 36 | Fun | Floating Down! | Holiday cLemmings Frost / fan:lldb-535 | 81.34 | 170.47 |  |
| 37 | Fun | Thunder-Lemmings are go! | Oh No! More Lemmings / Tame | 151.62 | 151.62 | Review |
| 38 | Fun | Still everything to play for | Oh Yes! More Lemmings! / Lemmings Versus | 71.69 | 170.00 |  |
| 39 | Fun | Frostbite | Van Clan Tame / fan:lldb-99 | 69.26 | 170.00 |  |
| 40 | Fun | and the winner is..... | Oh Yes! More Lemmings! / Lemmings Versus | 132.21 | 163.11 |  |
| 41 | Fun | Pollution | JM01 / fan:lldb-327 | 80.99 | 170.00 |  |
| 42 | Fun | Get a little extra help | Oh No! More Lemmings / Tame | 120.08 | 170.39 |  |
| 43 | Fun | Floating Lemming Flurry | Holiday Lemmings 1993 / Flurry | 146.74 | 170.46 |  |
| 44 | Fun | The Duel | Oh Yes! More Lemmings! / Oh No! More Lemmings Versus | 142.43 | 173.57 |  |
| 45 | Fun | Bomboozal | Lemmings / Taxing | 83.79 | 179.28 |  |
| 46 | Intermediate | Tricky 28.lvl | Amiga Tricky / fan:lldb-569 | 149.33 | 180.00 |  |
| 47 | Intermediate | Lemming Snowfall | Holiday Lemmings 1993 / Flurry | 141.84 | 187.00 |  |
| 48 | Intermediate | Lost something? | Lemmings / Tricky | 148.88 | 180.00 |  |
| 49 | Intermediate | As long as you try your best. | Crystal Remakes / fan:lldb-130 | 77.49 | 195.50 |  |
| 50 | Intermediate | Islands in the Sky | Oh Yes! More Lemmings! / Lemmings Versus | 94.40 | 198.50 |  |
| 51 | Intermediate | Pea Soup | Lemmings / Mayhem | 98.34 | 202.99 |  |
| 52 | Intermediate | At Home in a Cave | Holiday Lemmings 1993 / Flurry | 142.14 | 196.20 |  |
| 53 | Intermediate | A task for blockers and bombers | Lemmings / Fun | 129.82 | 198.50 |  |
| 54 | Intermediate | Custom built for Lemmings | Oh No! More Lemmings / Tame | 166.54 | 189.12 |  |
| 55 | Intermediate | 5 miles if you love Lemmings | Genesis Fun / fan:lldb-488 | 154.07 | 204.53 |  |
| 56 | Intermediate | The Undiscovered Country | Holiday Lemmings 1993 / Blizzard | 159.71 | 204.53 |  |
| 57 | Intermediate | Alternate Route | Lemmings The Official Companion / fan:lldb-585 | 138.48 | 202.49 |  |
| 58 | Intermediate | Not as complicated as it looks | Lemmings / Fun | 149.97 | 209.58 |  |
| 59 | Intermediate | Division Bell | Holiday Lemmings 1994 / Frost | 96.03 | 212.84 |  |
| 60 | Intermediate | Merry Lemmings | Van Clan Tame / fan:lldb-99 | 149.84 | 220.42 |  |
| 61 | Intermediate | Fun 08.lvl | Amiga Fun / fan:lldb-568 | 153.08 | 212.50 |  |
| 62 | Intermediate | The Rubbish Dump | Oh Yes! More Lemmings! / Lemmings Versus | 158.18 | 219.00 |  |
| 63 | Intermediate | Mayhem 28.lvl | Amiga Mayhem / fan:lldb-571 | 199.18 | 210.70 |  |
| 64 | Intermediate | King of the castle (part two) | Conway Challenges 1 / fan:lldb-263 | 171.50 | 221.00 |  |
| 65 | Intermediate | Mind the step..... | Lemmings / Mayhem | 199.18 | 210.70 |  |
| 66 | Intermediate | Lemming sanctuary in sight | Genesis Tricky / fan:lldb-489 | 159.75 | 221.00 |  |
| 67 | Intermediate | The Only Way Out | Oh Yes! More Lemmings! / Oh No! More Lemmings Versus | 181.57 | 228.08 |  |
| 68 | Intermediate | Level 06.lvl | Amiga Demo Two Player / fan:lldb-582 | 135.16 | 233.75 |  |
| 69 | Intermediate | Christmas South of the Equator | Holiday Lemmings 1993 / Flurry | 124.08 | 233.75 |  |
| 70 | Intermediate | Jingle Lemming | Xmas Lemmings 1992 / Xmas | 109.70 | 233.75 |  |
| 71 | Intermediate | Tricky 08.lvl | Amiga Tricky / fan:lldb-569 | 148.92 | 221.00 |  |
| 72 | Intermediate | Honey, I Saved The Lemmings | Oh No! More Lemmings / Tame | 132.06 | 233.75 |  |
| 73 | Intermediate | Intsy-Wintsy...Lemming? | Oh No! More Lemmings / Tame | 132.74 | 233.75 |  |
| 74 | Intermediate | There can be only one | Oh Yes! More Lemmings! / Lemmings Versus | 135.13 | 233.75 |  |
| 75 | Intermediate | King of the castle | Genesis Taxing / fan:lldb-490 | 172.87 | 221.00 |  |
| 76 | Intermediate | Fun 21.lvl | Amiga Fun / fan:lldb-568 | 202.83 | 228.08 |  |
| 77 | Intermediate | Lemming sanctuary in sight | Lemmings / Tricky | 146.54 | 221.00 |  |
| 78 | Intermediate | You Live and Lem | Lemmings / Fun | 202.83 | 228.08 |  |
| 79 | Intermediate | King of the castle | Lemmings / Taxing | 170.33 | 221.00 |  |
| 80 | Intermediate | Taxing 23.lvl | Amiga Taxing / fan:lldb-570 | 172.88 | 221.00 |  |
| 81 | Intermediate | Builders will help you here | Lemmings / Fun | 155.98 | 221.00 |  |
| 82 | Intermediate | Taxing 15.lvl | Amiga Taxing / fan:lldb-570 | 184.84 | 221.00 |  |
| 83 | Intermediate | What an AWESOME level | Lemmings / Taxing | 184.84 | 221.00 |  |
| 84 | Intermediate | Fun 19.lvl | Amiga Fun / fan:lldb-568 | 190.08 | 276.25 |  |
| 85 | Intermediate | Choose Your Solution | SeverSet1 / fan:lldb-183 | 162.68 | 265.73 |  |
| 86 | Intermediate | Just a Minute (Part Two) | Lemmings / Mayhem | 212.30 | 262.32 |  |
| 87 | Intermediate | Let's go camping. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 211.40 | 275.93 |  |
| 88 | Intermediate | 32 Lemmings Below Zero | Holiday Lemmings 1993 / Flurry | 181.88 | 263.56 |  |
| 89 | Intermediate | Fun 28.lvl | Amiga Fun / fan:lldb-568 | 198.34 | 270.56 |  |
| 90 | Intermediate | Lemm Of All Trades | TWPAK12 / fan:lldb-314 | 195.52 | 273.00 |  |
| 91 | Intermediate | If only they could fly | Lemmings / Fun | 198.34 | 270.56 |  |
| 92 | Intermediate | Take good care of my Lemmings | Lemmings / Fun | 190.08 | 276.25 |  |
| 93 | Intermediate | No Problemming! | Oh No! More Lemmings / Crazy | 260.16 | 276.25 |  |
| 94 | Intermediate | Careless clicking costs lives | Lemmings / Tricky | 190.58 | 276.25 |  |
| 95 | Intermediate | The Steel Mines of Kessel | Lemmings / Mayhem | 212.48 | 273.01 |  |
| 96 | Intermediate | Taxing 25.lvl | Amiga Taxing / fan:lldb-570 | 215.15 | 276.25 |  |
| 97 | Intermediate | Turn around young lemmings! | Lemmings / Tricky | 180.25 | 277.23 |  |
| 98 | Intermediate | Steel Block Party | Holiday Lemmings 1994 / Hail | 204.01 | 273.99 |  |
| 99 | Intermediate | Follow the leader... | Lemmings / Taxing | 215.15 | 276.25 |  |
| 100 | Intermediate | Tightrope City | Lemmings / Tricky | 264.39 | 275.42 |  |
| 101 | Intermediate | The Art Gallery | Lemmings / Taxing | 226.89 | 276.25 |  |
| 102 | Intermediate | Tricky 22.lvl | Amiga Tricky / fan:lldb-569 | 183.36 | 281.11 |  |
| 103 | Intermediate | Float and Dig | brickpk1 / fan:lldb-558 | 173.52 | 293.04 |  |
| 104 | Intermediate | Lemming Friendly | Oh No! More Lemmings / Crazy | 253.66 | 281.05 |  |
| 105 | Intermediate | Chains of Command | Holiday Lemmings 1994 / Frost | 160.98 | 296.56 |  |
| 106 | Intermediate | Many Lemmings make level work | Oh No! More Lemmings / Crazy | 149.29 | 303.69 |  |
| 107 | Intermediate | The Iron Puzzle | TimballistoPack1 / fan:lldb-354 | 297.58 | 297.58 |  |
| 108 | Intermediate | Clouds of Lemmings | Holiday Lemmings 1993 / Flurry | 209.58 | 302.56 |  |
| 109 | Intermediate | Take what you can, when you can | Oh Yes! More Lemmings! / Lemmings Versus | 202.02 | 298.94 |  |
| 110 | Intermediate | Taxing 24.lvl | Amiga Taxing / fan:lldb-570 | 245.36 | 301.05 |  |
| 111 | Intermediate | Lemming Snowjourn | Holiday Lemmings 1993 / Flurry | 189.31 | 306.00 |  |
| 112 | Intermediate | Take a running jump..... | Lemmings / Taxing | 244.56 | 301.05 |  |
| 113 | Intermediate | Turn around and look. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 218.50 | 306.00 |  |
| 114 | Intermediate | Yo-yo Lem-lem | Holiday Lemmings 1993 / Flurry | 246.94 | 308.30 |  |
| 115 | Intermediate | Ice Ice Lemming | Oh No! More Lemmings / Crazy | 262.47 | 303.83 |  |
| 116 | Intermediate | As long as you try your best | Genesis Fun / fan:lldb-488 | 247.06 | 308.51 |  |
| 117 | Intermediate | Smile if you love lemmings | Lemmings / Fun | 234.36 | 308.71 |  |
| 118 | Intermediate | Fun 09.lvl | Amiga Fun / fan:lldb-568 | 247.06 | 308.51 |  |
| 119 | Intermediate | Only floaters can survive this | Lemmings / Fun | 121.12 | 322.05 |  |
| 120 | Intermediate | Diggin' to a better world | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 121.63 | 324.01 |  |
| 121 | Intermediate | PRACTICE: FLOATER | Mikepak07 / fan:lldb-12 | 121.89 | 325.03 |  |
| 122 | Intermediate | Climb to victory | PSP Special 1 10 of 36 / fan:lldb-216 | 120.02 | 326.71 |  |
| 123 | Intermediate | Egypt Fall | Anatol00 / fan:lldb-3 | 125.77 | 324.53 |  |
| 124 | Intermediate | Lemming Express | Oh No! More Lemmings / Crazy | 182.04 | 317.75 |  |
| 125 | Intermediate | Float to safety | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 124.82 | 336.28 |  |
| 126 | Intermediate | I am A.T. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 232.62 | 331.74 |  |
| 127 | Intermediate | Last Lemming To Lemmingcentral | Oh No! More Lemmings / Wicked | 190.08 | 341.00 |  |
| 128 | Intermediate | Meeting Adjourned | Oh No! More Lemmings / Wild | 269.12 | 331.50 |  |
| 129 | Intermediate | Lemming Tracks in the Snow! | Holiday Lemmings 1993 / Flurry | 239.12 | 331.50 |  |
| 130 | Intermediate | Lock up your Lemmings | Lemmings / Fun | 283.85 | 319.20 |  |
| 131 | Intermediate | Down And Out Lemmings | Oh No! More Lemmings / Tame | 215.08 | 326.20 |  |
| 132 | Intermediate | Just for fun or to the death? | Oh Yes! More Lemmings! / Lemmings Versus | 278.95 | 331.50 |  |
| 133 | Intermediate | Taxing 27.lvl | Amiga Taxing / fan:lldb-570 | 290.54 | 331.50 |  |
| 134 | Intermediate | Tricky 29.lvl | Amiga Tricky / fan:lldb-569 | 301.11 | 331.50 |  |
| 135 | Intermediate | The Curse of Devil | Mad00 / fan:lldb-55 | 259.27 | 330.08 |  |
| 136 | Intermediate | Save the Lemmings with Floaters | PSP Special 1 10 of 36 / fan:lldb-216 | 232.61 | 328.18 |  |
| 137 | Intermediate | Lemming Hotel | Oh No! More Lemmings / Wild | 242.86 | 337.12 |  |
| 138 | Intermediate | A TOWERING PROBLEM | Oh No! More Lemmings / Wicked | 304.89 | 331.13 |  |
| 139 | Intermediate | Bitter Lemming | Genesis Tricky / fan:lldb-489 | 240.52 | 336.00 |  |
| 140 | Intermediate | Easy when you know how | Lemmings / Fun | 256.86 | 331.50 |  |
| 141 | Intermediate | Call in the bomb squad | Lemmings / Taxing | 288.44 | 331.50 |  |
| 142 | Intermediate | Rainbow Island | Lemmings / Tricky | 301.05 | 331.50 |  |
| 143 | Intermediate | How do you get up there? | JM10 / fan:lldb-336 | 320.08 | 331.50 |  |
| 144 | Intermediate | Bitter Lemming | Lemmings / Tricky | 239.79 | 336.00 |  |
| 145 | Intermediate | Fun 20.lvl | Amiga Fun / fan:lldb-568 | 275.22 | 337.32 |  |
| 146 | Intermediate | Gone With The Lemming | Oh No! More Lemmings / Tame | 216.33 | 347.20 |  |
| 147 | Intermediate | We are now at LEMCON ONE | Lemmings / Fun | 273.12 | 337.32 |  |
| 148 | Intermediate | Time to get up! | Lemmings / Mayhem | 319.74 | 331.50 |  |
| 149 | Intermediate | It`s a trade off | Oh No! More Lemmings / Crazy | 272.03 | 346.74 |  |
| 150 | Intermediate | The Long Way Around | Holiday Lemmings 1993 / Flurry | 305.15 | 349.33 |  |
| 151 | Intermediate | A Block from Home | Holiday Lemmings 1993 / Flurry | 348.40 | 348.40 |  |
| 152 | Intermediate | Downwardly Mobile Lemmings | Oh No! More Lemmings / Tame | 160.51 | 350.62 |  |
| 153 | Intermediate | Luvly Jubly | Lemmings / Tricky | 205.59 | 350.30 |  |
| 154 | Intermediate | New Lemmings On The Block | Oh No! More Lemmings / Tame | 161.16 | 350.62 |  |
| 155 | Intermediate | A long way to go | Giga pack 09 / fan:lldb-171 | 322.32 | 359.18 |  |
| 156 | Intermediate | Taxing 12.lvl | Amiga Taxing / fan:lldb-570 | 321.04 | 351.32 |  |
| 157 | Intermediate | Lemming Head | Oh No! More Lemmings / Wild | 297.54 | 357.48 |  |
| 158 | Intermediate | Going up....... | Lemmings / Mayhem | 292.20 | 355.38 |  |
| 159 | Intermediate | Confrontation | Oh Yes! More Lemmings! / Oh No! More Lemmings Versus | 164.20 | 350.62 |  |
| 160 | Intermediate | Livin` On The Edge | Lemmings / Taxing | 318.94 | 351.32 |  |
| 161 | Intermediate | Mayhem 23.lvl | Amiga Mayhem / fan:lldb-571 | 294.30 | 355.38 |  |
| 162 | Difficult | The Boiler Room (part two) | Conway Challenges 2 / fan:lldb-264 | 232.70 | 362.40 |  |
| 163 | Difficult | Konbanwa Lemming san | Lemmings / Fun | 271.56 | 360.00 |  |
| 164 | Difficult | The Boiler Room | Lemmings / Mayhem | 230.65 | 362.40 |  |
| 165 | Difficult | Level 08 (extra).lvl | Amiga Demo Two Player / fan:lldb-582 | 279.53 | 360.00 |  |
| 166 | Difficult | Stairway To Nowhere | Timpack11 / fan:lldb-98 | 134.12 | 362.58 |  |
| 167 | Difficult | Climbers can climb the wall | Deceits Lemmings Extras / fan:lldb-546 | 133.34 | 369.08 |  |
| 168 | Difficult | Floaters can land safely | Deceits Lemmings Extras / fan:lldb-546 | 134.25 | 372.57 |  |
| 169 | Difficult | Miners Can Mine Diagonally | Deceits Lemmings Extras / fan:lldb-546 | 136.08 | 371.53 |  |
| 170 | Difficult | Exit for Hell! | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 193.67 | 367.41 |  |
| 171 | Difficult | Crush & Crash 2 | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 232.58 | 365.58 |  |
| 172 | Difficult | Flow Control | Oh No! More Lemmings / Havoc | 249.06 | 361.82 |  |
| 173 | Difficult | Quote: "That`s a good level" | Oh No! More Lemmings / Crazy | 271.74 | 364.06 |  |
| 174 | Difficult | The Wrath of Lem | Holiday Lemmings 1993 / Blizzard | 260.08 | 371.17 |  |
| 175 | Difficult | SNOW JOKE | Oh No! More Lemmings / Wild | 266.41 | 365.28 |  |
| 176 | Difficult | Anxiety | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 261.73 | 371.60 |  |
| 177 | Difficult | De-fusing a time bomb | Snow remakes 01 / fan:lldb-144 | 235.29 | 375.46 |  |
| 178 | Difficult | Good game! Good game! | Oh Yes! More Lemmings! / Lemmings Versus | 277.40 | 360.00 |  |
| 179 | Difficult | Peak of Performance | Holiday Lemmings 1994 / Hail | 262.66 | 367.98 |  |
| 180 | Difficult | Train your body | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 269.76 | 360.53 |  |
| 181 | Difficult | Two heads are better... | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 265.30 | 374.91 |  |
| 182 | Difficult | If at first you don`t succeed.. | Lemmings / Taxing | 238.73 | 381.21 |  |
| 183 | Difficult | The Final Frontier | Holiday Lemmings 1993 / Blizzard | 275.78 | 374.49 |  |
| 184 | Difficult | Tribute to M.C.Escher | Lemmings / Taxing | 320.79 | 372.57 |  |
| 185 | Difficult | Dangerzone | Oh No! More Lemmings / Tame | 240.43 | 377.08 |  |
| 186 | Difficult | Mayhem 05.lvl | Amiga Mayhem / fan:lldb-571 | 331.74 | 381.98 |  |
| 187 | Difficult | V For Vendetta | Van Clan Tame / fan:lldb-88 | 303.71 | 383.00 |  |
| 188 | Difficult | Exodus! | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 378.92 | 378.92 |  |
| 189 | Difficult | Down, along, up. In that order | Lemmings / Mayhem | 331.74 | 381.98 |  |
| 190 | Difficult | Maybe not such a doddle | Holiday Lemmings 1994 / Frost | 289.29 | 386.75 |  |
| 191 | Difficult | Tricky 01.lvl | Amiga Tricky / fan:lldb-569 | 303.50 | 386.75 |  |
| 192 | Difficult | Game on!  Choose your tactics. | Oh Yes! More Lemmings! / Lemmings Versus | 314.25 | 386.75 |  |
| 193 | Difficult | Fun 27.lvl | Amiga Fun / fan:lldb-568 | 288.66 | 386.75 |  |
| 194 | Difficult | This should be a doddle! | Lemmings / Tricky | 299.58 | 386.75 |  |
| 195 | Difficult | Let's be careful out there | Lemmings / Fun | 288.66 | 386.75 |  |
| 196 | Difficult | Lemmings in the attic | Lemmings / Tricky | 309.71 | 386.75 |  |
| 197 | Difficult | Showdown! | Oh Yes! More Lemmings! / Oh No! More Lemmings Versus | 319.77 | 386.75 |  |
| 198 | Difficult | Triple trouble | Genesis Taxing / fan:lldb-490 | 346.63 | 386.75 |  |
| 199 | Difficult | Cross-over Point | Oh Yes! More Lemmings! / Lemmings Versus | 330.95 | 386.75 |  |
| 200 | Difficult | Triple Trouble | Lemmings / Taxing | 341.86 | 386.75 |  |
| 201 | Difficult | With Compliments | Oh No! More Lemmings / Tame | 231.34 | 397.63 |  |
| 202 | Difficult | The Lemming Learning Curve | Oh No! More Lemmings / Wicked | 325.11 | 386.75 |  |
| 203 | Difficult | 2 Minutes before midnight | Holiday Lemmings 1994 / Frost | 202.25 | 393.73 |  |
| 204 | Difficult | Climbing Will Help, Now | Holiday cLemmings Frost / fan:lldb-535 | 142.48 | 404.21 |  |
| 205 | Difficult | Float to safety | JM01 / fan:lldb-327 | 146.19 | 409.02 |  |
| 206 | Difficult | Bridge In A Fridge | TWPAK00 / fan:lldb-302 | 146.28 | 409.35 |  |
| 207 | Difficult | Just Float | TimpackE / fan:lldb-103 | 146.51 | 410.24 |  |
| 208 | Difficult | Which Exit? | beta / fan:lldb-371 | 141.96 | 408.35 |  |
| 209 | Difficult | Happy Holidays Mr Lemming! | Xmas Lemmings 1992 / Xmas | 179.60 | 404.15 |  |
| 210 | Difficult | It's Lemmingentry Watson | Lemmings / Tricky | 216.70 | 400.45 |  |
| 211 | Difficult | Dying Dream | Nepster01 / fan:lldb-219 | 228.62 | 395.97 |  |
| 212 | Difficult | Ice Station Lemming | Oh No! More Lemmings / Wild | 243.02 | 388.29 |  |
| 213 | Difficult | Have an ice day | Oh No! More Lemmings / Havoc | 284.08 | 385.65 |  |
| 214 | Difficult | Build Block | KillerMasters Lemmings 1 Wicked / fan:lldb-508 | 150.39 | 413.96 |  |
| 215 | Difficult | Training 07 - Let's Mine! | JEFFPCK6 / fan:lldb-240 | 145.52 | 415.92 |  |
| 216 | Difficult | Fun 04.lvl | Amiga Fun / fan:lldb-568 | 196.72 | 408.85 |  |
| 217 | Difficult | Dolly Dimple | Oh No! More Lemmings / Crazy | 312.59 | 391.76 |  |
| 218 | Difficult | Now use miners and climbers | Lemmings / Fun | 194.62 | 408.85 |  |
| 219 | Difficult | Watch right or left (Part two) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 357.49 | 387.91 |  |
| 220 | Difficult | Be sure to be a builder. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 302.66 | 388.98 |  |
| 221 | Difficult | LOoK BeFoRe YoU LeAp! | Oh No! More Lemmings / Havoc | 296.68 | 395.44 |  |
| 222 | Difficult | Now use miners and climbers | Crystal Remakes / fan:lldb-130 | 196.95 | 409.76 |  |
| 223 | Difficult | The Great Lemming Caper | Lemmings / Mayhem | 342.90 | 386.75 |  |
| 224 | Difficult | No world without you | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 382.47 | 386.75 |  |
| 225 | Difficult | Break On Through | Holiday Lemmings 1994 / Hail | 292.72 | 394.38 |  |
| 226 | Difficult | The Crossroads | Genesis Mayhem / fan:lldb-491 | 196.58 | 417.92 |  |
| 227 | Difficult | You going to Lemming Master | KillerMasters Lemmings 1 Havoc / fan:lldb-509 | 271.51 | 410.62 |  |
| 228 | Difficult | Mayhem 04.lvl | Amiga Mayhem / fan:lldb-571 | 196.58 | 417.92 |  |
| 229 | Difficult | Climbing to the Top! | Holiday Lemmings 1993 / Flurry | 240.38 | 417.92 |  |
| 230 | Difficult | The Crossroads | Lemmings / Mayhem | 180.36 | 417.92 |  |
| 231 | Difficult | Lemming Reunification | Holiday Lemmings 1994 / Frost | 289.34 | 417.92 |  |
| 232 | Difficult | Taxing 26.lvl | Amiga Taxing / fan:lldb-570 | 346.62 | 386.75 |  |
| 233 | Difficult | Steel Works | Lemmings / Mayhem | 333.15 | 401.72 |  |
| 234 | Difficult | Rent-a-Lemming | Oh No! More Lemmings / Tame | 319.26 | 408.13 |  |
| 235 | Difficult | Fun 29.lvl | Amiga Fun / fan:lldb-568 | 240.62 | 412.58 |  |
| 236 | Difficult | Steel Works (part two) | Conway Challenges 1 / fan:lldb-263 | 335.49 | 401.72 |  |
| 237 | Difficult | worra lorra lemmings | Lemmings / Fun | 240.62 | 412.58 |  |
| 238 | Difficult | In The Style Of... | Lemmings Plus DOS Project Mild / fan:lldb-551 | 301.13 | 400.44 |  |
| 239 | Difficult | Presents of Mind II | Holiday Lemmings 1993 / Blizzard | 321.70 | 406.61 |  |
| 240 | Difficult | Higgledy Piggledy | Oh No! More Lemmings / Wild | 316.87 | 416.03 |  |
| 241 | Difficult | Perseverance | Genesis Taxing / fan:lldb-490 | 322.86 | 402.64 |  |
| 242 | Difficult | Have a Pleasant Journey ! | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 268.04 | 395.76 |  |
| 243 | Difficult | The North Poles | Xmas Lemmings 1992 / Xmas | 292.83 | 408.89 |  |
| 244 | Difficult | Spiral staircase | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 278.68 | 415.89 |  |
| 245 | Difficult | Perseverance | Lemmings / Taxing | 320.77 | 402.67 |  |
| 246 | Difficult | Worra load of old blocks! | Oh No! More Lemmings / Crazy | 363.16 | 407.75 |  |
| 247 | Difficult | Watch your step | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 308.23 | 416.39 |  |
| 248 | Difficult | Mary Poppins` land | Lemmings / Taxing | 338.28 | 396.82 |  |
| 249 | Difficult | Scaling the Heights | Oh No! More Lemmings / Havoc | 372.17 | 403.50 |  |
| 250 | Difficult | Taxing 16.lvl | Amiga Taxing / fan:lldb-570 | 338.55 | 397.86 |  |
| 251 | Difficult | Mayhem 07.lvl | Amiga Mayhem / fan:lldb-571 | 351.25 | 414.93 |  |
| 252 | Difficult | Lemmy in the cold, cold ground | Holiday Lemmings 1994 / Hail | 359.03 | 414.75 |  |
| 253 | Difficult | Poles Apart | Lemmings / Mayhem | 349.15 | 414.93 |  |
| 254 | Difficult | You Take the High Road | Oh No! More Lemmings / Wild | 383.35 | 412.58 |  |
| 255 | Difficult | Mayhem 09.lvl | Amiga Mayhem / fan:lldb-571 | 314.55 | 413.48 |  |
| 256 | Difficult | gronklems -1.dat 1 | Gronklems 1 / fan:lldb-386 | 276.82 | 408.13 |  |
| 257 | Difficult | Curse of the Pharaohs | Lemmings / Mayhem | 314.49 | 413.48 |  |
| 258 | Difficult | Mayhem 20.lvl | Amiga Mayhem / fan:lldb-571 | 366.30 | 416.59 |  |
| 259 | Difficult | No added colours or Lemmings | Lemmings / Mayhem | 364.20 | 416.59 |  |
| 260 | Difficult | Intro to MCMarshy01.dat | MARSHY01 / fan:lldb-345 | 140.79 | 422.68 |  |
| 261 | Difficult | Diet Lemmingaid | Lemmings / Tricky | 144.50 | 422.94 |  |
| 262 | Difficult | Only climbers can do this | MARSHY01 / fan:lldb-345 | 149.82 | 422.98 |  |
| 263 | Difficult | Fun 13.lvl | Amiga Fun / fan:lldb-568 | 152.63 | 425.70 |  |
| 264 | Difficult | Climbing all the way | ANTHPCK1 / fan:lldb-221 | 152.90 | 425.01 |  |
| 265 | Difficult | Tailor-made for floaters | MARSHY01 / fan:lldb-345 | 154.99 | 429.86 |  |
| 266 | Difficult | Weave Your Lemmings | TWPAK09 / fan:lldb-311 | 180.38 | 428.07 |  |
| 267 | Difficult | Training 02 - Let's Float! | JEFFPCK6 / fan:lldb-240 | 150.00 | 433.14 |  |
| 268 | Difficult | Tricky 02.lvl | Amiga Tricky / fan:lldb-569 | 157.60 | 435.04 |  |
| 269 | Difficult | The Impossible Gap | MARSHY07 / fan:lldb-351 | 150.28 | 440.36 |  |
| 270 | Difficult | The Box. | isupck02 / fan:lldb-353 | 182.04 | 434.45 |  |
| 271 | Difficult | Separate Ways | Holiday Lemmings 1994 / Frost | 182.16 | 434.92 |  |
| 272 | Difficult | Classic lems find new home(Lem3) | Lemmy556 My little levels 2 / fan:lldb-66 | 160.73 | 441.23 |  |
| 273 | Difficult | Taxing 30.lvl | Amiga Taxing / fan:lldb-570 | 161.55 | 444.39 |  |
| 274 | Difficult | Speed Freaks | Ji Hoons Lemmings Remake Earth / fan:lldb-549 | 160.10 | 442.74 |  |
| 275 | Difficult | We all fall down | Lemmings / Taxing | 159.45 | 444.39 |  |
| 276 | Difficult | Rules to fall | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 208.05 | 435.48 |  |
| 277 | Difficult | We all fall down. | Crystal Remakes / fan:lldb-130 | 161.56 | 444.42 |  |
| 278 | Difficult | DON`T PANIC | Oh No! More Lemmings / Crazy | 325.48 | 421.70 |  |
| 279 | Difficult | Suicidal Tendencies | Oh No! More Lemmings / Wicked | 318.35 | 422.75 |  |
| 280 | Difficult | Lemmings Up High | Holiday Lemmings 1993 / Blizzard | 236.12 | 436.93 |  |
| 281 | Difficult | Plethora of Presents | Holiday Lemmings 1994 / Frost | 236.95 | 438.61 |  |
| 282 | Difficult | We all fall down | Lemmings / Fun | 157.63 | 453.02 |  |
| 283 | Difficult | PoP TiL YoU DrOp! | Oh No! More Lemmings / Wicked | 233.05 | 443.75 |  |
| 284 | Difficult | A Single Lemming... | Holiday Lemmings 1993 / Blizzard | 296.68 | 433.25 |  |
| 285 | Difficult | Ski Jump! | Holiday Lemmings 1994 / Frost | 170.09 | 450.25 |  |
| 286 | Difficult | We all fall down. | Crystal Remakes / fan:lldb-130 | 159.74 | 453.05 |  |
| 287 | Difficult | FunnyTopia | KillerMasters Lemmings 1 Wicked / fan:lldb-508 | 211.14 | 447.37 |  |
| 288 | Difficult | Mayhem 11.lvl | Amiga Mayhem / fan:lldb-571 | 165.06 | 453.74 |  |
| 289 | Difficult | Looks a Bit Nippy Out There | Oh No! More Lemmings / Havoc | 271.14 | 441.48 |  |
| 290 | Difficult | We all fall down | Lemmings / Mayhem | 162.96 | 453.74 |  |
| 291 | Difficult | The Land of the Bizarre | Holiday Lemmings 1994 / Frost | 271.80 | 442.26 |  |
| 292 | Difficult | We all fall down. | Crystal Remakes / fan:lldb-130 | 165.07 | 453.77 |  |
| 293 | Difficult | Day by Day | JM01 / fan:lldb-327 | 234.15 | 445.23 |  |
| 294 | Difficult | Lemming about town | Oh No! More Lemmings / Havoc | 321.74 | 426.76 |  |
| 295 | Difficult | Excavation Station | TWPAK00 / fan:lldb-302 | 265.20 | 421.90 |  |
| 296 | Difficult | Dig Down, Bash Across | PSP Special 1 10 of 36 / fan:lldb-216 | 283.70 | 429.10 |  |
| 297 | Difficult | Every Lemming for himself!!! | Lemmings / Taxing | 360.25 | 427.43 |  |
| 298 | Difficult | One On One | Oh Yes! More Lemmings! / Oh No! More Lemmings Versus | 275.38 | 425.00 |  |
| 299 | Difficult | Lend a helping hand.... | Lemmings / Taxing | 353.52 | 450.00 |  |
| 300 | Difficult | Bashing & Building | Nepster01 / fan:lldb-219 | 375.11 | 424.82 |  |
| 301 | Difficult | Taxing 07.lvl | Amiga Taxing / fan:lldb-570 | 362.47 | 427.88 |  |
| 302 | Difficult | Haunted botanical garden | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 343.01 | 442.64 |  |
| 303 | Difficult | Five Alive | Oh No! More Lemmings / Wicked | 330.16 | 441.22 |  |
| 304 | Difficult | The Next Lemeration | Holiday Lemmings 1993 / Blizzard | 339.35 | 450.00 |  |
| 305 | Difficult | It's Boxing Day! | Holiday Lemmings 1994 / Frost | 357.30 | 444.75 |  |
| 306 | Difficult | And now, the end is near... | Oh No! More Lemmings / Crazy | 320.71 | 452.04 |  |
| 307 | Difficult | Cyborglem Lab | KillerMasters Lemmings 1 Wild / fan:lldb-507 | 354.96 | 452.84 |  |
| 308 | Difficult | Dunes | Nepster01 / fan:lldb-219 | 367.72 | 450.00 |  |
| 309 | Difficult | Feel the heat! | Lemmings / Taxing | 346.04 | 450.00 |  |
| 310 | Difficult | LeMming ToMato KetchUp fAcilitY | Oh No! More Lemmings / Wicked | 326.42 | 450.00 |  |
| 311 | Difficult | Undercover Lemming | Oh No! More Lemmings / Tame | 252.68 | 439.63 |  |
| 312 | Difficult | Snow Lev 1 | ANTHPCK4 / fan:lldb-224 | 225.57 | 454.90 |  |
| 313 | Difficult | HIGHLAND FLING | Oh No! More Lemmings / Havoc | 400.72 | 450.00 |  |
| 314 | Difficult | There`s madness in the method | Oh No! More Lemmings / Havoc | 391.12 | 448.24 |  |
| 315 | Difficult | Dirt Runner | Nepster01 / fan:lldb-219 | 297.79 | 450.70 |  |
| 316 | Difficult | Just a Minute... | Lemmings / Mayhem | 312.01 | 454.90 |  |
| 317 | Difficult | Out, away from the tune | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 340.13 | 454.58 |  |
| 318 | Difficult | Postcard from Lemmingland | Lemmings / Tricky | 346.74 | 450.00 |  |
| 319 | Difficult | Hunt the Nessy.... | Lemmings / Taxing | 410.57 | 436.51 |  |
| 320 | Difficult | Time Gate | Nepster01 / fan:lldb-219 | 429.32 | 437.08 |  |
| 321 | Difficult | Rendezvous II | Holiday Lemmings 1994 / Hail | 410.10 | 450.50 |  |
| 322 | Difficult | Up, Down or Round and Round | Oh No! More Lemmings / Wicked | 242.67 | 456.73 |  |
| 323 | Difficult | Just two minutes | JM06 / fan:lldb-332 | 160.02 | 477.84 |  |
| 324 | Difficult | The Voyage Home... | Holiday Lemmings 1993 / Blizzard | 257.20 | 459.25 |  |
| 325 | Difficult | Maybe would be a doddle! | CRISFN11 / fan:lldb-275 | 228.88 | 478.65 |  |
| 326 | Difficult | Digger Conversions | Lemmings The Official Companion / fan:lldb-585 | 262.26 | 470.88 |  |
| 327 | Difficult | Quest for Kieran | Holiday Lemmings 1994 / Frost | 288.50 | 459.00 |  |
| 328 | Difficult | Lemmingdelica | Oh No! More Lemmings / Wild | 267.48 | 459.00 |  |
| 329 | Difficult | Dr Lemminggood | Oh No! More Lemmings / Wild | 252.87 | 459.00 |  |
| 330 | Difficult | Got anything....Lemmingy??? | Oh No! More Lemmings / Wild | 322.96 | 459.00 |  |
| 331 | Difficult | Down the tube | Oh No! More Lemmings / Wicked | 327.06 | 459.00 |  |
| 332 | Difficult | CindyLand | Holiday Lemmings 1994 / Frost | 298.86 | 459.00 |  |
| 333 | Difficult | Steel Ice Span | Holiday Lemmings 1994 / Hail | 308.87 | 459.00 |  |
| 334 | Difficult | Up, up, and away! | Holiday Lemmings 1994 / Hail | 305.48 | 459.00 |  |
| 335 | Difficult | How on Earth? | Oh No! More Lemmings / Wicked | 327.66 | 459.00 |  |
| 336 | Difficult | 24 hour Lemathon | Oh No! More Lemmings / Crazy | 328.41 | 459.75 |  |
| 337 | Difficult | Presents of Mind | Holiday Lemmings 1993 / Flurry | 337.94 | 459.00 |  |
| 338 | Difficult | This Corrosion | Oh No! More Lemmings / Wicked | 342.84 | 459.00 |  |
| 339 | Difficult | Marshmallow Land | Holiday Lemmings 1993 / Flurry | 346.80 | 459.00 |  |
| 340 | Difficult | Tailor-made for blockers | Lemmings / Fun | 188.60 | 486.10 |  |
| 341 | Difficult | This Corrosion | Xmas Lemmings 1991 / Wicked | 342.84 | 459.00 |  |
| 342 | Difficult | Inside the bone | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 330.59 | 456.65 |  |
| 343 | Difficult | Turn around young lemmings! (rm) | LEMREMAKE / fan:lldb-465 | 261.77 | 457.62 |  |
| 344 | Difficult | Is this a circus? | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 239.53 | 480.77 |  |
| 345 | Difficult | With a twist of Lemming please | Genesis Mayhem / fan:lldb-491 | 304.53 | 473.41 |  |
| 346 | Difficult | Evacuating a coal mine | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 331.06 | 456.32 |  |
| 347 | Difficult | The Hammock... | Oh Yes! More Lemmings! / Lemmings Versus | 343.44 | 461.90 |  |
| 348 | Difficult | Here is Mr.Lemming's house | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 311.52 | 470.06 |  |
| 349 | Difficult | Graffiti | Oh Yes! More Lemmings! / Lemmings Versus | 342.14 | 465.08 |  |
| 350 | Difficult | Walk the web rope (part two) | Conway Challenges 1 / fan:lldb-263 | 352.96 | 459.82 |  |
| 351 | Difficult | Any chance of a truce? | Oh Yes! More Lemmings! / Lemmings Versus | 172.53 | 476.00 |  |
| 352 | Difficult | Taxing 20.lvl | Amiga Taxing / fan:lldb-570 | 350.36 | 459.82 |  |
| 353 | Difficult | As long as you try your best | Lemmings / Fun | 296.53 | 475.90 |  |
| 354 | Difficult | Walk the web rope | Lemmings / Taxing | 350.04 | 459.82 |  |
| 355 | Difficult | The Crystal Cavern Mark II | Oh Yes! More Lemmings! / Lemmings Versus | 342.02 | 485.83 |  |
| 356 | Difficult | Come on over to my place | Lemmings / Taxing | 380.13 | 471.13 |  |
| 357 | Difficult | Broken Symmetry | Nepster01 / fan:lldb-219 | 371.03 | 471.13 |  |
| 358 | Difficult | With a twist of lemming please | Lemmings / Mayhem | 304.53 | 473.41 |  |
| 359 | Difficult | Temple of Love | Oh No! More Lemmings / Wicked | 408.92 | 467.60 |  |
| 360 | Difficult | Move on in two separate groups. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 421.14 | 462.97 |  |
| 361 | Difficult | Cave quest | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 355.21 | 479.08 |  |
| 362 | Difficult | Taxing 22.lvl | Amiga Taxing / fan:lldb-570 | 388.01 | 471.13 |  |
| 363 | Difficult | Mayhem 03.lvl | Amiga Mayhem / fan:lldb-571 | 373.02 | 484.04 |  |
| 364 | Difficult | ICE SPY | Oh No! More Lemmings / Wild | 398.26 | 474.61 |  |
| 365 | Difficult | It`s hero time! | Lemmings / Mayhem | 373.02 | 484.04 |  |
| 366 | Difficult | We all fall down | Lemmings / Tricky | 170.09 | 491.12 |  |
| 367 | Difficult | ROCKY VI | Oh No! More Lemmings / Crazy | 310.79 | 496.93 |  |
| 368 | Difficult | We all fall down. | Crystal Remakes / fan:lldb-130 | 172.27 | 491.44 |  |
| 369 | Difficult | Ozone friendly Lemmings | Genesis Tricky / fan:lldb-489 | 194.92 | 495.84 |  |
| 370 | Difficult | Break on through... | Holiday Lemmings 1993 / Blizzard | 297.68 | 518.74 |  |
| 371 | Difficult | Ozone friendly Lemmings | Lemmings / Tricky | 194.92 | 495.84 |  |
| 372 | Difficult | All or Nothing | Lemmings / Mayhem | 265.22 | 495.84 |  |
| 373 | Difficult | What exit? | JM11 / fan:lldb-337 | 300.59 | 510.53 |  |
| 374 | Difficult | The Funeral | MATTPCK2 / fan:lldb-249 | 269.10 | 510.53 |  |
| 375 | Difficult | Check Your Hints! | Holiday Lemmings 1993 / Blizzard | 297.28 | 510.53 |  |
| 376 | Difficult | The Lemming Funhouse | Oh No! More Lemmings / Wicked | 448.11 | 518.74 |  |
| 377 | Difficult | Mutiny On The Bounty | Oh No! More Lemmings / Wild | 329.91 | 514.25 |  |
| 378 | Difficult | Almost Nearly Virtual Reality | Oh No! More Lemmings / Wicked | 305.60 | 514.25 |  |
| 379 | Difficult | The Chain with no name | Oh No! More Lemmings / Wild | 315.68 | 514.25 |  |
| 380 | Difficult | Oh No! It`s the 4TH DIMENSION! | Oh No! More Lemmings / Wicked | 332.18 | 514.25 |  |
| 381 | Difficult | On the Antarctic Coast | Oh No! More Lemmings / Crazy | 362.75 | 514.25 |  |
| 382 | Difficult | Up on the Rooftops | Holiday Lemmings 1994 / Frost | 412.84 | 514.25 |  |
| 383 | Difficult | PoP YoR ToP!!! | Oh No! More Lemmings / Wild | 329.66 | 514.25 |  |
| 384 | Difficult | NO PROBLEM | Oh No! More Lemmings / Crazy | 388.48 | 490.03 |  |
| 385 | Difficult | Santus Lemmingus | Holiday Lemmings 1993 / Blizzard | 345.95 | 493.03 |  |
| 386 | Difficult | DIGGING FOR VICTORY | Oh No! More Lemmings / Crazy | 396.34 | 492.20 |  |
| 387 | Difficult | Co-operation | Oh Yes! More Lemmings! / Oh No! More Lemmings Versus | 306.56 | 498.30 |  |
| 388 | Difficult | Libra | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 287.44 | 508.18 |  |
| 389 | Difficult | The gate trap Lemmings. | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 425.62 | 503.58 |  |
| 390 | Difficult | The Stack | Oh No! More Lemmings / Crazy | 429.63 | 490.04 |  |
| 391 | Difficult | Sir Edmund Hilemming | Holiday Lemmings 1994 / Hail | 423.19 | 514.25 |  |
| 392 | Difficult | Welcome to the party, pal! | Oh No! More Lemmings / Havoc | 366.96 | 514.25 |  |
| 393 | Difficult | LoTs moRe wHeRe TheY caMe fRom | Oh No! More Lemmings / Wicked | 423.90 | 514.25 |  |
| 394 | Difficult | Inroducing SUPERLEMMING | Oh No! More Lemmings / Wicked | 366.73 | 509.60 |  |
| 395 | Difficult | Stray sheep | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 352.12 | 516.96 |  |
| 396 | Difficult | Don't settle for anything less | Conway Challenges 1 / fan:lldb-263 | 425.93 | 515.82 |  |
| 397 | Difficult | Be more than just a number | Oh No! More Lemmings / Havoc | 435.18 | 514.25 |  |
| 398 | Difficult | The Cascade: Part II | Modlvls / fan:lldb-357 | 422.21 | 515.82 |  |
| 399 | Difficult | ROCKY ROAD | Oh No! More Lemmings / Wicked | 413.29 | 521.98 |  |
| 400 | Difficult | Tricky 25.lvl | Amiga Tricky / fan:lldb-569 | 407.21 | 515.82 |  |
| 401 | Difficult | Cascade | Lemmings / Tricky | 407.80 | 515.82 |  |
| 402 | Difficult | Doomsday | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 321.34 | 536.48 |  |
| 403 | Difficult | Happy New Year! | Holiday Lemmings 1994 / Frost | 415.14 | 529.82 |  |
| 404 | Difficult | SPAM,SPAM,SPAM,EGG AND LEMMING | Oh No! More Lemmings / Wicked | 414.48 | 540.00 |  |
| 405 | Difficult | A ladder would be handy (Part2) | JM01 / fan:lldb-327 | 403.50 | 540.00 |  |
| 406 | Difficult | Lemming Productions Present... | Oh No! More Lemmings / Tame | 424.90 | 540.00 |  |
| 407 | Difficult | Tricky 03.lvl | Amiga Tricky / fan:lldb-569 | 394.92 | 540.00 |  |
| 408 | Difficult | Merry Christmaze | Holiday Lemmings 1994 / Hail | 286.14 | 552.13 |  |
| 409 | Difficult | Save 'em First... | JEFFPCK7 / fan:lldb-241 | 392.18 | 544.00 |  |
| 410 | Difficult | The hunt is on! | QBeez03 / fan:lldb-33 | 453.53 | 540.00 |  |
| 411 | Difficult | Have a nice day! | Lemmings / Mayhem | 449.58 | 540.00 |  |
| 412 | Difficult | Taxing 29.lvl | Amiga Taxing / fan:lldb-570 | 419.20 | 540.00 |  |
| 413 | Difficult | One way digging to freedom | Lemmings / Tricky | 368.42 | 549.40 |  |
| 414 | Difficult | A ladder would be handy | Lemmings / Tricky | 394.92 | 540.00 |  |
| 415 | Difficult | Tricky 20.lvl | Amiga Tricky / fan:lldb-569 | 368.98 | 549.40 |  |
| 416 | Difficult | How do I dig up the way? | Lemmings / Taxing | 419.20 | 540.00 |  |
| 417 | Difficult | Level 02.lvl | Amiga Demo / fan:lldb-581 | 366.88 | 549.40 |  |
| 418 | Difficult | Splunk n' country | Epic Giga03 / fan:lldb-141 | 434.15 | 546.48 |  |
| 419 | Difficult | Climb and Float | brickpk1 / fan:lldb-558 | 372.72 | 554.90 |  |
| 420 | Difficult | Just a random heap of junk! | Nepster01 / fan:lldb-219 | 454.46 | 556.53 |  |
| 421 | Difficult | FlameBungee | KillerMasters Lemmings 1 Tame / fan:lldb-505 | 403.07 | 554.90 |  |
| 422 | Difficult | Fun 22.lvl | Amiga Fun / fan:lldb-568 | 325.32 | 564.18 |  |
| 423 | Difficult | Time waits for no Lemming | Oh No! More Lemmings / Crazy | 397.45 | 569.50 |  |
| 424 | Difficult | Water processing plant | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 431.98 | 569.50 |  |
| 425 | Difficult | Time waits for no Lemming | Xmas Lemmings 1991 / Crazy | 397.45 | 569.50 |  |
| 426 | Difficult | Just a minute (Part Three) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 446.95 | 569.50 |  |
| 427 | Difficult | It`s the price you have to pay | Oh No! More Lemmings / Havoc | 452.11 | 569.50 |  |
| 428 | Difficult | Emmings!  (No L) | Holiday Lemmings 1994 / Hail | 479.42 | 569.50 |  |
| 429 | Difficult | A Beast of a level | Lemmings / Fun | 325.32 | 564.18 |  |
| 430 | Difficult | Lemming Rhythms | Oh No! More Lemmings / Wild | 394.96 | 581.48 |  |
| 431 | Difficult | Lemming Playground | Nepster01 / fan:lldb-219 | 406.42 | 585.56 |  |
| 432 | Difficult | Taxing 17.lvl | Amiga Taxing / fan:lldb-570 | 443.60 | 592.94 |  |
| 433 | Difficult | Simply Smashing | Epic Giga03 / fan:lldb-141 | 514.30 | 569.50 |  |
| 434 | Difficult | X marks the spot | Lemmings / Taxing | 443.60 | 592.94 |  |
| 435 | Difficult | A task for blockers and bomber | Genesis 2P 2 / fan:lldb-405 | 326.25 | 598.50 |  |
| 436 | Difficult | With A Little Help From... | Yawg02 / fan:lldb-85 | 297.60 | 598.88 |  |
| 437 | Difficult | Take care, Sweetie | Oh No! More Lemmings / Wild | 338.92 | 598.88 |  |
| 438 | Difficult | Hard when you don't know how | MARSHY02 / fan:lldb-346 | 317.22 | 598.88 |  |
| 439 | Difficult | Go Thataway! | Holiday Lemmings 1994 / Hail | 441.67 | 598.88 |  |
| 440 | Difficult | Again & Again | JM03 / fan:lldb-329 | 321.01 | 598.88 |  |
| 441 | Difficult | Four Play | Holiday Lemmings 1994 / Frost | 550.15 | 598.88 |  |
| 442 | Difficult | Puzzle Time.ini | grams88 / fan:lldb-416 | 327.09 | 598.88 |  |
| 443 | Difficult | Compression Method 1 | Lemmings / Taxing | 318.21 | 598.88 |  |
| 444 | Difficult | Fall and no life (Part Two) | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 513.76 | 595.48 |  |
| 445 | Difficult | Patience | Lemmings / Fun | 421.98 | 595.98 |  |
| 446 | Expert | SUNSOFT Special | Oh Yes! More Lemmings! / Mega Drive Sunsoft | 389.00 | 600.61 |  |
| 447 | Expert | Who`s That Lemming | Oh No! More Lemmings / Tame | 373.34 | 606.82 |  |
| 448 | Expert | It`s all a matter of timing | Oh No! More Lemmings / Havoc | 299.52 | 603.50 |  |
| 449 | Expert | The Search for Lem | Holiday Lemmings 1993 / Blizzard | 443.10 | 624.75 |  |
| 450 | Expert | KEEP ON TRUCKING | Oh No! More Lemmings / Crazy | 434.90 | 624.75 |  |
| 451 | Expert | Polar Expedition | Holiday Lemmings 1994 / Hail | 467.57 | 624.75 |  |
| 452 | Expert | Where Lemmings Dare | Oh No! More Lemmings / Havoc | 497.36 | 624.75 |  |
| 453 | Expert | THE SILENCE OF THE LEMMINGS | Oh No! More Lemmings / Wild | 481.37 | 624.75 |  |
| 454 | Expert | Tubular Lemmings | Oh No! More Lemmings / Havoc | 481.59 | 602.03 |  |
| 455 | Expert | Upsidedown World | Lemmings / Taxing | 423.24 | 611.11 |  |
| 456 | Expert | Just A Quicky | Oh No! More Lemmings / Wild | 439.03 | 611.11 |  |
| 457 | Expert | Taxing 13.lvl | Amiga Taxing / fan:lldb-570 | 426.05 | 611.11 |  |
| 458 | Expert | The Prison! | Lemmings / Taxing | 349.20 | 623.68 |  |
| 459 | Expert | Not as complicated as it looks | Genesis Fun / fan:lldb-488 | 370.15 | 626.08 |  |
| 460 | Expert | Taxing 05.lvl | Amiga Taxing / fan:lldb-570 | 351.30 | 623.68 |  |
| 461 | Expert | C'mon everybody body | Giga pack 08 / fan:lldb-170 | 484.29 | 607.81 |  |
| 462 | Expert | Don't bash the wall | JM10 / fan:lldb-336 | 444.42 | 629.00 |  |
| 463 | Expert | Back in Hell | JMGM01 / fan:lldb-454 | 239.66 | 637.50 |  |
| 464 | Expert | Not just a pretty Lemming | Oh No! More Lemmings / Tame | 468.85 | 630.00 |  |
| 465 | Expert | Tricky 10.lvl | Amiga Tricky / fan:lldb-569 | 450.92 | 663.00 |  |
| 466 | Expert | Save Me | Lemmings / Mayhem | 393.27 | 646.46 |  |
| 467 | Expert | Crazy stairs | Giga pack 07 / fan:lldb-169 | 417.88 | 658.51 |  |
| 468 | Expert | It`s a tight fit! | Oh No! More Lemmings / Wild | 442.87 | 656.96 |  |
| 469 | Expert | ONWARD AND UPWARD | Oh No! More Lemmings / Wild | 507.97 | 658.48 |  |
| 470 | Expert | Creature Discomforts | Oh No! More Lemmings / Havoc | 517.87 | 655.94 |  |
| 471 | Expert | There's a lot of them about | Lemmings / Tricky | 446.37 | 663.00 |  |
| 472 | Expert | Origins and Lemmings | Lemmings / Fun | 501.55 | 667.72 |  |
| 473 | Expert | And now this... | Oh No! More Lemmings / Tame | 396.84 | 673.32 |  |
| 474 | Expert | I have a cunning plan | Genesis Tricky / fan:lldb-489 | 418.76 | 672.48 |  |
| 475 | Expert | Snuggle up to a Lemming | Oh No! More Lemmings / Tame | 480.11 | 673.32 |  |
| 476 | Expert | Tricky 26.lvl | Amiga Tricky / fan:lldb-569 | 418.76 | 672.48 |  |
| 477 | Expert | Lemmings in a situation | Oh No! More Lemmings / Havoc | 457.29 | 680.30 |  |
| 478 | Expert | I have a cunning plan | Lemmings / Tricky | 416.66 | 672.48 |  |
| 479 | Expert | Oogilemming! | Holiday Lemmings 1993 / Blizzard | 497.20 | 680.00 |  |
| 480 | Expert | Get the Point? | Holiday Lemmings 1994 / Hail | 553.20 | 688.50 |  |
| 481 | Expert | Lemmings Get Lost in Afterlife | ssam1221s Lemmings Wicked / fan:lldb-515 | 273.42 | 722.50 |  |
| 482 | Expert | Heaven can wait (we hope!!!!) | Lemmings / Taxing | 281.82 | 722.50 |  |
| 483 | Expert | In And Out | TimpackD / fan:lldb-102 | 503.74 | 700.00 |  |
| 484 | Expert | Feel the pain | joem5 / fan:lldb-320 | 411.24 | 700.00 |  |
| 485 | Expert | Lemmings...The Motion Picture | Holiday Lemmings 1993 / Blizzard | 398.87 | 700.00 |  |
| 486 | Expert | Christmas Bonus | Xmas Lemmings 1991 / Xmas | 364.92 | 700.00 |  |
| 487 | Expert | And a Happy New Year! | Holiday Lemmings 1994 / Hail | 382.54 | 700.00 |  |
| 488 | Expert | Merry Christmas Mr Lemming | Xmas Lemmings 1991 / Xmas | 385.80 | 700.00 |  |
| 489 | Expert | They just keep on coming | Lemmings / Tricky | 361.83 | 700.00 |  |
| 490 | Expert | These walls | JMGM02 / fan:lldb-455 | 371.57 | 700.00 |  |
| 491 | Expert | Let's get it Started | Deceits Lemmings Extras / fan:lldb-546 | 389.70 | 700.00 |  |
| 492 | Expert | Tricky 27.lvl | Amiga Tricky / fan:lldb-569 | 415.36 | 700.00 |  |
| 493 | Expert | Mayhem 08.lvl | Amiga Mayhem / fan:lldb-571 | 400.32 | 700.00 |  |
| 494 | Expert | The Far Side | Lemmings / Mayhem | 417.09 | 700.00 |  |
| 495 | Expert | Last one out is a rotten egg! | Lemmings / Mayhem | 398.22 | 700.00 |  |
| 496 | Expert | The Island of the Wicker people | Lemmings / Tricky | 413.26 | 700.00 |  |
| 497 | Expert | One way or another | Lemmings / Mayhem | 397.09 | 700.00 |  |
| 498 | Expert | From The Boundary Line part two | Conway Challenges 1 / fan:lldb-263 | 444.11 | 700.00 |  |
| 499 | Expert | DO NOT ENTER | QBeez03 / fan:lldb-33 | 422.09 | 700.00 |  |
| 500 | Expert | Do the Lemmys way! | Lemmy556 My little levels / fan:lldb-65 | 457.22 | 700.00 |  |
| 501 | Expert | Taxing 28.lvl | Amiga Taxing / fan:lldb-570 | 461.25 | 700.00 |  |
| 502 | Expert | Stepping Stones | Lemmings / Mayhem | 457.22 | 700.00 |  |
| 503 | Expert | POOR WEE CREATURES! | Lemmings / Taxing | 460.80 | 700.00 |  |
| 504 | Expert | There can be only one | Genesis 2P 1 / fan:lldb-404 | 439.94 | 700.00 |  |
| 505 | Expert | Lemming Drops | Lemmings / Tricky | 418.77 | 700.00 |  |
| 506 | Expert | Here's one I prepared earlier | Lemmings / Tricky | 426.91 | 700.00 |  |
| 507 | Expert | Lemmingology | Genesis Tricky / fan:lldb-489 | 381.75 | 700.00 |  |
| 508 | Expert | All the 6`s ........ | Lemmings / Tricky | 374.38 | 700.00 |  |
| 509 | Expert | Nightmare on Lem street | Lemmings / Fun | 365.98 | 700.00 |  |
| 510 | Expert | I've lost that Lemming feeling | Lemmings / Fun | 356.12 | 700.00 |  |
| 511 | Expert | Lemmingology | Lemmings / Tricky | 381.74 | 700.00 |  |
| 512 | Expert | A Lemming Holiday | Xmas Lemmings 1992 / Xmas | 426.15 | 700.00 |  |
| 513 | Expert | Tricky 04.lvl | Amiga Tricky / fan:lldb-569 | 429.01 | 700.00 |  |
| 514 | Expert | Don't let your eyes deceive you | Lemmings / Fun | 488.66 | 700.00 |  |
| 515 | Expert | We`re in this one together | Oh Yes! More Lemmings! / Lemmings Versus | 500.45 | 700.00 |  |
| 516 | Expert | Fun 15.lvl | Amiga Fun / fan:lldb-568 | 495.68 | 700.00 |  |
| 517 | Expert | flag test map | Orig Extra Levels / fan:lldb-407 | 516.37 | 700.00 |  |
| 518 | Expert | Taxing 03.lvl | Amiga Taxing / fan:lldb-570 | 283.92 | 722.50 |  |
| 519 | Expert | Travelling Lemmings | Nepster01 / fan:lldb-219 | 575.09 | 700.00 |  |
| 520 | Expert | Tricky 23.lvl | Amiga Tricky / fan:lldb-569 | 518.09 | 700.00 |  |
| 521 | Expert | The Needs of the Many... | Holiday Lemmings 1993 / Blizzard | 479.80 | 700.00 |  |
| 522 | Expert | Taxing 02.lvl | Amiga Taxing / fan:lldb-570 | 537.81 | 700.00 |  |
| 523 | Expert | Taxing 11.lvl | Amiga Taxing / fan:lldb-570 | 508.25 | 700.00 |  |
| 524 | Expert | Devil's Right Hand | Nepster01 / fan:lldb-219 | 533.39 | 700.00 |  |
| 525 | Expert | The ascending pillar scenario | Lemmings / Taxing | 506.15 | 700.00 |  |
| 526 | Expert | Pillars of Hercules | Lemmings / Mayhem | 554.17 | 700.00 |  |
| 527 | Expert | From The Boundary Line | Lemmings / Tricky | 518.09 | 700.00 |  |
| 528 | Expert | Watch out, there`s traps about | Lemmings / Taxing | 537.81 | 700.00 |  |
| 529 | Expert | Tricky 30.lvl | Amiga Tricky / fan:lldb-569 | 537.25 | 700.00 |  |
| 530 | Expert | Tricky 07.lvl | Amiga Tricky / fan:lldb-569 | 538.72 | 700.00 |  |
| 531 | Expert | The Fast Food Kitchen... | Lemmings / Mayhem | 562.66 | 700.00 |  |
| 532 | Expert | Been there, seen it, done it | Lemmings / Tricky | 536.62 | 700.00 |  |
| 533 | Expert | The Crankshaft | Lemmings / Tricky | 537.25 | 700.00 |  |
| 534 | Expert | Rendezvous at the Mountain | Lemmings / Mayhem | 536.15 | 700.00 |  |
| 535 | Expert | Izzie Wizzie lemmings get busy | Lemmings / Taxing | 434.67 | 700.00 |  |
| 536 | Expert | Any chance of a truce? | Genesis 2P 1 / fan:lldb-404 | 421.78 | 700.00 |  |
| 537 | Expert | Izzie Wizzie Lemmings get busy | Genesis Taxing / fan:lldb-490 | 434.68 | 700.00 |  |
| 538 | Expert | Chill out! | Oh No! More Lemmings / Wicked | 558.37 | 700.00 |  |
| 539 | Expert | The Green Mile | Van Clan Tame / fan:lldb-99 | 561.42 | 700.00 |  |
| 540 | Expert | AAAAAARRRRRRGGGGGGHHHHHH!!!!!! | Oh No! More Lemmings / Havoc | 477.17 | 748.00 |  |
| 541 | Expert | It Came Upon a Lemnight Clear | Holiday Lemmings 1993 / Blizzard | 557.79 | 735.25 |  |
| 542 | Expert | Head for the Hills! | Holiday Lemmings 1993 / Flurry | 270.77 | 781.15 | Review |
| 543 | Expert | Now get out of that! | Oh No! More Lemmings / Havoc | 293.69 | 785.88 |  |
| 544 | Expert | The race against cliches | Oh No! More Lemmings / Havoc | 433.13 | 776.14 |  |
| 545 | Expert | Firestorm | GARJEN04 / fan:lldb-284 | 431.34 | 773.50 |  |
| 546 | Expert | MENACING !! | Lemmings / Tricky | 565.10 | 803.25 |  |
| 547 | Expert | Mayhem 18.lvl | Amiga Mayhem / fan:lldb-571 | 572.62 | 816.00 |  |
| 548 | Expert | Synchronised Lemming | Oh No! More Lemmings / Havoc | 565.10 | 816.00 |  |
| 549 | Expert | And then there were four.... | Lemmings / Mayhem | 569.32 | 816.00 |  |
| 550 | Expert | The Passing Place | Oh Yes! More Lemmings! / Lemmings Versus | 283.69 | 850.00 |  |
| 551 | Expert | The Rope Bridge | Oh Yes! More Lemmings! / Lemmings Versus | 264.85 | 843.48 |  |
| 552 | Expert | Happy New Year II! | Holiday Lemmings 1994 / Frost | 441.86 | 843.48 |  |
| 553 | Expert | Lemmintaschen? | Holiday Lemmings 1994 / Hail | 474.65 | 843.48 |  |
| 554 | Expert | Mayhem 22.lvl | Amiga Mayhem / fan:lldb-571 | 450.37 | 850.00 |  |
| 555 | Expert | Don't do anything too hasty | Lemmings / Fun | 442.35 | 850.00 |  |
| 556 | Expert | A BeastII of a level | Lemmings / Mayhem | 450.37 | 850.00 |  |
| 557 | Expert | Keep your hair on Mr. Lemming | Lemmings / Fun | 427.47 | 850.00 |  |
| 558 | Expert | Across The Gap | Oh No! More Lemmings / Crazy | 555.35 | 850.00 |  |
| 559 | Expert | Tailor-made for Athletes | JEFFPCK1 / fan:lldb-235 | 479.06 | 850.00 |  |
| 560 | Expert | Swallowing method 1 | Lemmings platinum Fragle part 2 / fan:lldb-181 | 553.79 | 850.00 |  |
| 561 | Expert | Sudenly lemming | Lemmings platinum Careful Part 1 / fan:lldb-188 | 543.92 | 850.00 |  |
| 562 | Expert | Oscillating Lemmings | Pieuws Lemmings 2007 Peace / fan:lldb-542 | 466.96 | 850.00 |  |
| 563 | Expert | It Takes Two To Tango | Van Clan Tame / fan:lldb-99 | 576.36 | 850.00 |  |
| 564 | Expert | May the craftiest player win | Oh Yes! More Lemmings! / Lemmings Versus | 626.68 | 850.00 |  |
| 565 | Expert | Be Careful... | Lemmings Plus DOS Project Mild / fan:lldb-551 | 583.08 | 850.00 |  |
| 566 | Expert | The Graveyard | Lemmings Plus DOS Project Mild / fan:lldb-551 | 633.39 | 850.00 |  |
| 567 | Expert | Free Lemmings | Oh No More cLemmings Tame / fan:lldb-530 | 620.59 | 850.00 |  |
| 568 | Expert | Easy when you know how | Genesis Fun / fan:lldb-488 | 625.47 | 850.00 |  |
| 569 | Expert | Remember where you find them! | Ji Hoons Lemmings Remake Heaven / fan:lldb-547 | 659.90 | 850.00 |  |
| 570 | Expert | Double Lemmings | KillerMasters Lemmings 2 Tame / fan:lldb-510 | 631.46 | 850.00 |  |
| 571 | Expert | This is a doddle | JM09 / fan:lldb-335 | 543.20 | 850.00 |  |
| 572 | Expert | Floaters Away! | cLemmings Tricky / fan:lldb-527 | 589.55 | 850.00 |  |
