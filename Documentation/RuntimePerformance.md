# Runtime performance

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
cinematic explosions. Output is limited to 30 Hz and two pixels per point. A
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
rewind history, the 128-voice rescue chorus, DJ style and recording pitch/tempo.
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
foreground windows. Sustained older-Mac frame timing, audible playback and the
CRT GPU path remain manual validation gaps.
