# Classic Lemmings completion evidence

All **120 of 120** original DOS levels have preserved winning replays that pass the native engine completion gate. Each run uses the original population, rescue requirement, skills, terrain and time limit. Every input must apply, the level must finish with a win, and a fresh run must reproduce the recorded outcome and state hash. Missing or invalid evidence fails the gate.

**103 levels rescue their entire population.** Those replays prove zero necessary sacrifices. The other 17 have verified winning solutions, but their upper rescue bounds remain unproven. The maximum-rescue task is not complete.

The older all-level smoke test established loading and movement over 510 ticks. It did not establish completion. These fixtures now provide the missing completion evidence.

## Reproduce

Build the local app with its original game data, then run:

```sh
zsh Scripts/verify-classic-completion.sh
python3 Tests/ClassicDOSCompletionTests/test_gate.py .build/classic-completion/check/verify '.build/local/Ultimate Lemmings.app/Contents/Resources/Ports/lemmings_dos_1991-07-30'
```

The negative checks remove a replay, add an unavailable skill assignment, and change an expected rescue count. Each must fail. [Tool instructions](../../Tools/ClassicCompletion/README.md) explain discovery and manual plans. [Evidence manifest](evidence.json) records fixture hashes, outcomes, engine source fingerprint, and matching reference recordings where available.

## Physics correction

