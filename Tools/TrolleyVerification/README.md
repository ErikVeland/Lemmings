# Rescue certificate verification

The verifier replays candidate routes against the native engines and preserves
only repeatable wins. A full-population rescue proves the population bound.
A route with losses proves an achievable rescue count, not an optimum.

Classic inputs retain their recorded timing, including live after-tick commands.
The verifier rejects refused skills and inputs that remain unused at completion.
L2 uses the shared `Lemmings2ReplayWitness` and `Lemmings2EventCursor` types for
both version 1 input/pointer recordings and version 2 ordered events. Input order,
viewport limits, accepted actions and consumed events remain mandatory.

`TROLLEY_RESOURCES` selects a resource bundle. `TROLLEY_OUTPUT` selects an isolated
evidence directory. The `--shard=index/count` option selects Classic or L2 level
indices for focused checks. A partial shard does not certify a complete campaign.

After compiling the verifier, run:

```sh
python3 Tools/TrolleyVerification/test_event_routes.py VERIFIER RESOURCES
python3 -m unittest discover -s Tools/TrolleyVerification -p 'test_*.py'
```

The event test checks a preserved version 2 win, a refused assignment and an
unused late event. Its fixture edits and outputs are isolated in a temporary
project. The policy tests reject missing or lower published rescue targets.

`Scripts/verify-trolley-maxima.sh` runs the full audit and merges its results.
The merge requires complete campaign coverage, matching engine fingerprints,
valid witness hashes and retention of every published rescue target. Do not
package a partial audit or replace the catalogue with unchecked search results.

After a reviewed Classic engine change, `classic --refresh-outcomes` and
`ports --refresh-outcomes` replay the preserved inputs against the current engine.
They check the published witness bytes, validate every input, reproduce the new
outcome and retain every published rescue count. A current completion fixture
can replace an obsolete input sequence only if it meets that rescue target.
The default audit still rejects changed stored outcomes. Merge requires all
families to use the current source fingerprint.

Run `python3 Tools/TrolleyVerification/test_refresh.py VERIFIER RESOURCES` to
check strict rejection of stale outcomes, explicit refresh and rescue-count
retention.
