# Lemmings 2 completion evidence

The Lemmings 2 gate replays every recorded campaign route twice from a fresh
runtime. Both runs must agree on the state hash, the saved count and the ticks.
It uses the same replay code as the runtime suite, so the two cannot drift apart.

## Coverage

64 of the 120 campaign levels have a recorded winning route. 56 do not.

| Tribe | Recorded routes | Levels that chain |
| --- | ---: | ---: |
| Classic | 7 | 2 |
| Beach | 5 | 1 |
| Cavelems | 5 | 3 |
| Circus | 7 | 2 |
| Egyptian | 8 | 1 |
| Highland | 3 | 1 |
| Medieval | 4 | 1 |
| Outdoor | 7 | 1 |
| Polar | 6 | 1 |
| Shadow | 3 | 1 |
| Space | 4 | 1 |
| Sports | 5 | 1 |

A missing route does not prove a level is broken. It shows that nobody recorded
a win. Loading and rendering are separate checks. They do not prove a solution.

## Route quality

The recorded routes earn 5 gold, 9 silver and 50 bronze medals.

Every winning route earns at least bronze, so a medal alone does not show how
well a route plays. 43 routes save one lemming of sixty. They count as bronze.

Three routes save one lemming of one: Cavelems 2, Cavelems 3 and Circus 2. Each
starts with the single lemming that the level before it saved. Saving one of one
is a complete rescue, so the game rates it gold.

Medal quality does not gate the evidence. The gate reports it so that progress
stays visible.

## Population carry-over

A tribe's first level starts with 60 lemmings. Each later level starts with the
number saved on the level before it. A route proves only the population it was
recorded with.

A tribe chains through a level when that route starts with exactly the number the
previous route saved. The table counts how many levels chain from the start of
each tribe, without a break.

No tribe chains through all ten levels. Cavelems chains furthest, through three.
Egyptian has eight consecutive routes but chains through only one, because its
first route saves 40 and its second route starts with 60.

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

Strict mode fails while any level has no recorded route.

```sh
zsh Scripts/verify-lemmings2-completion.sh --negative
```

Negative mode damages one field of a known route at a time and requires the gate
to reject it.

After you add or change a fixture, run `python3 Tools/Lemmings2Completion/report.py`
and then the gate. Do not regenerate the manifest to hide a changed outcome.
