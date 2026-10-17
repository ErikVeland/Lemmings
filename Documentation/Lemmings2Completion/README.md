# Lemmings 2 completion evidence

The Lemmings 2 gate replays every recorded campaign route twice from a fresh
runtime. Both runs must agree on the state hash, the saved count and the ticks.
It uses the same replay code as the runtime suite, so the two cannot drift apart.

## Coverage

All 120 campaign levels have a recorded winning route.
The strict native gate passed on 10 October 2026: 120 routes, 70 carry-over
variants and all twelve continuous tribe chains. Every witness passed two fresh
replays with matching saved counts, ticks and state hashes.

On 15 October 2026, the route replay at `main` revision `061e1b99` verified all
120 routes, 70 carry-over variants and twelve ten-level chains. This route
result does not prove ark completion. Each chain ended with one survivor and a
Bronze talisman, so the ark prerequisites remained open.

The fresh payload replay ran at `fc52cac4`, when the worktree matched
`origin/main`. The worktree has since advanced to `c38831f3`. The L2 runtime,
solver, completion verifier, event verifier and fixtures still match the
recorded payload run. The runtime suite was rebuilt at `d537e822` and passed
against the staged 218-file build 83 app payload. The current test source
still matches that build. It includes a regression check for the crowd
assignment query.

At current-main commit `c38831f3`, I reran the route, event and runtime test
binaries against the exact 218-file build 83 payload. All three commands
exited 0. The route verifier passed all 120 routes, 70 carry-over variants and
twelve chains. The event verifier passed its valid and invalid event checks.
The runtime suite passed. `main` has since advanced to `98623744`. No L2 runtime,
completion, event-verifier or runtime-test source changed between those commits;
the runtime source still has the recorded SHA-256. These results therefore
remain current for L2 source and build 83 payload. They do not close
source-engine parity or the Gold ark requirements. See the [payload replay
record](../ReleaseReadiness/2.0-build83/lemmings2-build83-payload-replay.json).

A direct current-main rerun against the locally installed L2 tree also passed
all three checks. The app identifies as 1.9.1 build 76. Its 218 L2 files match
the retained manifest. This does not recheck the 2.0.2 build 85 shipping
package. The ark and original-DOS behaviour gates remain open. See the
[build 76 recheck record](installed-build76-l2-recheck-2026-10-16.json).

The recorded payload replay passed the 120-route gate, 70 carry-over variants
and all twelve ten-level chains. The event suite passed all 120 routes and
rejected refused, off-viewport and out-of-order events.

The build uses Xcode 26.6 and Swift 6.3.3. A temporary source copy disables
optimisation only for `ClassicDOSSimulation.handleJumping`, to work around the
documented compiler failure. `Lemmings2Runtime.swift` matches current `main`
byte for byte. The current library hash is
`2904de481368af1ed13512e9f8271d9afd593447a59840e13ea32e4059f20607`. The
current route verifier hash is
`d247cbedb81804f2ab2d35743aba2bec7275b8b6c09850fcfe9d5a8aeac443b0`.

The strict ark gate still fails because each tribe ends with one survivor and a
Bronze talisman. A Gold talisman and 30 survivors per tribe remain open. The
payload replay audit records the source revision, build hashes and commands.

The route gate also passed against the 218-file L2 app payload staged from the
exact build 83 archive extraction. Every staged file matches the retained
1.9.7 build 82 manifest; its tree hash matches the installed build 76 resource
tree. The archive extraction also contained 14 original DOS interpreter and
support files, which the app packager excludes. The 2.0 build 83 source
equivalence record confirms the gameplay sources are unchanged. The direct
payload replay passed 120 routes, 70 carry-over variants, all twelve chains and
the event suite. It still fails the ark prerequisites. See the [payload replay
audit](../ReleaseReadiness/2.0-build83/lemmings2-build83-payload-replay.json)
and [resource equivalence audit](../ReleaseReadiness/2.0-build83/lemmings2-resource-equivalence.json).

The full build 83 extraction has 232 L2 files. The app payload uses 218. The
app packager excludes 14 DOS files. I recorded their sizes and hashes in the
[reference-file manifest](../ReleaseReadiness/2.0-build83/lemmings2-reference-excluded-files-2026-10-16.json).
The manifest confirms which files the app omits. It does not prove gameplay
parity with the original DOS engine.

A 15 October Cavelems route update now chains all ten levels from 60 lemmings.
It records 59 saved on Level 1, then 36, 17, 4, 2, 2, 1, 1, 1 and 1. The
strict route gate verifies the new routes twice. The ark gate remains open.
A bounded search from this worktree did not improve Beach Level 3 from 1 of 42.
It used the installed 1.9.1 build 76 resource tree and did not improve the route.
All 218 L2 resources match the build 82 manifest, which build 83 source-equivalence
evidence links to the release package. See the resource audit linked above.

A 16 October seeded Beach Level 1 search used a beam of 8,192, a 2-pixel
decision grid and a 24-tick refire interval for 300 seconds. It replayed the
42-of-60 route and found no higher-survivor witness. The accepted fixture did
not change. See the [Beach 1 search record](beach01-seeded-beam8192-search-2026-10-16.json).

