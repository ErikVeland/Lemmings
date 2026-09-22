# Rescue maximum verification

This audit covered 562 bundled level identities. It produced 202 proven maxima and 194 completed solutions without optimality proofs. It collected no winning witness for 166 levels. Classic Lemmings has a winning replay for every level. Coverage of the other campaigns remains incomplete.

See the [level-by-level results](levels.md) for every campaign level and the [full evidence data](audit.json) for exact conditions and notes.

The audit tried 36,687 candidate runs. Failed searches do not establish an optimum.

Maximum saveable means the population minus unavoidable sacrifices. A successful solution proves that its saved count is achievable. It does not prove that its deaths are necessary. The bundled certificates currently require a completed, repeatable rescue of the entire finite population.

| Campaign | Levels | Maximum proven | Winning witness | No witness collected |
| --- | ---: | ---: | ---: | ---: |
| Lemmings | 120 | 103 | 17 | 0 |
| Xmas Lemmings 1991 | 4 | 3 | 1 | 0 |
| Oh No! More Lemmings | 100 | 43 | 47 | 10 |
| Xmas Lemmings 1992 | 4 | 4 | 0 | 0 |
| Lemmings 2: The Tribes | 120 | 2 | 70 | 48 |
| Holiday Lemmings 1993 | 32 | 22 | 6 | 4 |
| Oh Yes! More Lemmings | 60 | 6 | 2 | 52 |
| All New World of Lemmings | 90 | 0 | 41 | 49 |
| Holiday Lemmings 1994 | 32 | 19 | 10 | 3 |

Tribes uses 60 Lemmings for the campaign audit. Preserved fixtures also cover 12 carry-over configurations. Each certificate applies only to its exact population.

Chronicles keeps unreleased Lemmings in reserve. They are survivors, not sacrifices. Fixed-input L3 completion fixtures are checked twice with their level hashes, exact starting population, accepted inputs, terminal state and retained reserves. Uncovered levels receive a no-input check. See [the completion fixtures](../../Tests/Lemmings3CompletionTests/Fixtures) and [verification tools](../../Tools/Lemmings3Completion).

All 120 Classic Lemmings levels now have saved winning replays on the native engine. The strict completion gate checks every assignment and repeats each result from a fresh simulation. These replays are imported into this rescue audit. See [the completion report](../ClassicCompletion/README.md) and [the replay fixtures](../../Tests/ClassicDOSCompletionTests/Fixtures). The older 510-tick smoke test remains a separate load-and-movement check.

The converted Oh Yes! pack resolves artwork by source rank. Sunsoft ground metadata and its special picture override the shared original graphics. Its audit uses the same lookup as the app.

Classic searches sample one skill assignment to the first Lemming at ticks 36 through 600, in steps of eight, and abandon new candidates at the first death. This searches for zero-loss rescues and can miss ordinary winning solutions. Cached winning replays are checked again. Tribes replays the existing runtime fixtures, including recorded fan inputs. All full-rescue witnesses are replayed twice before certification. Search failure never establishes an unavoidable sacrifice.

