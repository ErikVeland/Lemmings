# Lemmings 2 solver spike

This report records phase 1 of the Lemmings 2 route solver. It tests whether a
crowd search that branches at decision points can find winning routes.

## Method

Each level ran with 60 lemmings, a beam width of 64, a location cell of 8 pixels,
a re-fire window of 150 ticks and a budget of 15 minutes on one core. The depth
limit is the number of decision points on a run without input, plus 40. A route counts only after the written file
replays twice to the same state hash, saved count and tick count.

## Results

| Level | Result | Saved | Ticks | Density per 100 ticks | Depth limit | Decision points | From fallback | Expanded | Time | Candidate SHA-256 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `classic-01` (known answer) | UNSOLVED | 0 of 60 | - | 2.6 | 157 | 72442 | 0% | 72441 | 19 s | - |
| `cavelem-01` | SOLVED | 40 of 60 | 3600 | 12.6 | 248 | 17616 | 0% | 17615 | 13 s | a08e2d50488f |
| `highland-03` | UNSOLVED | 0 of 60 | - | 14.4 | 560 | 44280 | 0% | 44279 | 51 s | - |
| `space-03` | UNSOLVED | 0 of 60 | - | 2.7 | 160 | 17746 | 0% | 17813 | 52 s | - |
| `medieval-03` | UNSOLVED | 0 of 60 | - | 8.0 | 257 | 35547 | 0% | 35546 | 41 s | - |

Density counts decision points per 100 ticks on a run without input. A high
density points to detector tuning, not to a level that cannot be solved. The
fallback share shows how many decision points came from the 150 tick fallback. A
high share means that the trigger model misses a mechanic on that level. An unsolved level has no ticks, because no accepted route reached the end.

## Verdict

**NO-GO, inconclusive**

Go requires an accepted `cavelem-01` route that saves at least 30 of 60, and
accepted routes that save at least 20 of 60 on at least two of `highland-03`,
`space-03` and `medieval-03`.

A go verdict starts phase 2, which needs its own plan. A no-go verdict makes
seeded search the primary method.

`classic-01` is the known answer. Its recorded route saves 60 of 60. It does not
change a go verdict. If the verdict is no-go and the solver also saves fewer than
30 on `classic-01`, the verdict is inconclusive: the search fails on a level with a
proven route, so the no-go may come from the search rather than from the levels.

A level without a found route is unsolved by search. It is not a broken level.

## Checks before the spike

- The search found the planted crowd route on the synthetic level: 3 of 3.
- The known answer on `classic-01` appears in the table as its own row.
- The runtime suite, the completion gate and its negative mode still pass.

Candidates stay in `.build/l2-solver/candidates/`. Phase 1 does not promote them
into the fixture directory.