On 16 October, a current solver search against the build 83 app payload found
a Cavelems Level 3 route that saves 34 of 36, compared with the accepted 17.
Seeded searches also found 13 of 34 on Level 4 and 10 of 13 on Level 5. Neither
a seeded nor unseeded Level 6 search found a route at population 10. Those
candidates are not in the accepted chain; the verified ten-level chain remains
unchanged. See the [ark reconnection search record](cavelem-ark-reconnection-search-2026-10-16.json).

A 16 October current-main follow-up searched Cavelems Level 6 at population 13
for 300 seconds with a beam of 8,192. It found no route. A seeded Level 5
search reproduced the existing 10-of-13 route. A wider Classic Level 2 search
also reproduced its accepted 13-of-60 route. All inputs matched the 218-file
build 83 app payload. No route or chain fixture changed. See the [current-main
search record](ark-reconnection-search-2026-10-16-current-main.json).

A later current-main search tried Cavelems Level 2 at population 59. The
unseeded 8,192-beam search found no win after 1,033,283 expansions. The seeded
16,384-beam search replayed the accepted 36-of-59 route twice after 1,393,376
expansions. It did not improve the route or chain. See the [Cavelems Level 2
search record](cavelem02-current-main-ark-route-searches-2026-10-16.json).

The solver previously offered only the first three triggered lemming IDs at a
decision. It now offers every triggered actor, with a six-actor regression
test. A new 16,384-beam Cavelems Level 2 search expanded 1,393,819 candidates
and replayed the same 36-of-59 route twice. The route and chain did not change.
See the [all-actor follow-up](cavelem02-all-actor-followup-search-2026-10-16.json).

A further unseeded search used a 32,768-state beam, one-pixel decision
sampling and a 600-second budget. It expanded 2,049,584 candidates and found
no winning route. The best partial candidate saved none. The accepted 36-of-59
route and chain remain unchanged. The Gold ark requirement stays open. Three
searches from partial prefixes also failed to improve the route. See the
[wider and seeded search record](cavelem02-unseeded-beam32768-cell1-search-2026-10-16.json). A current-origin/main rebuild with the L2 runtime optimisation also retained 36/59 and found no improvement.

A temporary current-main chain check replaces Cavelems Levels 3–5 with the
higher-survivor candidates. Each route passes two fresh replays, producing
36→34→13→10 survivors through Level 5. The alternative chain reaches Level 6
with ten survivors but stops there. Two current all-actor searches at that
population, seeded and unseeded, expanded 747,437 and 876,791 candidates
without a win. The accepted 12-tribe chain remains unchanged; the ark gate
stays open. See the [candidate-chain reconciliation]
(cavelem-candidate-chain-reconciliation-2026-10-16.json).

The current all-actor solver also searched Cavelems Level 6 at population 13,
both from the start and seeded with the accepted 2-of-2 route. The two
600-second searches expanded 1,291,693 and 1,463,726 candidates without a
win. These bounds do not prove the level impossible; the Gold ark remains
unproved. The same [candidate-chain record]
(cavelem-candidate-chain-reconciliation-2026-10-16.json) retains both runs.

Two further unseeded Cavelems Level 4 searches used the carried population of
34, a beam of 8,192 and a 300-second budget. The standard 4-pixel grid expanded
1,014,578 candidates; the 2-pixel grid with a 24-tick refire interval expanded
1,126,648. Neither found a win; the 13-of-34 witness remains the best retained
Level 4 route. The accepted chain did not change. See the [wider Level 4 search
record](cavelem04-beam8192-search-2026-10-16.json).

A seeded search at the same population used the 2-pixel grid and 24-tick
refire interval. It reproduced the retained 13-of-34 Bronze route byte for
byte after 782,183 expansions. It did not improve the route or change the
accepted chain. A follow-up with a 4-pixel grid reached 755,516 expansions
and reproduced the same route byte for byte. A search with the solver's
standard 8-pixel grid and 50-tick refire interval expanded 771,657 candidates
and also reproduced the seed. See the [seeded Level 4 search record](cavelem04-seeded-beam8192-search-2026-10-16.json).

A further 300-second Cavelems Level 6 search at population 10 used beam 8,192
and depth 80. It expanded 692,245 candidates and found no win. This raises the
search bound but does not prove the level unsolvable. The ark remains open,
and each accepted chain still ends with one survivor.

A 16 October current-main search then tested Cavelems Level 6 at the chained
population of 13. It used a 16,384 beam, a 2-pixel decision grid and a 24-tick
refire interval for 600 seconds. It expanded 1,250,232 candidates and found no
route. The accepted chain did not change. This bounded result does not prove
the level impossible. See the [wide Level 6 search record](cavelem06-pop13-beam16384-current-main-2026-10-16.json).

| Tribe | Recorded routes | Levels that chain |
| --- | ---: | ---: |
| Classic | 10 | 10 |
| Beach | 10 | 10 |
| Cavelems | 10 | 10 |
| Circus | 10 | 10 |
| Egyptian | 10 | 10 |
| Highland | 10 | 10 |
| Medieval | 10 | 10 |
| Outdoor | 10 | 10 |
| Polar | 10 | 10 |
| Shadow | 10 | 10 |
| Space | 10 | 10 |
| Sports | 10 | 10 |

