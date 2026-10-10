# Classic Complete + Fan Bridges

The saved playlist contains **387 levels: 352 official Classic levels and 35 fan bridges**.

Every official level occurs once, in the application's campaign order. The playlist is not limited to 100 entries.

To play the complete saved sequence, set Settings → Gameplay → Level Select to All. The current Player Unlocked setting blocks playlists that contain locked campaign levels. This audit does not change that preference or campaign progress.

## Evidence and limits

Audited 6374 levels: 352 official and 6022 fan levels. 6374 passed native loading, rendering and simulation construction.

Confidence: 24 high, 682 medium, 5668 low. Winning replays were checked with a budget of ten timing perturbations each.

25 selected fan bridges have metadata-only estimates. These are provisional placements, not demonstrated measures of human puzzle difficulty or proof that the levels are solvable.

The inserted levels reduce the largest estimated score step in 19 official transitions. 10 selected fan levels have validated native winning replays.

92 transitions still exceed a 100-point score increase. The installed corpus and available replay evidence do not support claiming every gap is closed.

Fan copies with the same initial simulation hash as an official level are excluded. Repeated fan copies are excluded from selection. Official repeats remain because this playlist retains the complete campaigns.

Scope: all Classic campaigns and Classic-format fan archives discovered by the existing app loaders. Standalone NeoLemmix levels and Lemmings 2/3 are outside this Classic playlist. The earlier NeoLemmix audit remains separate because those levels lack playable catalogue routes.

Source: `.build/local/Ultimate Lemmings.app/Contents/Resources`, downloaded fan packs, bundled solutions and recorded Classic routes. The source snapshot manifest is `.build/classic-progression-audit/source-manifest.sha256`.

Pack/decode failures: 0. Per-level load or replay issues: 9. See `failures.json` and `all-levels.csv`.

## Official coverage

| Campaign | Levels |
| --- | ---: |
| Lemmings | 120 |
| Xmas Lemmings 1991 | 4 |
| Oh No! More Lemmings | 100 |
| Xmas Lemmings 1992 | 4 |
| Holiday Lemmings 1993 | 32 |
| Oh Yes! More Lemmings! | 60 |
| Holiday Lemmings 1994 | 32 |

## Files

- `playlist.json`: native saved playlist, including catalogue revisions and source fingerprints.
- `playlist.csv`: full order, grades' underlying scores and confidence.
- `all-levels.csv` and `audit.json`: every audited level and its evidence.
- `selections.json`: graph-selection reasons and costs.
- `gaps.json`: original jumps, inserted bridges and remaining jumps.

## Inserted fan levels

| Position | Fan level | Score | Confidence |
| ---: | --- | ---: | --- |
| 9 | Nepster01 / Dying Dream | 228.6 | medium |
| 12 | Nepster01 / Bashing & Building | 375.1 | medium |
| 16 | Nepster01 / Dirt Runner | 297.8 | medium |
| 17 | Nepster01 / Broken Symmetry | 371.0 | medium |
| 18 | Nepster01 / Lemming Playground | 406.4 | medium |
| 24 | Giga pack 01 / AIIIIIYYYEEEEEEEE!!!!!!! | 102.0 | low |
| 32 | PSP Special 27 36 / The stairs are not floored | 106.9 | low |
| 33 | Conway12 / Let's play Lemmings!!! | 121.5 | low |
| 34 | Gronklems 1 / gronklems -1.dat 2 | 131.0 | low |
| 42 | Nepster01 / Dunes | 367.7 | medium |
| 47 | Nepster01 / Just a random heap of junk! | 454.5 | medium |
| 55 | Nepster01 / Time Gate | 429.3 | medium |
| 56 | Nepster01 / Devil's Right Hand | 533.4 | medium |
| 93 | Yawg03 / Everything Counts | 95.8 | low |
| 94 | Epic Fernito 1 / Wish it was 13... | 118.7 | low |
| 120 | QBeez05 / Take a break! | 108.2 | low |
| 121 | Andi / LEMMINGS FOR EVER ! ! ! | 121.5 | low |
| 249 | Mikepak06 / Double clambering ! | 106.4 | low |
| 250 | DOS Xmas 1992 / A Lemming Holiday | 122.9 | low |
| 283 | Giga pack 02 / Insert name here | 106.6 | low |
| 284 | geooPk1 / Palace o/t once-hacked Lemmings | 120.1 | low |
| 285 | Nepster01 / Travelling Lemmings | 575.1 | medium |
| 289 | Crystal Remakes / Triple Trouble | 114.2 | low |
| 298 | ssam1221s Lemmings Wild / You need bashers this time | 79.1 | low |
| 299 | Mikepak06 / Lemmings on the boat 2 | 114.1 | low |
| 300 | ssam1221s Lemmings Wild / It's Lemmy Day | 122.9 | low |
| 306 | Epic giga02 / Winter Solstice | 117.3 | low |
| 315 | oldbutgo / Agh! More 1 pixel gaps! | 82.9 | low |
| 316 | JannPck3 / Z'Ha'Dum | 117.9 | low |
| 327 | Yawg06 / Just Dig! Again! | 102.0 | low |
| 328 | Giga pack 01 / The pole onslaught of a lemming | 118.7 | low |
| 360 | Fernito pack 1 / Dilemma | 115.9 | low |
| 375 | Pacpack1 / Just a bomb away !! | 67.9 | low |
| 376 | Giga pack 02 / The minroah the merryer | 102.0 | low |
| 377 | Gronklems 6 / 10) Bring it Together!.ini | 118.7 | low |

