# Performance baseline

Use this harness before changing engine or presentation code. It does not change
engine rules, release evidence or recorded replay expectations.

## Fixed inputs

Capture tracked files and non-ignored untracked files into a new directory:

```sh
python3 Tools/PerformanceBaseline/snapshot.py "$PWD" "$PWD/.build/performance-run" \
  --resources "/path/to/Ultimate Lemmings.app/Contents/Resources" \
  --neo "/path/to/full/local/NeoLemmixCorpus" \
  --classic-candidates "$PWD/Artifacts/LearningJourney/candidate-solutions.json"
```

Keep the captured source unchanged. This copies the required resource directories
into `assets/resources`, and the complete NeoLemmix `levels` and `styles`
directories into `assets/neo`. It follows asset symlinks while copying and freezes
the resulting files. It retains file hashes, original paths and an aggregate
manifest hash. The candidate argument is optional. The source-only snapshot form
omits all three asset arguments.

The case selector uses the retained build 83 fan inventory and snapshot route
fixtures. It reads Classic candidates from `assets/candidate-solutions.json`
and the copied `Hints/solutions.json` and `Progression/solutions.json` files.
The selected Classic replays are copied into `assets/selected-replays`. Selection
then reseals the asset manifest, including those derived replay files.

```sh
python3 Tools/PerformanceBaseline/select.py \
  .build/performance-run/source .build/performance-run/assets \
  .build/performance-run/cases.json
python3 Tools/PerformanceBaseline/run.py build \
  .build/performance-run/source .build/performance-run/build
python3 Tools/PerformanceBaseline/run.py measure \
  .build/performance-run/source .build/performance-run/assets \
  .build/performance-run/cases.json .build/performance-run/build \
  .build/performance-run/results
python3 Tools/PerformanceBaseline/run.py build-extras \
  .build/performance-run/source .build/performance-run/build
python3 Tools/PerformanceBaseline/run.py measure-extras \
  .build/performance-run/source .build/performance-run/assets \
  .build/performance-run/build .build/performance-run
```

The build uses the host architecture, `-O`, Swift 6 and the Mac shell's module
boundary. Build commands are retained in logs. XCTest requires the selected
Xcode's XCTest overlay libraries. XCTest runs through `Tools/UITestRunner/run.py`
in offscreen, muted mode. A missing headless Metal device is a failed check.
Report that failure or obtain GPU access without changing window mode.

## Measurement boundaries

Each simulation case has one warm-up, seven timed samples and one separate
allocation sample. The warm-up determines a fixed batch size targeting at least
100 ms of tick work per sample. Times are divided by that batch size. Every route
in a batch must reproduce the warm-up state. Decode, initial-state construction and final-state hashing
are outside the tick timer. Commands, completion checks and normal engine events
are inside it. Samples start from the same prepared value and therefore include
the first mutation's normal copy-on-write cost. No renderer or audio output runs.

Classic uses recorded fan routes. L2 uses the shared timed-event cursor. L3 uses
the retained route input adapter. A pre-existing L3 expected-outcome mismatch is
recorded as `recordedOutcomeMatches: false`; it is never rebased or called a
passing reference replay. The corpus runner records preparation/input failures
as errors and continues, so missing coverage stays visible.

NeoLemmix simulation cases run at most 4,096 no-input ticks. The extra scripted
stress case sets spawn interval 4 at tick 1 and nukes at tick 1,024. It is a
generated stress trace, not an external winning replay. `CorpusMain.swift`
separately retains the runnable gate's 256-tick run and 64-tick save/restore check.
NeoLemmix hashes normalise known sets and the enum-keyed skill dictionary, while
preserving actor and command order. Hashes include the encoded simulation.

The diagnostic C counter temporarily installs `malloc_logger`. It counts
successful malloc-family allocation events on the benchmark thread. Its mandatory
self-test must see exactly one allocation. Counts exclude ARC operations, direct
VM allocations and other threads. Counter-instrumented timings are not baseline
timings. This private diagnostic hook is never linked into an application.

XCTest records clock, CPU and memory metrics for four decoders, four level-load
paths, Classic CPU scene composition plus texture upload, the rewind capture tick
and checkpoint encoding. Decoder tests contain 100 operations per iteration.
Other tests contain one operation. Memory peak is the process physical footprint,
not retained memory attributable only to that operation. The texture test reads
pixels back and requires exact equality. It measures CPU submission, not GPU
frame time or displayed fps.

`AudioBench.swift` is concatenated after the frozen MusicRewindBuffer,
MusicFileDeck, ModuleMusicPlayer, VinylRamp and SoundEffectPlayer sources, then
compiled as a standalone `main.swift`. It measures offline 1,024-frame blocks.
It never starts an audio engine. Run it through the muted native test runner.

`CRTBench.swift` uses the shipping Mac CRT encoder without a window or drawable.
It draws frozen Classic terrain/object pixels at 640 × 320 into a 1280 × 640
RGBA16 texture. Seven samples each contain 32 completed command buffers, after
warm-up. Static/full, changing/full and changing/minimal cases retain CPU submit,
GPU execution and completion wall times. Every sample must produce the same
final pixels as its warm-up. This isolates the passes and upload cost. It does
not measure display pacing, sprite composition or presentation latency.
The harness sets the retained source fields directly before timing. Calling
`setSource` would invoke `render` and prepare the upload before the timer.

## Evidence and comparison

```sh
python3 Tools/PerformanceBaseline/run.py verify \
  .build/performance-run/source-manifest.json .build/performance-run/source
python3 Tools/PerformanceBaseline/run.py compare before/simulation.json after/simulation.json
python3 -m unittest discover -s Tools/PerformanceBaseline -p 'test_*.py'
```

Comparison requires the same case identities, state hashes, tick counts, saved
counts, dimensions and recorded-outcome status. It rejects empty or duplicate
case sets. Compare per-level corpus output separately, including errors and
unverified routes. Aggregate pass counts cannot establish determinism.

Classic, L2 and L3 retain the existing replay-gate digest definitions. In
particular, the L2/L3 digests do not serialize every private runtime field.
These outputs support gate comparison, not a claim that every runtime byte was
compared. Keep this limit explicit before changing engine state or snapshots.

`classic_corpus.py` adds final-state output fields to a generated copy of the
existing Classic audit. It leaves the snapshot source unchanged and rejects
unknown source anchors. Retain and hash the generated source beside its output.

Collect Instruments traces separately from uninstrumented timing runs. The
`SimulationTicks` signposts identify timed regions. Keep trace launch arguments,
tool versions, host load, inputs and compiler flags. Do not compare trace timings
with uninstrumented samples. Do not launch the normal app to obtain a launch
metric if it can request full screen, activate the desktop or change player data.
Report interactive launch, sustained frame pacing and physical-device thermals
as unmeasured until a suitable headless harness or authorised device run exists.

Keep machine-specific results under ignored `.build` storage. Keep one-off reports
in `~/Documents/Ultimate Lemmings/Posts`. Do not update release claims from these
measurements.

Build the frozen Mac executable and shared modules with the shell build flags
before recording their sizes. `sizes.py BUILD_DIR REFERENCE_APP OUTPUT_JSON`
records host module sizes, existing reference slices and resource totals by
directory and extension. It extracts existing slices without compiling Intel or
building a universal app. `report.py BASELINE_DIR OUTPUT_MARKDOWN` writes the
combined table and records corpus failures and measurement limits.
