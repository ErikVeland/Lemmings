# 2.0.8 build 92 source candidate

Prepared on 19 October 2026 from the working tree after v2.0.7. This record
covers source and interface checks. It does not certify a published package.
The feed remains on 2.0.7. See the [candidate notes](../../ReleaseNotes-2.0.8-build92.md).

Later access, presentation, hints and review work has its own
[anniversary foundation evidence](../AnniversaryFoundations-2026-10-19/README.md).
The checks below retain their original source scope.

## Player journeys

- Journey Map and Resume resolve only the selected solo or Hot Seat session.
  A saved solo Journey remains discoverable while another session owns the
  active queue. Opening the map preserves roster and turn.
- Journey queues, positions, cleared states and Mac L2 carry-over snapshots
  share their owning session's archive. Safe-menu imports and paused Ready
  handovers remain in place.
- Sync credential access and persistence stay in the background. Partial
  library reads/writes and progress changed during upload remain pending.
  Tester setup state and actual delivery status appear separately.
- The welcome screen reflows inside About's bounded bitmap reading column.
  About's release index uses 44-point targets and opens the installed notes.
- Shared iOS/tvOS fan completion resolves the favourites list's actual source
  library, including the level index used for its completion record.

## Checks

All native checks used `Tools/UITestRunner/run.py` with offscreen windows and
muted audio. No test changed system volume or saved player audio settings.

- Focused Swift tests: 49 XCTest checks and 40 Swift Testing checks pass.
  Coverage includes cloud merges, credential races, offline branches, session
  ownership, mobile Journey state, telemetry targets, menu hierarchy, precision
  fade and Amiga Versus requirements.
- Presentation checks: release-history selection, resizing and scroll
  reachability pass at three widths. The welcome localisation check passes
  across all explicit language choices. Ten mobile Journey regressions also pass.
- Native integration: welcome reflow and Continue, About tabs and release
  selection, offline contributor cache, donation targets and count-reset
  recovery pass. Renders were inspected at compact and standard sizes.
- Five Python checks pass for pre-feed history packaging, deduplication and
  release-note stamping.
- Fresh arm64 simulator SDK module compilation passes for NxlvKit, AppCore,
  MobileCore, TVCore, GameArt and MobileUI on both iOS and tvOS. No simulator
  was launched for this check.

The sandbox blocked standalone macOS app registration before the first
integration attempt reached its checks. The rebuilt runner passed with the
required sandbox access, retaining offscreen windows and muted audio.
The default SwiftPM build backend could not scan system dependencies in this
sandbox. The native backend passed with its module cache inside `.build`.

[source-checks.json](source-checks.json) retains result excerpts and hashes of
the changed source inputs. Detailed logs and renders remain under `.build`.

## Remaining acceptance

Live iCloud/hosted propagation, updated installed devices, physical input and
composited device output remain unverified. Mobile Journey playback remains
Classic-only, with sequel steps and Mac carry-over snapshots retained.
New release-summary prose uses the normal English fallback where a translation
is absent. Existing translated navigation and release headings remain tested.

No full engine replay audit, universal release build, signing, notarisation,
update installation or publication was performed for this source candidate.
Existing engine, content and rescue-target verification limits remain in force.
