# Ultimate Lemmings content roadmap

This document defines how Ultimate Lemmings expands beyond the current macOS
release without showing unfinished work as completed content.

## User-facing content rule

The main game library shows only content that has passed its declared release
gate.

- **Complete** content has a verified winning route for every advertised level.
- **Playable** content loads, renders and runs, but does not claim full route
  coverage. Community content can use this status when its limits are clear.
- **Preview** content appears in a separate, labelled area. Lemmings 2 and
  Lemmings 3 remain Preview until their engine fidelity and campaign evidence
  meet the required gate.
- **Beta** content appears only in a beta build or after the player enables the
  relevant preview option.
- **Unverified** content does not appear in the normal library. It can remain
  available through an explicit import or developer test path.

The application must not present an unverified engine as a completed release.
It must show the source engine, content status and known limits before play.

## Release goals

### 1.1 — Mac three-engine reference release

Keep Classic, Lemmings 2 and Lemmings 3 in one macOS application.

- Classic remains the completed reference engine.
- Lemmings 2 and Lemmings 3 remain clearly labelled Preview engines.
- All three engines share targeting, input, pause, retry, recovery and save
  behaviour where their rules allow it.
- The first 1.1 beta gets a new readiness record. It must not reuse 1.0
  evidence as proof of the new build.

### 1.2 — Content atlas and import boundary

Create a machine-readable catalogue for every supported or investigated pack.
Each record should include:

- source engine and version;
- file format and pack structure;
- level, graphics, audio and replay dependencies;
- licence and redistribution status;
- import, render, run, replay and completion evidence;
- known conversion loss or rule differences.

The catalogue must distinguish Classic fan levels from NeoLemmix levels. A
level format alone must not decide which physics engine runs the level.

Add the player-facing content browser in the same milestone:

- Use a CoverFlow-style carousel with the selected pack or level in the centre,
  shipped pixel artwork, a clear focus state and one primary start action.
- Keep the browser usable with mouse, keyboard, controller and VoiceOver. Add a
  list or grid path when reduced motion is enabled.
- Add `Shuffle all` for eligible fan levels. Do not mix unverified content into
  the normal library, and do not repeat a level until the selected pool is
  exhausted unless the player starts a new shuffle.
- Let the player create a playlist from ten random eligible levels or from a
  manually selected and ordered set of levels.
- Store the source engine, pack identity, level identity and catalogue revision
  in each playlist entry. Reject or repair entries that no longer resolve.
- Keep playlist progress separate from campaign progress, Hot Seat ownership,
  saved attempts, replays and verified completion records.
- Check for new compatible fan packs in the background at launch. Rate-limit
  sequential requests, validate each archive and readable level before install,
  and never replace an installed pack or change a running game.
- Show the update result in the fan-pack browser. Keep installed packs and
  progress available offline, and retry an unavailable check on a later launch.
- Limit automatic updates to supported releases in the Lemmings Level Database.
  Do not fetch forum attachments or install engine and graphics dependencies.
- Add automated application updates for supported macOS builds. Check a signed
  release feed in the background, verify the package and platform before install,
  and show release notes before the player accepts an update.
- Let the player defer an update and never interrupt a running game. Keep a
  manual download path for offline use or when an update check is unavailable.

Current source status:

- Classic level cards follow the active player's progress within each rating.
  Each rating starts with its first level available. A saved Settings option can
  unlock all Classic cards without changing campaign progress.
- The active player profile owns its saved playlists and active sequence.
  Manual playlists preserve their chosen order. `Random 10` asks for one pack
  and saves up to ten distinct eligible levels from that pack.
- A playlist can run in manual order or use a stable seeded shuffle.
  `Shuffle all` shows its fan-level pool before play and stores one
  non-repeating order.
- The active sequence stores its fixed entries and current position for resume.
  Playlist play does not advance campaign or fan-pack progress and does not
  write Hot Seat, recovery, route, replay or verified record state.
- Missing and changed entries keep their saved names and appear as invalid.
  The player can remove or replace them instead of receiving a substitute.

The current source includes the browser, playlist storage, background fan-pack
checks and application update path. Targeted tests cover these features.
The content atlas still needs the complete supported-pack catalogue. A signed
package, physical controller use and a complete VoiceOver journey still need
validation on the release Mac.

### L2 and L3 completion verification

Make sequel completion verification a 1.2 exit gate. Keep the current Preview
labels until every condition passes:

- preserve and replay a winning route for all 120 Lemmings 2 levels and all 90
  Lemmings 3 levels;
- compare Lemmings 2 rules with the original engine and resolve the provisional
  Lemmings 3 tool, movement and trap semantics;
- verify continuous campaign progression, Lemmings 2 survivor carry-over and
  both games' endings;
- complete Lemmings 3 environmental effects, original movie audio and story
  transitions, and close the remaining Lemmings 2 media and fidelity gaps;
- verify app-session completion, saved-run recovery, replay identity and result
  records against the current engine and content revisions.

The current baseline is 73/120 Lemmings 2 routes and 41/90 Lemmings 3 routes.
The missing 96 routes are an open verification gap, not evidence that those
levels are broken. A passing load or smoke check does not close this gate.

### 1.5 — NeoLemmix compatibility

Target NeoLemmix 12.14 data and replay compatibility, plus the current
NeoLemmix Community Edition contract.

The gate requires real packs and reference replays, not synthetic fixtures
only. It includes styles, lemming sprites, all standard skills, terrain masks,
gadgets, special effects, zombies, Superlemming, pack progress and recovery.

Until this gate passes, NeoLemmix support remains Beta or Preview and stays out
of the completed main library.

The executable development plan is in the [1.5 NeoLemmix roadmap](1.5Roadmap.md).
The source gate uses NeoLemmix Community Edition 1.2.0 at a pinned commit. It
separates level import and rendering from runnable mechanics, and it has a
strict mode that fails while any required mechanic remains unsupported. The
current-format replay decoder is covered by synthetic tests. Real reference
replays and native result comparison remain mandatory external evidence.

### Later — wider 2D content

Add separate compatibility lanes for:

- DOS and Lemmix variants not covered by the Classic corpus;
- Lemmini and SuperLemmini content;
- historical Amiga, Macintosh, Genesis and SNES content;
- Lix levels and multiplayer as a separate engine family;
- other documented 2D engines and archives discovered by the content atlas.

The project should preserve each source engine's rules. It must not convert all
content into Classic rules and call the result universal compatibility.

## Compatibility vocabulary

Every engine and pack uses these gates in order:

1. **Recognised** — the application identifies the format.
2. **Imported** — the parser retains the required data.
3. **Rendered** — terrain, objects, sprites and masks are available.
4. **Runnable** — the engine starts and accepts input.
5. **Replay-compatible** — reference replays reproduce the result.
6. **Behaviour-compatible** — rules match the source engine within the agreed
   tolerance.
7. **Complete** — every advertised level has verified completion evidence.

Passing an earlier gate does not imply that a later gate passed.

## External map

The research baseline should include the Lemmings Level Database, the Lemmings
Forums pack and fangame lists, the Lemmings Universe archive, NeoLemmix and
Community Edition source, SuperLemmini tools, Lemmix source, and Lix source.
Use these sources as format and behaviour references. Review their licences
before copying code, assets or content.

## Exclusions

Three-dimensional games, console-only services and unlicensed commercial
content are not silently included in the 2D compatibility claim. The catalogue
can record them as investigated or excluded items with a reason.