## Largest remaining jumps

| From | To | Largest step | Fan bridges |
| --- | --- | ---: | ---: |
| Oh Yes! More Lemmings! / Still everything to play for | Oh Yes! More Lemmings! / May the craftiest player win | 455.0 | 3 |
| Lemmings / Pea Soup | Lemmings / The Fast Food Kitchen... | 441.2 | 2 |
| Oh Yes! More Lemmings! / There can be only one | Oh Yes! More Lemmings! / We`re in this one together | 365.3 | 0 |
| Oh No! More Lemmings / Get a little extra help | Oh No! More Lemmings / Not just a pretty Lemming | 348.8 | 0 |
| Lemmings / Turn around young lemmings! | Lemmings / From The Boundary Line | 337.8 | 0 |
| Holiday Lemmings 1993 / The Undiscovered Country | Holiday Lemmings 1993 / The Needs of the Many... | 320.1 | 0 |
| Oh No! More Lemmings / Downwardly Mobile Lemmings | Oh No! More Lemmings / Snuggle up to a Lemming | 319.6 | 0 |
| Oh No! More Lemmings / Lemmings For Presidents! | Oh No! More Lemmings / Lemming Productions Present... | 310.0 | 0 |
| Lemmings / If at first you don`t succeed.. | Lemmings / Watch out, there`s traps about | 299.1 | 0 |
| Oh Yes! More Lemmings! / I am A.T. | Oh Yes! More Lemmings! / Fall and no life (Part Two) | 281.1 | 0 |
| Holiday Lemmings 1994 / Quest for Kieran | Holiday Lemmings 1994 / Four Play | 261.6 | 0 |
| Lemmings / We all fall down | Lemmings / The Far Side | 254.1 | 0 |
| Xmas Lemmings 1992 / Happy Holidays Mr Lemming! | Xmas Lemmings 1992 / A Lemming Holiday | 246.5 | 0 |
| Oh No! More Lemmings / SNOW JOKE | Oh No! More Lemmings / ONWARD AND UPWARD | 241.6 | 0 |
| Oh No! More Lemmings / Intsy-Wintsy...Lemming? | Oh No! More Lemmings / Who`s That Lemming | 240.6 | 0 |
| Lemmings / Curse of the Pharaohs | Lemmings / Pillars of Hercules | 239.7 | 0 |
| Holiday Lemmings 1994 / 2 Minutes before midnight | Holiday Lemmings 1994 / Happy New Year II! | 239.6 | 0 |
| Lemmings / Rainbow Island | Lemmings / The Crankshaft | 236.2 | 0 |
| Lemmings / Lemmings Lemmings everywhere | Lemmings / Nightmare on Lem street | 235.0 | 3 |
| Lemmings / Bomboozal | Lemmings / Walk the web rope | 231.3 | 2 |
