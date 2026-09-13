# Production-loop performance measurement

13 September 2026. The old local benchmark called Metal's
`waitUntilCompleted()` after every submission. The shipping app submits
asynchronously. The extra wait changed update cadence, so the old sample did not
measure the production loop.

Performance builds now collect GPU completion callbacks instead of blocking
inside each frame. Reports distinguish:

- `cpuFrameMS`: app update, drawing and submission work on the main thread.
- `gpuExecutionMS`: command-buffer GPU execution duration.
- `gpuCompletionMS`: submission-to-completion latency, including queued work.

These distributions cannot be added together to produce an end-to-end percentile.
GPU completion is not a measurement of photons reaching the display.

Submitted GPU work must complete without errors. The test drains it after the
timed interval. Each scenario uses a separate metrics object, so late completion
from an earlier scenario cannot contaminate the next one.

The benchmark also verifies one captured replay frame per simulated tick and
checks recorder failure. Each movie is then finalised and its encoded video samples
are counted. The count must match the captured frames. Finalisation and reading
occur outside the timed loop. It cannot claim capture-enabled throughput after
a failed or incomplete recording. `LEMMINGS_PERFORMANCE_OUTPUT` can select an evidence file
without overwriting earlier runs.

## Investigation

The initial sampled baseline was useful for locating drawing costs but was not
used as a clean throughput comparison. Converting full scene images regressed
CRT performance. Converting and caching only the visible crop showed no meaningful
throughput gain against an unprofiled baseline. Both product changes were removed.
The shipped renderer and 12 ms fast-forward input budget remain unchanged.

The resulting fix is to measurement accuracy and failure detection. It is not a
claim that gameplay was accelerated.

## Validation scope

The local benchmark uses a 1280 × 720 window, one Classic level, replay capture,
visual effects and a nuke when the scenario lasts long enough. It uses short
samples and silent audio. Native L2/L3 sustained workloads, audible audio stability,
physical Intel, minimum macOS, other displays and thermal runs remain unverified.

Evidence is under `.build/beta-exit-performance/`. The original sampled run,
clean baseline and rejected experiments are retained. Only the production-loop
report represents the revised benchmark.


## Final local results

Apple M4 Pro, 24 GB RAM, macOS 27.0, optimized arm64 app with beta 27 resources.
Samples lasted 14–20 seconds. These are observed speeds, not sustained guarantees.

| Display | Requested | Observed | CPU p95 | GPU execution p95 | GPU completion p95 | Encoded frames |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Flat | 1× | 1.00× | 8.98 ms | — | — | 340 |
| Flat | 10× | 9.08× | 27.82 ms | — | — | 2,208 |
| Monitor | 10× | 7.05× | 29.36 ms | 3.50 ms | 4.09 ms | 1,704 |
| Television | 10× | 6.92× | 30.72 ms | 3.56 ms | 4.00 ms | 1,680 |

All 5,932 captured frames are present in the final movies. Both CRT scenarios
completed all 484 submitted GPU frames without errors. Peak resident memory
ranged from 289 to 341 MiB. That range does not establish long-session memory
stability. Main-thread work remains a throughput constraint.

The normal replay suite also passes: exact 51-frame output with audio,
17.5 Hz L2 and 23 Hz L3 clocks, all 41 ghost frames, upright playback and export.
The two release-audit integrity tests pass.

The release audit now runs this measurement with `--app` and writes
`performance.json` beside its other evidence. Without `--app` it is explicitly
not run. Passing the measurement checks does not close the throughput gate.

Final evidence: `final.json`, `final.log`, `movie-final.log`,
`audit-tests.log` and `results.json` under the evidence directory above.
