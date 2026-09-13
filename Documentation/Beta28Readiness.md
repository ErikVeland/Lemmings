# Beta 28 readiness

Version 0.1, build 28. Universal arm64 and x86_64; macOS 13 or later.
Full soundtrack assets are included. This is the standard local-records build.

## Release status

The universal app is signed with Developer ID Application: Erik Veland
(54WU29TRTY), with hardened runtime and a timestamp. Apple accepted submission
`0e991a68-9933-4e2b-bde8-ea1ae421200c`. The ticket is stapled and validated. The finished ZIP was
extracted, marked as downloaded, and accepted by Gatekeeper as Notarized
Developer ID. Strict signature checks passed on the extracted app.

The tester download is
`/Users/veland/Downloads/UltimateLemmings-beta28-macOS.zip`.
SHA-256: `347748c85bd674c8205bba79d9a71d0e0276d41f1d221aa2a8d75ff4344c014f`.
The archive is about 407 MiB and includes `Release Notes.md`.
Matching notes are in Downloads. Beta 27 remains available as a fallback.

## Frozen inputs

The app was compiled from a frozen copy of commit `4cd8cab` plus the working-tree
changes for the beta-exit fixes and typography. The frozen checkout is
`.build/beta28/source`. Source, game data, scripts and test inputs are copied,
not shared with the working checkout. The final input inventory is
`.build/beta28/final-input-manifest.json`; the original snapshot is retained in
`input-manifest.json`. No application or engine source changed after compilation.

Release-data updates were made only after replay validation. The finish script
checks the final input hashes and requires the staged archive to match every
file in the tested app before it submits the archive to Apple.

## Validation

- All 25 core/resource regression suites and all 18 Swift tests passed.
- All 120 original Lemmings routes and 103 additional Classic-family routes
  passed their strict completion gates. The L3 gate verified 16 routes and its
  rejection cases.
- The L2 gate verified all 64 recorded routes and rejected seven damaged
  fixtures. No complete ten-level tribe chain is claimed.
- Both full app journeys passed: Apple silicon and Intel under Rosetta. These
  cover controls, hints, solution playback, save recovery, legacy fan settings,
  typography, Search editing, interruption and Hot Seat ownership.
- The fan-library and Amiga/style suites passed, including literal archive
  member names, holiday styles and exact steel handling.
- All 120 hint decks were regenerated from exact winning replay outcomes. Deck
  contents and opening moves are unchanged. Their engine identity is current.
- The proof audit covered 562 levels and 565 configurations. It retained all
  166 maximum-rescue certificates and 17 rescue records. All 183 conditions and
  witness files exactly match the previous release after replay validation.
- Sequel artwork checks passed for 59,542 frames, 120 checked-in visual hashes
  and 214 level assets. The full sequel UI journey passed, including the live
  packaged L2 proof, handovers, stepping and saved-run navigation.
- Rendered panel checks passed at five widths. Movie tests passed the stalled
  encoder case, exact frame counts, audio, exports and L2/L3 movie clocks.
- HDR, CRT shaders, L2 viewport geometry and slim-packaging checks passed.
- The signed production app stayed running through eight-second startup checks
  on both architectures. Strict signature validation passed.

## Packaging corrections

The initial app journey found that the hint catalogue still named the earlier
engine. Regeneration replayed all 120 solutions and changed only that engine
identity. Packaging now rejects stale hint or proof data before it builds.

The initial sequel journey exposed a path-dependent asset fingerprint in the
proof audit. The audit now resolves symlinks before deriving relative paths,
matching the live app. L2 proofs were replayed again and the full sequel UI
journey passed. No witness bytes or proof conditions needed to change.

Initial failed logs are retained as `app-arm64-initial.log` and
`sequel-ui-initial.log`. Final logs, comparisons and the finish script are under
`.build/beta28`.

## Remaining scope

The latest Classic/fan corpus audit records 605 verified wins, 23 load/start
failures and 5,790 identities without verified winning routes. This package does
not close those broader compatibility or coverage gates. L2 and L3 remain
previews. Physical Intel/minimum-macOS, full VoiceOver, physical controller and
sustained 10x performance checks remain open. See [release scope](ReleaseScope.md)
and [release notes](ReleaseNotes-beta28.md).
