# Runtime performance

## 2.3 audio and performance blocker — 26 October 2026

The owner reports crackling on the latest iPhone Duo, iPad 8th generation and
Apple TV 4K. Output routes, OS versions, soundtrack and exact triggering stages
have not yet been isolated. Treat this as a reproduced user-facing blocker on
those platforms. Its cause is not yet proved. Clean compilation and muted UI
checks do not close it. The requirement applies throughout launch, menus,
loading, gameplay, pause, results, replay and transitions.

### Phone Home Screen, Duo folding and menu handover — 30 October 2026

The owner clarified that reported crackling follows leaving the app for the
phone's Home Screen, and suspects the previous inactivity delay during Duo
folding as well. These physical-device triggers remain unverified locally.
Earlier source inspection also found
that game disappearance queues audio-session deactivation while Home starts its
theme without waiting for activation. Repeated disappearance callbacks also
suspend the shared music transport after ownership has moved to Home.

The shared iOS/tvOS session queue now tracks live owners and skips deactivation
while Home or another level owns audio. Home waits for activation before starting
or resuming its theme. Gameplay pause/suspend callbacks carry the attempt ID and
cannot change Home's transport, including activation in flight. Home resets the
gameplay pitch; late gameplay telemetry cannot restore failure/nuke processing.
Soundtrack names are cached instead of recursively scanning recordings during
every music-state query; download completion and library removal invalidate them.

The former 400 ms full-volume inactivity grace is removed. Menu music now begins
a 120 ms spin-down before inactive-scene layout work, omits the decorative
1.2-second reverb tail, and preserves the loaded track. Tracker output accounts
for up to 186 ms of already queued PCM before parking; a menu cleanup scheduled
after 350 ms releases its session. Reactivation cancels that cleanup and uses the
existing spin-up. Recording rate/gain ramps still run on the main actor, so this
does not establish continuity under a blocked UI thread or make spinning cheaper
than immediate suspension. Gameplay keeps its immediate suspension and explicit
player Resume behaviour.

Application background entry overrides any spin-down immediately, parks every
music transport and revokes session ownership. Pending activations are
invalidated; new preparation/activation requests cannot run in the background.
Foreground entry permits new requests without automatically resuming gameplay.
The short-brake option is shared by MOD, recording and Adaptive DJ transports;
desktop callers retain the existing pause timings through default arguments.

Silent, headless session checks cover overlapping level activation, repeated
outgoing-game suspends after Home activation, last-owner release, activation
failure, superseded requests, released controllers, backgrounding during an
in-flight activation, blocked background requests, overlapping-owner release,
foreground recovery and rapid fold reactivation; these checks pass. iOS/tvOS SDK
modules and application entry points compile. The native audio performance and
DJ programs compile, including new short-brake cancellation, omitted-tail and
background-override checks. The muted, offscreen offline-audio run aborts while
creating `AVAudioUnitEQ` (`comp != nullptr`), before those transport checks can
execute. Their runtime result is unverified. Logs are
`.build/phone-background-audio-{ios-final,tvos-final,native-compile,offline}.log`.
Simulation and broad engine/release suites were skipped
for this audio-lifecycle change. Installed-device listening,
route changes and sustained playback remain unverified; this fixes source-level
transition faults and does not close the physical-device crackling gate.

### Invalid player time during stop — 27 October 2026

The muted offline spatial-audio suite reproduced a Core Audio exception during
`BufferedAudioSource.stop()`: a non-nil `lastRenderTime` can still have neither
a valid sample time nor a valid host time. Passing that value to
`playerTime(forNodeTime:)` throws while the output is stopping. The source now
checks both validity flags before querying and falls back to its last stored
frame. The full muted, offscreen audio performance suite passes with this fix.
This closes the reproduced invalid-time crash only. It does not establish clean
audio on the reported physical devices or close the audio release gate.

Source assessment at `234acea9`, including the working-tree recording-deck
idempotence change:

| Finding | Evidence | Required work |
| --- | --- | --- |
| Effects callbacks can wait on control work | `SoundEffectPlayer.fillVoice` takes the same blocking `NSLock` as library changes, camera placement and rewind construction. `playRewindScrub` allocates and constructs a sample slice while holding it. Supplement decoding also occurs under this lock. | Remove control-thread waits from render callbacks. Prepare samples and rewind work outside the render-owned state, then transfer bounded commands or prepared buffers. Do not substitute silent blocks for blocked callbacks and call the dropout fixed. |
| Render work includes mutable collections | `fillVoice` copies a `Voice`, updates its rescue-layer array and removes completed layers inside the sample loop. | Bound and preallocate render state. Measure allocations and callback time with active rescue layers, not just idle sources. |
| Music buffering lacks release diagnostics | MOD uses eight 1,024-frame buffers. Recordings use eight 2,048-frame buffers. `scheduledFrames` supports the MOD clock; it is not a reported starvation counter. `MusicPCMStream` discards refill errors with `try?`. | Record reserve low-water marks, refill delays/errors, callback deadline misses and unexpected engine restarts without logging or allocating in the render callback. Surface decoder failures outside that callback. |
| Nonblocking rewind can still lose audio | `MusicRewindBuffer.record` skips history under contention. Its reverse source outputs zero when its try-lock fails. | Measure contention and audible continuity during repeated rewind. Nonblocking execution alone does not establish uninterrupted output. |
| Lifecycle and route evidence is missing | Mobile requests a preferred buffer duration and handles interruptions/route loss. Repeated recording `play()` has a working-tree guard against restarting its fade. | Verify actual negotiated rate, buffer duration and output route. Exercise interruptions, background/foreground, media-service reset, speaker/headphone changes and TV HDMI on the installed candidate. The idempotence change is not proof of a general crackling fix. |

At 44.1 kHz, those queues nominally hold about 186 ms of MOD audio and 372 ms
of recording audio. These are reserve sizes, not measured end-to-end latency
or a guarantee under contention. The earlier four-buffer/93 ms description below
is historical. Do not keep increasing buffers without measuring latency and the
work that exhausts them.

