# Evaluation evidence and limits

The [ledger](levels.csv) contains 6,816 distinct pack and level identities: 6,022 Classic fan levels and 794 bundled NeoLemmix levels. Each has a numeric difficulty score. The `completion` and `confidence` columns state whether a score comes from a winning replay or from metadata. The `replay_sha256` column identifies the replay used for each verified win.

A winning replay validates completion in the native engine and supports replay-based scoring. It is not, by itself, a comparison with the source engine. The `physics_parity` column stays unverified until the same solution is checked against an independent engine or reference state, including the rescue result and relevant timing and terrain changes.

## Current result

| Corpus | Levels | Winning replay scores | Estimates without a verified win |
| --- | ---: | ---: | ---: |
| Classic fan packs | 6,022 | 796 | 5,226 |
| Bundled NeoLemmix | 794 | 275 | 519 |

The NeoLemmix count includes 160 Redux levels, 72 Introduction Pack levels and 43 Original Lemmings levels. For NeoLemmix, 130 attempted replay analyses failed and 389 levels had no matching replay. A failed replay does not prove the level is impossible. Nine winning NeoLemmix scores used a replay from a different level version. They are native wins on the bundled level, but source version parity is unverified.

The pinned NeoLemmix Community Edition style set at commit `38d0449f87501798e78ac668a9494848f4aa9649` rendered and ran all 794 levels in the strict corpus diagnostic, with zero unsupported levels or import failures. The smaller style set currently bundled in `Content/NeoLemmix/styles` left 75 levels without the styles needed for that diagnostic.

The replay inputs came from the public [Lemmings Redux replay post](https://www.lemmingsforums.net/index.php?topic=4374.msg105852#msg105852) and [NeoLemmix Introduction Pack discussion](https://www.lemmingsforums.net/index.php?topic=5204.0). The downloaded archives and the full community style set remain in the ignored local build directory; this repository does not redistribute them.

The Redux paired verifier checked all 160 replays against the 160 Redux levels. All 160 completed natively and again after saved-state recovery. All 160 recorded completion frames matched. Two replays used a different source level version; the native win is valid, but source version parity is unverified.

The Introduction Pack paired verifier checked 98 replays against its 120 levels. It reached 75 native completions, reproduced all 75 after saved-state recovery, and reported 23 failures. The 23 failed replays require compatible source versions or fixes to native replay behaviour before they can support a difficulty score.

An earlier hash-ordered Classic solver sample of 58 previously unverified levels produced no further winning replay. A later score-prioritised sample searched 100 levels and proposed 24 wins. The native verifier rescanned 535 packs with those candidates and route templates; it accepted 211 distinct witnesses. Three levels gained their first verified score, and eight existing scores improved. The learning path now contains 507 levels: 317 official and 190 fan levels. Its generator still excludes metadata-only fan scores, duplicate puzzles and two-player levels. A failed bounded search does not prove that a level is impossible.

## Checks

The report generator is `Tools/DifficultyDiagnostics/full_corpus_report.py`. The strict corpus check used `Scripts/run-nxlv-corpus-diagnostics.sh` with the bundled levels, the pinned full style set, and `--require-runnable`. NeoLemmix replay scoring used `Tools/DifficultyDiagnostics/main.swift` with ten timing probes per winning replay. The paired verifier was built by `Scripts/run-nxrp-paired-corpus-diagnostics.sh`. Its compiled binary ran the separate pack checks because a later wrapper rebuild hit a local Command Line Tools compiler and SDK mismatch.

The 5,745 estimated scores must remain marked as estimates until a replay wins on the exact bundled level. Some supplied replays diverge under the native engine. Those failures need investigation before a full completion claim is possible.

The [Lemmings Level Database](https://lldb.camanis.net/) publishes watchable community solutions for many Classic levels. Its browser links contain compressed Golems replay data. No native importer or source-engine state comparison has been validated for those links, so they do not yet count as verified wins or physics parity evidence here.
