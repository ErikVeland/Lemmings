# NeoLemmix final-state oracle contract

The replay parity gate compares gameplay state, not only the pass result or
completion frame. Both engines must emit `neolemmix-final-state-v1` JSON for
the same replay bytes and the same terminal tick.

Generate the native manifest with:

```sh
zsh Scripts/run-nxrp-paired-corpus-diagnostics.sh \
  /path/to/levels /path/to/replays /path/to/styles \
  --write-final-states /tmp/native-final-states.json
```

Compare an independently generated CE manifest with:

```sh
zsh Scripts/run-nxrp-paired-corpus-diagnostics.sh \
  /path/to/levels /path/to/replays /path/to/styles \
  --compare-final-states /tmp/ce-final-states.json
```

The comparison requires exactly one record for every replay SHA-256. Level IDs
and versions use sixteen-digit uppercase hexadecimal values with an `x` prefix.
No path or filename is an identity.

Native exports use `"producer": "native"`. An oracle manifest must use a
reviewed identifier beginning with `ce:`, for example `ce:1.2.0+oracle.1`.
The comparator rejects a native manifest in the oracle position, so a
self-comparison cannot satisfy the release gate.

For the pinned 32-bit CE 1.2.0 executable, the repository also contains a
reviewed live-memory exporter. Its plan is tab-separated replay SHA-256,
terminal tick and replay path. Terminal ticks must come from the reference
replay result or source-engine result, not from a native run made only for this
comparison. Run it through the same CrossOver bottle used for CE:

```sh
zsh Scripts/run-neolemmix-ce-final-state-oracle.sh \
  /path/to/crossover/bin/wine BottleName /path/to/NeoLemmixCE.exe \
  /path/to/plan.tsv /path/to/matched/levels /tmp/ce-final-states.json \
  /tmp/ce-final-state-snapshots
```

The command accepts only executable SHA-256
`58d2fccd31e20d5513ee8d2d5eafb6d368f847d8d2cb4a152efeedcb6d4eaf36`.
It restarts each replay at tick zero, advances CE with its own replay controls,
waits for the cross-object lemming state to settle, and copies game, lemming,
gadget, physics, terrain and renderer memory. The Ruby exporter derives fields
from those CE snapshots. It also recovers the final constructive gradient step
from CE placement geometry when a bright theme clamps steps 11 and 12 to the
same rendered colour. It never reads a native manifest.

## Terminal tick

Emit the state immediately when CE's mass replay checker decides pass, fail or
undetermined. Do not advance animations or lemmings after that decision. The
native runner uses the same source-compatible cutoff and the replay's recorded
completion frame when it is valid.

## Scalar and lemming fields

The manifest records the tick, released, saved, lost and cloned counts, the
remaining time, spawn interval, entrance-open and nuke states, completion and
win results, and the remaining skill inventory. `null` skill count means
infinite. Skills, traits, actions and removal reasons use the lowercase names
from the level and replay formats.

Every created lemming remains in the list, including removed lemmings. Sort by
numeric ID. Record its foot position, direction (`-1` left, `1` right), action,
animation frame and progress, fall counters, traits, pending explosion,
constructive state, gadget targets, teleporter and portal state, Slider pin,
clone parent, removal state and Oh-No history.

Zone IDs, remaining finite entrance or exit capacities, primary gadget frames
and secondary animation states are sorted by their numeric IDs and animation
indices. Missing optional maps are equivalent to empty maps.

## Terrain hashes

Record level dimensions and SHA-256 for the complete row-major arrays:

- solid, steel, one-way and visual-opacity masks as one byte per pixel;
- construction shade as one byte per pixel;
- Stoner owner values as little-endian signed 32-bit integers;
- Stoner source values as little-endian unsigned 16-bit integers.

An absent optional layer is JSON `null`; it is not the hash of an empty array.
These hashes cover live terrain after all destructive and constructive edits.

The native schema and comparison implementation are in
`Sources/NxlvKit/NeoLemmixFinalState.swift`. A CE oracle is authoritative only
when it is built from the pinned reviewed CE source and emits these fields
without consulting native output.

## Verified corpus

On 28 September 2026, the reviewed exporter captured all 160 terminal states
for the March 2025 Lemmings Redux replay corpus from CE 1.2.0. The repository
comparator matched all 160 native records to that manifest with no field or
terrain-hash differences. The same run completed all 160 native and recovered
routes; all 158 exact-version pairs completed, and the two known
source-version-mismatched routes remained classified separately.
