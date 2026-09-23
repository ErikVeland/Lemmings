# Ultimate Lemmings

Ultimate Lemmings is an unofficial native macOS port of the 2D Lemmings
games. It uses native Swift interpreters and does not run DOS code through an
emulator. Commercial game data is not committed to this repository; local
builds use the assets supplied in `Sources/Ports`, `Sources/Music` and
`Content/` when present.

The project is not affiliated with, endorsed by or licensed by Sony
Interactive Entertainment. Read [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
before distributing a build.

## Start here

- [Architecture](ARCHITECTURE.md) — module boundaries, runtime flow and release packaging.
- [Project overview](Documentation/Overview.md) — player-facing status and roadmap.
- [QoL roadmap](docs/superpowers/plans/2026-09-23-qol-roadmap.md) — target selection and rewind priorities.
- [Release scope](Documentation/ReleaseScope.md) — the meaning of Complete, Playable and Preview.
- [Content roadmap](Documentation/ContentUniverseRoadmap.md) — the path towards broader 2D content.
- [Beta testing](Documentation/BetaTesting.md) — local package and validation procedure.
- [Release evidence](Documentation/ReleaseReadiness/) — current gate records and manifests.

The current milestone is 1.1 on macOS. Classic content is the completed
reference engine. Lemmings 2 and Lemmings 3 are labelled Preview. The bundled
corpus contains 6,020 Classic-format fan levels in 535 packs; this is not a
claim of NeoLemmix fan-pack compatibility. NeoLemmix `.nxlv` support has
parser, renderer and synthetic simulation coverage. Real NeoLemmix pack
compatibility is a 1.5 goal and remains outside the completed library until
its gate passes.

## Requirements

- macOS 13 or later;
- Apple Command Line Tools with Swift 6 support;
- Python 3;
- ImageMagick (`magick`) for asset preparation;
- `unar` for the supplied Holiday installer;
- local game data for builds that package commercial content.

The repository's source and tests remain useful without the commercial data,
but data-dependent build and evidence gates report their missing inputs.

## Build and run

Build a universal arm64/x86_64 local application:

```sh
zsh Scripts/build-local-app.sh
open ".build/local/Ultimate Lemmings.app"
```

The finished bundle contains the resources required by the app. It must not
depend on the source checkout, current working directory, Homebrew or a
developer-only data path after it is copied.

## Verification

Run the release audit for the current source and fixture set:

```sh
python3 Tools/ReleaseReadiness/audit.py --app
```

Run the principal deterministic gates when working on the engines:

```sh
zsh Scripts/verify-classic-completion.sh
zsh Scripts/verify-lemmings2-completion.sh
```

Run the focused regression suites with the repository scripts. For example:

```sh
zsh Scripts/run-classic-dos-simulation-regressions.sh
zsh Scripts/run-neolemmix-end-to-end.sh
zsh Scripts/run-nxlv-renderer-tests.sh
```

The audit and completion documents define what each gate proves. A passing
load or smoke test does not prove a winning route or source-engine fidelity.

## Local release packaging

The release script performs the source-change, release-notes, build, signing,
notarisation and archive checks. It creates three timestamped ZIP files in
`~/Downloads`: the standard Developer ID build, a macOS 12 Monterey build and
the development-signed Game Center build.

```sh
SIGNING_IDENTITY="Developer ID Application: Example (TEAMID)" \
NOTARY_PROFILE="lemmings-notary" \
zsh Scripts/build-and-notarise.sh
```

The Monterey worktree must contain the release commit. Set
`MONTEREY_WORKTREE` when it is not at `.claude/worktrees/macos12`. Set
`DOWNLOADS_DIR` to use another output directory. Use `--dry-run` to exercise
the gates without building or contacting Apple services.

Game Center is a separate development-signed archive for registered devices;
Apple does not accept that entitlement in a Developer ID notarisation.

## Repository map

| Path | Role |
| --- | --- |
| `Sources/NxlvKit` | Shared format, rendering and simulation library |
| `Sources/LemmingsLocal` | Native macOS application shell |
| `Sources/LemmingsDataTool` | Development data inspection utility |
| `Tests` | Focused engine, data, app and evidence suites |
| `Scripts` | Repeatable build and validation gates |
| `Tools` | Probes, catalogues, solvers and evidence generators |
| `Resources` | Repository-owned application resources |
| `Documentation` | Product status, scope, operations and evidence |
| `docs/superpowers` | Active design specifications and implementation plans |

Generated `.build` output, application bundles, local commercial assets,
credentials and worktrees are ignored. `.archive/` is an intentionally ignored
local archive of superseded release records; it is not evidence for the
current build line.

## Input and player-facing behaviour

The app supports keyboard, mouse and supported extended controllers. Shared
QoL behaviour must remain aligned across Classic, Lemmings 2 and Lemmings 3
where their rules allow it. Engine-specific limits stay visible in the
release-scope and overview documents.

See [controller QoL](Documentation/ControllerQoL.md),
[speed controls](Documentation/SuperSpeed.md),
[level hints](Documentation/LevelHints.md) and
[save recovery](Documentation/SaveRecovery.md) for focused behaviour notes.

### Controller controls

The complete binding table and validation boundary are maintained in
[Controller QoL](Documentation/ControllerQoL.md). The in-game help and
Settings pages expose the current bindings for the connected device.
