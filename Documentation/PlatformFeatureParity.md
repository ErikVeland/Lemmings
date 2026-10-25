# Cross-platform feature parity

Source audit: 25 October 2026, Australia/Brisbane. This register describes the
working checkout. It does not establish availability in an installed release.

Applicable capabilities belong on Mac, iPhone, iPad, Duo and Apple TV. Input,
layout and file transfer may adapt to the device. An engine label, shared
protocol or visible settings choice does not prove that its implementation is
connected. Check the session, renderer, input route and persistence path.

iPhone, iPad and Duo use the same mobile frontend. The normal TV application
uses that frontend with remote/controller, focus and LAN-transfer adapters.
The older standalone TV development shell is not the production parity baseline.

## Confirmed source gaps

These rows have source evidence. They are not an exhaustive acceptance claim.
P1 affects gameplay, recovery or an established product capability. P2 covers
remaining presentation and optional-content parity.

| Priority | Capability | Mac | iPhone / iPad / Duo / TV | Source and required closure |
| --- | --- | --- | --- | --- |
| P1 | L2 machine, chain and held aiming input | Routes machine/chain interactions before ordinary skill assignment and records pointer inputs | Session records skills, nuke and fan only | `Lemmings2PlayWindow.assign`, `SequelMobileSessions.Lemmings2MobileSession.Input`. Add shared input adapters and retain commands through checkpoint, rewind and ghost playback. |
| P1 | Review and movie export for L2, L3 and supported NeoLemmix attempts | Captures and plays visual recordings for all engines | Only Classic implements `replayDocument` and `makeReplaySession`. Other sessions inherit nil defaults, so their result actions are absent | `MobileGameSession`, `ClassicMobileSession`, `MobileGameViewController.presentCompletion`, `MobileReplayExport`. Export also decodes a Classic replay directly. Add bounded recordings/playback, move history, cancellation and engine sound banks without changing progress or turns. |
| P1 | Saved action replay viewing beyond Classic | Shared action replay viewer supports the native engines and NeoLemmix | Record/online playback routes construct Classic sessions only | `MobileRecordsPages`, `MobileRankings`, `LeaderboardActionReplay`. Use the correct engine, validate inputs/outcomes and keep playback read-only. |
| P1 | L2 practice | Native practice menu and selectable practice skills | Native mobile library exposes campaign levels only | `Lemmings2PlayWindow` practice flow and `Lemmings2MobileLibrary`. Add an isolated practice route without granting campaign progress. |
| P2 | Sequel artwork switching | L2/L3 support reconstructed Macintosh artwork alongside original PC artwork | L2/L3 render native indexed artwork. Their settings do not replace terrain, actors or objects | `Lemmings2PlayWindow`, `Lemmings3PlayWindow`, native mobile scene renderers, `MobileGameInput.cycleGraphics`. Port matching artwork choices and preserve the run, camera and input geometry. NeoLemmix machine-art substitution is not an existing Mac capability. |
| P2 | Sprite speed afterimages and rewind echoes | Shared `SpeedTrails` draws native sprite echoes across engines | Mobile has other speed feedback and shared rewind audio, but no sprite-echo pass | `GameplayPresentation`, `MobilePlayfieldView`, `MobileHDRView`. Reuse bounded sprite masks, respect reduced effects and retain the explicit TV performance policy. |
| P2 | L2 short-game samplers | Catalogue can start carried L2 sequences | Mobile short games prepare and launch the Classic sequence only | `main.shortGameEntries`, `MobileLibraryShortGames`, `MobileShortPlayCatalogue`. Preserve L2 population carry-over and saved queue ownership. L3 carried samplers remain a shared limit. |
| P2 | Original sequel media | L3 pause menu includes the original FLIC movie gallery. Mac also has native sequel story/media routes | No matching mobile/TV movie gallery or story-media adapter | `Lemmings3PlayWindow.showOriginalMovies`, `OriginalMoviePlayer`, native mobile libraries. Keep media separate from run replays and keep covered gameplay paused. Automatic L3 story playback is also incomplete on Mac. |
| P2 | NeoLemmix extra-skill rewards and individual inspection | Extra skill grants exist. Individual naming has explicit engine limits | Mobile NeoLemmix inherits empty bonus-skill choices and nil inspection | `SequelMobileSessions.NeoLemmixMobileSession`, `MobileGameSession`, `ExtraSkillRewards`. Port valid charge grants and assistance markers. Preserve the explicit naming deferral for preplaced actors, clones and unlimited populations. |

## Corrections in this audit

- Native mobile L2/L3 libraries now supply the exact primary-sprite mask and
  position to the shared selection outline and assignment pulse.
  NeoLemmix uses the same feedback state and its resolved native sprite sheets.
  Animation time follows the simulation. Reduced motion/flashes retain their
  policies. Checkpoint restore and rewind clear stale assignment feedback.
- Mobile/TV NeoLemmix now uses the shared crowd-shadow pass. The preceding fix
  connected Classic, L2 and L3. Shadows darken rear sprite ink only.
