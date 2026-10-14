# Ultimate Lemmings 1.9.6 — Shared fixes for Mac, iPhone and iPad

Build: 81
Release base: v1.9.4

This release brings the current shared engine, artwork, saves and audio fixes to macOS. The companion iPhone and iPad beta is version 2.0, build 13, and uses the same release source.

## All platforms

- Bombs scatter crisp pixel debris and show bitmap countdown digits. Explosion artwork ends after its brief animation.
- Selection uses a steady white outline and green halo. Dying, exiting and exploding lemmings no longer retain selection or rescue outlines.
- Rewind scratches backwards through recent music and effects. Repeated requests reuse bounded audio buffers.
- Recorded music decodes in bounded queues. Short loops blend their seams, and peak protection follows the effects mix.
- Shared rendering budgets reduce added-effects work while simulation keeps its authored tick rate. Terrain and panel caches avoid unchanged bitmap conversions.
- Profiles, records, recovery, playlists and Hot Seat use shared modules. Saved runs and handovers stay paused until the player is ready.
- Golden Path moves “Let’s be careful out there” later in the journey. Saved journeys preserve visited levels and player ownership.

## macOS

The Mac build includes Classic, The Tribes, Chronicles and NeoLemmix. The Tribes remains Complete. Chronicles and NeoLemmix remain Beta.

Fresh starts and retries have a short 3–2–1 countdown. Rewinds add brief sprite echoes when modern effects are enabled. Profiles and result pages keep the primary action last in their navigation order.

The Cloud saves page supports linked private libraries and recovery keys. Local saves remain available. Chronicles retains 90 standalone winning routes out of 90. This does not establish a complete chained campaign or remove its Beta status.

The universal Mac app supports Apple silicon and Intel on macOS 12.3 or later. The slim download includes essential music and offers optional soundtrack libraries. Automatic updates retain the full soundtrack.

## iPhone and iPad — 2.0 beta

The beta plays the Classic family, Holiday packs, Oh Yes! More Lemmings! and installed fan packs. It includes profiles, favourites, recent levels, playlists, journeys, records and Hot Seat.

Portrait and landscape controls use the shared stone artwork and bitmap symbols. Mouse, trackpad and Pencil targeting use level-space pick boxes. Camera movement refreshes targeting while paused. Hot Seat identifies the player through Ready, play, pause, results and handover. The player's portrait and green name sit above the HUD counters during play. Skip and restored runs preserve the saved turn. Collections places Resume beside Back as the primary action.

The pause screen shows the level preview, rescue target, remaining lemmings, skills, time and current music. Resume stays in a fixed position while the details scroll.

Pause on skill selection helps new players plan their first ten uses. The next Play action offers Keep pausing or Turn off and saves the choice. Settings can change it at any time.

Music, replay history, calmer rescue effects, recovery and saved-journey fixes follow the shared Mac source. The companion private beta includes all 495 soundtrack versions. Local builds now include them by default. Slim builds offer optional soundtrack libraries in Settings; downloads require the app to remain in the foreground.

The display adapts to sustained load and avoids repeated bitmap conversion. Gameplay keeps its authored tick rate. Sustained performance on older iPads remains a device acceptance check.

Lemmings 2, Lemmings 3 and NeoLemmix remain unavailable to play on iOS. Game Center runtime availability remains disabled until Apple-side configuration is verified. TestFlight delivery and Beta App Review are separate from public App Store publication.

## Validation scope

CI checks shared regressions, the universal Mac executable, iOS Debug and Release simulator builds, the unsigned Release device build, and iPhone/iPad layout and lifecycle contracts. Distribution tooling checks signatures, provisioning, content manifests and update metadata.

Local automated checks use offscreen windows and muted audio. Release evidence records each result against the frozen source. Physical input, audible listening, foreground shipping-app launch, HDR appearance, minimum-OS hardware and sustained device performance remain manual validation gaps.
