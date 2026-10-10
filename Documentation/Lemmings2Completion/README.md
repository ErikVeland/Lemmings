# Lemmings 2 completion evidence

The Lemmings 2 gate replays every recorded campaign route twice from a fresh
runtime. Both runs must agree on the state hash, the saved count and the ticks.
It uses the same replay code as the runtime suite, so the two cannot drift apart.

## Coverage

All 120 campaign levels have a recorded winning route.
The strict native gate passed on 10 October 2026: 120 routes, 70 carry-over
variants and all twelve continuous tribe chains. Every witness passed two fresh
replays with matching saved counts, ticks and state hashes.

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

All twelve tribes chain through all ten levels. These chains finish with one
lemming. The ark ending requires a golden talisman and at least 30 survivors
from each tribe, so it remains unproved.
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

Strict mode fails while any level has no recorded route or any tribe lacks a
continuous ten-level chain. Independent level wins cannot close this gate.

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
