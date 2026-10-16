# Development workflow

`main` is the combined development branch for the Mac and iOS apps. It can
contain unreleased work. Release tags identify shipped source. Read the
[release scope](ReleaseScope.md) before making compatibility claims.

## Branches and unfinished work

Use `feature/` branches when work needs an isolated checkout. Keep a branch
focused on one change. Merge its code, tests and required evidence into `main`
together. Delete merged local branches after preserving any unfinished work.

Check every linked worktree and stash before consolidating branches. A merged
branch can still have uncommitted fixes in its worktree. Compare those fixes
with the current source. Older implementations must not replace their newer
shared equivalents.

Keep recoverable snapshots in the ignored `.archive/` directory. Preserve
branch history, changed files and untracked source files before pruning.
Keep worktrees with local assets or signing inputs until those inputs are
accounted for. Remote branch deletion and publication are separate actions.

## Shared Mac build modules

`Scripts/build-shared-modules.sh` builds the libraries imported by the Mac app.
Build `NxlvKit` first, then call the helper with the module directory, library
directory, target and optional Swift compiler flags. The helper builds
`LemmingsAppCore`, `LemmingsAudio`, `LemmingsMobileCore` and `LemmingsGameArt`
in dependency order. `Scripts/build-game-art-module.sh` remains a compatible
entry point.

Standalone Mac app and test executables must link the shared libraries they
use. Packaged apps must embed all of those libraries in `Contents/Frameworks`.
The Swift package uses the dependencies declared in `Package.swift`.

## Validation

Run `python3 Tools/RepositoryMaintenance/check.py` for tracked-file hygiene,
Python and shell syntax, JSON/plist validation, local Markdown links and matching
release metadata. This check also runs in Mac CI. It does not need game assets.
Run `zsh Scripts/run-localisation-tests.sh` for the catalogue and native Mac
language-picker regressions. The picker checks need the shipped bitmap artwork.

Use focused checks for the changed behaviour. Keep native UI tests offscreen
and muted through `Tools/UITestRunner/run.py`. Report checks that require
visible windows instead of changing window mode.

A local manual test build uses only the current Mac architecture and goes to
Downloads. It skips automated tests and release audits. Follow
[AGENTS.md](../AGENTS.md) for the complete build and test policy.
