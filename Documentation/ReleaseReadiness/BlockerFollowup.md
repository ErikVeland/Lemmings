# Mac release blocker follow-up

This work improves the existing Mac candidate. It does not establish 1.0 readiness.

## Implemented

- Classic campaigns save a versioned run checkpoint every five seconds and on pause, interruption, level changes and quit. Resume Saved Run rebuilds the recorded inputs, checks the engine, level and state hashes, and restores the game paused. It preserves run identity, future inputs after rewind, assistance counters and camera position without counting another attempt.
- Checkpoint files use checksums, atomic replacement, a backup, a serial writer and stale-writer rejection. Unsupported files remain intact. Completing a run clears both checkpoint copies.
- Controller buttons can be remapped in Settings. Changing a binding swaps the displaced action, preserves access to every action and persists the choice. Menu controls remain standard. Changed bindings and interrupted input cannot leave a held speed boost active.
- Controller help uses names and symbols supplied by the connected device. Physical device verification remains separate.
- The direct-download packaging script disables App Store Game Center capabilities before Developer ID signing. Provisioned App Store builds remain a separate path.

See [save recovery](../SaveRecovery.md), [controller controls](../ControllerQoL.md) and [Game Center setup](../GameCenterSetup.md) for details.

## Performance evidence

The optimized local test used an M4 Pro Mac mini with 24 GB RAM, a 1280 × 720 app window, replay recording, enabled visual effects and synchronous Metal completion. Audio was silent. Samples lasted at most 20 seconds and included a nuke.

| Display | Requested speed | Measured speed | Frame p50 | Frame p95 | Peak resident memory |
| --- | ---: | ---: | ---: | ---: | ---: |
| Flat | 1× | 1.00× | 1.71 ms | 11.33 ms | 282 MiB |
| Flat | 10× | 7.83× | 18.58 ms | 30.59 ms | 305 MiB |
| Monitor | 10× | 7.22× | 20.83 ms | 26.94 ms | 320 MiB |
| Television | 10× | 6.94× | 22.46 ms | 27.66 ms | 253 MiB |

These results expose a remaining speed limit with replay capture enabled. They do not pass the sustained 10×, audio, thermal, memory-growth or hardware gates. The 1× sample also contains a 146 ms maximum frame. Full measurements are in `.build/blocker-closure/performance.json`. The earlier `performance-debug.json` used an unoptimized build; `performance-invalid-fixture.json` did not exercise gameplay. Neither is release performance evidence.

## Remaining work

The [gate register](gates.json) remains authoritative. Remaining internal work includes classic fan-import and L2 practice checkpoints, 214 missing core campaign winning routes plus conversions, sequel fidelity and media, scalable text, broader VoiceOver navigation and localisation. The local guided route discovery found no additional winning routes; it does not prove those levels are broken.

External evidence is still needed for physical controllers, Intel and minimum-version Macs, sustained display/audio trials, novice playtests, provisioned Game Center accounts and rights-holder approval. iPhone, iPad and console delivery are separate projects.

Do not rename this candidate to 1.0 or mark these gates closed based on the changes above.

## Regression checks

The optimized full Mac integration suite passed when run without another UI test app. It covers all original hint tiers, help-to-hints resume, remapping, exact checkpoint continuation and rejection of invalid checkpoint versions, ticks, skills, counters and hashes. The rejected restore must leave the live simulation unchanged.

The sequel suite passed, including 59,542 artwork frames, 214 levels and live L2/L3 UI, input, media and result checks. Save-file recovery and migration, settings persistence, controller binding tests, capability signing validation and the audit's own integrity tests also passed.

Logs are under `.build/blocker-closure`: `full-app-isolated.log`, `sequels.log`, `save-files.log`, `settings.log`, `controller-unit.log`, `signing-tests.log` and `audit-tests.log`. `full-app.log` records a help-to-hints pause assertion during overlapping UI test runs. The same executable passed in isolation. UI suites should run sequentially so they do not compete for key-window ownership.

## Candidate status

The earlier packaging attempt was stopped before signing because source inputs changed during the build. The concurrent task **Refine CRT shaders and text** was editing the shared rendering and panel code. That attempt produced no signed or notarised archive. `.build/blocker-closure/package-aborted.json` records the input drift. The earlier passing UI and performance results describe the source before those rendering changes; they must not be presented as validation of the final combined candidate.