The [community maximum-saved records](https://www.lemmingsforums.net/index.php?topic=1383.0) provide reference targets for the original releases, including 100% for every DOS Tribes level. Those records include port and glitch differences. They are not imported as native-engine proofs.

## Proven campaign targets

| Campaign | Level | Saveable | Necessary sacrifices | Replay |
| --- | --- | ---: | ---: | --- |
| Lemmings | Fun 1: Just dig! | 10/10 | 0 | [Witness](witnesses/lemmings-0.json) |
| Lemmings | Fun 2: Only floaters can survive this | 10/10 | 0 | [Witness](witnesses/lemmings-1.json) |
| Lemmings | Fun 4: Now use miners and climbers | 10/10 | 0 | [Witness](witnesses/lemmings-3.json) |
| Lemmings | Fun 5: You need bashers this time | 50/50 | 0 | [Witness](witnesses/lemmings-4.json) |
| Lemmings | Fun 7: Builders will help you here | 50/50 | 0 | [Witness](witnesses/lemmings-6.json) |
| Lemmings | Fun 8: Not as complicated as it looks | 80/80 | 0 | [Witness](witnesses/lemmings-7.json) |
| Lemmings | Fun 9: As long as you try your best | 80/80 | 0 | [Witness](witnesses/lemmings-8.json) |
| Lemmings | Fun 10: Smile if you love lemmings | 20/20 | 0 | [Witness](witnesses/lemmings-9.json) |
| Lemmings | Fun 11: Keep your hair on Mr. Lemming | 60/60 | 0 | [Witness](witnesses/lemmings-10.json) |
| Lemmings | Fun 12: Patience | 80/80 | 0 | [Witness](witnesses/lemmings-11.json) |
| Lemmings | Fun 13: We all fall down | 20/20 | 0 | [Witness](witnesses/lemmings-12.json) |
| Lemmings | Fun 14: Origins and Lemmings | 80/80 | 0 | [Witness](witnesses/lemmings-13.json) |
| Lemmings | Fun 15: Don't let your eyes deceive you | 80/80 | 0 | [Witness](witnesses/lemmings-14.json) |
| Lemmings | Fun 16: Don't do anything too hasty | 80/80 | 0 | [Witness](witnesses/lemmings-15.json) |
| Lemmings | Fun 17: Easy when you know how | 50/50 | 0 | [Witness](witnesses/lemmings-16.json) |
| Lemmings | Fun 19: Take good care of my Lemmings | 80/80 | 0 | [Witness](witnesses/lemmings-18.json) |
| Lemmings | Fun 20: We are now at LEMCON ONE | 50/50 | 0 | [Witness](witnesses/lemmings-19.json) |
| Lemmings | Fun 21: You Live and Lem | 80/80 | 0 | [Witness](witnesses/lemmings-20.json) |
| Lemmings | Fun 22: A Beast of a level | 80/80 | 0 | [Witness](witnesses/lemmings-21.json) |
| Lemmings | Fun 23: I've lost that Lemming feeling | 80/80 | 0 | [Witness](witnesses/lemmings-22.json) |
| Lemmings | Fun 24: Konbanwa Lemming san | 30/30 | 0 | [Witness](witnesses/lemmings-23.json) |
| Lemmings | Fun 25: Lemmings Lemmings everywhere | 80/80 | 0 | [Witness](witnesses/lemmings-24.json) |
| Lemmings | Fun 26: Nightmare on Lem street | 2/2 | 0 | [Witness](witnesses/lemmings-25.json) |
| Lemmings | Fun 27: Let's be careful out there | 50/50 | 0 | [Witness](witnesses/lemmings-26.json) |
| Lemmings | Fun 28: If only they could fly | 80/80 | 0 | [Witness](witnesses/lemmings-27.json) |
| Lemmings | Fun 29: worra lorra lemmings | 80/80 | 0 | [Witness](witnesses/lemmings-28.json) |
| Lemmings | Fun 30: Lock up your Lemmings | 60/60 | 0 | [Witness](witnesses/lemmings-29.json) |
| Lemmings | Mayhem 1: Steel Works | 80/80 | 0 | [Witness](witnesses/lemmings-90.json) |
| Lemmings | Mayhem 2: The Boiler Room | 80/80 | 0 | [Witness](witnesses/lemmings-91.json) |
| Lemmings | Mayhem 3: It`s hero time! | 25/25 | 0 | [Witness](witnesses/lemmings-92.json) |
| Lemmings | Mayhem 4: The Crossroads | 50/50 | 0 | [Witness](witnesses/lemmings-93.json) |
| Lemmings | Mayhem 6: One way or another | 75/75 | 0 | [Witness](witnesses/lemmings-95.json) |
| Lemmings | Mayhem 7: Poles Apart | 50/50 | 0 | [Witness](witnesses/lemmings-96.json) |
| Lemmings | Mayhem 8: Last one out is a rotten egg! | 80/80 | 0 | [Witness](witnesses/lemmings-97.json) |
| Lemmings | Mayhem 9: Curse of the Pharaohs | 80/80 | 0 | [Witness](witnesses/lemmings-98.json) |
| Lemmings | Mayhem 11: We all fall down | 80/80 | 0 | [Witness](witnesses/lemmings-100.json) |
| Lemmings | Mayhem 12: The Far Side | 75/75 | 0 | [Witness](witnesses/lemmings-101.json) |
| Lemmings | Mayhem 13: The Great Lemming Caper | 2/2 | 0 | [Witness](witnesses/lemmings-102.json) |
| Lemmings | Mayhem 14: Pea Soup | 80/80 | 0 | [Witness](witnesses/lemmings-103.json) |
| Lemmings | Mayhem 15: The Fast Food Kitchen... | 80/80 | 0 | [Witness](witnesses/lemmings-104.json) |
| Lemmings | Mayhem 16: Just a Minute... | 50/50 | 0 | [Witness](witnesses/lemmings-105.json) |
| Lemmings | Mayhem 17: Stepping Stones | 80/80 | 0 | [Witness](witnesses/lemmings-106.json) |
| Lemmings | Mayhem 18: And then there were four.... | 80/80 | 0 | [Witness](witnesses/lemmings-107.json) |
| Lemmings | Mayhem 20: No added colours or Lemmings | 50/50 | 0 | [Witness](witnesses/lemmings-109.json) |
| Lemmings | Mayhem 21: With a twist of lemming please | 50/50 | 0 | [Witness](witnesses/lemmings-110.json) |
| Lemmings | Mayhem 22: A BeastII of a level | 80/80 | 0 | [Witness](witnesses/lemmings-111.json) |
| Lemmings | Mayhem 23: Going up....... | 80/80 | 0 | [Witness](witnesses/lemmings-112.json) |
| Lemmings | Mayhem 24: All or Nothing | 50/50 | 0 | [Witness](witnesses/lemmings-113.json) |
| Lemmings | Mayhem 25: Have a nice day! | 80/80 | 0 | [Witness](witnesses/lemmings-114.json) |
| Lemmings | Mayhem 27: Just a Minute (Part Two) | 50/50 | 0 | [Witness](witnesses/lemmings-116.json) |
| Lemmings | Mayhem 28: Mind the step..... | 1/1 | 0 | [Witness](witnesses/lemmings-117.json) |
| Lemmings | Mayhem 30: Rendezvous at the Mountain | 80/80 | 0 | [Witness](witnesses/lemmings-119.json) |
| Lemmings | Taxing 1: If at first you don`t succeed.. | 80/80 | 0 | [Witness](witnesses/lemmings-60.json) |
| Lemmings | Taxing 2: Watch out, there`s traps about | 80/80 | 0 | [Witness](witnesses/lemmings-61.json) |
| Lemmings | Taxing 3: Heaven can wait (we hope!!!!) | 80/80 | 0 | [Witness](witnesses/lemmings-62.json) |
| Lemmings | Taxing 4: Lend a helping hand.... | 40/40 | 0 | [Witness](witnesses/lemmings-63.json) |
| Lemmings | Taxing 5: The Prison! | 60/60 | 0 | [Witness](witnesses/lemmings-64.json) |
| Lemmings | Taxing 6: Compression Method 1 | 50/50 | 0 | [Witness](witnesses/lemmings-65.json) |
| Lemmings | Taxing 8: The Art Gallery | 80/80 | 0 | [Witness](witnesses/lemmings-67.json) |
| Lemmings | Taxing 9: Perseverance | 20/20 | 0 | [Witness](witnesses/lemmings-68.json) |
| Lemmings | Taxing 10: Izzie Wizzie lemmings get busy | 5/5 | 0 | [Witness](witnesses/lemmings-69.json) |
| Lemmings | Taxing 11: The ascending pillar scenario | 50/50 | 0 | [Witness](witnesses/lemmings-70.json) |
| Lemmings | Taxing 12: Livin` On The Edge | 10/10 | 0 | [Witness](witnesses/lemmings-71.json) |
| Lemmings | Taxing 13: Upsidedown World | 80/80 | 0 | [Witness](witnesses/lemmings-72.json) |
| Lemmings | Taxing 14: Hunt the Nessy.... | 80/80 | 0 | [Witness](witnesses/lemmings-73.json) |
| Lemmings | Taxing 15: What an AWESOME level | 80/80 | 0 | [Witness](witnesses/lemmings-74.json) |
| Lemmings | Taxing 16: Mary Poppins` land | 80/80 | 0 | [Witness](witnesses/lemmings-75.json) |
| Lemmings | Taxing 17: X marks the spot | 80/80 | 0 | [Witness](witnesses/lemmings-76.json) |
| Lemmings | Taxing 18: Tribute to M.C.Escher | 75/75 | 0 | [Witness](witnesses/lemmings-77.json) |
| Lemmings | Taxing 20: Walk the web rope | 80/80 | 0 | [Witness](witnesses/lemmings-79.json) |
| Lemmings | Taxing 21: Feel the heat! | 20/20 | 0 | [Witness](witnesses/lemmings-80.json) |
| Lemmings | Taxing 22: Come on over to my place | 50/50 | 0 | [Witness](witnesses/lemmings-81.json) |
| Lemmings | Taxing 23: King of the castle | 80/80 | 0 | [Witness](witnesses/lemmings-82.json) |
| Lemmings | Taxing 24: Take a running jump..... | 80/80 | 0 | [Witness](witnesses/lemmings-83.json) |
| Lemmings | Taxing 25: Follow the leader... | 80/80 | 0 | [Witness](witnesses/lemmings-84.json) |
| Lemmings | Taxing 26: Triple Trouble | 80/80 | 0 | [Witness](witnesses/lemmings-85.json) |
| Lemmings | Taxing 29: How do I dig up the way? | 80/80 | 0 | [Witness](witnesses/lemmings-88.json) |
| Lemmings | Taxing 30: We all fall down | 60/60 | 0 | [Witness](witnesses/lemmings-89.json) |
| Lemmings | Tricky 1: This should be a doddle! | 80/80 | 0 | [Witness](witnesses/lemmings-30.json) |
| Lemmings | Tricky 2: We all fall down | 40/40 | 0 | [Witness](witnesses/lemmings-31.json) |
| Lemmings | Tricky 3: A ladder would be handy | 80/80 | 0 | [Witness](witnesses/lemmings-32.json) |
| Lemmings | Tricky 4: Here's one I prepared earlier | 80/80 | 0 | [Witness](witnesses/lemmings-33.json) |
| Lemmings | Tricky 5: Careless clicking costs lives | 80/80 | 0 | [Witness](witnesses/lemmings-34.json) |
| Lemmings | Tricky 6: Lemmingology | 5/5 | 0 | [Witness](witnesses/lemmings-35.json) |
| Lemmings | Tricky 7: Been there, seen it, done it | 75/75 | 0 | [Witness](witnesses/lemmings-36.json) |
| Lemmings | Tricky 8: Lemming sanctuary in sight | 80/80 | 0 | [Witness](witnesses/lemmings-37.json) |
| Lemmings | Tricky 9: They just keep on coming | 75/75 | 0 | [Witness](witnesses/lemmings-38.json) |
| Lemmings | Tricky 10: There's a lot of them about | 80/80 | 0 | [Witness](witnesses/lemmings-39.json) |
| Lemmings | Tricky 11: Lemmings in the attic | 50/50 | 0 | [Witness](witnesses/lemmings-40.json) |
| Lemmings | Tricky 12: Bitter Lemming | 50/50 | 0 | [Witness](witnesses/lemmings-41.json) |
| Lemmings | Tricky 13: Lemming Drops | 80/80 | 0 | [Witness](witnesses/lemmings-42.json) |
| Lemmings | Tricky 14: MENACING !! | 80/80 | 0 | [Witness](witnesses/lemmings-43.json) |
| Lemmings | Tricky 19: Postcard from Lemmingland | 50/50 | 0 | [Witness](witnesses/lemmings-48.json) |
| Lemmings | Tricky 20: One way digging to freedom | 80/80 | 0 | [Witness](witnesses/lemmings-49.json) |
| Lemmings | Tricky 21: All the 6`s ........ | 66/66 | 0 | [Witness](witnesses/lemmings-50.json) |
| Lemmings | Tricky 22: Turn around young lemmings! | 80/80 | 0 | [Witness](witnesses/lemmings-51.json) |
| Lemmings | Tricky 24: Tightrope City | 80/80 | 0 | [Witness](witnesses/lemmings-53.json) |
| Lemmings | Tricky 25: Cascade | 80/80 | 0 | [Witness](witnesses/lemmings-54.json) |
| Lemmings | Tricky 26: I have a cunning plan | 80/80 | 0 | [Witness](witnesses/lemmings-55.json) |
| Lemmings | Tricky 27: The Island of the Wicker people | 80/80 | 0 | [Witness](witnesses/lemmings-56.json) |
| Lemmings | Tricky 28: Lost something? | 80/80 | 0 | [Witness](witnesses/lemmings-57.json) |
| Lemmings | Tricky 29: Rainbow Island | 80/80 | 0 | [Witness](witnesses/lemmings-58.json) |
| Lemmings | Tricky 30: The Crankshaft | 80/80 | 0 | [Witness](witnesses/lemmings-59.json) |
| Xmas Lemmings 1991 | Xmas 1: Merry Christmas Mr Lemming | 50/50 | 0 | [Witness](witnesses/xmasLemmings1991-0.json) |
| Xmas Lemmings 1991 | Xmas 2: Christmas Bonus | 50/50 | 0 | [Witness](witnesses/xmasLemmings1991-1.json) |
| Xmas Lemmings 1991 | Xmas 4: This Corrosion | 50/50 | 0 | [Witness](witnesses/xmasLemmings1991-3.json) |
| Oh No! More Lemmings | Crazy 2: Dolly Dimple | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-21.json) |
| Oh No! More Lemmings | Crazy 4: Lemming Express | 20/20 | 0 | [Witness](witnesses/ohNoMoreLemmings-23.json) |
| Oh No! More Lemmings | Crazy 5: 24 hour Lemathon | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-24.json) |
| Oh No! More Lemmings | Crazy 6: The Stack | 20/20 | 0 | [Witness](witnesses/ohNoMoreLemmings-25.json) |
| Oh No! More Lemmings | Crazy 7: And now, the end is near... | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-26.json) |
| Oh No! More Lemmings | Crazy 9: On the Antarctic Coast | 20/20 | 0 | [Witness](witnesses/ohNoMoreLemmings-28.json) |
| Oh No! More Lemmings | Crazy 12: Lemming Friendly | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-31.json) |
| Oh No! More Lemmings | Crazy 16: Across The Gap | 16/16 | 0 | [Witness](witnesses/ohNoMoreLemmings-35.json) |
| Oh No! More Lemmings | Havoc 3: It`s the price you have to pay | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-82.json) |
| Oh No! More Lemmings | Havoc 4: The race against cliches | 20/20 | 0 | [Witness](witnesses/ohNoMoreLemmings-83.json) |
| Oh No! More Lemmings | Havoc 6: Now get out of that! | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-85.json) |
| Oh No! More Lemmings | Havoc 8: Lemming about town | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-87.json) |
| Oh No! More Lemmings | Havoc 9: AAAAAARRRRRRGGGGGGHHHHHH!!!!!! | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-88.json) |
| Oh No! More Lemmings | Havoc 11: Welcome to the party, pal! | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-90.json) |
| Oh No! More Lemmings | Havoc 12: It`s all a matter of timing | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-91.json) |
| Oh No! More Lemmings | Havoc 14: Synchronised Lemming | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-93.json) |
| Oh No! More Lemmings | Havoc 15: Have an ice day | 10/10 | 0 | [Witness](witnesses/ohNoMoreLemmings-94.json) |
| Oh No! More Lemmings | Havoc 19: Looks a Bit Nippy Out There | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-98.json) |
| Oh No! More Lemmings | Tame 1: Down And Out Lemmings | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-0.json) |
| Oh No! More Lemmings | Tame 3: Undercover Lemming | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-2.json) |
| Oh No! More Lemmings | Tame 4: Downwardly Mobile Lemmings | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-3.json) |
| Oh No! More Lemmings | Tame 6: Intsy-Wintsy...Lemming? | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-5.json) |
| Oh No! More Lemmings | Tame 10: New Lemmings On The Block | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-9.json) |
| Oh No! More Lemmings | Tame 11: With Compliments | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-10.json) |
| Oh No! More Lemmings | Tame 12: Citizen Lemming | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-11.json) |
| Oh No! More Lemmings | Tame 13: Thunder-Lemmings are go! | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-12.json) |
| Oh No! More Lemmings | Tame 16: Gone With The Lemming | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-15.json) |
| Oh No! More Lemmings | Tame 17: Honey, I Saved The Lemmings | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-16.json) |
| Oh No! More Lemmings | Tame 18: Lemmings For Presidents! | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-17.json) |
| Oh No! More Lemmings | Tame 20: Custom built for Lemmings | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-19.json) |
| Oh No! More Lemmings | Wicked 2: Inroducing SUPERLEMMING | 1/1 | 0 | [Witness](witnesses/ohNoMoreLemmings-61.json) |
| Oh No! More Lemmings | Wicked 3: This Corrosion | 50/50 | 0 | [Witness](witnesses/ohNoMoreLemmings-62.json) |
| Oh No! More Lemmings | Wicked 5: Chill out! | 20/20 | 0 | [Witness](witnesses/ohNoMoreLemmings-64.json) |
| Oh No! More Lemmings | Wicked 14: The Lemming Learning Curve | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-73.json) |
| Oh No! More Lemmings | Wicked 18: LoTs moRe wHeRe TheY caMe fRom | 60/60 | 0 | [Witness](witnesses/ohNoMoreLemmings-77.json) |
| Oh No! More Lemmings | Wild 1: PoP YoR ToP!!! | 60/60 | 0 | [Witness](witnesses/ohNoMoreLemmings-40.json) |
| Oh No! More Lemmings | Wild 4: Meeting Adjourned | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-43.json) |
| Oh No! More Lemmings | Wild 6: Just A Quicky | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-45.json) |
| Oh No! More Lemmings | Wild 7: You Take the High Road | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-46.json) |
| Oh No! More Lemmings | Wild 8: It`s a tight fit! | 10/10 | 0 | [Witness](witnesses/ohNoMoreLemmings-47.json) |
| Oh No! More Lemmings | Wild 14: ICE SPY | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-53.json) |
| Oh No! More Lemmings | Wild 16: Take care, Sweetie | 1/1 | 0 | [Witness](witnesses/ohNoMoreLemmings-55.json) |
| Oh No! More Lemmings | Wild 17: The Chain with no name | 80/80 | 0 | [Witness](witnesses/ohNoMoreLemmings-56.json) |
| Xmas Lemmings 1992 | Xmas 1: Jingle Lemming | 50/50 | 0 | [Witness](witnesses/xmasLemmings1992-0.json) |
| Xmas Lemmings 1992 | Xmas 2: Happy Holidays Mr Lemming! | 80/80 | 0 | [Witness](witnesses/xmasLemmings1992-1.json) |
| Xmas Lemmings 1992 | Xmas 3: A Lemming Holiday | 80/80 | 0 | [Witness](witnesses/xmasLemmings1992-2.json) |
| Xmas Lemmings 1992 | Xmas 4: The North Poles | 2/2 | 0 | [Witness](witnesses/xmasLemmings1992-3.json) |
| Lemmings 2: The Tribes | Classic 1: Do You Remember? | 60/60 | 0 | [Witness](witnesses/lemmings2-0-60.json) |
| Lemmings 2: The Tribes | Highland 1: CREAM OF LEMMING SOUP | 60/60 | 0 | [Witness](witnesses/lemmings2-50-60.json) |
| Holiday Lemmings 1993 | Blizzard 2: Lemmings Up High | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-17.json) |
| Holiday Lemmings 1993 | Blizzard 3: Check Your Hints! | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-18.json) |
| Holiday Lemmings 1993 | Blizzard 4: Santus Lemmingus | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-19.json) |
| Holiday Lemmings 1993 | Blizzard 6: A Single Lemming... | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-21.json) |
| Holiday Lemmings 1993 | Blizzard 7: Break on through... | 60/60 | 0 | [Witness](witnesses/holidayLemmings1993-22.json) |
| Holiday Lemmings 1993 | Blizzard 8: Presents of Mind II | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-23.json) |
| Holiday Lemmings 1993 | Blizzard 9: Lemmings...The Motion Picture | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-24.json) |
| Holiday Lemmings 1993 | Blizzard 10: The Wrath of Lem | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-25.json) |
| Holiday Lemmings 1993 | Blizzard 11: The Search for Lem | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-26.json) |
| Holiday Lemmings 1993 | Blizzard 14: The Undiscovered Country | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-29.json) |
| Holiday Lemmings 1993 | Flurry 2: Floating Lemming Flurry | 20/20 | 0 | [Witness](witnesses/holidayLemmings1993-1.json) |
| Holiday Lemmings 1993 | Flurry 3: Holiday Mining | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-2.json) |
| Holiday Lemmings 1993 | Flurry 4: Lemming Tracks in the Snow! | 50/50 | 0 | [Witness](witnesses/holidayLemmings1993-3.json) |
| Holiday Lemmings 1993 | Flurry 5: Christmas South of the Equator | 75/75 | 0 | [Witness](witnesses/holidayLemmings1993-4.json) |
| Holiday Lemmings 1993 | Flurry 6: Lemming Snowfall | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-5.json) |
| Holiday Lemmings 1993 | Flurry 7: Lemming Snowjourn | 50/50 | 0 | [Witness](witnesses/holidayLemmings1993-6.json) |
| Holiday Lemmings 1993 | Flurry 10: 32 Lemmings Below Zero | 32/32 | 0 | [Witness](witnesses/holidayLemmings1993-9.json) |
| Holiday Lemmings 1993 | Flurry 11: At Home in a Cave | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-10.json) |
| Holiday Lemmings 1993 | Flurry 12: Presents of Mind | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-11.json) |
| Holiday Lemmings 1993 | Flurry 13: Yo-yo Lem-lem | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-12.json) |
| Holiday Lemmings 1993 | Flurry 14: Marshmallow Land | 80/80 | 0 | [Witness](witnesses/holidayLemmings1993-13.json) |
| Holiday Lemmings 1993 | Flurry 15: Head for the Hills! | 10/10 | 0 | [Witness](witnesses/holidayLemmings1993-14.json) |
| Oh Yes! More Lemmings | Lemmings Versus 3: Still everything to play for | 100/100 | 0 | [Witness](witnesses/ohYesMoreLemmings-2.json) |
| Oh Yes! More Lemmings | Lemmings Versus 5: and the winner is..... | 80/80 | 0 | [Witness](witnesses/ohYesMoreLemmings-4.json) |
| Oh Yes! More Lemmings | Lemmings Versus 6: In the thick of the fray | 75/75 | 0 | [Witness](witnesses/ohYesMoreLemmings-5.json) |
| Oh Yes! More Lemmings | Lemmings Versus 14: The Pipe Room... | 100/100 | 0 | [Witness](witnesses/ohYesMoreLemmings-13.json) |
| Oh Yes! More Lemmings | Oh No! More Lemmings Versus 6: Test Of Skill | 40/40 | 0 | [Witness](witnesses/ohYesMoreLemmings-25.json) |
| Oh Yes! More Lemmings | Oh No! More Lemmings Versus 7: Give And Take | 40/40 | 0 | [Witness](witnesses/ohYesMoreLemmings-26.json) |
| Holiday Lemmings 1994 | Frost 2: Ski Jump! | 50/50 | 0 | [Witness](witnesses/holidayLemmings1994-1.json) |
| Holiday Lemmings 1994 | Frost 3: CindyLand | 80/80 | 0 | [Witness](witnesses/holidayLemmings1994-2.json) |
| Holiday Lemmings 1994 | Frost 4: Separate Ways | 50/50 | 0 | [Witness](witnesses/holidayLemmings1994-3.json) |
| Holiday Lemmings 1994 | Frost 5: Lemming Reunification | 70/70 | 0 | [Witness](witnesses/holidayLemmings1994-4.json) |
| Holiday Lemmings 1994 | Frost 8: Division Bell | 80/80 | 0 | [Witness](witnesses/holidayLemmings1994-7.json) |
| Holiday Lemmings 1994 | Frost 9: Quest for Kieran | 40/40 | 0 | [Witness](witnesses/holidayLemmings1994-8.json) |
| Holiday Lemmings 1994 | Frost 10: Four Play | 4/4 | 0 | [Witness](witnesses/holidayLemmings1994-9.json) |
| Holiday Lemmings 1994 | Frost 11: Maybe not such a doddle | 80/80 | 0 | [Witness](witnesses/holidayLemmings1994-10.json) |
| Holiday Lemmings 1994 | Frost 12: It's Boxing Day! | 80/80 | 0 | [Witness](witnesses/holidayLemmings1994-11.json) |
| Holiday Lemmings 1994 | Frost 13: 2 Minutes before midnight | 80/80 | 0 | [Witness](witnesses/holidayLemmings1994-12.json) |
| Holiday Lemmings 1994 | Hail 1: Go Thataway! | 75/75 | 0 | [Witness](witnesses/holidayLemmings1994-16.json) |
| Holiday Lemmings 1994 | Hail 7: Steel Ice Span | 80/80 | 0 | [Witness](witnesses/holidayLemmings1994-22.json) |
| Holiday Lemmings 1994 | Hail 8: Sir Edmund Hilemming | 80/80 | 0 | [Witness](witnesses/holidayLemmings1994-23.json) |
| Holiday Lemmings 1994 | Hail 9: Up, up, and away! | 50/50 | 0 | [Witness](witnesses/holidayLemmings1994-24.json) |
| Holiday Lemmings 1994 | Hail 11: Emmings!  (No L) | 70/70 | 0 | [Witness](witnesses/holidayLemmings1994-26.json) |
| Holiday Lemmings 1994 | Hail 12: Merry Christmaze | 25/25 | 0 | [Witness](witnesses/holidayLemmings1994-27.json) |
| Holiday Lemmings 1994 | Hail 13: Polar Expedition | 50/50 | 0 | [Witness](witnesses/holidayLemmings1994-28.json) |
| Holiday Lemmings 1994 | Hail 15: Steel Block Party | 60/60 | 0 | [Witness](witnesses/holidayLemmings1994-30.json) |
| Holiday Lemmings 1994 | Hail 16: Peak of Performance | 10/10 | 0 | [Witness](witnesses/holidayLemmings1994-31.json) |

## Reproduce

Run `zsh Scripts/verify-trolley-maxima.sh` from the repository. The bundled game data must already exist in `.build/local/Ultimate Lemmings.app`. Set `TROLLEY_AUDIT_JOBS` to control the number of Classic audit processes (default: 8).

The script compiles the current engines, replays solutions, checks all 562 level identities, and packages valid certificates. `audit.json` contains every level and its evidence status. The `witnesses` folder preserves completed solutions. Rejected candidates do not become records.

App builds stamp the current engine sources. Certificates require an exact stamp and exact level conditions. Changed engine sources, level data, population, skills, time, or modifiers cannot inherit a certificate. Expired bundled evidence is removed from current targets, while historical attempt snapshots remain unchanged. Minimum pass requirements and optional retries remain unchanged.