The audit found that destructive masks were clipped against every steel pixel. DOS checks steel at skill-specific probe points, then applies an eligible mask in full. The native engine now follows that behavior while retaining steel metadata and the existing probes. The focused digger regression fails with the old mask implementation and passes with the correction. Existing steel tests and the full simulation regression suite also pass. See the reference implementation in [Lemmix LemGame.pas](https://github.com/AaronKelley/LemmixPlayer/blob/main/PlayerSourceTrad/LemGame.pas), including RemovePixelAt, HandleDigging and the destructive mask routines.

## Candidate sources

Community Lemmix recordings supplied candidate inputs, which were accepted only after successful native replay verification. Recordings may solve reused terrain under a different level title; the final fixture always verifies the actual target level and its original constraints. Native searches and the preserved manual plans supplied additional solutions. Matching source recordings and their hashes appear in the evidence manifest; no match means the manifest makes no external source attribution.

Source collections on Lemmings Forums: [maximum saved](https://www.lemmingsforums.net/index.php?topic=1383.0), [undamaged levels](https://www.lemmingsforums.net/index.php?topic=1490.0), [minimum skills](https://www.lemmingsforums.net/index.php?topic=1018.0), [minimum skills at maximum rescue](https://www.lemmingsforums.net/index.php?topic=1068.0), [essential skills](https://www.lemmingsforums.net/index.php?topic=1084.0), [skills for maximum rescue](https://www.lemmingsforums.net/index.php?topic=1414.0), [one assignment per lemming](https://www.lemmingsforums.net/index.php?topic=1050.0), [one direction](https://www.lemmingsforums.net/index.php?topic=1317.0), [fewest skill types](https://www.lemmingsforums.net/index.php?topic=1094.0), and [one worker](https://www.lemmingsforums.net/index.php?topic=1059.0).

The [Camanis mirror of LemmingsWelt challenge replays](https://www.camanis.net/lemmings/lemmingswelt/index.php?cmd=cd&dir=challenge_replays) supplied the improved Tricky 23, Taxing 20, and Taxing 28 recordings. [Archive provenance](reference-archives.json) preserves their download URLs and SHA-256 hashes. Each recording reproduced its result without timing adjustments in the native engine.

Tricky 16 combines the initial miner and basher assignments from [Clam’s one-survivor recording](https://www.lemmingsforums.net/index.php?topic=1601.15) with four timed bombers found in the native engine. Lowering the basher into the starting platform keeps its tunnel continuous through both barriers. The final replay saves 46 of 50 without using the nuke. The adapted source hash is preserved in the archive provenance file.

## Maximum-rescue status

The saved replay count improved from 60 to 103 full rescues during the maximum-rescue pass. All 120 levels still have winning evidence. Native replays match the [published DOS record table](https://www.lemmingsforums.net/index.php?topic=1383.0) for 120 levels. A matched nonzero-loss record is a reference result, not proof that our engine cannot save more. The bundled catalogue certifies full-population rescues only. It also supplies the other 17 replay counts as best-known targets for optional stars and leaderboards, without claiming proved minimum sacrifices.

The remaining levels are:

| Level | Title | Native saved | Published DOS record | Remaining work |
| --- | --- | ---: | ---: | --- |
| Fun 3 | Tailor-made for blockers | 47/50 | 47/50 | Record matched; upper bound unproven |
| Fun 6 | A task for blockers and bombers | 48/50 | 48/50 | Record matched; upper bound unproven |
| Fun 18 | Let's block and blow | 65/70 | 65/70 | Record matched; upper bound unproven |
| Tricky 15 | Ozone friendly Lemmings | 7/10 | 7/10 | Record matched; upper bound unproven |
| Tricky 16 | Luvly Jubly | 46/50 | 46/50 | Record matched; upper bound unproven |
| Tricky 17 | Diet Lemmingaid | 48/50 | 48/50 | Record matched; upper bound unproven |
| Tricky 18 | It's Lemmingentry Watson | 9/10 | 9/10 | Record matched; upper bound unproven |
| Tricky 23 | From The Boundary Line | 79/80 | 79/80 | Record matched; upper bound unproven |
| Taxing 7 | Every Lemming for himself!!! | 79/80 | 79/80 | Record matched; upper bound unproven |
| Taxing 19 | Bomboozal | 65/70 | 65/70 | Record matched; upper bound unproven |
| Taxing 27 | Call in the bomb squad | 77/80 | 77/80 | Record matched; upper bound unproven |
| Taxing 28 | POOR WEE CREATURES! | 70/80 | 70/80 | Record matched; upper bound unproven |
| Mayhem 5 | Down, along, up. In that order | 76/80 | 76/80 | Record matched; upper bound unproven |
| Mayhem 10 | Pillars of Hercules | 73/75 | 73/75 | Record matched; upper bound unproven |
| Mayhem 19 | Time to get up! | 48/50 | 48/50 | Record matched; upper bound unproven |
| Mayhem 26 | The Steel Mines of Kessel | 76/80 | 76/80 | Record matched; upper bound unproven |
| Mayhem 29 | Save Me | 78/80 | 78/80 | Record matched; upper bound unproven |

## Per-level results

“Saved” is the native witness result. The reference column reports the published DOS record; it is not a native upper bound.

| Level | Title | Population | Required | Saved | DOS record | Minimum sacrifices | Evidence |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| Fun 1 | Just dig! | 10 | 1 | 10 | 10 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-01.json) |
| Fun 2 | Only floaters can survive this | 10 | 1 | 10 | 10 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-02.json) |
| Fun 3 | Tailor-made for blockers | 50 | 5 | 47 | 47 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-03.json) |
| Fun 4 | Now use miners and climbers | 10 | 10 | 10 | 10 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-04.json) |
| Fun 5 | You need bashers this time | 50 | 5 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-05.json) |
| Fun 6 | A task for blockers and bombers | 50 | 10 | 48 | 48 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-06.json) |
| Fun 7 | Builders will help you here | 50 | 25 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-07.json) |
| Fun 8 | Not as complicated as it looks | 80 | 76 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-08.json) |
| Fun 9 | As long as you try your best | 80 | 72 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-09.json) |
| Fun 10 | Smile if you love lemmings | 20 | 10 | 20 | 20 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-10.json) |
| Fun 11 | Keep your hair on Mr. Lemming | 60 | 50 | 60 | 60 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-11.json) |
| Fun 12 | Patience | 80 | 40 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-12.json) |
| Fun 13 | We all fall down | 20 | 20 | 20 | 20 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-13.json) |
| Fun 14 | Origins and Lemmings | 80 | 60 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-14.json) |
| Fun 15 | Don't let your eyes deceive you | 80 | 40 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-15.json) |
| Fun 16 | Don't do anything too hasty | 80 | 50 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-16.json) |
| Fun 17 | Easy when you know how | 50 | 20 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-17.json) |
| Fun 18 | Let's block and blow | 70 | 50 | 65 | 65 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-18.json) |
| Fun 19 | Take good care of my Lemmings | 80 | 56 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-19.json) |
| Fun 20 | We are now at LEMCON ONE | 50 | 30 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-20.json) |
| Fun 21 | You Live and Lem | 80 | 48 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-21.json) |
| Fun 22 | A Beast of a level | 80 | 64 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-22.json) |
| Fun 23 | I've lost that Lemming feeling | 80 | 20 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-23.json) |
| Fun 24 | Konbanwa Lemming san | 30 | 20 | 30 | 30 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-24.json) |
| Fun 25 | Lemmings Lemmings everywhere | 80 | 40 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-25.json) |
| Fun 26 | Nightmare on Lem street | 2 | 2 | 2 | 2 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-26.json) |
| Fun 27 | Let's be careful out there | 50 | 25 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-27.json) |
| Fun 28 | If only they could fly | 80 | 48 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-28.json) |
| Fun 29 | worra lorra lemmings | 80 | 48 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-29.json) |
| Fun 30 | Lock up your Lemmings | 60 | 40 | 60 | 60 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/fun-30.json) |
| Tricky 1 | This should be a doddle! | 80 | 40 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-01.json) |
| Tricky 2 | We all fall down | 40 | 40 | 40 | 40 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-02.json) |
| Tricky 3 | A ladder would be handy | 80 | 40 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-03.json) |
| Tricky 4 | Here's one I prepared earlier | 80 | 16 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-04.json) |
| Tricky 5 | Careless clicking costs lives | 80 | 16 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-05.json) |
| Tricky 6 | Lemmingology | 5 | 4 | 5 | 5 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-06.json) |
| Tricky 7 | Been there, seen it, done it | 75 | 55 | 75 | 75 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-07.json) |
| Tricky 8 | Lemming sanctuary in sight | 80 | 48 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-08.json) |
| Tricky 9 | They just keep on coming | 75 | 70 | 75 | 75 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-09.json) |
| Tricky 10 | There's a lot of them about | 80 | 74 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-10.json) |
| Tricky 11 | Lemmings in the attic | 50 | 42 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-11.json) |
| Tricky 12 | Bitter Lemming | 50 | 40 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-12.json) |
| Tricky 13 | Lemming Drops | 80 | 56 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-13.json) |
| Tricky 14 | MENACING !! | 80 | 70 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-14.json) |
| Tricky 15 | Ozone friendly Lemmings | 10 | 6 | 7 | 7 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-15.json) |
| Tricky 16 | Luvly Jubly | 50 | 40 | 46 | 46 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-16.json) |
| Tricky 17 | Diet Lemmingaid | 50 | 48 | 48 | 48 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-17.json) |
| Tricky 18 | It's Lemmingentry Watson | 10 | 9 | 9 | 9 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-18.json) |
| Tricky 19 | Postcard from Lemmingland | 50 | 50 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-19.json) |
| Tricky 20 | One way digging to freedom | 80 | 76 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-20.json) |
| Tricky 21 | All the 6`s ........ | 66 | 44 | 66 | 66 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-21.json) |
| Tricky 22 | Turn around young lemmings! | 80 | 72 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-22.json) |
| Tricky 23 | From The Boundary Line | 80 | 48 | 79 | 79 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-23.json) |
| Tricky 24 | Tightrope City | 80 | 75 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-24.json) |
| Tricky 25 | Cascade | 80 | 10 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-25.json) |
| Tricky 26 | I have a cunning plan | 80 | 80 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-26.json) |
| Tricky 27 | The Island of the Wicker people | 80 | 72 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-27.json) |
| Tricky 28 | Lost something? | 80 | 72 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-28.json) |
| Tricky 29 | Rainbow Island | 80 | 79 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-29.json) |
| Tricky 30 | The Crankshaft | 80 | 72 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/tricky-30.json) |
| Taxing 1 | If at first you don`t succeed.. | 80 | 79 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-01.json) |
| Taxing 2 | Watch out, there`s traps about | 80 | 64 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-02.json) |
| Taxing 3 | Heaven can wait (we hope!!!!) | 80 | 80 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-03.json) |
| Taxing 4 | Lend a helping hand.... | 40 | 30 | 40 | 40 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-04.json) |
| Taxing 5 | The Prison! | 60 | 45 | 60 | 60 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-05.json) |
| Taxing 6 | Compression Method 1 | 50 | 30 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-06.json) |
| Taxing 7 | Every Lemming for himself!!! | 80 | 78 | 79 | 79 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-07.json) |
| Taxing 8 | The Art Gallery | 80 | 80 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-08.json) |
| Taxing 9 | Perseverance | 20 | 20 | 20 | 20 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-09.json) |
| Taxing 10 | Izzie Wizzie lemmings get busy | 5 | 5 | 5 | 5 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-10.json) |
| Taxing 11 | The ascending pillar scenario | 50 | 50 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-11.json) |
| Taxing 12 | Livin` On The Edge | 10 | 8 | 10 | 10 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-12.json) |
| Taxing 13 | Upsidedown World | 80 | 79 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-13.json) |
| Taxing 14 | Hunt the Nessy.... | 80 | 76 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-14.json) |
| Taxing 15 | What an AWESOME level | 80 | 64 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-15.json) |
| Taxing 16 | Mary Poppins` land | 80 | 77 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-16.json) |
| Taxing 17 | X marks the spot | 80 | 72 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-17.json) |
| Taxing 18 | Tribute to M.C.Escher | 75 | 65 | 75 | 75 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-18.json) |
| Taxing 19 | Bomboozal | 70 | 64 | 65 | 65 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-19.json) |
| Taxing 20 | Walk the web rope | 80 | 70 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-20.json) |
| Taxing 21 | Feel the heat! | 20 | 20 | 20 | 20 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-21.json) |
| Taxing 22 | Come on over to my place | 50 | 40 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-22.json) |
| Taxing 23 | King of the castle | 80 | 76 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-23.json) |
| Taxing 24 | Take a running jump..... | 80 | 79 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-24.json) |
| Taxing 25 | Follow the leader... | 80 | 72 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-25.json) |
| Taxing 26 | Triple Trouble | 80 | 79 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-26.json) |
| Taxing 27 | Call in the bomb squad | 80 | 48 | 77 | 77 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-27.json) |
| Taxing 28 | POOR WEE CREATURES! | 80 | 56 | 70 | 70 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-28.json) |
| Taxing 29 | How do I dig up the way? | 80 | 76 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-29.json) |
| Taxing 30 | We all fall down | 60 | 60 | 60 | 60 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/taxing-30.json) |
| Mayhem 1 | Steel Works | 80 | 72 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-01.json) |
| Mayhem 2 | The Boiler Room | 80 | 72 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-02.json) |
| Mayhem 3 | It`s hero time! | 25 | 25 | 25 | 25 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-03.json) |
| Mayhem 4 | The Crossroads | 50 | 40 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-04.json) |
| Mayhem 5 | Down, along, up. In that order | 80 | 60 | 76 | 76 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-05.json) |
| Mayhem 6 | One way or another | 75 | 75 | 75 | 75 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-06.json) |
| Mayhem 7 | Poles Apart | 50 | 45 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-07.json) |
| Mayhem 8 | Last one out is a rotten egg! | 80 | 72 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-08.json) |
| Mayhem 9 | Curse of the Pharaohs | 80 | 79 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-09.json) |
| Mayhem 10 | Pillars of Hercules | 75 | 50 | 73 | 73 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-10.json) |
| Mayhem 11 | We all fall down | 80 | 80 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-11.json) |
| Mayhem 12 | The Far Side | 75 | 75 | 75 | 75 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-12.json) |
| Mayhem 13 | The Great Lemming Caper | 2 | 2 | 2 | 2 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-13.json) |
| Mayhem 14 | Pea Soup | 80 | 75 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-14.json) |
| Mayhem 15 | The Fast Food Kitchen... | 80 | 60 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-15.json) |
| Mayhem 16 | Just a Minute... | 50 | 50 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-16.json) |
| Mayhem 17 | Stepping Stones | 80 | 70 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-17.json) |
| Mayhem 18 | And then there were four.... | 80 | 72 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-18.json) |
| Mayhem 19 | Time to get up! | 50 | 46 | 48 | 48 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-19.json) |
| Mayhem 20 | No added colours or Lemmings | 50 | 50 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-20.json) |
| Mayhem 21 | With a twist of lemming please | 50 | 50 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-21.json) |
| Mayhem 22 | A BeastII of a level | 80 | 68 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-22.json) |
| Mayhem 23 | Going up....... | 80 | 64 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-23.json) |
| Mayhem 24 | All or Nothing | 50 | 50 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-24.json) |
| Mayhem 25 | Have a nice day! | 80 | 72 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-25.json) |
| Mayhem 26 | The Steel Mines of Kessel | 80 | 60 | 76 | 76 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-26.json) |
| Mayhem 27 | Just a Minute (Part Two) | 50 | 50 | 50 | 50 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-27.json) |
| Mayhem 28 | Mind the step..... | 1 | 1 | 1 | 1 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-28.json) |
| Mayhem 29 | Save Me | 80 | 64 | 78 | 78 | Unproven | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-29.json) |
| Mayhem 30 | Rendezvous at the Mountain | 80 | 60 | 80 | 80 | 0 (proved) | [Replay](../../Tests/ClassicDOSCompletionTests/Fixtures/mayhem-30.json) |