A missing route does not prove a level is broken. It shows that nobody recorded
a win. Loading and rendering are separate checks. They do not prove a solution.

## Route quality

The recorded routes earn 52 gold, 15 silver and 53 bronze medals.

Every winning route earns at least bronze, so a medal alone does not show how
well a route plays. 44 routes save one lemming from a larger crowd. Most start
with sixty. They count as bronze or silver.

53 standalone routes start with fewer than 60 lemmings. These routes establish
individual wins. The manifest records their starting populations. A complete
rescue earns gold, even for one lemming of one.

Medal quality does not gate the evidence. The gate reports it so that progress
stays visible.

## Population carry-over

A tribe's first level starts with 60 lemmings. Each later level starts with the
number saved on the level before it. A route proves only the population it was
recorded with.

A tribe chains through a level when that route starts with exactly the number the
previous route saved. The table counts how many levels chain from the start of
each tribe, without a break.

All twelve tribes chain through all ten levels. Each chain finishes with one
lemming and a Bronze talisman. The ark ending requires a golden talisman and at
least 30 survivors from each tribe, so it remains unproved.
70 separate carry-over witnesses preserve the correct starting populations.
The gate verifies every route and carry-over variant twice before it uses that
route in a chain.

A continuous tribe run needs routes that chain. Independent routes for every
level do not provide one.

## Running the gate

The final check used the current native sources. The standard optimised build
hits a Swift compiler failure in `ClassicDOSSimulation.handleJumping`. The
validation helper disabled optimisation only for that function in a temporary
source copy. Lemmings 2 sources were unchanged. The input replay checks and the
synthetic runtime regression checks also passed. Release build and
original-engine equivalence remain separate checks.

```sh
zsh Scripts/verify-lemmings2-completion.sh
```

The gate first checks the committed [manifest](evidence.json). It then replays
every route and prints the chain result for each tribe.

```sh
zsh Scripts/verify-lemmings2-completion.sh --require-all
```

`--require-all` fails while any level has no recorded route or any tribe lacks
a continuous ten-level chain. Independent level wins cannot close this gate.

Use `--require-ark` to also require a golden talisman and at least 30 survivors
from every tribe. This checks the ending prerequisites. Ending playback, media
and original-engine parity retain separate checks.

Run `zsh Scripts/verify-lemmings2-completion.sh --require-ark` to check those
conditions with the bundled L2 data.

```sh
zsh Scripts/verify-lemmings2-completion.sh --negative
```

Negative mode damages one field of a known route at a time and requires the gate
to reject it.

After you add or change a fixture, run `python3 Tools/Lemmings2Completion/report.py`
and then the gate. Do not regenerate the manifest to hide a changed outcome.

## Carry-over discovery

`Tools/Lemmings2Completion/adapt.swift` replays existing inputs with the actual
number saved by the preceding level. It records only applied inputs and retains
a candidate only after the shared witness validator reproduces it twice. An
unsuccessful adaptation stops that tribe. `Chains` holds accepted variants,
separately from `Fixtures`, so improving continuity does not discard earlier
standalone evidence. Both sets are hash-checked in the manifest.

The chain tests cover matching populations, missing levels and ambiguous routes.
Real replay tests also reject altered hashes, outcomes, versions, invalid
populations and orphan variants.

## 17 October current-main check

`HEAD` and `origin/main` match at `833f396b`. The L2 runtime, route and event
verifiers, and completion fixtures have no changes after the 16 October source
check at `9a95012e`. Its 120 standalone routes, 70 carry-over variants and 12
chains remain source-current for the recorded build 83 payload. This does not
close original-engine parity or the Gold Ark requirement.

## 17 October population-60 Trolley search

The Trolley audit has no population-60 witness for Cavelems 6 or Highland 10.
Their standalone fixtures use populations two and four. I searched each level at
population 60 with an 8,192-state beam for 180 seconds. Each seeded search used
the accepted standalone route. None of the four initial searches found a win.

The best saved count was 0 of 60 in the four 180-second runs. A seeded
600-second Cavelems 6 search also saved 0 of 60 after 1,275,815 expansions.
A later 300-second Highland 10 search used a 16,384-state beam, one-pixel
action sampling and a 24-tick refire interval. It expanded 905,384 candidates
and also saved 0 of 60.

The first 32,768-state Cavelems 6 attempt stopped with exit 137. The cause was
not confirmed. A bounded-frontier solver then completed a 600-second search
with the same seed and beam width. It also used one-pixel action sampling and
a 24-tick refire interval. It expanded 1,719,537 candidates and held at most
65,536 pending candidates, but it still saved 0 of 60. These bounded searches
do not prove that either level is unsolvable. Both Trolley targets remain open.
The results do not prove parity with the original DOS game. See the [search
record](unknown-trolley-population60-search-2026-10-17.json) for conditions,
commands, hashes and candidate counts.
