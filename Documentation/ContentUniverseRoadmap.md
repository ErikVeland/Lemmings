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

### 1.5 — NeoLemmix compatibility

Target NeoLemmix 12.14 data and replay compatibility, plus the current
NeoLemmix Community Edition contract.

The gate requires real packs and reference replays, not synthetic fixtures
only. It includes styles, lemming sprites, all standard skills, terrain masks,
gadgets, special effects, zombies, Superlemming, pack progress and recovery.

Until this gate passes, NeoLemmix support remains Beta or Preview and stays out
of the completed main library.

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
