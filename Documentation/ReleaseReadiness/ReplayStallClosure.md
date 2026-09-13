# Replay encoder stall handling

13 September 2026. Local changes after the text-steel pass. No release package
was produced.

## Defect and change

The replay queue holds twelve images, but accepting another image previously
waited without a deadline on the main thread. A stalled encoder could therefore
block game input. The encoder's own ten-second readiness timeout did not bound
all queue work.

Frame admission now waits at most 500 ms. A timeout marks the entire recording
as failed. Later capture and audio submissions stop. Review and save return the
error without waiting for the blocked queue. Successful recordings still contain
one frame per simulation tick.

Shared capture now evaluates its drawing closure only when recording can accept
frames. Inactive, failed, finishing and discarded runs avoid capture work. Classic,
L2 and L3 use this shared path. No engine rules, controls or saved-run formats
changed.

This bounds one encoder-related input stall. It does not establish sustained
10× throughput or complete the hardware/performance gate.

## Validation

Evidence is under `.build/beta-exit-replay/`.

- `replay-tests-final.log`: the deliberately blocked queue stops submissions and
  returns an error while still blocked. It cannot return a partial movie as a
  success. Capture closures remain unused after recording stops.
- The same suite verifies 51 exact video frames, upright images, module and SFX
  audio, speed exports, 17.5 Hz L2 and 23 Hz L3 clocks, 41 directional-ghost frames,
  bitmap replay controls and playback audio ownership.
- `audit-tests.log`: both release-audit integrity tests passed. The release audit
  now includes the movie suite when run with `--app` and explicitly compiles for
  macOS 13, avoiding a host-default deployment-target mismatch.
- `app.log`: the optimised full app journey passed against beta 27 resources,
  including hints, solution playback, saved attempts, interruption handling and
  Hot Seat. The recorded application/core source inputs did not change during
  validation (`inputs.json`, `results.json`).

A 100 ms trial interrupted normal encoder startup and was rejected. The final
500 ms policy passes the ordinary movie tests. This is a measured local check,
not a guarantee for every encoder or physical Mac.

## Campaign search

The separate Xmas 1992 level 2 search found no winning route. It used a beam of
24, up to 18 assignments and a 4,200-tick limit. The strict tool reported the level
as unverified and wrote no fixture. `xmas-search.log` retains the result. The
search does not prove the level impossible and does not reduce the route gap.

Missing campaign evidence, fan compatibility, sequel fidelity and media, physical
hardware/input/recovery validation, VoiceOver listening and distribution approval
remain tracked in [the gate register](gates.json).