The standalone playfield draw script now includes its recovery, controller pointer and focus-highlight dependencies. A fresh candidate needs a new source manifest, sequential UI regression runs and the complete signing/notarisation check after the rendering work settles.

The repaired standalone playfield suite passed (`.build/blocker-closure/playfield.log`), including draw order, speed trails, PC/Mac explosions, nuke/undo gestures, panel counts at multiple sizes, camera and menus. This does not replace the final combined app check.

## Further recovery and rendering repairs

The next pass added disk recovery for NeoLemmix files and native L2/L3 campaigns. Each path validates original inputs and replayed state, resumes paused and keeps the same arcade attempt. Tests include successful actions, queued input, nuke undo where supported, exact continuation and rejected journals. NeoLemmix file opening also now switches into gameplay correctly. Checkpoint loading has a 64 MiB limit and can find a valid run alongside an unrelated corrupt file.

Replay audio now writes directly into its output channels, skips per-sample mixing for silent stretches and evaluates crossfade trigonometry only during a fade. Bitmap game-font lines have a bounded cache; pixel comparisons pass against the original glyph renderer. Invisible Mac sprites and unchanged trail updates avoid repeated work. Playfield terrain and sprites now draw cached image pixels directly; the playfield regression suite passes. No replay frames are dropped. The direct-drawing timing sample overlapped compilation, so it does not establish a performance gain.

Passing evidence under `.build/blocker-next` includes `replay.log` (video/audio timing and frame counts), `final-app.log` (complete optimized app suite), `sequel-final.log` (L2/L3 file recovery and native UI checks), and `playfield-final.log` (draw order, trails, explosions, camera and controls). The sequel artwork suite also checked 59,542 frames across 214 levels. These results are local regression evidence, not hardware certification.

Performance instrumentation found negligible encoder backpressure. Replay drawing on the main thread remains the main measured cost. Short 10× trials still run below the requested rate. Raising the per-frame simulation budget made frame latency worse and was not retained. The sustained performance gate remains open.

The source snapshots and logs are retained in `.build/blocker-next`. The latest combined full app suite (`combined-app.log`), sequel UI and disk recovery suite (`combined-sequel.log`), and direct-image playfield suite (`playfield-cg-actual.log`) all pass against `final-source`. `results.json` records their log hashes. No 1.0 version or release claim is made by this pass.

### Repeat rendering measurement

A repeat of the direct-image renderer test without concurrent Swift compilation measured the following. Asset indexing and packaging were still running, so this was not an idle-machine certification. Audio remained silent and samples were short.

| Display | Requested speed | Measured speed | Frame p95 | Peak resident memory |
| --- | ---: | ---: | ---: | ---: |
| Flat | 1× | 1.00× | 14.10 ms | 341 MiB |
| Flat | 10× | 8.68× | 31.83 ms | 310 MiB |
| Monitor | 10× | 6.83× | 51.79 ms | 288 MiB |
| Television | 10× | 7.74× | 29.21 ms | 290 MiB |

See `.build/blocker-next/performance-cg-repeat.json`. These results do not establish a sustained 10× pass or a controlled before/after performance gain. The performance executable uses the retained performance snapshot, not the later combined recovery build.

### Checked frozen package

The frozen snapshot produced `.build/blocker-next/package/UltimateLemmings-0.1-beta12.zip`. Both the app and core library contain arm64 and x86_64 slices targeting macOS 13. Developer ID signing, strict signature verification, Apple notarization, stapling and Gatekeeper verification of a freshly extracted quarantined zip all passed. Game Center is disabled and no App Store provisioning profile is embedded.

Apple accepted submission `b776d9d2-fb9e-4559-b726-47ad0c454f3a`. `.build/blocker-next/results.json` records the archive SHA-256, logs and source manifest. The frozen inputs had zero drift after packaging. The shared workspace received a later `Sources/LemmingsLocal/ArcadeWindow.swift` edit from the concurrent task; that edit is outside this tested package.

This is a checked beta snapshot, not a 1.0 release. The final release must be rebuilt and verified after the remaining gates and later code changes are resolved.
