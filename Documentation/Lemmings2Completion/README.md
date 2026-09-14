# Lemmings 2 completion evidence

The Lemmings 2 gate replays every recorded campaign route twice from a fresh
runtime. Both runs must agree on the state hash, the saved count and the ticks.
It uses the same replay code as the runtime suite, so the two cannot drift apart.

## Coverage

67 of the 120 campaign levels have a recorded winning route. 53 do not.

| Tribe | Recorded routes | Levels that chain |
| --- | ---: | ---: |
| Classic | 7 | 5 |
| Beach | 5 | 1 |
| Cavelems | 6 | 5 |
| Circus | 8 | 3 |
| Egyptian | 8 | 8 |
| Highland | 3 | 1 |
| Medieval | 4 | 1 |
| Outdoor | 7 | 3 |
| Polar | 6 | 4 |
| Shadow | 3 | 1 |
| Space | 5 | 1 |
| Sports | 5 | 2 |

A missing route does not prove a level is broken. It shows that nobody recorded
a win. Loading and rendering are separate checks. They do not prove a solution.

## Route quality

The recorded routes earn 7 gold, 10 silver and 50 bronze medals.

Every winning route earns at least bronze, so a medal alone does not show how
well a route plays. 41 routes save one lemming of sixty. They count as bronze.

Six standalone routes start with fewer than 60 lemmings, because a tribe run
found them with the population that the level before passes on:

- Cavelems 2, Cavelems 3, Circus 2 and Circus 3 save one lemming of one.
- Cavelems 5 saves two of two.
- Space 2 saves one of three.

A complete rescue earns gold. Newer carry-over witnesses can start these levels
with different populations. Space 2's route does not chain yet, because Space 1's
route saves 51.

Medal quality does not gate the evidence. The gate reports it so that progress
stays visible.

## Population carry-over

A tribe's first level starts with 60 lemmings. Each later level starts with the
number saved on the level before it. A route proves only the population it was
recorded with.

A tribe chains through a level when that route starts with exactly the number the
previous route saved. The table counts how many levels chain from the start of
each tribe, without a break.

No tribe chains through all ten levels. Egyptian now chains through eight.
Nineteen separate carry-over witnesses preserve the correct starting populations.
The 64 standalone routes include improved seeded-search results. The gate verifies every
variant twice before it uses that route in a chain.

A continuous tribe run needs routes that chain. Independent routes for every
level do not provide one.

## Running the gate

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