- Mobile NeoLemmix now records exact shared action commands and accepts the
  same Hot Seat ghost archive as Mac. Absolute queued spawn-interval choices
  convert to the shared command format without losing multiple changes at one
  tick. Legacy checkpoints that retain only a mid-level state cannot create a
  complete ghost and remain explicitly unsupported for that recording.
- NeoLemmix draws earlier players with the shared native-sprite tint/cache and
  blending code, behind live actors. Ghosts add no input targets or sounds.
  Hiding them leaves their archive intact. Handovers retain the existing Ready
  boundary.

## Tester sync lifecycle — 26 October 2026

The shared `CloudLibrarySync` coordinator requests sync at startup. Both native
frontends request it on foreground activation. Mac termination now flushes local
saves and waits up to 20 seconds for a final pass. The production iPhone, iPad,
Duo and TV frontend requests UIKit background time and runs that same final pass
on background entry. It waits for active uploads and captures local progress
again, including changes made during upload. Legacy `test99` entry persists the
tester flag; existing tester credentials recover it during sync.

This applies to every player and saved Hot Seat across Classic, L2, L3 and
supported NeoLemmix completion records. Safe-menu import rules remain in place.
Mid-level checkpoints remain local on every platform. Force-quit, offline
providers and expired background time cannot guarantee completed uploads.
Physical-device lifecycle and live service acceptance remain open.

## Shared coverage and intentional adaptations

The source connects native campaign play, owner-scoped checkpoints, rewind and
single stepping, Retry/Continue, named Hot Seat choices and paused Ready
handovers across the three native games. Shared libraries also provide profiles,
collections, settings, hints/coaching, records and the main audio system.
Engine-specific controls remain explicit: L2 fan and L3 tool direction have their
own controls; L2/L3 expose no release-rate setting and L3 has no nuke.

Classic supports artwork switching, deterministic review, verified solution
viewing and the separate solution ghost on mobile and TV. Matching verified
solution viewers and checked hints for L2/L3 remain a shared engine/content gap,
not a complete Mac feature that mobile merely hides. The learning curriculum is
also Classic-only across platforms.

| Adaptation | Reason to preserve it |
| --- | --- |
| Sparkle on Mac; App Store/TestFlight on mobile and TV | Platform distribution model |
| Mac menu bar; touch pages and keyboard discovery; TV focus/remote controls | Native input and window model. Home/End/F1 are handled by the mobile hardware-keyboard adapter despite their omission from command discovery. |
| iOS share sheets; TV token-protected LAN transfer | TV has no equivalent document/share picker. Capability still needs physical transfer acceptance. |
| TV omits completion glow, extra cinematic/HDR surfaces and explosion cores | Explicit owner performance instruction. Keep selection and assignment feedback. |
| Manual familiar-name entry on TV | Native contact-picker difference. Do not silently request broader contact access. |
| Duo hinge-triggered clock versus ordinary clock routes elsewhere | Device-specific hardware trigger. The shared clock remains available through platform-appropriate entry points. |

## Validation and remaining acceptance

Run `Scripts/run-platform-parity-tests.sh` with the default muted, offscreen
runner. It supplies the packaged engine identity to the test hosts so ghost
archives exercise the production validation rules. Native captures are written
to `.build/platform-parity/renders`. Run both Apple SDK checks after changing
shared UI. SDK compilation verifies source coverage, not device input delivery.

Current evidence: 39 focused tests pass with muted audio and offscreen execution.
They cover native sequel masks and assignment feedback, reduced effects,
checkpoint/reset behaviour, exact NeoLemmix command/state replay, ghost drawing
and unchanged targets, plus existing touch, precision, reward and rewind
regressions. Six native captures were produced and representative L2/L3
highlights and NeoLemmix ghost/selection output were inspected. Both iOS and
tvOS SDK module/application checks pass. These checks do not close the source
gaps in the table or physical-device acceptance.

The audit also exposed a shared NeoLemmix engine limit: nuking before the final
hatch release can leave a run incomplete after all active actors disappear.
`NeoLemmixSimulation.isComplete` still requires the unreleased population to
reach zero while nuke suppresses further release. This affects the shared engine
and needs its own rule, result, replay and recovery regression. Ghost rendering
acceptance must not conceal that failure with a platform-specific workaround.

Physical touch, Siri Remote, controller/keyboard delivery, VoiceOver, CRT/EDR,
thermal behaviour and live service/cloud journeys remain device acceptance.
Cloud library progress does not back up every mid-level checkpoint on any
platform. App Store Connect, provisioning and production service setup are
external acceptance items, not proof of absent source capabilities.

Older matrices and port checklists contain historical claims. Use this register
for the gaps above, with [iOS coverage](IOSInterfaceParity.md),
[TV adaptations](../Apps/UltimateLemmingsTV/IOSParity.md) and
[cross-game behaviour](ReleaseReadiness/CrossGameParity.md) for detailed context.
