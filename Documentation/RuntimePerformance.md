# Runtime performance

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