### Evidence limits

`Scripts/run-audio-performance-tests.sh` exercises offline audio. Its MOD fixture
covers a bounded synthesis stall, refill and loop joins. The idle effects check
calls voices directly; it does not run a complete game with competing graphics,
loading and audio callbacks. The DJ command uses `--signal-only`, so the later
real-time file-loop, suspend/resume and installed-track scenarios in that test
program are not executed by this script. Some signal-path coverage still runs.
Muted UIKit gameplay checks bypass normal effects preparation and playback.
They establish UI behaviour, not simultaneous audio/render performance.

The latest published Mac measurement retained in
[2.2.2 build 99](ReleaseReadiness/2.2.2-build99/audit-performance.json) is also
silent, uses one Classic workload at 1280×720 with recording enabled, and lasts
about 15–20 seconds per scenario. Its `television` case is the Mac CRT preset,
not an Apple TV hardware run.

| Mac scenario | Requested speed | Observed speed | CPU p95 | CPU p99 |
| --- | ---: | ---: | ---: | ---: |
| Flat | 1× | 1.00× | 22.89 ms | 23.97 ms |
| Flat | 10× | 4.70× | 32.24 ms | 43.68 ms |
| Monitor | 10× | 3.36× | 34.04 ms | 40.00 ms |
| Television preset | 10× | 3.45× | 33.43 ms | 34.93 ms |

This report does not establish current 2.3 speeds or a regression against another
machine. It does establish that a passing measurement command did not require
the requested throughput or clean audible output. CPU p95 at 1× exceeded a
16.67 ms presentation interval in that sample. Frame delivery needs its own
measurement; CPU and GPU percentiles cannot be added.

`Tools/ReleaseReadiness/audit.py` defaults to the `minor` scope and checks open
gates in its exit status only when closure is required. Recording P0 entries
under the broad scopes is not automatic publication enforcement. The release
approval path must consult the applicable 2.3 blockers explicitly, while
retaining the owner's rule against unrelated routine Mac test suites.

### Closure order

1. Add bounded audio diagnostics and isolate music-only, effects-only and mixed
   output on each reported device. Record build/content identity and output route.
2. Remove shared callback waits and heavy locked work. Check file refill errors,
   gain/loop continuity and repeated start/resume separately. Preserve spatial
   feedback, warnings, musical timing and deliberate vinyl effects.
3. Stress the combined production path: Classic/L2/L3/Neo crowds, 1× and fast
   speeds, supported nukes, repeated rewind, camera/zoom, replay capture/export,
   engine changes, catalogue loading and cloud activity. Measure both cold and
   warm transitions.
4. Use installed, optimised candidates for sustained sessions and thermal/low-power
   runs. Begin with the reported Duo, iPad 8 and Apple TV 4K, then the supported
   Mac and remaining iPhone/iPad hardware. A proposed minimum is 30 minutes per
   representative device workload, plus repeated transitions; this is not a claim
   that a finite soak proves every future session.
5. Close the gate only with no unintended crackle, clicks or dropouts in those
   runs, no unexplained starvation/deadline failures, and measured presentation,
   input, memory and achieved simulation speed. Track maximum callback cost and
   p95/p99, not averages alone. Reduce decorative work before compromising audio
   or input. Record the supported presentation target for each device.

