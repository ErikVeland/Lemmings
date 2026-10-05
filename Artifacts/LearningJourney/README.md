# Oh My! All Lemmings!

292 selected lessons from 1717 validated, deduplicated single-player candidates. 156 official levels and 136 library levels.

## Selection before ordering

The recommended journey is a selective curriculum. The complete library and original campaigns remain available separately. It has no requirement to include every official level or every validated fan level.

Skill introductions no longer force their way into the opening lessons. The order uses source rank and winning replay evidence. Fun, Easy and Tame levels can start the path. A low-demand witness from another rank can introduce a skill in Intermediate when no beginner-ranked witness qualifies. Levels with a Tricky or higher rank, unknown rank, or a full-rescue requirement have a higher placement floor. The model still needs novice playtesting.

The target is roughly 292 levels: the combined size of Classic, Oh No! and the 72 seasonal levels. The path uses Classic mechanics only. Confirmed L2/L3 levels remain outside this journey. All six source campaigns are checked in corpus-coverage.json.

Packs identified as Lemmini are excluded from this Classic learning path. Two levels in those packs have native Classic wins, but source-engine behaviour is unverified. See `../DifficultyEvaluation/source-engine-families.json` and its validation notes.

Official levels take priority within comparable 35-point demand bands. Library levels supply missing applications. An application signature records the skill set, job changes, three-step sequences and worker roles. Identical signatures are excluded even across different titles. Repeated assignments, worker counts and score buckets do not create new lessons. These are evidence-based distinctions that still need human review.

The Fun stage contains beginner-ranked levels below the demand threshold. Unknown ranks and Tricky or higher ranks move to later stages. A winning route that must save every released lemming starts at Difficult. These rules do not prove that a level is easy. Difficult and Expert retain the existing demand boundaries.

## Evidence and limits

Objectives are inferred from winning replay commands and measured profiles. They describe an observed route, not a proved necessary technique or a human difficulty rating. Geometry-specific lessons such as steel recognition and safe digging depth are not reliably detected by the current evidence. Those require authored review before claiming complete teaching coverage.

The selector retains multiplayer and port-duplicate exclusions. The generator checks each selected fan witness against its profile digest and source identity. Basic introductions, unique objectives, source coverage of the selected list and reversed-input ordering are checked.

Stages: {'Fun': 7, 'Intermediate': 119, 'Difficult': 107, 'Expert': 59}. Skill introductions: 8. Full-rescue requirements: 31. Duplicate objectives: 0. Largest demand increase: 48.00/1000. Preparation gaps: 0.

## Transitions for playtesting

- 7. Thunder-Lemmings are go!: New component high: executionPrecision.
- 207. Ten Green Lemmings: New component high: concurrencyBurden.
- 230. Go Thataway!: New component high: executionPrecision.

A support flag remains a review request. An absent flag is not proof that a novice will find a solution obvious.

## Reproduce

Run `zsh Scripts/generate-learning-journey.sh`, then `python3 Tools/DifficultyDiagnostics/learning_report.py report`. The generator exports the eligible pool, selects distinct objectives with `curate_learning.py`, and builds the ordered journey. `curriculum.json` records the reason for every selection.

Solved and parked levels stay saved by identity. A new curriculum version rebuilds the remaining order. Removing a level from this recommendation does not remove it from the library.

## Full order

