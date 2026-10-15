# Lemmings 2 completion evidence

The Lemmings 2 gate replays every recorded campaign route twice from a fresh
runtime. Both runs must agree on the state hash, the saved count and the ticks.
It uses the same replay code as the runtime suite, so the two cannot drift apart.

## Coverage

All 120 campaign levels have a recorded winning route.
The strict native gate passed on 10 October 2026: 120 routes, 70 carry-over
variants and all twelve continuous tribe chains. Every witness passed two fresh
replays with matching saved counts, ticks and state hashes.

The latest strict gate replay passed on 15 October 2026 at `main` revision
`061e1b99` with Xcode 26.6. Strict ark mode replayed all 120 routes and 70
carry-over variants twice, then replayed all twelve ten-level chains. Every
chain ends with one survivor and a Bronze talisman, so the gate correctly fails
the ark prerequisites. The evidence does not prove a golden talisman or an ark
ending.

The worktree is now at `main` revision `fc2c59e6`. Review from the last
source replay found no L2 runtime, level data, solver or completion-gate
changes. A fresh build from this revision passed the 120-route gate, 70
carry-over variants and all twelve ten-level chains against the installed L2
resources. The event suite passed all 120 routes and rejected refused,
off-viewport and out-of-order events. The strict ark gate still fails because
each tribe ends with one survivor and a Bronze talisman. A Gold talisman and
30 survivors per tribe remain open. The fresh verifier hash is
`fd39550127699e48c68db51e8f3e1f40866de23f027d129705e7fcbef4906a91`. The fresh
`libNxlvKit.dylib` hash is
`5afb912bcfdfb8dd45c077adbbba8c769cfdd6c5e8d7d2d11944be942e59a067`.

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

A 15 October Cavelems route update now chains all ten levels from 60 lemmings.
It records 59 saved on Level 1, then 36, 17, 4, 2, 2, 1, 1, 1 and 1. The
strict route gate verifies the new routes twice. The ark gate remains open.
A bounded search from this worktree did not improve Beach Level 3 from 1 of 42.
It used the installed 1.9.1 build 76 resource tree and did not improve the route.
All 218 L2 resources match the build 82 manifest, which build 83 source-equivalence
evidence links to the release package. See the resource audit linked above.

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