Mechanical checks remain offscreen and muted. Audible acceptance needs an explicit
owner-requested listening run under `AGENTS.md`; none was performed for this audit.
See [2.3 release assessment](ReleaseScope.md#23-release-assessment).

## Crowded play, 18 October 2026

A 100-lemming Classic crowd and real L2/L3 levels were measured with optimised
builds on Apple silicon. Engine ticks, targeting and checkpoints cost less than
0.1 ms. The frame cost came from presentation, not from the number of lemmings.

The shared iOS and tvOS playfield drew the whole level on the CPU for each tick
and camera move. Fitted zoom and the 1.2 pixel aspect use non-integer scales,
which force the slow Core Graphics path. One iPad-sized draw took 7–9 ms on
Apple silicon. Core Animation now scales the engine bitmap on the GPU with
nearest filtering. Selection, cursor and effect overlays draw above it, and an
empty overlay keeps no backing store. Bitmaps above 8,192 pixels keep the CPU
path. CRT display is unchanged.

The minimap colour-matched the full level image to draw a small map. A shared
thumbnail now samples each new frame once at the map's device-pixel size. This
applies to the Mac panel and the mobile and TV HUD. The Mac panel draw fell from
3.9 ms to 1.65 ms with Macintosh artwork on a P3 display. The Mac Classic and
NeoLemmix playfield retains its level crop between ticks. Redraws between ticks
then reuse the colour-matched pixels: 2.40 ms became 1.69 ms in isolation. The
mobile Classic renderer reads sprite and frame bytes in place. Its render time
fell by about a third.

Recorded crowd pixel digests, the TV console checks and the Mac scene pixel
checks pass offscreen and muted. The iOS Simulator build shows the GPU-scaled
playfield, overlays and minimap. Camera panning, sustained frame timing and
older iPad, Apple TV and Intel Mac hardware still need device validation.
The L2 and L3 Mac canvases already reuse their terrain images; their CPU fill
cost is unchanged.

## Loading and frame budgets, 14 October 2026

The shipping Mac, iOS and tvOS paths retain their authored simulation rates.
All three Mac engines now limit catch-up work to the existing 12 ms input budget,
including fixed-speed fast-forward. Unprocessed ticks remain in the accumulator.
The shared iOS/tvOS controller uses a frame-rate-aware CPU deadline and returns
unprocessed ticks to its clock. It still renders and services input each frame.
This bounds catch-up batches. One synchronous simulation tick or render can
still exceed a deadline on slow hardware.

Lemmings 2 mobile rendering retains the expanded terrain pixels while source
pixels and palette remain unchanged. Content comparisons also invalidate the
cache after rewind, restoration or a different terrain branch. Compositing uses
copy-on-write storage, so live actors cannot change the retained background.
Lemmings 3 prepares its authored RGBA scene during loading and applies only its
sparse terrain edits during rendering. Tests compare both paths with fresh
conversion, including palette changes, construction, removal and rewind.
Its mobile library also reuses decoded style, sprite and palette banks for each
of its three tribes. Those banks stay bound to the library's content revision.

The shared mobile controller reuses each frame's status snapshot and skips
replay-only status work during live play. Chronicles retains its fixed skill
labels. Active-population counts avoid temporary arrays. The hidden library
input clock pauses during gameplay. Constrained, hot or low-power devices load
the selected carousel cover without speculative neighbour requests.

Mac catalogue warming stops when an engine enters gameplay. Cancelled warmers
cannot publish late catalogues. Progression analysis propagates cancellation
to its worker. Mac fan counts use a cancellable utility task and read their
existing counts once per scan. Cancellation rejects queued progress callbacks.
Counting resumes in the library. A detached Mac carousel cancels its pending artwork requests.
Catalogue warming also prepares the installed Mac sequel banks. L2 retains its
front-end, practice, campaign, sprite, mask and sound data. L3 retains each tribe's
style, sprites and availability checks. Fresh sessions restore the current
owner's progress after taking a copy of the decoded campaign. The caches never
retain player progress, and mutable imported directories keep fresh decoding.
The shared-module build script also includes TV core, which the current game-art
module requires for headless Mac checks.

An optimized local Apple Silicon microbenchmark uses 128 samples per size.
It measures terrain preparation only, with no actors, textures, audio or display.
At 1024 × 512, full palette conversion took about 0.45 ms and applying 128 sparse
edits took about 0.028 ms. This is approximately 16 times less CPU work for that
operation. Cached L2 conversion avoids the palette loop. Its later compositing
copy and actor draws are outside this measurement. Evidence is in
`.build/platform-terrain-benchmark.json`.

These changes do not establish perfect frame rates across devices. Physical
iPhone, iPad, Apple TV, older/Intel Mac, display-refresh and sustained thermal
measurements remain necessary. AppKit image creation, unprepared cold starts and
mutable Mac imports still have synchronous work in their construction path. The shared mobile level
workers and cancellation checks are described in [loading performance](LoadingPerformance.md).

The focused Mac checks run through the offscreen, muted runner with
`TEST_SCOPE=frame-performance`. They pass real input and frame-clock checks,
native L2/L3 starts and paused retries, cancelled fan counts, and carousel
detachment/return. Fifty-eight focused mobile/TV tests pass, including real
sequel loading, rendering and checkpoint restoration against the built iOS
assets. The current-architecture Mac code and unsigned arm64 iOS/tvOS apps compile.
The broader browser harness still has existing
home-menu and fixed-row-count assertions that do not match the current menus.
Those checks remain intact. The independent progression fixture also needs
`.build/ios-ports/source-revisions.json` before its real-campaign check can run.

Adaptive presentation is a core product requirement. The shared CPU/GPU budget
now covers Mac and iOS effects. See [adaptive presentation](AdaptivePresentation.md)
for capability discovery, quality curves, platform integration and validation gaps.

Classic on macOS and iOS reuses terrain pixels between terrain edits. Animated
objects and lemmings retain their normal updates. Digging, construction and
explosions invalidate terrain. Rewind, nuke undo, restoration, session replacement
and artwork replacement clear the cache. Macintosh and Amiga artwork use the
same shared terrain renderers as DOS artwork.

Mac Classic, Lemmings 2 and Lemmings 3 capture immutable engine values for recovery
hashes. The serial recovery writer computes those hashes, encodes checkpoints and
writes files off the game thread during play. A busy writer skips periodic saves
to bound retained snapshots. Session changes and exit saves preserve queue order
and wait for completion when requested. Saved formats, owners, turns and paused
handovers retain their existing behaviour. NeoLemmix uses the same serial writer
and admission limit with its existing state-equality recovery format.

Mac settings already live in memory. Lemmings 2 already caches terrain by revision
and panel art by content. Lemmings 3 retains its decoded terrain background and
draws live changes separately. Both retain these paths. The shared module and
recording audio players skip pitch updates below 0.1 cent, after combining game
speed and DJ mix compensation. The Mac CRT drawable uses framebuffer-only storage
because all its uses are render attachments. Retina output and HDR remain active.

iOS retains its device-specific 30 Hz, one-pixel-per-point and SDR budgets for
older GPUs. Its audio-session buffer request also remains platform-specific.
Mac keeps its existing presentation rate and output resolution.

## Mobile speed and explosion light

iOS shares the Mac speed streaks, engagement burst, cinematic explosion shaders
and wall-clock timelines. Flat and CRT presentation both support this surface.
It uses FP16 extended-linear colour and the screen's current EDR headroom, capped
at 8. SDR screens retain the same shapes and animation at SDR brightness.

The surface requires more than two CPU cores and Apple GPU family 4 or later.
Older iPads retain their existing lightweight explosion cores. Low Power Mode,
serious or critical thermal pressure, disabled HD effects and Reduce Flashes
disable the extra surface. Reduce Motion also disables speed animation and
cinematic explosions. Output now follows the shared effect budget, up to 60 Hz
and two pixels per point, with lower resolution and cadence under measured pressure. A
nuke retains at most eight bursts, with at most one screen exposure per 0.9
seconds. The surface stays hidden and requests no drawable or flash mask when idle,
and clears on menus, backgrounding and rewind. It cannot receive touch input.

Modern selection retains the last actor for a 0.35-second smooth fade after
selection ends. The retained ID follows the current pose and camera. New
selection restores full opacity. Rewind and new runs clear the fade. Bitmap and
CRT output fade the outline and halo together. The fade uses the existing frame
clock; selection has no extra HDR surface or timer. The iOS CRT path updates its
selection without uploading the unchanged playfield image.

Mac Classic, Lemmings 2 and Lemmings 3 use the same fade. The shared iOS playfield
supports speed light for each engine. Classic supplies explosion and sprite-mask
data. L2/L3 mobile adapters still lack native sprite renderers, explosion metadata
and masks, so their mobile pop and outline output remains deferred with those
renderers. Their Mac effects remain supported.

The Mac and arm64 iOS UI targets compile. Offscreen, muted Metal checks cover
FP16 pop and speed brightness, SDR fallback, expiry, bounded nuke bursts, clear
controls, selection timing and bitmap/Metal fade pixels. Physical iOS EDR output,
sustained frame timing, touch pass-through and thermal transitions need device
validation. These checks do not claim measured performance on older hardware.

## iOS loading and audio, 13 October 2026

The mobile preview worker retains up to three prepared sessions and 12 MiB of
preview pixels. Play consumes the selected session once. Retry creates a fresh
session. The worker applies artwork settings and restores saved payloads before
transferring ownership to the UI. Saved journeys check their level identity from
catalogue metadata without building a simulation. Memory warnings release the
preview cache. Immutable bundled Macintosh and Amiga artwork banks share a bounded
NSCache. Imported artwork keeps its existing reload behaviour.

The shared MOD player synthesises on a serial worker into four reusable stereo
PCM buffers of 1,024 frames. AVAudioPlayerNode consumes them. Tracker synthesis,
its control lock, loop reconstruction and crossfade allocation no longer run in
the audio render callback. The queue holds about 93 ms of audio at 44.1 kHz.
The source and beat clocks compensate for queued samples. The output mixer mutes
queued samples and effect tails immediately. Music style, pitch, stereo treatment,
spatial effects and rescue polyphony retain their existing behaviour.

Silent spatial voices zero their output directly. Effect history clears once per
render block and accumulates active voices without repeated silent-source work.
Unchanged camera geometry skips spatial mixer updates. UIKit reuses skill images
and skips camera layout work when its size is unchanged. Camera movement redraws
the retained playfield instead of composing the same world frame again.

`Scripts/run-audio-performance-tests.sh` uses the muted, offscreen runner and
offline audio rendering. Checks cover queued playback while the synthesis lock is
held, refill, short module loops, crossfades, clocks, mute, restart, spatial output,
rewind history, the bounded rescue chorus, DJ style and recording pitch/tempo.
Apple audio units need access outside the filesystem sandbox on this host. The
first sandboxed run could not initialise them and is not counted as a pass.
The local Apple silicon debug measurement for one idle 64-voice, 1,024-frame block
was about 0.13 ms. This is a host CPU measurement, not iPhone frame timing.

Twenty-one focused mobile tests cover layout, input, camera and preparation
ownership. The bitmap audit checks portrait and landscape input geometry,
including all skills after scrolling. The iOS device target compiles. Physical
iPhone 17 Pro crackle, route changes, sustained frame timing, load durations and
touch delivery still need installed-device validation. The audio-session category
and buffer preference remain unchanged. L2/L3 use shared audio and controls,
but playable mobile libraries and native sprite renderers remain deferred.

## Validation

`Scripts/run-mac-performance-tests.sh` builds for the current Mac architecture
and runs through the offscreen, muted UI runner. It compares the real Classic
playfield's scene pixels with uncached reference renders throughout digging,
construction, explosions, rewind, nuke undo and restoration. It checks session
and artwork replacement and verifies that unchanged terrain is built once.

The local Apple silicon debug scene benchmark, using 64 renders per case,
measured the following. These are scene composition times, not full-frame rates
or measurements of older Mac hardware.

| Artwork | Uncached | Cached |
| --- | ---: | ---: |
| DOS | 24.0 ms | 0.29 ms |
| Macintosh | 21.5 ms | 0.96 ms |
| Amiga | 21.5 ms | 1.23 ms |

Eight focused store tests pass. They cover captured Classic and sequel hashes
while live state advances, execution off the main thread, busy-writer admission,
ordered session saves, failed-hash retry, cleared runs and saved-format round
trips. The Mac app and iOS UI target compile. The checks use no audible output or
foreground windows. Sustained older-Mac frame timing and audible playback remain manual validation
gaps. The Mac CRT GPU checks are described below.

## Mac adaptive effects and resource reuse

Classic, NeoLemmix, Lemmings 2 and Lemmings 3 use the shared presentation budget.
Device capabilities set the starting quality and overlay pixel budget. Measured
CPU and GPU pressure adjust independent budgets. Older Metal devices can recover
to full quality when measurements permit it. No Metal limits the software path
to minimal quality. Low Power Mode and fair thermal pressure cap quality at
balanced; serious or critical thermal pressure cap it at minimal. Low Power Mode
also limits decorative effects to 30 Hz. These restrictions apply while paused.

A half-second moving average ignores brief spikes. At a 60 Hz target, sustained
cost above 13 ms lowers a tier after two seconds, with at least three seconds
between reductions. Cost below 7 ms must persist for twelve seconds before one
tier returns. Thresholds follow the presentation interval. Sleep and backwards
clock jumps reset the observation window. CPU pressure limits trail count and
length; GPU pressure limits bloom resolution, effect-surface resolution and
simultaneous decorative bursts. Effect cadence follows the lower budget.
Memory-derived pixel limits bound large overlay surfaces. Existing HD effects,
Reduce Motion and Reduce Flashes preferences still control which effects run.

The sharp scene, physical selection outline, simulation clock and replay clocks
retain their existing resolution and timing. The policy does not increase effect
brightness. Rescue feedback now uses only the faint rim described below. When reducing nuke
bursts, both Metal and software output retain the bounded exposure burst.

The CRT view retains three source/flash texture slots and their CPU drawing
contexts. A submitted slot is immutable until its GPU command completes. At a
stable size, source images upload only when their content changes. Selection
fades reuse the composed source and cached halation. Flash-only updates retain
scene pixels; expired flashes clear their masks. Disabled bloom runs no bright
or blur passes and needs no scratch allocation. A resize or changed bloom budget
rebuilds scratch textures. Failed GPU commands invalidate the affected caches.
Menus retain their normal redraws; gameplay composition revisions include scene,
viewport, turn badge, status and control changes.

Replay capture retains at most two ordinary bitmap contexts, with no more than
8 MiB of pixel storage per context. Larger exports use transient contexts. Each
capture clears the previous pixels and restores graphics state. Core Graphics
snapshots remain immutable while the encoder retains earlier frames. Capture
profiles report composition and submission cost; encoder profiles separately
report queue admission, encoding, writer wait, frame counts and peak outstanding
frames. The existing twelve-frame admission bound and failure-on-stall behaviour
remain in place. Capture never skips a game tick to gain speed.

The local Apple silicon debug checks passed offscreen and muted. Shipping Metal
passes were exercised without a window or drawable. Checks cover all three
texture slots, cached-versus-fresh fade pixels, identical sharp image and
selection output across quality tiers, zero bloom, HDR flash expiry and CRT input
projection. The existing HDR checks cover Retina outlines, clipping, golden
light, SDR/HDR output and idle cleanup. Preview images were inspected.

The real playfield component of 1280×720 movie composition measured 1.55–1.67 ms
per frame across DOS, Macintosh and Amiga artwork. A separate cold 640×400 encoder
burst measured 11.66 ms per frame, including startup, and 9.97 ms per frame waiting
for queue admission. Writer readiness wait was 0.002 ms per frame. That burst
reached the twelve-frame queue limit and retained all 51 frames. These debug
measurements identify separate costs; they do not establish sustained playback
or fast-forward rates. Movie checks also retain exact 17 Hz Classic, 17.5 Hz L2
and 23 Hz L3 clocks, directional ghosts, encoded audio and 0.25×–8× review controls.
No test audio was played.

The Mac app builds. Physical older-Mac performance, sustained load, live thermal
transitions and physical HDR brightness still need manual validation before a
public release. This work does not run the public release audit or publish a
version.

## Rescue feedback, 14 October 2026

Jubilant music now takes priority as soon as the rescue target is secured,
including 100% rescue levels. The shared DJ player begins its 2.6-second fade
immediately. It does not wait for the opening hold or bar alignment. Paused
output defers the cue, and the alternate-soundtrack preference still applies.

Classic, Lemmings 2 and Lemmings 3 no longer blur scenery or build golden sprite
masks for rescue feedback. Their Mac and iOS playfields draw only one faint
single-pixel rim at 10% opacity. TV retains no completion glow. The shared state
uses the existing game clock, has no timer, and requests a redraw only on entry,
reset or brief expiry. Mobile updates its decoration only, without rebuilding
or uploading the CRT source for the rescue cue. All-rescued cues expire after
1.5 seconds. Game rules, selection, assignment feedback and input targets retain
their existing behaviour.

Focused core checks cover one-shot music cues, 100% rescue, perimeter-only pixel
changes, brief expiry, rewind reset and 1,000 repeated updates without redraws.
Offscreen, muted Classic/L2/L3 canvas checks pass with less than 1% changed
pixels and no crowd auras. The local debug bitmap-capture averages were
0.60/0.61 ms for Classic, 3.74/3.17 ms for L2 and 4.55/4.49 ms for L3
(inactive/secured, 32 captures per state). These are host CPU checks, not full
frame rates. Muted playback checks pass for immediate rescue crossfades, paused
output, cue reset, repeated results and all three engines' music selection and
handover. Sequel fixture comparisons resolve symlinked app resources before
comparing selected files. Mac, iOS and tvOS source compilation passes. Native
canvas and muted playback checks are recorded in the local
`.build/rescue-feedback` logs. Physical sustained frame timing and audible
musical judgement remain separate device validation.

## Device effect limits, 14 October 2026

Classic, Lemmings 2 and Lemmings 3 share a memory-aware effects policy on Mac,
iOS and tvOS. GPU support and measured CPU/GPU cost still apply. Physical RAM
now sets a ceiling that fast frame samples cannot exceed.

| Physical RAM | Maximum FX quality | Overlay pixels | Spatial sources | Rescue playheads |
| --- | --- | ---: | ---: | ---: |
| Up to 2 GiB | Minimal | 262,144 | 8 | 4 |
| Over 2, up to 4 GiB | Balanced | 720,000 | 12 | 8 |
| Over 4, up to 8 GiB | Full | 2,097,152 | 24 | 24 |
| Over 8 GiB | Full | 8,388,608 | 32 | 64 |

These are ceilings, not allocation targets. The GPU working-set budget can lower
the pixel limit. Two-core devices admit at most eight spatial sources and four
rescue playheads. Mobile retains its smaller existing rescue limits. Extra HDR
speed and cinematic explosion surfaces are disabled on devices with at most
4 GiB RAM. TV retains its existing limit of no extra HDR surface.

One shared process monitor responds to memory warnings, thermal state and Low
Power Mode. A memory warning holds the smaller budget for 60 seconds. It disables
optional HDR/bloom and admits at most six spatial sources and two rescue
playheads. Critical thermal state uses the same audio limits. Combined pressure
always takes the strictest limit. Sustained CPU cost also reduces audio
admission. FX recovery still requires measured spare capacity.

Audio sources remain attached during gameplay. Pressure trims active voices and
extra rescue layers without rebuilding the graph or changing saved settings.
Actions and warnings take priority over decorative sounds. Replay players inherit
the same device policy. This replaces the previous unbounded Mac rescue overflow.
Music and game-event clocks retain their existing timing.

Minimal FX quality releases bloom scratch textures and skips the bright/blur
passes. Bloom and flash masks stay within pixel budgets. Idle mobile HDR views
release drawables, and memory warnings remove their optional surface. Mobile
admits one HDR submission at a time; Mac admits at most two. A busy effect surface
skips a decorative update instead of adding work to the GPU queue. The mobile CRT
surface stays at one pixel per point when enhanced effects are unavailable.
Native HUD and menu lettering retain their scale. Selection and input mapping
remain independent of bloom.

Headless policy checks cover 2/4/8/16 GiB profiles, two-core limits, every combined
thermal/power/memory state and delayed FX recovery. Muted offline mixer checks
cover thousands of overlapping requests, finite voice/layer bounds, pressure
trimming, protected warnings, rewind, replay budgets and rescue cleanup. Native
Mac Metal checks verify bloom release/recreation, scene and selection pixels,
and unchanged input targets. The quality-tier renders were inspected. The
current-architecture Mac app and unsigned arm64 iOS/tvOS apps build successfully.
Local evidence is in `.build/device-effects-policy.log`,
`.build/device-effects-audio-final.log`, `.build/device-effects-mac-final.log`,
`.build/device-effects-mac-build-final.log`, `.build/device-effects-ios-final.log`
and `.build/device-effects-tv-final.log`. No visible test windows or audio were
used.

These checks establish policy and rendering behaviour. They do not establish
the reported iPad bottleneck or guarantee a frame rate on physical devices.
Sustained iPad/Mac/TV frame timing, real memory warnings and thermal transitions
still need device profiling. Native UIKit/Metal output on iPad and TV was not
run in a visible test window.

## Input, rewind and presentation follow-up — 29 October 2026

The current source removes the synchronous PCM-worker query from effects rewind.
The worker publishes a short, locked playback-position snapshot; readers project
it only as far as scheduled audio. Rewind copies bounded history under the effects
lock, then resamples, envelopes and normalises outside it. Silence and suspension
invalidate an in-flight scrub. This reduces refill contention; it is not proof of
crackle-free hardware playback. Audio queue sizes and user settings are unchanged.

L2/L3/Neo live history keeps recent snapshots densely and spreads older snapshots
across the existing entry budget. Input-prefix selection uses a binary search.
Action replay backward seeks first use native history, retaining exact same-tick
command ownership, and fall back to fresh reconstruction when needed. Replay move
navigation is cached and displayed skill history retains only three entries.

The mobile/TV HUD skips unchanged presentation updates and redraws the skill
canvas only when its visible state changes. Accessibility status computes the
selected actor's ordered rank in one pass without a temporary sorted array and
updates text only when its value changes. No input targets or assistive actions
were removed. L3 caches unchanged sparse terrain conversion; Neo caches native
terrain conversion independently of animated gadgets. Each new terrain-image
cache is limited to 4 MiB of RGBA pixels; huge imports keep fresh conversion.
Retained physics arrays can still add copy-on-write memory and the rewind byte
estimate remains an estimate rather than a measured memory ceiling.

Flat funeral presentation retains opaque scene composition, at native pixel
density with a 1,048,576-pixel ceiling, and uses nearest GPU scaling. Its temporary
surface is released on recovery. This avoids full display-resolution CPU scaling
without adding a Metal/HDR effect pass. CRT still prepares its native viewport on
the CPU. Whole-level actor composition, movie image composition and expensive
seeks beyond retained checkpoints remain architectural optimisation opportunities;
the continuation below supersedes those initial source gaps for mobile/TV.

Validation: 20 focused mobile terrain/rewind/parity checks passed. Additional
regressions cover prepared Neo terrain versus fresh PC/Mac scene pixels through
removal/construction/rewind, actor writes against cached L3 terrain, cached seeks
versus independent reconstruction and live rewind checkpoint equivalence. Muted,
offscreen funeral composition checks pass; headless Metal was unavailable. Audio,
spatial and DJ performance programs compile, but runtime audio-unit creation failed
in this environment, so mixed playback and audible acceptance remain open. The
broader mobile-core run reported existing layout assertions outside this change
and was interrupted after the focused checks were isolated. Final iOS/tvOS SDK
source checks are recorded separately in the platform parity register.

No sustained 10×, frame-time, tap-latency, thermal, actual peak-memory or crackling
claim is established. Device profiling with simultaneous production music and
crowded gameplay remains required on the reported iPad 8, Duo and Apple TV.

The shared mobile controller emits Instruments Points of Interest intervals for
input polling, simulation batches, scene presentation, and HUD/music work. They
provide phase attribution on installed iOS/tvOS builds without per-frame strings,
retained frame logs or render-callback logging. Existing audio reserve/refill
statistics remain separate from device underrun evidence.

## Viewport, input and PCM continuation — 29 October 2026

The shared mobile/TV controller separates its input clock (up to 60 Hz) from its
adaptive scene clock (including 30/20 Hz). Controller requests coalesce. Pointer,
touch preview, skill selection and TV target cycling reuse the rendered scene
when its tick and camera coverage are unchanged. Gameplay commands still update
the engine before presenting feedback. Reusing a frame does not change hit
targets, pause ownership, Hot Seat readiness or replay command order.

Classic, L2, L3 and supported NeoLemmix mobile rendering now scopes composition
to a tile-aligned viewport with a 32-pixel guard band. Native and Macintosh
artwork retain their source resolution and nearest scaling. Terrain-only minimap
thumbnails refresh separately from actor points. Full-level terrain conversion,
source artwork and some actor traversal remain; this is not a fully incremental
GPU terrain renderer. L2 updates changed palette pixels in its retained RGBA
terrain; palette changes rebuild it and rewind detects earlier terrain content.
The pixel comparison still scans indexed terrain. Classic reduced-colour
conversion uses a 256-entry lookup over the composed viewport.

CRT preparation retains a camera-scene image independently of cursor, marker,
assignment and trail overlays. Overlay changes copy that image rather than
rescaling the terrain again. Reusable bitmap contexts retain their allocation.
Explosion expiry and transient-effect reset invalidate the overlay signature.
Menu previews and the touch loupe account for the viewport origin, including
countdown anchors. Mac rendering and movie composition retain their existing
paths; no full-scene Mac rendering replacement is claimed.

Production effects PCM runs without the control/library lock. The serial worker
owns its voices and reserved rescue-layer arrays; each voice has one bounded
pending command and fixed-size progress storage. Status transfers happen under a
separate handoff lock. Mutable-array reconciliation and destruction of replaced
commands run outside it. Completed rescue layers cannot reappear when a later
camera/gain update arrives. The worker still reconciles layers between blocks,
and rewind copies at most one second of history under its separate history lock.
This is reduced contention, not a lock-free mixer or proof of the crackling cause.

All shared mobile/TV rewind entry points, backward steps and replay navigation
use cancellable seek operations, targeting 2 ms of reconstruction per slice.
The controller yields to the run loop between slices. Live state remains intact
until the exact result commits; cancellation drops the private reconstruction.
Releasing held rewind now stops new distance requests and lets accepted work finish
(see the stacked-rewind follow-up below).
Commands at the target tick keep their order, and assistance counts update only
at commit. A single tick, initial factory/checkpoint preparation and commit can
still exceed the slice target. Sparse checkpoints accelerate history without
discarding its recorded commands. Custom Classic rolling-history configurations
retain their original oldest-frame eviction contract.

Shared cache leases bound admitted optional terrain RGBA across engines. History
density uses a separate estimated-byte allowance, reduced by available memory
and pressure. Pressure originates in the shared effects monitor, including on
Mac. Once per second of mobile/TV presentation, Points of Interest report actual
process footprint, sampled peak and leased cache bytes. Sampled peak can miss
short spikes; neither it nor cache leases bound all process memory. Current
frames, immutable artwork, GPU surfaces and copy-on-write snapshots remain
outside that accounting. Physical peak-memory profiling is still required.

Validation is headless and muted. The focused core run passes 22 tests covering
native/Macintosh viewport pixels and fractional camera placement, cached terrain
versus fresh conversion, cancelled seeks, same-tick Classic live/replay commands,
L2/L3 seek state and assistance counts, Neo sparse history and scoped raster
requests. Eleven scene/arrow/liquid checks and the Classic DOS rewind program
also pass. A separate production NeoLemmix actor/terrain viewport check passes
without changing simulation state. A separate PCM bridge check passes completed-rescue cleanup, pending
replacement protection, camera/gain updates, 10,000 coalesced commands and silence.
The current-architecture Mac development build passes. Platform SDK and audio
compilation receipts are retained in `.build/resume-*-sdk.log` and
`.build/resume-audio-compile.log`; final controller source checks are in
`.build/resume-ui-final/`. The mixed offline audio run aborts while creating a
Core Audio EQ unit (`comp != nullptr`), before exercising the mixer. Bridge
checks do not close that environment gap. These are local verification, not release
packages. Full release audits, universal packaging, signing and notarisation were
not requested. No foreground windows, production saves or audible tests were used.

Sustained 10×, physical tap latency, thermal frame delivery and crackle-free mixed
playback remain unverified on iPad 8, Duo and Apple TV. Existing TV effects limits
and native artwork remain intact. This work does not close the audio release gate.

## Viewport, input and audio worker optimisation — 29 October 2026

This follow-up supersedes the architectural limits recorded in the earlier
29 October entry for the shared UIKit playfield. Classic, L2, L3 and supported
NeoLemmix now rasterise the visible level rectangle with a tile-aligned guard
band. Objects, actors, ghosts and crowd shadows retain world coordinates and
clip into the smaller destination. Native and reconstructed Macintosh pixels
keep their original resolution. Full-scene rendering remains available to
previews, exports and other callers. The minimap retains a bounded thumbnail:
scenery refreshes at most four times per second, while live lemming positions
follow presented game ticks without assignment probes or sprite decoding.

Pointer and selection updates reuse the existing scene whenever its tick and
covered viewport remain valid. Authored target marks now draw in the overlay;
their states, colours and native pixel sizes remain engine-specific. The display
link requests up to 60 Hz for controller polling and held-touch recognition even
when scene presentation adapts to 30 or 20 Hz. OS limits still determine actual
callback delivery, and a synchronous engine tick can still delay the main thread.
Touch loupe countdowns and pause previews translate cropped image coordinates
back to the same level and input coordinates. No input targets were removed.

CRT presentation caches its native scene separately from cursor and assignment
composition. An unchanged presentation reuses the uploaded source and bloom.
Scene or camera changes rebuild the native base; cursor changes reuse that base.
Trail reset and flash expiry invalidate the composite. The additional CPU surface
is released under memory pressure. This does not claim that every CRT overlay is
a separate GPU layer. TV retains its existing effects and HDR exclusions.

Effects PCM generation owns its running voice playheads and preallocated rescue
layer storage. Controls prepare bounded, replaceable commands per spatial source.
A separate mailbox transfers commands and scalar progress; decoding, admission,
mutable-array cleanup and retired sample destruction stay outside its lock. PCM
never takes the effects control/library lock. Completed rescue layers cannot be
reintroduced by an older camera update. Rewind history still uses a separate
bounded-copy lock, and device callbacks still consume queued PCM. This removes
one contention path; it is not a hardware crackling diagnosis or acceptance result.

Mobile/TV rewind, backward stepping, replay move navigation and replay restart use
private reconstruction cursors with a cooperative two-millisecond slice and a
run-loop yield between slices. Only a completed exact state is committed. Input,
Resume, navigation, interruption and memory pressure cancel obsolete work; additional
rewind/backward-step inputs accumulate instead. Same-tick
commands and assistance counts survive reconstruction. One engine tick, initial
cursor preparation or final replay verification may exceed the slice budget.
Native Mac callers retain their synchronous seek APIs.

Terrain and reconstructed sequel-art caches share process-wide pixel admission.
RAM and available process memory set the ceiling; memory pressure disables optional
pixel retention. Rewind acceleration accounts for mutable terrain masks, actor
storage and relevant runtime collections rather than level area alone. Sparse
sequel caches may be removed entirely while the authoritative input history remains.
Default Classic history retains its oldest reconstruction anchor while thinning
intermediate states; explicitly configured bounded histories retain their existing
reach contract. These are conservative storage estimates, not an RSS guarantee.
A sampled process footprint, sampled peak and retained cache byte count are exposed
in Instruments once per second. L2 palette conversion and L3 sparse edits update
changed pixels; Classic reduced-colour conversion uses an equivalent 256-entry
lookup table. Large uncached terrain conversion and full minimap scenery work
remain possible costs.

Validation: 33 focused tests pass across six suites, covering native/Mac viewport
pixel equivalence, Neo layers, Mac arrow bevels, liquid masking, fractional camera
placement, cached CRT base copying, rewind cancellation and same-tick commands.
The standalone Classic rewind suite passes against original DOS data, including
bounded history, reopen and replay verification. The muted offscreen worker check
passes 10,000 pending updates, playhead preservation, completed rescue cleanup and
silence. Representative Classic and L3 native-art captures were inspected.

The full audio program compiles, but its offline run cannot create the required
`AVAudioUnitEQ` in this environment (`comp != nullptr`). Mixed audio, actual refill
continuity and audible acceptance remain unverified. No audible or foreground test
was run. Physical iPad 8, Duo and Apple TV testing must still establish sustained
frame timing, input latency, achieved fast-forward speed, memory and thermal
behaviour. No percentage improvement or crackle-free playback is claimed.

The final iOS and tvOS SDK module builds pass from a frozen source snapshot;
additional primary-file checks pass for the final controller release-cancellation
change on both SDKs. Evidence is in `.build/runtime-sdk-final.log`,
`.build/runtime-sdk-ios-controller-final.log`,
`.build/runtime-sdk-tvos-controller-final.log`, `.build/runtime-final-tests.log`,
`.build/runtime-classic-tests/run.log` and `.build/runtime-worker-tests/run.log`.
The failed full audio execution is retained in `.build/runtime-audio-final/run.log`.
These checks do not constitute an installed app, App Store or physical-device run.


## Stacked mobile and TV rewind — 29 October 2026

The TV controller previously emitted only the initial held-rewind request: the
repeat callback belonged to the touch HUD. The shared game frame loop now drives
held rewind too, with a common 80 ms repeat gate so touch and frame callbacks do
not double the rate. TV starts repeating after its existing trigger hold threshold;
touch keeps its initial 350 ms repeat delay. The existing 0.4 / 0.8 / 1.6-second
rewind distances accelerate after one and two seconds of holding.

`MobileRewindQueue` bases subsequent requests on the requested destination rather
than the still-displayed tick. One private seek finishes while additional rewind
presses or backward steps accumulate into one next destination. Repeated inputs
no longer cancel reconstruction or discard distance while it is busy. A quick L2
tap retains one-frame precision; held L2 repeats continuously. Rapid L2 taps
within 650 ms grow from one frame to 0.4, 0.8, 1.6 and 3.2 seconds per tap.
Discrete Rewind grows from 2 to 4, 8 and 16 seconds per press. Both cap their
per-press distance, stack against the requested destination and retain their burst
across completed seeks. A longer gap, Resume, other cancelling input or starting
held rewind resets the burst. Dedicated backward-step controls stay precise. Accepted movement
finishes after release and leaves gameplay paused. Resume, edits, menus, navigation,
interruption and memory pressure still cancel pending work. Assistance counts
commit with each accepted batch, and checkpoint requests wait for the queue to
finish after release.

The production shared frontend covers Classic, Lemmings 2, Lemmings 3, supported
NeoLemmix and their replay sessions on iPhone, iPad, Duo and TV. Mac retains its
existing synchronous transport. No artwork, input bounds or TV effect surfaces
change. Physical TV timing and audible rewind continuity remain acceptance checks.

Validation: 30 focused, muted checks pass, covering queue accumulation and
cancellation, exact state hashes and counts in all four live engines, existing
Classic/replay rewind regressions, held-rewind timing and TV trigger transport.
iOS and tvOS SDK modules and application entry points compile; the final shared
frontend was recompiled for both SDKs after the last input-cancellation fix.
An empty touch-router cancellation no longer cancels an active rewind.
The broader portrait-HUD run reports 20 assertions in two unrelated layout tests
(`twoRowsKeepHeightAndMapAcrossEngines` and `originalIPadProUsesMacPanelInLandscape`);
no layout source was changed by this rewind fix. Device input feel, rendered
transport feedback and audible continuity remain unverified. No release or local
app package was produced; broad release audits were skipped.

Rapid-press follow-up validation: 34 focused muted checks pass. These add burst
acceleration after completed seeks, increased TV trigger-tap distances, inactivity
and cancellation resets, and accelerated accumulation during reconstruction at
17/20/30 ticks per second. Updated core and frontend SDK modules compile for iOS
and tvOS. Physical TV feel and audible continuity remain acceptance checks.


## Rewind helper source integration — 30 October 2026

`MobileRewindQueue` and `MobileRewindPressAcceleration` now live beside the
existing touch/hold timing code in `MobileHUDPress.swift`. Their declarations and
behaviour are unchanged. This avoids depending on Xcode discovering newly added
source files in an already loaded local package. A retained Apple TV source list
included `MobileHUDPress.swift` but neither standalone rewind helper.

All six queue/press-acceleration checks pass. iOS and tvOS core/frontend SDK module
compilation passes without the standalone helper sources. Full Xcode project
verification did not complete: the first attempt hit a protected SwiftPM cache;
a retry with project-local caches omitted the local package and reported missing
`LemmingsTVUI`. These attempts do not establish a successful app package build.
