# Release-local fan graphics

13 September 2026. This closes a fan graphics selection defect. The full beta-exit gate remains open.

Some DOS-format archives retain the graphics slots of their source release.
Oh No! uses slots 0–3 for brick, rock, snow and bubble. The combined-editor format
uses those slots for dirt, fire, marble and pillar. The loader previously treated
every numeric slot as a combined-editor slot. This could produce either missing
terrain errors or a playable scene with the wrong terrain.

The loader now recognises 13 exact archives by SHA-256 and byte count. It selects
the original release directory and retains the level's numeric slot. It does not
change level records, engine rules or distributed artwork. Explicit named styles
and archive-supplied graphics retain precedence. Unknown or modified archives keep
the existing combined-editor convention. Renaming verified bytes is safe.

## Verified archive identities

| Archive | Source directory | SHA-256 |
| --- | --- | --- |
| 0477-DOS-Amiga-Tame.zip | oh_no_more_lemmings_dos-1991-11-14_2232 | `4657df879d7b2e81e52d0f5e5f2d2d15d8d31176be4628dcfa67366c9c1450bc` |
| 0478-DOS-Amiga-Crazy.zip | oh_no_more_lemmings_dos-1991-11-14_2232 | `8d65d85e93e941b486e9543d3b6d4435495d2e56eadb53d744bd1782eb051da6` |
| 0479-DOS-Amiga-Wild.zip | oh_no_more_lemmings_dos-1991-11-14_2232 | `9447da45833dc536df6fb4e25fd7dff06423ae5e67a769a9c9e94c9416ba439a` |
| 0480-DOS-Amiga-Wicked.zip | oh_no_more_lemmings_dos-1991-11-14_2232 | `63ab956e498283467aba9a3dd87680abe43f00fd07ae16279a6bfd950c54a0a2` |
| 0481-DOS-Amiga-Havoc.zip | oh_no_more_lemmings_dos-1991-11-14_2232 | `575f71040f97db65494e2fd5ab5b3a4351fa43073677480e9af4a9881b02d997` |
| 0486-DOS-Xmas-1991.zip | xmas_dos_XmasLemmingsV1.9 | `fd76e9ca94eeb1d7a54ca3ae0861efecc9541422a9972c39376d40795b7258be` |
| 0487-DOS-Xmas-1992.zip | xmas_dos_XmasLemmingsV1.9a1 | `4361935304ac1fd403c4a5ea63b0a4be415117ff601841b501bac0130e946a91` |
| 0530-Oh-No-More-cLemmings-Tame.zip | oh_no_more_lemmings_dos-1991-11-14_2232 | `b4cce71d3c06d23b8211c86de6f76ff300331d8adc0c121d3f0924ce4a23037a` |
| 0531-Oh-No-More-cLemmings-Crazy.zip | oh_no_more_lemmings_dos-1991-11-14_2232 | `e7eb1cb2ed4152fe7d0b78cfcfca504b5e526cb53dc1287672410afce8f08585` |
| 0532-Oh-No-More-cLemmings-Wild.zip | oh_no_more_lemmings_dos-1991-11-14_2232 | `06cc76ea462e87444c3294ca16d48b06d6df24af0d6e6825df4012b79e26ea5e` |
| 0533-Oh-No-More-cLemmings-Wicked.zip | oh_no_more_lemmings_dos-1991-11-14_2232 | `8473c39f4bf9a6cc9b19dd6d27633e8fa7ccb8e70c52210758f6211bde8f22ba` |
| 0534-Oh-No-More-cLemmings-Havoc.zip | oh_no_more_lemmings_dos-1991-11-14_2232 | `64cd29e779476667eeb9b20370f45d6c39626711de511685c2ddf354ccd93456` |
| 0583-Amiga-Oh-No-More-Lemmings-Two-Player.zip | oh_no_more_lemmings_dos-1991-11-14_2232 | `1331231b1a47cc1c92aaa411bbfd05bbabe9b122406c6ab79cc673b8ed23dfd8` |

The Oh No! reissues are checked against original campaign terrain and object
records. The cLemmings and Amiga two-player archives use the same four local slots;
their snow, rock, brick and bubble records render with the corresponding original
assets. Xmas 1991 also contains two Oh No! promotional levels, so it uses the
Xmas release's own slot files instead of forcing every level to snow.

Holiday archives were excluded from this first correction. Frost/Hail are now
covered by [the Holiday follow-up](HolidayStyleClosure.md). Mixed Flurry/Blitz
graphics slots still need separate evidence;
an initial candidate mapping failed on “Vacation in Gemland”. A renderable terrain
piece alone is not sufficient proof of the intended style.

## Saved attempts and shared engines

The optional checkpoint field `fanLocalStyles` records the convention for a fan
attempt. A missing field retains the old graphics. Retry starts a new attempt
with the corrected convention. The app regression checks an exact paused legacy
restore, a changed terrain state on retry, and exact restoration of the new save.

This mapping applies to Classic-format fan archives. Lemmings 2 and Lemmings 3
keep their native asset selection. The shared checkpoint field is optional, and
this pass verifies Classic/Neo recovery and Classic Hot Seat flows. Native L2/L3
recovery and handover suites were not rerun; no native engine path changed.

## Validation

- All 218 levels in the 13 archives render and start.
- Renamed, same-size modified, unknown and explicitly named-style cases are covered.
- Save-file corruption, migration protection, stale-writer and queue checks pass.
- All 108 canonical reissue terrain/object records match the official release.
- The full 6,395-level audit recovers 62 load/start failures (85 → 23), adds 73
  verified fan wins (294 → 367), and changes 218 initial states. No previous win
  is lost and no new load/start failure appears.
- The 23 remaining failures are nine unavailable-terrain references and 14 records
  without an entrance. All remain in the catalogue and failure inventory.
- All 590 verified routes replay to identical winning outcomes twice. The strict
  gate still fails because 5,805 levels lack a verified winning route.
- The complete optimized arm64 app integration suite passes, including legacy and
  current fan saves, retry, interruption and Hot Seat boundaries.
- Final input hashes report no drift; core sources match the previously validated
  macOS 13 arm64 library exactly.

Local evidence: `.build/beta-exit-fan/fan-library-evidence.log`,
`recovery.log`, `app-final.log`, `comparison.json` and
`corpus-final/{levels.jsonl,coverage.json,inputs.json,input-drift.json}`.
The app run uses beta 27 resources; the corpus uses the same hashed resource
directory as the preceding audit. These source changes are not a signed release.
