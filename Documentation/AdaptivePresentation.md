# Adaptive presentation

Updated 13 October 2026.

## Product requirement

Adaptive presentation is a core benefit of Ultimate Lemmings. Each device should
deliver the richest visual presentation it can sustain with responsive input,
stable frame pacing and a suitable power budget. Apply this requirement to
Classic, Lemmings 2 and Lemmings 3 on Mac, iPhone and iPad, and to the future
Apple TV implementation.

Use hardware and software capabilities to select the initial budget. Use measured
work to lower or raise quality during play. A hardware generation is a starting
hint, not a permanent quality ceiling. Preserve the player's chosen artwork,
display style, enabled effects and accessibility limits.

## Shared policy

`LemmingsGameArt/AdaptiveFXPerformance.swift` owns device profiles and separate
CPU and GPU controllers. Metal availability bounds supported rendering. GPU
family and CPU count select a conservative initial quality. The GPU's recommended
working set bounds soft overlay pixels. It is not treated as a speed measurement.
Existing mobile enhanced-effect eligibility remains in place for older hardware.

The policy uses three bounded quality levels. CPU quality controls bitmap trail
counts and echoes. GPU quality controls bloom resolution, soft overlay resolution
and concurrent cinematic bursts. Effect cadence follows the lower quality and
the presentation target. Sharp terrain, sprites, interface pixels and selection
outlines do not change resolution with these budgets.

Frame work above 78% of the requested frame interval for two seconds lowers one
level, with at least three seconds between reductions. Work below 42% for twelve
seconds raises one level. Brief spikes and lifecycle gaps do not trigger changes.
Thermal and power ceilings apply immediately, including while paused. Removing a
ceiling requires measured recovery rather than immediately restoring all effects.
Current adapters cap presentation targets at 60 Hz. High-refresh presentation is
future work, not a claim that authored sprite animation runs at 120 Hz.

CPU update and deferred drawing stages report separately on mobile. GPU completion
callbacks collect execution durations without waiting in the shipping frame loop.
Samples from active surfaces expire after half a second. Their sum is a budgeting
estimate, not an end-to-end latency measurement or a sum of independent percentiles.
There is no additional measurement timer, benchmark at startup or network upload.

## Platform integration

Mac's shared presentation policy is used by Classic, NeoLemmix and both native
sequels. CPU work reduces bitmap trails independently of CRT glow detail. CRT and
HDR completion callbacks report GPU cost. Effects respect display refresh limits,
power and thermal states. Large displays also respect the overlay pixel budget.

iPhone and iPad share the policy through the common game controller and playfield.
The existing mobile thermal frame-rate and simulation clock policies remain.
Eligible soft effects adapt between 30, 45 and 60 Hz, bounded by the current
presentation target, rather than always requesting 30 Hz. Cinematic burst counts
retain the exposure burst when reducing decorative bursts. Idle effects remain
hidden and request no drawable.

Mobile CRT scales its bloom intermediates without reducing the sharp output.
Selection-only redraws reuse unchanged bloom. Disabled bloom runs no extraction
or blur passes. Changes to source pixels, gamma or bloom dimensions rebuild the
intermediates. Selection and input projection retain their existing geometry.

L2/L3 mobile adapters still lack complete native sprite rendering, masks and
explosion metadata. The shared policy is available to them, but it cannot create
those missing visuals. There is no tvOS target yet. Apple TV needs its own adapter
and physical-device acceptance before this benefit can be claimed there.

## Validation and next work

Run `Scripts/run-adaptive-fx-policy-tests.sh` for headless capability, CPU/GPU
isolation, promotion, refresh-budget, thermal, stale-sample and memory-bound checks.
Run native renderer checks through the offscreen, muted UI runner. Compare sharp
pixels, selection outlines, input projection and replay state across quality levels.
Keep existing saved-run, simulation and Hot Seat readiness behaviour unchanged.

Local checks on 13 October 2026 passed the policy scenarios, two mobile thermal
and clock regressions, the Mac app build and the arm64 iOS UI target compile.
Offscreen, muted Metal checks passed unchanged-scene reuse, selection fade, zero
bloom, all quality levels, flash expiry and input projection. The three exported
SDR quality renders were inspected. Classic DOS, Macintosh and Amiga scene
comparisons also passed digging, construction, nuke, rewind, undo and restoration.
These are local checks, not sustained measurements across hardware generations.
Native L2/L3 sustained workloads and mobile rendered states remain unverified.

Physical acceptance must cover sustained loads on older and newer devices, display
changes, thermal recovery, battery use and actual HDR appearance. Mobile rendered
output needs device or headless simulator coverage. Compilation alone is not
visual acceptance, and controller tests do not establish a measured speed gain.

Further work should follow measured bottlenecks: texture conversion and upload
reuse, changed-region updates, missed-presentation feedback, resource pressure,
event-aware preparation, shader variants and smooth quality transitions. Expand
the quality curve only when visual comparisons and sustained measurements justify
the additional levels. Avoid oscillating texture allocations or draining a battery
merely because a device has spare processing capacity.