| Step | Stage | Level | Source | Lesson purpose |
| ---: | --- | --- | --- | --- |
| 1 | Fun | Just dig! | Lemmings | First assignment of the digger skill. |
| 2 | Fun | Only Float is Survive | KillerMasters Lemmings 1 Tame | First assignment of the floater skill. |
| 3 | Fun | You need bashers this time | Lemmings | First assignment of the basher skill. |
| 4 | Fun | Up Up UP They Go | Van Clan Tame | First assignment of the climber skill. |
| 5 | Fun | Let's block and blow | Lemmings | First assignment of the bomber skill. |
| 6 | Fun | The Broken Stair | KillerMasters Lemmings 1 Tame | First assignment of the builder skill. |
| 7 | Fun | Thunder-Lemmings are go! | Oh No! More Lemmings | Assign basher and builder to separate workers without changing their skills. |
| 8 | Intermediate | Mienrs <--- lol, typo | Ji Hoons Lemmings Remake Heaven | First assignment of the miner skill. |
| 9 | Intermediate | Nuclear War on the dance floor | joem7 | First assignment of the blocker skill. |
| 10 | Intermediate | Lemmings For Presidents! | Oh No! More Lemmings | Assign basher and miner to separate workers without changing their skills. |
| 11 | Intermediate | PRACTICE: CLIMBER | Mikepak07 | Apply Climber again while changing the release rate. |
| 12 | Intermediate | Block and Dig | brickpk2 | Assign blocker and digger to separate workers without changing their skills. |
| 13 | Intermediate | Build a Bridge | JM04 | Assign blocker and builder to separate workers without changing their skills. |
| 14 | Intermediate | Blockers can block others | Deceits Lemmings Extras | Change the release rate while preparing a route. |
| 15 | Intermediate | A task for blockers and bombers | Lemmings | Change the same worker from blocker to bomber in a winning route. |
| 16 | Intermediate | Lemming Snowfall | Holiday Lemmings 1993 | Change the same worker from basher to builder in a winning route. |
| 17 | Intermediate | At Home in a Cave | Holiday Lemmings 1993 | Change the same worker from digger to basher in a winning route. |
| 18 | Intermediate | It'll be Comin' Round the Mtn. | Oh No More cLemmings Tame | Change the same worker from miner to builder in a winning route. |
| 19 | Intermediate | Lost something? | Lemmings | Worker roles: basher; builder; miner. |
| 20 | Intermediate | Floating Lemming Flurry | Holiday Lemmings 1993 | Change the same worker from floater to basher in a winning route. |
| 21 | Intermediate | Not as complicated as it looks | Lemmings | Change the same worker from builder to basher in a winning route. |
| 22 | Intermediate | The Undiscovered Country | Holiday Lemmings 1993 | Assign digger and miner to separate workers without changing their skills. |
| 23 | Intermediate | Custom built for Lemmings | Oh No! More Lemmings | Worker roles: basher + builder. Job changes: basher → builder. |
| 24 | Intermediate | Jungle!! | CRISFN01 | Worker roles: blocker + bomber; builder. Job changes: blocker → bomber. |
| 25 | Intermediate | Heading on in... | Lemmings Plus DOS Project Mild | Worker roles: builder; digger. Also practise release-rate-manipulation. |
| 26 | Intermediate | Test map | Orig Extra Levels | Worker roles: digger + miner. Job changes: digger → miner. Also practise release-rate-manipulation. |
| 27 | Intermediate | Lemming sanctuary in sight | Lemmings | Manage two working regions in one route. |
| 28 | Intermediate | Be RiGhT bAcK! | Oh No More cLemmings Tame | Worker roles: builder; miner. Also practise release-rate-manipulation. |
| 29 | Intermediate | With Lemmings on Top | cLemmings Fun | Worker roles: basher + digger. Job changes: basher → digger. Also practise release-rate-manipulation. |
| 30 | Intermediate | BashintheDirectionoftheArrows | PSP Special 1 10 of 36 | Worker roles: basher; basher + builder. Job changes: builder → basher. Also practise release-rate-manipulation. |
| 31 | Intermediate | Bridge Across, Mine Through | PSP Special 1 10 of 36 | Reuse a worker by returning to an earlier job after a different assignment. |
| 32 | Intermediate | Avoid the Fall ! | Pieuws Lemmings 2007 Peace | Worker roles: basher + digger. Job changes: digger → basher. Also practise release-rate-manipulation. |
| 33 | Intermediate | Float and Bomb | brickpk1 | Worker roles: bomber; floater. Also practise release-rate-manipulation. |
| 34 | Intermediate | Merry Lemmings | Van Clan Tame | Change the same worker from blocker to miner in a winning route. |
| 35 | Intermediate | Dying Not Reccomended | Lemmings Plus DOS Project Mild | Worker roles: basher + digger; digger. Job changes: basher → digger. Also practise release-rate-manipulation. |
| 36 | Intermediate | Let's go to the moon! | Genesis Tricky | Worker roles: builder + miner. Job changes: miner → builder. Also practise release-rate-manipulation. |
| 37 | Intermediate | Down The Wall | Lemmings Plus DOS Project Wimpy | Worker roles: basher; basher + digger. Job changes: digger → basher. Also practise release-rate-manipulation. |
| 38 | Intermediate | Rising to Paradise | Pieuws Lemmings 2007 Peace | Worker roles: basher; basher + builder; builder. Job changes: basher → builder. Also practise release-rate-manipulation. |
| 39 | Intermediate | Lake in the Cavern | CPs Level Pack | Worker roles: basher + bomber; bomber. Job changes: basher → bomber. Also practise release-rate-manipulation. |
| 40 | Intermediate | Bomb and Build | brickpk1 | Worker roles: bomber + builder; builder. Job changes: builder → bomber. Also practise release-rate-manipulation. |
| 41 | Intermediate | A toe | Level Design Game 03 | Worker roles: blocker; miner. Also practise release-rate-manipulation. |
| 42 | Intermediate | It is impossible to do? | CRISFN04 | Worker roles: basher + builder; builder. Job changes: basher → builder. Also practise release-rate-manipulation. |
| 43 | Intermediate | PRACTICE: STEEL | Mikepak07 | Use a blocker while two terrain-changing skills prepare the route. |
| 44 | Intermediate | Float and Block | brickpk1 | Worker roles: blocker + floater; floater. Job changes: floater → blocker. Also practise release-rate-manipulation. |
| 45 | Intermediate | Welcome Back! | KillerMasters Lemmings 2 Tame | Worker roles: basher; miner. Also practise release-rate-manipulation. |
| 46 | Intermediate | Symmetry | EMPACK | Worker roles: blocker; digger. Also practise release-rate-manipulation. |
| 47 | Intermediate | Block and Bash | brickpk2 | Worker roles: basher; blocker. Also practise release-rate-manipulation. |
| 48 | Intermediate | 100% Pure Woven Lemming | EMPACK | Worker roles: basher; basher + miner. Job changes: basher → miner. Also practise release-rate-manipulation. |
| 49 | Intermediate | Don't leave any Lemmings | Genesis Tricky | Worker roles: bomber; bomber + builder; builder. Job changes: builder → bomber. Also practise release-rate-manipulation. |
| 50 | Intermediate | Climb and Block | brickpk1 | Worker roles: blocker + climber; climber. Job changes: climber → blocker. Also practise release-rate-manipulation. |
| 51 | Intermediate | You Live and Lem | Lemmings | Worker roles: basher + builder; miner. Job changes: basher → builder. |
| 52 | Intermediate | You Want Me To Go Where??? | Van Clan Tame | Worker roles: basher + builder. Job changes: basher → builder. Also practise release-rate-manipulation. |
| 53 | Intermediate | A Trap is a trap. | Genesis Present | Worker roles: blocker; bomber. Also practise release-rate-manipulation. |
| 54 | Intermediate | That, Though, Is a Lemming | Holiday cLemmings Frost | Worker roles: digger + miner; miner. Job changes: digger → miner. Also practise release-rate-manipulation. |
| 55 | Intermediate | 4 Pixels (or so) from Victory | ISteve03 | Give a permanent skill to one worker while other workers modify the route. |
| 56 | Intermediate | 32 Lemmings Below Zero | Holiday Lemmings 1993 | Worker roles: builder; builder + digger; builder + miner. Job changes: digger → builder; miner → builder. |
| 57 | Intermediate | The Great Lemming Road | Oh No More cLemmings Tame | Plan a three-skill sequence on one worker: basher, builder, miner. |
| 58 | Intermediate | Just When You Think You Know! | Lemmings Plus DOS Project Wimpy | Worker roles: blocker + bomber; builder + digger. Job changes: blocker → bomber; digger → builder. |
| 59 | Intermediate | Tricky Hit | Lemmings Plus DOS Project Mild | Worker roles: basher + digger + miner. Job changes: basher → miner; digger → basher. Three-step plans: digger → basher → miner. Also practise release-rate-manipulation. |
| 60 | Intermediate | Terrorist Attack | Pieuws Lemmings 2007 Artful | Worker roles: basher; bomber. Also practise release-rate-manipulation. |
| 61 | Intermediate | Take good care of my Lemmings | Lemmings | Worker roles: basher; builder. Also practise multiple-worker-coordination. |
| 62 | Intermediate | Careless clicking costs lives | Lemmings | Worker roles: basher; basher + builder. Job changes: basher → builder. Also practise multiple-worker-coordination. |
| 63 | Intermediate | We want to escape! | KillerMasters Lemmings 2 Tame | Worker roles: basher; basher + builder; blocker. Job changes: builder → basher. Also practise release-rate-manipulation. |
| 64 | Intermediate | Subterranean Exit | Pieuws Lemmings 2007 Peace | Worker roles: bomber; bomber + miner. Job changes: miner → bomber. Also practise release-rate-manipulation. |
| 65 | Intermediate | It's a Pipe-World | Pieuws Lemmings 2007 Peace | Worker roles: basher; bomber; builder. Also practise release-rate-manipulation. |
| 66 | Intermediate | Steel Block Party | Holiday Lemmings 1994 | Worker roles: basher; builder + digger. Job changes: digger → builder. |
| 67 | Intermediate | If only they could fly | Lemmings | Worker roles: builder + climber + floater; digger. Job changes: climber → floater; floater → builder. Three-step plans: climber → floater → builder. |
| 68 | Intermediate | Crematory Chamber | cLemmings Fun | Worker roles: builder + digger; builder + miner. Job changes: builder → miner; digger → builder. Also practise release-rate-manipulation. |
| 69 | Intermediate | The gauntlet | Giga pack 08 | Worker roles: builder; builder + digger; digger. Job changes: digger → builder. Also practise release-rate-manipulation. |
| 70 | Intermediate | Gather round and break away | PSP Special 27 36 | Worker roles: basher; blocker; builder. Also practise release-rate-manipulation. |
| 71 | Intermediate | Level 01.lvl | Amiga Demo | Worker roles: basher + builder; builder; builder + digger. Job changes: builder → basher; digger → builder. Also practise release-rate-manipulation. |
| 72 | Intermediate | The abyss | CRISFN03 | Worker roles: blocker; builder. Also practise multiple-worker-coordination. |
| 73 | Intermediate | Impassable | JM12 | Worker roles: basher + builder; builder; digger. Job changes: basher → builder. Also practise release-rate-manipulation. |
| 74 | Intermediate | Block and Build | brickpk1 | Worker roles: blocker; blocker + builder; builder. Job changes: builder → blocker. Also practise multiple-worker-coordination. |
| 75 | Intermediate | Just four in each room | CRISFN09 | Worker roles: basher; basher + bomber; bomber. Job changes: basher → bomber. Also practise multiple-worker-coordination. |
| 76 | Intermediate | Tea time in the ball country | Genesis Fun | Worker roles: basher; basher + digger; builder. Job changes: digger → basher. Also practise release-rate-manipulation. |
| 77 | Intermediate | Both The 7's...................! | TWPAK01 | Worker roles: basher + builder; builder; builder + digger. Job changes: basher → builder; digger → builder. Also practise release-rate-manipulation. |
| 78 | Intermediate | Eater of Luck | joe04 | Worker roles: builder + miner; climber. Job changes: miner → builder. Also practise release-rate-manipulation. |
| 79 | Intermediate | Satan Loves You | TWPAK01 | Worker roles: bomber + climber; builder. Job changes: climber → bomber. Also practise release-rate-manipulation. |
| 80 | Intermediate | Tightrope City | Lemmings | Worker roles: basher; basher + digger; blocker; builder. Job changes: digger → basher. |
| 81 | Intermediate | Float and Dig | brickpk1 | Change the same worker from miner to floater in a winning route. |
| 82 | Intermediate | Get up, up, up! | Lemmings Plus DOS Project Wimpy | Worker roles: basher; basher + builder; builder. Job changes: basher → builder; builder → basher. |
| 83 | Intermediate | Lemming Snowjourn | Holiday Lemmings 1993 | Worker roles: basher + digger. Job changes: digger → basher. |
| 84 | Intermediate | The lemming paradox | LEVIPAK3 | Worker roles: basher + builder + digger. Job changes: basher → builder; builder → digger; digger → basher. Three-step plans: basher → builder → digger; builder → digger → basher. Also practise release-rate-manipulation. |
| 85 | Intermediate | Clouds of Lemmings | Holiday Lemmings 1993 | Complete a short route with higher measured resource pressure. |
| 86 | Intermediate | Death Row | Lemmings Plus DOS Project PSYCHO | Worker roles: basher + digger; builder; digger. Job changes: digger → basher. |
| 87 | Intermediate | Hot Dungeon | KillerMasters Lemmings 1 Tame | Worker roles: basher; builder. Also practise release-rate-manipulation. |
| 88 | Intermediate | Turn around and look. | Oh Yes! More Lemmings! | Worker roles: builder + miner. Job changes: miner → builder. |
| 89 | Intermediate | Six Feet Under | Lemmings Plus DOS Project Medi | Worker roles: blocker + bomber; bomber. Job changes: blocker → bomber. Also practise release-rate-manipulation. |
| 90 | Intermediate | Float and Build | brickpk1 | Worker roles: builder + floater; floater. Job changes: floater → builder. Also practise release-rate-manipulation. |
| 91 | Intermediate | It's...... FACE?? | KillerMasters Lemmings 1 Tame | Worker roles: basher + builder; builder; miner. Job changes: basher → builder. |
| 92 | Intermediate | The Emerald Grotto | Pieuws Lemmings 2007 Peace | Worker roles: blocker; blocker + bomber; blocker + builder; builder. Job changes: blocker → bomber; builder → blocker. Also practise release-rate-manipulation. |
| 93 | Intermediate | Have a Pleasant Journey ! | Pieuws Lemmings 2007 Artful | Worker roles: bomber; miner. Also practise release-rate-manipulation. |
| 94 | Intermediate | Fun For The Whole Family! | TWPAK08 | Worker roles: builder; builder + miner. Job changes: builder → miner. Also practise release-rate-manipulation. |
| 95 | Intermediate | Pink pyramid | CRISFN14 | Worker roles: basher + builder + digger. Job changes: basher → builder; digger → basher. Three-step plans: digger → basher → builder. Also practise release-rate-manipulation. |
| 96 | Intermediate | Yo-yo Lem-lem | Holiday Lemmings 1993 | Worker roles: builder; builder + climber. Job changes: climber → builder. Also practise multiple-worker-coordination. |
| 97 | Intermediate | The great escape | Conway07 | Worker roles: blocker + builder; bomber; bomber + builder. Job changes: blocker → builder; bomber → builder; builder → blocker. Also practise release-rate-manipulation. |
| 98 | Intermediate | Toy Train | KillerMasters Lemmings 1 Tame | Worker roles: basher + digger; builder; builder + digger. Job changes: basher → digger; digger → basher; digger → builder. Also practise release-rate-manipulation. |
| 99 | Intermediate | Starry Level | EMPACK | Worker roles: basher + builder; builder; builder + miner. Job changes: basher → builder; builder → miner. Also practise release-rate-manipulation. |
| 100 | Intermediate | The Iron Puzzle | TimballistoPack1 | Worker roles: basher; basher + builder; builder. Job changes: builder → basher. Also practise multiple-worker-coordination. |
| 101 | Intermediate | The Strange Relict of Rhodes | Pieuws Lemmings 2007 Peace | Worker roles: basher + builder; basher + miner. Job changes: basher → builder; basher → miner. Also practise release-rate-manipulation. |
| 102 | Intermediate | Down And Out Lemmings | Oh No! More Lemmings | Plan a three-skill sequence on one worker: blocker, digger, miner. |
| 103 | Intermediate | Gone With The Lemming | Oh No! More Lemmings | Worker roles: basher + digger + miner. Job changes: digger → miner; miner → basher; miner → digger. Three-step plans: digger → miner → basher. |
| 104 | Intermediate | Bitter Lemming | Lemmings | Worker roles: basher + builder + digger + floater; floater. Job changes: basher → builder; digger → basher; floater → digger. Three-step plans: digger → basher → builder; floater → digger → basher. |
| 105 | Intermediate | I am A.T. | Oh Yes! More Lemmings! | Worker roles: builder + digger; digger. Job changes: digger → builder. Also practise release-rate-manipulation. |
| 106 | Intermediate | Lemming Tracks in the Snow! | Holiday Lemmings 1993 | Worker roles: basher; blocker; miner. Also practise multiple-worker-coordination. |
| 107 | Intermediate | The pit of doom | CRISFN13 | Worker roles: blocker + bomber; builder. Job changes: blocker → bomber. Also practise release-rate-manipulation. |
| 108 | Intermediate | Maniacal Lemmings | cLemmings Tricky | Worker roles: basher + builder; blocker; builder. Job changes: builder → basher. Also practise release-rate-manipulation. |
| 109 | Intermediate | Lovely jubilee | Genesis Tricky | Worker roles: basher + miner; bomber. Job changes: miner → basher. Also practise release-rate-manipulation. |
| 110 | Intermediate | Save the Lemmings with Floaters | PSP Special 1 10 of 36 | Change the same worker from climber to floater in a winning route. |
| 111 | Intermediate | Easy when you know how | Lemmings | Worker roles: basher; basher + builder + digger; basher + digger. Job changes: basher → builder; digger → basher. Three-step plans: digger → basher → builder. Also practise multiple-worker-coordination. |
| 112 | Intermediate | Twice the same? | geooPk1 | Worker roles: bomber + builder; builder. Job changes: builder → bomber. Also practise multiple-worker-coordination. |
| 113 | Intermediate | A Giant Leap for Lemmingkind | MARTPCK1 | Worker roles: blocker + bomber; bomber; builder. Job changes: blocker → bomber. Also practise release-rate-manipulation. |
| 114 | Intermediate | Dead Lemmings Tell no Tales | cLemmings Tricky | Worker roles: builder; builder + digger. Job changes: digger → builder. Also practise release-rate-manipulation. |
| 115 | Intermediate | We are now at LEMCON ONE | Lemmings | Worker roles: basher; builder; builder + digger; digger. Job changes: digger → builder. Also practise multiple-worker-coordination. |
| 116 | Intermediate | Asy-Lemm Seekers | TWPAK01 | Worker roles: basher; basher + builder + digger. Job changes: basher → builder; digger → basher. Three-step plans: digger → basher → builder. Also practise release-rate-manipulation. |
| 117 | Intermediate | Bridge over the iced water | JANNPCK1 | Worker roles: basher + digger; bomber. Job changes: digger → basher. Also practise release-rate-manipulation. |
| 118 | Intermediate | Lock up your Lemmings | Lemmings | Worker roles: builder + digger; digger. Job changes: builder → digger; digger → builder. Also practise multiple-worker-coordination. |
| 119 | Intermediate | Compression Method X | Yawg05 | Worker roles: basher + builder + digger; builder. Job changes: basher → digger; digger → builder. Three-step plans: basher → digger → builder. Also practise release-rate-manipulation. |
| 120 | Intermediate | A TOWERING PROBLEM | Oh No! More Lemmings | Worker roles: bomber; bomber + builder; bomber + climber; builder. Job changes: builder → bomber; climber → bomber. Also practise release-rate-manipulation. |
| 121 | Intermediate | The Long Way Around | Holiday Lemmings 1993 | Worker roles: basher + builder; blocker. Job changes: basher → builder; builder → basher. Also practise release-rate-manipulation. |
| 122 | Intermediate | Rainbow Island | Lemmings | Worker roles: basher; blocker + builder; builder. Job changes: builder → blocker. Also practise multiple-worker-coordination. |
| 123 | Intermediate | A Block from Home | Holiday Lemmings 1993 | Worker roles: basher + builder + digger; builder. Job changes: basher → builder; digger → basher. Three-step plans: digger → basher → builder. Also practise multiple-worker-coordination. |
| 124 | Intermediate | Luvly Jubly | Lemmings | Worker roles: basher + miner; bomber. Job changes: miner → basher. |
| 125 | Intermediate | Sacrifice | ssam1221s Lemmings Tame | Worker roles: blocker + bomber. Job changes: blocker → bomber. Also practise release-rate-manipulation. |
| 126 | Intermediate | A long way to go | Giga pack 09 | Worker roles: basher + builder + climber; builder. Job changes: basher → climber; climber → builder. Three-step plans: basher → climber → builder. Also practise multiple-worker-coordination. |
| 127 | Difficult | Value each moment | Genesis Taxing | Worker roles: bomber; builder. Also practise release-rate-manipulation. |
| 128 | Difficult | The metal walkway | ANTHPCK1 | Change a worker’s job and control the flow of followers. |
| 129 | Difficult | An "l" to serch | The lemming google pack | Change the same worker from builder to climber in a winning route. |
| 130 | Difficult | The Lemmyrinth | MazuLems 02 | Change the same worker from climber to builder in a winning route. |
| 131 | Difficult | Bash and Dig | brickpk2 | Worker roles: basher; digger. Also practise release-rate-manipulation. |
| 132 | Difficult | The waterfall | CRISFN01 | Worker roles: digger + floater; floater. Job changes: floater → digger. Also practise release-rate-manipulation. |
| 133 | Difficult | Underground Exit | Pieuws Lemmings 2007 Artful | Worker roles: basher + builder + digger; builder. Job changes: basher → digger; digger → builder. Three-step plans: basher → digger → builder. |
| 134 | Difficult | Lemm Of All Trades | TWPAK12 | Plan a three-skill sequence on one worker: builder, climber, floater. |
| 135 | Difficult | Let's go camping. | Oh Yes! More Lemmings! | Change the same worker from digger to builder in a winning route. |
| 136 | Difficult | Float and Bash | brickpk1 | Worker roles: basher + floater; floater. Job changes: floater → basher. Also practise release-rate-manipulation. |
| 137 | Difficult | Climb and Bash | brickpk1 | Worker roles: basher + climber; climber. Job changes: climber → basher. Also practise release-rate-manipulation. |
| 138 | Difficult | Iron Industry | Pieuw01 | Plan a three-skill sequence on one worker: basher, digger, miner. |
| 139 | Difficult | Freedom of the Lemmings | Deceits Lemmings Fun | Worker roles: basher; basher + floater; blocker. Job changes: basher → floater. Also practise release-rate-manipulation. |
| 140 | Difficult | Make a choice | Pieuws Lemmings 2007 Awkward | Change the same worker from climber to bomber in a winning route. |
| 141 | Difficult | The crystal caverns | CRISFN11 | Change the same worker from basher to digger in a winning route. |
| 142 | Difficult | If at first you don`t succeed.. | Lemmings | Worker roles: basher + builder + digger; digger. Job changes: basher → builder; digger → basher. Three-step plans: digger → basher → builder. |
| 143 | Difficult | Flow Control | Oh No! More Lemmings | Combine timing-sensitive assignments with release-rate control. |
| 144 | Difficult | Dangerzone | Oh No! More Lemmings | Manage several changes of job on one worker. |
| 145 | Difficult | Guess The Game | TWPAK10 | Worker roles: basher; basher + builder + miner; builder. Job changes: basher → builder; builder → miner. Three-step plans: basher → builder → miner. Also practise release-rate-manipulation. |
| 146 | Difficult | Snow Way! | TWPAK04 | Worker roles: builder + digger. Job changes: digger → builder. Also practise release-rate-manipulation. |
| 147 | Difficult | The Wrath of Lem | Holiday Lemmings 1993 | Worker roles: basher + builder; builder. Job changes: basher → builder. |
| 148 | Difficult | Use The Pen!!! | Lemmings Plus DOS Project Danger | Worker roles: basher + builder + climber. Job changes: basher → builder; climber → basher. Three-step plans: climber → basher → builder. Also practise release-rate-manipulation. |
| 149 | Difficult | Anxiety | Oh Yes! More Lemmings! | Worker roles: builder; builder + miner; miner. Job changes: builder → miner; miner → builder. Also practise release-rate-manipulation. |
| 150 | Difficult | Train your body | Oh Yes! More Lemmings! | Worker roles: basher; basher + builder + digger; digger. Job changes: basher → builder; builder → basher; digger → basher. Three-step plans: digger → basher → builder. |
| 151 | Difficult | Peak of Performance | Holiday Lemmings 1994 | Organise a route using four familiar skills. |
| 152 | Difficult | Konbanwa Lemming san | Lemmings | Worker roles: blocker; builder + floater + miner; digger. Job changes: floater → builder; miner → floater. Three-step plans: miner → floater → builder. |
| 153 | Difficult | Two heads are better... | Oh Yes! More Lemmings! | Worker roles: bomber + climber; climber + floater. Job changes: climber → bomber; climber → floater. |
| 154 | Difficult | The Final Frontier | Holiday Lemmings 1993 | Worker roles: blocker; blocker + bomber + builder; builder. Job changes: blocker → bomber; builder → blocker. Three-step plans: builder → blocker → bomber. Also practise release-rate-manipulation. |
| 155 | Difficult | Some Kind Of Lemming | Lemmings Plus DOS Project Danger | Worker roles: basher + builder; blocker; builder + miner; miner. Job changes: basher → builder; miner → builder. |
| 156 | Difficult | PiPeLiNe PaRaLLeL | Deceits Lemmings Tricky | Worker roles: builder; builder + digger. Job changes: digger → builder. Also practise multiple-worker-coordination. |
| 157 | Difficult | Cloud-Covered Stalactite | Pieuws Lemmings 2007 Awkward | Worker roles: basher; basher + builder; bomber. Job changes: basher → builder. Also practise release-rate-manipulation. |
| 158 | Difficult | Out of BASHERS??? | CRISFN03 | Change the same worker from builder to miner in a winning route. |
| 159 | Difficult | Call in the bomb squad | Lemmings | Worker roles: blocker + builder; bomber; bomber + builder; builder. Job changes: builder → blocker; builder → bomber. Also practise multiple-worker-coordination. |
| 160 | Difficult | ============Pipeline============ | TWPAK01 | Worker roles: basher; basher + builder. Job changes: basher → builder; builder → basher. Also practise multiple-worker-coordination. |
| 161 | Difficult | What comes down must go up. | QBeez06 | Worker roles: basher + digger; blocker; builder + digger. Job changes: digger → basher; digger → builder. |
| 162 | Difficult | Loop the loop! | unfinisd | Worker roles: basher; basher + builder + digger; basher + digger; builder. Job changes: basher → builder; digger → basher. Three-step plans: digger → basher → builder. Also practise release-rate-manipulation. |
| 163 | Difficult | Take new Lemmings! | Lemmy556 More levels | Worker roles: builder + floater; climber; floater. Job changes: floater → builder. Also practise release-rate-manipulation. |
| 164 | Difficult | Tunneling under | ANTHPCK5 | Worker roles: basher; basher + digger + miner; digger. Job changes: basher → digger; miner → basher. Three-step plans: miner → basher → digger. Also practise release-rate-manipulation. |
| 165 | Difficult | Snow Lev 5 | ANTHPCK4 | Worker roles: builder; builder + climber; builder + digger. Job changes: climber → builder; digger → builder. Also practise multiple-worker-coordination. |
| 166 | Difficult | Livin` On The Edge | Lemmings | Worker roles: basher; basher + builder; builder. Job changes: basher → builder; builder → basher. Also practise multiple-worker-coordination. |
| 167 | Difficult | Tribute to M.C.Escher | Lemmings | Worker roles: basher + builder + floater; builder. Job changes: builder → basher; builder → floater; floater → builder. Three-step plans: floater → builder → basher. Also practise multiple-worker-coordination. |
| 168 | Difficult | The end | Pieuws Lemmings 2007 Awkward | Worker roles: basher + builder; bomber; builder. Job changes: basher → builder; builder → basher. Also practise multiple-worker-coordination. |
| 169 | Difficult | Romeo n Juliet | Deceits Lemmings Fun | Worker roles: basher + builder; builder + floater. Job changes: basher → builder; builder → basher; floater → builder. Also practise multiple-worker-coordination. |
| 170 | Difficult | Maybe not such a doddle | Holiday Lemmings 1994 | Worker roles: blocker; builder; digger + miner. Job changes: digger → miner. Also practise multiple-worker-coordination. |
| 171 | Difficult | Let's be careful out there | Lemmings | Worker roles: builder; builder + digger + floater; floater; floater + miner. Job changes: digger → floater; floater → builder; miner → floater. Three-step plans: digger → floater → builder. Also practise multiple-worker-coordination. |
| 172 | Difficult | Have an ice day | Oh No! More Lemmings | Worker roles: basher + builder + digger. Job changes: basher → builder; builder → basher; digger → builder. Three-step plans: digger → builder → basher. Also practise release-rate-manipulation. |
| 173 | Difficult | This should be a doddle! | Lemmings | Manage a route with higher measured coordination demands. |
| 174 | Difficult | Lemmings in the attic | Lemmings | Worker roles: basher; basher + builder + climber + miner; builder. Job changes: basher → builder; builder → basher; builder → miner; climber → builder. Three-step plans: basher → builder → miner; climber → builder → basher. Also practise multiple-worker-coordination. |
| 175 | Difficult | Perseverance | Lemmings | Combine four skills under high measured resource pressure. |
| 176 | Difficult | The Lemming Learning Curve | Oh No! More Lemmings | Worker roles: basher; builder; builder + miner; climber. Job changes: miner → builder. Also practise multiple-worker-coordination. |
| 177 | Difficult | Triple Trouble | Lemmings | Worker roles: basher + builder + climber; builder; builder + climber; digger. Job changes: builder → basher; climber → builder. Three-step plans: climber → builder → basher. Also practise multiple-worker-coordination. |
| 178 | Difficult | Watch right or left (Part two) | Oh Yes! More Lemmings! | Worker roles: basher + bomber + builder + digger; bomber. Job changes: basher → bomber; basher → builder; builder → basher; digger → basher. Three-step plans: builder → basher → bomber; digger → basher → builder. Also practise release-rate-manipulation. |
| 179 | Difficult | No world without you | Oh Yes! More Lemmings! | Worker roles: basher + builder + digger; builder + climber. Job changes: basher → builder; basher → digger; climber → builder; digger → basher. Three-step plans: digger → basher → builder. Also practise multiple-worker-coordination. |
| 180 | Difficult | Rules to fall | Oh Yes! More Lemmings! | Worker roles: digger + floater; floater. Job changes: digger → floater. |
| 181 | Difficult | Plethora of Presents | Holiday Lemmings 1994 | Worker roles: basher; basher + builder; miner. Job changes: basher → builder. |
| 182 | Difficult | Lemmings Up High | Holiday Lemmings 1993 | Worker roles: basher + builder; builder. Job changes: builder → basher. Also practise release-rate-manipulation. |
| 183 | Difficult | Undercover Lemming | Oh No! More Lemmings | Worker roles: basher + digger + miner. Job changes: basher → miner; digger → miner; miner → basher; miner → digger. Three-step plans: basher → miner → digger; digger → miner → basher. |
| 184 | Difficult | Suicidal Tendencies | Oh No! More Lemmings | Worker roles: blocker; blocker + bomber; builder + miner. Job changes: blocker → bomber; builder → miner. Also practise release-rate-manipulation. |
| 185 | Difficult | Lemming about town | Oh No! More Lemmings | Combine a long single-worker sequence with a restricted skill budget. |
| 186 | Difficult | Five Alive | Oh No! More Lemmings | Worker roles: bomber; builder; climber + miner; floater. Job changes: climber → miner. |
| 187 | Difficult | Haunted botanical garden | Oh Yes! More Lemmings! | Worker roles: builder; digger; miner. Also practise multiple-worker-coordination. |
| 188 | Difficult | Every Lemming for himself!!! | Lemmings | Worker roles: basher; bomber + builder; builder + climber. Job changes: bomber → builder; climber → builder. Also practise multiple-worker-coordination. |
| 189 | Difficult | It's Boxing Day! | Holiday Lemmings 1994 | Worker roles: basher + builder; basher + digger. Job changes: builder → basher; digger → basher. Also practise release-rate-manipulation. |
| 190 | Difficult | Hunt the Nessy.... | Lemmings | Worker roles: basher + builder + miner; builder + digger. Job changes: basher → miner; builder → basher; digger → builder; miner → builder. Three-step plans: basher → miner → builder; builder → basher → miner. Also practise multiple-worker-coordination. |
| 191 | Difficult | The Voyage Home... | Holiday Lemmings 1993 | Worker roles: bomber; bomber + digger. Job changes: digger → bomber. |
| 192 | Difficult | Quest for Kieran | Holiday Lemmings 1994 | Worker roles: builder; miner. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 193 | Difficult | CindyLand | Holiday Lemmings 1994 | Worker roles: basher; blocker. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 194 | Difficult | Steel Ice Span | Holiday Lemmings 1994 | Worker roles: builder; builder + climber. Job changes: climber → builder. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 195 | Difficult | Up, up, and away! | Holiday Lemmings 1994 | Worker roles: basher + builder; builder. Job changes: builder → basher. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 196 | Difficult | How on Earth? | Oh No! More Lemmings | Worker roles: blocker; blocker + builder; builder. Job changes: builder → blocker. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 197 | Difficult | Presents of Mind | Holiday Lemmings 1993 | Worker roles: basher + builder; builder. Job changes: basher → builder. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 198 | Difficult | Evacuating a coal mine | Oh Yes! More Lemmings! | Worker roles: basher + builder + climber + miner; builder. Job changes: basher → miner; builder → basher; builder → miner; climber → basher; miner → builder. Three-step plans: basher → miner → builder; climber → basher → miner; miner → builder → basher. |
| 199 | Difficult | This Corrosion | Oh No! More Lemmings | Worker roles: builder; builder + digger; digger. Job changes: digger → builder. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 200 | Difficult | Marshmallow Land | Holiday Lemmings 1993 | Combine measured timing pressure with concurrent work. |
| 201 | Difficult | Santus Lemmingus | Holiday Lemmings 1993 | Worker roles: basher + digger; builder + climber + digger + floater. Job changes: climber → floater; digger → basher; digger → builder; floater → digger. Three-step plans: climber → floater → digger; floater → digger → builder. |
| 202 | Difficult | Inroducing SUPERLEMMING | Oh No! More Lemmings | Worker roles: basher + builder + climber + digger + miner. Job changes: basher → climber; builder → basher; builder → digger; climber → digger; digger → builder; miner → basher. Three-step plans: basher → climber → digger; climber → digger → builder; digger → builder → basher; miner → basher → climber. |
| 203 | Difficult | Up on the Rooftops | Holiday Lemmings 1994 | Worker roles: builder; builder + climber + floater. Job changes: climber → floater; floater → builder. Three-step plans: climber → floater → builder. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 204 | Difficult | Sir Edmund Hilemming | Holiday Lemmings 1994 | Worker roles: builder; builder + digger; builder + miner. Job changes: builder → miner; digger → builder; miner → builder. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 205 | Difficult | The gate trap Lemmings. | Oh Yes! More Lemmings! | Worker roles: basher; basher + builder + digger; blocker; builder. Job changes: basher → builder; builder → basher; digger → basher. Three-step plans: digger → basher → builder. Also practise multiple-worker-coordination. |
| 206 | Difficult | Three-way Call | GARJEN01 | Combine a high resource pressure with work across several regions. |
| 207 | Difficult | Ten Green Lemmings | cLemmings Taxing | Bridge moderate coordination and expert concurrency with a busier familiar-skill route. |
| 208 | Difficult | Doomsday | Oh Yes! More Lemmings! | Worker roles: blocker + bomber; blocker + bomber + builder; blocker + builder; builder; climber. Job changes: blocker → bomber; builder → blocker. Three-step plans: builder → blocker → bomber. |
| 209 | Difficult | Tribute to M.C.Escher (remake) | LEMREMAKE | Worker roles: basher + builder + climber + floater + miner; builder + miner. Job changes: basher → builder; builder → miner; climber → floater; floater → builder; miner → basher. Three-step plans: builder → miner → basher; climber → floater → builder; floater → builder → miner; miner → basher → builder. Also practise release-rate-manipulation. |
| 210 | Difficult | One way digging to freedom | Lemmings | Worker roles: basher + builder + climber + digger + floater. Job changes: basher → builder; basher → digger; basher → floater; builder → basher; climber → basher; digger → basher; digger → builder; floater → digger. Three-step plans: basher → floater → digger; climber → basher → digger; digger → basher → floater; digger → builder → basher; floater → digger → builder. |
| 211 | Difficult | A ladder would be handy | Lemmings | Worker roles: basher + digger; builder + climber + floater + miner. Job changes: builder → climber; builder → miner; climber → builder; digger → basher; floater → builder. Three-step plans: climber → builder → miner; floater → builder → climber. Also practise multiple-worker-coordination. |
| 212 | Difficult | Happy New Year! | Holiday Lemmings 1994 | Worker roles: basher; basher + bomber + builder; basher + builder; blocker; blocker + builder. Job changes: basher → bomber; basher → builder; builder → basher; builder → blocker. Three-step plans: builder → basher → bomber. Also practise multiple-worker-coordination. |
| 213 | Difficult | SPAM,SPAM,SPAM,EGG AND LEMMING | Oh No! More Lemmings | Worker roles: basher + builder + floater + miner; blocker; blocker + bomber. Job changes: basher → miner; blocker → bomber; builder → basher; floater → builder; miner → builder. Three-step plans: basher → miner → builder; builder → basher → miner; floater → builder → basher. Also practise release-rate-manipulation. |
| 214 | Difficult | Lemming Productions Present... | Oh No! More Lemmings | Worker roles: basher + bomber + builder + climber; blocker; blocker + bomber + climber; miner. Job changes: blocker → bomber; bomber → builder; bomber → climber; builder → basher; climber → bomber. Three-step plans: blocker → bomber → climber; bomber → builder → basher; climber → bomber → builder. Also practise multiple-worker-coordination. |
| 215 | Difficult | The delivery service | ANTHPCK5 | Use five distinct skills in one worker’s sequence. |
| 216 | Difficult | The moon cave | CRISFN01 | Worker roles: basher + builder; basher + miner; builder; builder + miner; miner. Job changes: basher → builder; builder → basher; miner → basher; miner → builder. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 217 | Difficult | Faithful Friends | GARJEN09 | Worker roles: basher + climber; basher + climber + digger + floater; climber; climber + miner. Job changes: basher → climber; climber → floater; climber → miner; digger → basher; digger → climber; floater → digger. Three-step plans: climber → floater → digger; digger → climber → floater; floater → digger → basher. Also practise multiple-worker-coordination. |
| 218 | Difficult | A Beast of a level | Lemmings | Worker roles: basher; basher + blocker; basher + builder; builder + digger; builder + miner. Job changes: basher → builder; blocker → basher; builder → basher; digger → builder; miner → builder. |
| 219 | Difficult | Ecsape From Nightmare | ssam1221s Lemmings Havoc | Worker roles: basher; basher + builder; builder. Job changes: basher → builder; builder → basher. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 220 | Difficult | Snow Lev 7 | ANTHPCK4 | Worker roles: blocker; builder + digger; builder + miner. Job changes: builder → digger; digger → builder; miner → builder. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 221 | Difficult | Seeing double! | PSP Special 11 26 of 36 | Worker roles: basher + builder; basher + builder + climber; basher + climber; blocker + bomber; climber. Job changes: basher → builder; blocker → bomber; builder → basher; builder → climber; climber → basher. Three-step plans: basher → builder → climber. Also practise release-rate-manipulation. |
| 222 | Difficult | Water processing plant | Oh Yes! More Lemmings! | Worker roles: basher + builder + miner; builder; builder + floater. Job changes: builder → miner; floater → builder; miner → basher. Three-step plans: builder → miner → basher. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 223 | Difficult | Just a minute (Part Three) | Oh Yes! More Lemmings! | Worker roles: basher + climber + miner; basher + digger. Job changes: basher → miner; climber → miner; digger → basher; miner → basher. Three-step plans: climber → miner → basher. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 224 | Difficult | It`s the price you have to pay | Oh No! More Lemmings | Worker roles: basher; basher + builder + digger + miner; basher + builder + miner. Job changes: basher → builder; builder → digger; digger → miner; miner → basher. Three-step plans: builder → digger → miner; digger → miner → basher; miner → basher → builder. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 225 | Difficult | X marks the spot | Lemmings | Worker roles: builder; builder + climber + miner; miner. Job changes: builder → climber; builder → miner; climber → miner; miner → builder. Three-step plans: builder → climber → miner; climber → miner → builder. Also practise multiple-worker-coordination. |
| 226 | Difficult | Emmings!  (No L) | Holiday Lemmings 1994 | Worker roles: builder; builder + climber + digger; builder + climber + digger + miner; miner. Job changes: climber → digger; digger → builder; miner → climber. Three-step plans: climber → digger → builder; miner → climber → digger. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 227 | Difficult | Were ready for landing | Giga pack 04 | Worker roles: basher + builder; builder; builder + climber + miner; digger; miner. Job changes: basher → builder; builder → basher; builder → miner; climber → builder; miner → builder. Three-step plans: climber → builder → miner. Also practise multiple-worker-coordination. |
| 228 | Difficult | Lemming City | Pieuws Lemmings 2007 Awkward | Worker roles: basher; basher + builder + climber + floater. Job changes: basher → builder; basher → floater; builder → basher; climber → basher; floater → basher. Three-step plans: climber → basher → floater; floater → basher → builder. Also practise multiple-worker-coordination. |
| 229 | Difficult | Patience | Lemmings | Worker roles: blocker + climber; builder; builder + climber + digger + floater + miner. Job changes: blocker → climber; builder → climber; builder → digger; climber → floater; digger → miner; floater → builder; miner → builder. Three-step plans: builder → climber → floater; builder → digger → miner; climber → floater → builder; digger → miner → builder; floater → builder → digger. Also practise multiple-worker-coordination. |
| 230 | Difficult | Go Thataway! | Holiday Lemmings 1994 | Worker roles: basher + builder + climber + floater. Job changes: builder → basher; climber → floater; floater → builder. Three-step plans: climber → floater → builder; floater → builder → basher. Also practise release-rate-manipulation. |
| 231 | Difficult | Science from the 4th dimension | Mikes Lemmix Pack | Worker roles: basher + blocker; basher + builder + climber; basher + digger; blocker; blocker + climber; digger; miner. Job changes: blocker → basher; builder → basher; climber → blocker; climber → builder; digger → basher. Three-step plans: climber → builder → basher. Also practise release-rate-manipulation. |
| 232 | Difficult | Fall and no life (Part Two) | Oh Yes! More Lemmings! | Worker roles: basher; basher + builder + floater + miner; builder; miner. Job changes: basher → builder; basher → miner; builder → basher; floater → builder; miner → basher. Three-step plans: builder → basher → miner; floater → builder → basher; miner → basher → builder. Also practise multiple-worker-coordination. |
| 233 | Difficult | Four Play | Holiday Lemmings 1994 | Worker roles: basher + builder + digger; digger. Job changes: basher → builder; digger → basher. Three-step plans: digger → basher → builder. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 234 | Expert | Many Lemmings make level work | Oh No! More Lemmings | Assign bomber and builder to separate workers without changing their skills. |
| 235 | Expert | Mind the step..... | Lemmings | Plan a three-skill sequence on one worker: basher, builder, digger. |
| 236 | Expert | The Steel Mines of Kessel | Lemmings | Worker roles: blocker + builder; bomber; builder. Job changes: blocker → builder; builder → blocker. |
| 237 | Expert | The Boiler Room | Lemmings | Worker roles: builder + climber; builder + climber + floater; climber. Job changes: builder → climber; builder → floater; floater → builder. Three-step plans: floater → builder → climber. |
| 238 | Expert | Dr Lemminggood | Oh No! More Lemmings | Worker roles: bomber; builder. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 239 | Expert | Lemming Net | Lemmings Plus DOS Project Wimpy | Apply familiar skills with demanding assignment timing. |
| 240 | Expert | No Problemming! | Oh No! More Lemmings | Change a worker’s job while managing another working region. |
| 241 | Expert | Lemming Friendly | Oh No! More Lemmings | Worker roles: basher + builder. Job changes: basher → builder; builder → basher. Also practise release-rate-manipulation. |
| 242 | Expert | It`s a trade off | Oh No! More Lemmings | Worker roles: builder; digger; miner. Also practise release-rate-manipulation. |
| 243 | Expert | Meeting Adjourned | Oh No! More Lemmings | Worker roles: basher; basher + builder; digger. Job changes: basher → builder. Also practise multiple-worker-coordination. |
| 244 | Expert | Going up....... | Lemmings | Worker roles: basher + builder; builder. Job changes: basher → builder; builder → basher. Also practise multiple-worker-coordination. |
| 245 | Expert | Lemming Head | Oh No! More Lemmings | Worker roles: blocker; blocker + bomber; builder. Job changes: blocker → bomber. Also practise release-rate-manipulation. |
| 246 | Expert | It`s all a matter of timing | Oh No! More Lemmings | Apply the learned techniques across highly concurrent work. |
| 247 | Expert | Time to get up! | Lemmings | Worker roles: bomber + builder; bomber + builder + climber; builder. Job changes: builder → bomber; climber → builder. Three-step plans: climber → builder → bomber. Also practise multiple-worker-coordination. |
| 248 | Expert | ROCKY VI | Oh No! More Lemmings | Worker roles: basher + builder; bomber + builder; builder. Job changes: basher → builder; builder → bomber. Also practise release-rate-manipulation. |
| 249 | Expert | Got anything....Lemmingy??? | Oh No! More Lemmings | Worker roles: builder; digger. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 250 | Expert | DON`T PANIC | Oh No! More Lemmings | Worker roles: basher + builder + digger. Job changes: basher → builder; builder → basher; builder → digger. Three-step plans: basher → builder → digger. Also practise release-rate-manipulation. |
| 251 | Expert | The Great Lemming Caper | Lemmings | Worker roles: basher + builder; basher + climber + floater. Job changes: basher → climber; builder → basher; floater → basher. Three-step plans: floater → basher → climber. Also practise multiple-worker-coordination. |
| 252 | Expert | Take care, Sweetie | Oh No! More Lemmings | Worker roles: builder + climber. Job changes: builder → climber. |
| 253 | Expert | On the Antarctic Coast | Oh No! More Lemmings | Worker roles: basher; builder; miner. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 254 | Expert | Who`s That Lemming | Oh No! More Lemmings | Worker roles: basher; blocker + bomber + floater; bomber + climber; builder; builder + floater; climber; floater; miner. Job changes: blocker → bomber; bomber → floater; builder → floater; climber → bomber. Three-step plans: blocker → bomber → floater. |
| 255 | Expert | SUNSOFT Special | Oh Yes! More Lemmings! | Worker roles: basher + builder + digger; blocker; blocker + bomber. Job changes: basher → builder; blocker → bomber; builder → basher; digger → basher. Three-step plans: digger → basher → builder. Also practise release-rate-manipulation. |
| 256 | Expert | Time waits for no Lemming | Oh No! More Lemmings | Worker roles: basher + blocker; blocker; builder; digger. Job changes: basher → blocker. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 257 | Expert | NO PROBLEM | Oh No! More Lemmings | Worker roles: basher + builder + miner. Job changes: basher → builder; basher → miner; builder → basher; builder → miner; miner → builder. Three-step plans: basher → builder → miner; builder → basher → miner; miner → builder → basher. Also practise release-rate-manipulation. |
| 258 | Expert | DIGGING FOR VICTORY | Oh No! More Lemmings | Control crowd spacing through a route that uses five skills. |
| 259 | Expert | Lemming Rhythms | Oh No! More Lemmings | Worker roles: basher + builder + miner. Job changes: basher → builder; builder → basher; builder → miner; miner → builder. Three-step plans: basher → builder → miner; miner → builder → basher. Also practise release-rate-manipulation. |
| 260 | Expert | The Stack | Oh No! More Lemmings | Worker roles: builder; builder + climber + digger. Job changes: builder → digger; climber → builder; climber → digger; digger → builder. Three-step plans: climber → builder → digger; climber → digger → builder. Also practise multiple-worker-coordination. |
| 261 | Expert | KEEP ON TRUCKING | Oh No! More Lemmings | Combine a complex multi-skill route with high resource pressure. |
| 262 | Expert | Wild Lemmings | Oh No More cLemmings Wild | Worker roles: blocker + bomber; builder + digger + floater + miner. Job changes: blocker → bomber; builder → miner; digger → floater; floater → builder; miner → builder. Three-step plans: digger → floater → builder; floater → builder → miner. |
| 263 | Expert | Just A Quicky | Oh No! More Lemmings | Worker roles: basher + builder + digger + miner. Job changes: basher → builder; basher → digger; builder → basher; builder → miner; digger → builder; miner → builder; miner → digger. Three-step plans: basher → builder → miner; basher → digger → builder; builder → basher → digger; digger → builder → basher; miner → builder → basher; miner → digger → builder. Also practise release-rate-manipulation. |
| 264 | Expert | Have a nice day! | Lemmings | Worker roles: basher; blocker; builder; builder + digger + floater; builder + miner. Job changes: builder → digger; builder → miner; digger → builder; floater → builder. Three-step plans: floater → builder → digger. Also practise multiple-worker-coordination. |
| 265 | Expert | Tubular Lemmings | Oh No! More Lemmings | Worker roles: builder + digger. Job changes: builder → digger; digger → builder. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 266 | Expert | Save Me | Lemmings | Worker roles: basher + blocker + builder + digger; basher + builder + digger; blocker; blocker + builder. Job changes: basher → digger; blocker → basher; blocker → builder; builder → basher; builder → blocker; builder → digger; digger → builder. Three-step plans: basher → digger → builder; blocker → basher → digger; digger → builder → basher; digger → builder → blocker. |
| 267 | Expert | It`s a tight fit! | Oh No! More Lemmings | Worker roles: builder + climber + floater; climber + floater. Job changes: climber → floater; floater → builder. Three-step plans: climber → floater → builder. Also practise release-rate-manipulation. |
| 268 | Expert | There's a lot of them about | Lemmings | Worker roles: blocker + builder; builder; builder + climber; miner. Job changes: builder → blocker; builder → climber; climber → builder. Also practise multiple-worker-coordination. |
| 269 | Expert | Not just a pretty Lemming | Oh No! More Lemmings | Worker roles: basher; basher + miner; blocker + bomber + climber; bomber + floater; builder; climber; floater; miner. Job changes: blocker → bomber; bomber → climber; bomber → floater; miner → basher. Three-step plans: blocker → bomber → climber. Also practise multiple-worker-coordination. |
| 270 | Expert | Creature Discomforts | Oh No! More Lemmings | Worker roles: basher + builder + climber + miner; blocker; blocker + bomber; builder; builder + climber + digger; climber. Job changes: basher → miner; blocker → bomber; builder → climber; climber → builder; digger → builder; miner → climber. Three-step plans: basher → miner → climber; digger → builder → climber; miner → climber → builder. Also practise multiple-worker-coordination. |
| 271 | Expert | ONWARD AND UPWARD | Oh No! More Lemmings | Worker roles: basher + bomber + builder + climber + miner; blocker + bomber; blocker + bomber + climber; bomber. Job changes: basher → bomber; basher → builder; blocker → bomber; builder → basher; climber → blocker; climber → miner; miner → basher. Three-step plans: builder → basher → bomber; climber → blocker → bomber; climber → miner → basher; miner → basher → builder. Also practise release-rate-manipulation. |
| 272 | Expert | And now this... | Oh No! More Lemmings | Worker roles: basher; basher + climber; blocker + bomber + builder + digger + floater; builder; climber; floater. Job changes: basher → climber; blocker → bomber; bomber → floater; builder → blocker; climber → basher; digger → builder. Three-step plans: blocker → bomber → floater; builder → blocker → bomber; digger → builder → blocker. |
| 273 | Expert | I have a cunning plan | Lemmings | Worker roles: basher + blocker; basher + builder + digger; blocker + builder; builder + digger + miner. Job changes: basher → blocker; blocker → builder; builder → basher; builder → digger; builder → miner; digger → builder; digger → miner; miner → builder. Three-step plans: builder → digger → miner; digger → builder → basher; digger → miner → builder; miner → builder → digger. |
| 274 | Expert | Lemmings in a situation | Oh No! More Lemmings | Worker roles: basher + bomber + builder + climber + digger + floater. Job changes: basher → builder; builder → basher; builder → digger; climber → floater; digger → bomber; digger → builder; floater → builder. Three-step plans: basher → builder → digger; builder → digger → bomber; climber → floater → builder; digger → builder → basher; floater → builder → digger. |
| 275 | Expert | Snuggle up to a Lemming | Oh No! More Lemmings | Worker roles: basher + digger; blocker + bomber; blocker + bomber + climber + miner; bomber; climber; digger; floater. Job changes: blocker → bomber; bomber → climber; digger → basher; miner → blocker. Three-step plans: blocker → bomber → climber; miner → blocker → bomber. Also practise multiple-worker-coordination. |
| 276 | Expert | Origins and Lemmings | Lemmings | Carry permanent skills through a complex construction sequence. |
| 277 | Expert | Oogilemming! | Holiday Lemmings 1993 | Worker roles: basher + builder + digger; blocker; builder + climber + floater. Job changes: basher → builder; builder → basher; climber → floater; digger → builder; floater → builder. Three-step plans: climber → floater → builder; digger → builder → basher. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 278 | Expert | Get the Point? | Holiday Lemmings 1994 | Worker roles: blocker + floater; builder; builder + digger + floater; builder + floater; floater. Job changes: digger → builder; floater → blocker; floater → builder; floater → digger. Three-step plans: floater → digger → builder. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 279 | Expert | Merry Christmas Mr Lemming | Xmas Lemmings 1991 | Worker roles: basher + builder + climber + digger + miner. Job changes: basher → builder; basher → climber; basher → miner; builder → basher; builder → miner; climber → digger; digger → builder; miner → basher; miner → builder. Three-step plans: basher → builder → miner; basher → climber → digger; basher → miner → builder; builder → basher → miner; builder → miner → basher; climber → digger → builder; digger → builder → miner; miner → basher → builder. |
| 280 | Expert | The Far Side | Lemmings | Worker roles: basher + builder + climber + digger + miner. Job changes: basher → builder; basher → digger; builder → basher; builder → climber; builder → digger; climber → digger; digger → basher; digger → builder; digger → miner; miner → builder; miner → digger. Three-step plans: basher → digger → builder; builder → basher → digger; builder → climber → digger; builder → digger → basher; builder → digger → miner; climber → digger → miner; digger → basher → builder; digger → miner → builder; miner → builder → digger. |
| 281 | Expert | Stepping Stones | Lemmings | Worker roles: basher + blocker + digger; basher + builder + climber + digger + miner; basher + miner; blocker; builder. Job changes: basher → digger; basher → miner; blocker → digger; builder → miner; climber → miner; digger → basher; digger → builder; miner → climber; miner → digger. Three-step plans: basher → digger → builder; blocker → digger → basher; climber → miner → digger; digger → builder → miner; miner → digger → basher. |
| 282 | Expert | Don't let your eyes deceive you | Lemmings | Worker roles: blocker + climber + floater; builder; builder + climber + digger + floater + miner; builder + climber + floater; climber + digger + floater + miner. Job changes: blocker → floater; builder → digger; climber → floater; digger → miner; floater → blocker; floater → builder; floater → climber; floater → digger; miner → climber. Three-step plans: blocker → floater → climber; builder → digger → miner; climber → floater → blocker; climber → floater → builder; digger → miner → climber; floater → builder → digger; floater → digger → miner. Also practise multiple-worker-coordination. |
| 283 | Expert | Rendezvous at the Mountain | Lemmings | Worker roles: builder; builder + climber + digger + miner; builder + climber + miner; builder + digger; climber + digger + miner. Job changes: builder → digger; builder → miner; climber → builder; climber → digger; climber → miner; digger → builder; digger → miner; miner → builder. Three-step plans: climber → builder → digger; climber → digger → miner; climber → miner → builder; digger → builder → miner. Also practise multiple-worker-coordination. |
| 284 | Expert | The Fast Food Kitchen... | Lemmings | Worker roles: basher; basher + blocker + builder + digger; basher + builder; basher + builder + digger; basher + miner; blocker; builder; builder + climber + digger; builder + climber + floater. Job changes: basher → builder; basher → digger; blocker → digger; builder → basher; climber → builder; climber → digger; digger → basher; digger → builder; floater → climber; miner → basher. Three-step plans: basher → digger → builder; blocker → digger → builder; climber → digger → builder; digger → builder → basher; floater → climber → builder. Also practise multiple-worker-coordination. |
| 285 | Expert | Chill out! | Oh No! More Lemmings | Combine long worker sequences, crowd spacing and concurrent work. |
| 286 | Expert | AAAAAARRRRRRGGGGGGHHHHHH!!!!!! | Oh No! More Lemmings | Worker roles: builder; climber; climber + miner. Job changes: climber → miner. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 287 | Expert | It Came Upon a Lemnight Clear | Holiday Lemmings 1993 | Worker roles: basher + bomber + builder + climber; blocker; builder; digger + miner. Job changes: basher → builder; builder → basher; builder → bomber; climber → builder; digger → miner. Three-step plans: basher → builder → bomber; climber → builder → basher. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 288 | Expert | Zygoptera | AkseliPack01 | Worker roles: basher + digger; blocker; bomber; builder; climber; miner. Job changes: basher → digger. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 289 | Expert | Waste High! | ANTHPCK5 | Worker roles: blocker + bomber; builder + climber + floater + miner; builder + digger. Job changes: blocker → bomber; builder → climber; builder → miner; climber → builder; digger → builder; floater → builder; miner → builder. Three-step plans: climber → builder → miner; floater → builder → climber. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 290 | Expert | A group of entrances | Genesis Mayhem | Worker roles: basher + builder; basher + climber; basher + digger; blocker + bomber; builder; miner. Job changes: basher → builder; basher → digger; blocker → bomber; builder → basher; climber → basher; digger → basher. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 291 | Expert | Three Birds With One Stone | Lemmings Plus DOS Project PSYCHO | Worker roles: blocker + bomber + climber + floater; bomber + builder + climber + digger; bomber + climber + floater; builder; climber + floater + miner; floater. Job changes: blocker → bomber; builder → digger; climber → builder; climber → floater; digger → bomber; floater → blocker; floater → bomber; floater → miner. Three-step plans: builder → digger → bomber; climber → builder → digger; climber → floater → blocker; climber → floater → bomber; climber → floater → miner; floater → blocker → bomber. Also practise multiple-worker-coordination, release-rate-manipulation. |
| 292 | Expert | Operation Rescue | CPs Level Pack | Combine substantial coordination with long worker sequences. |
