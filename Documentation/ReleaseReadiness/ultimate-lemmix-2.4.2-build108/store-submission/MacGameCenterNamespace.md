# Mac Game Center namespace

The Mac Store package now uses Lemmix-specific `ulx.v1` Game Center identifiers. Apple export and exact package checks passed.
The Lemmings `ul.v1` identifiers and shared source resources remain unchanged. No upload or submission occurred.

The deterministic transform preserves all 359 boards, four sets and 178 ranked conditions. It changes only Apple identities and the setup bundle ID.
An inverse round-trip check verifies every non-identity field. Game Center remains enabled.
The setup manifest now names `academy.glasscode.ultimatelemmix`.

Resource code commit: `043a43dca9b701c76891d2f81d078ed2df4d6d1d`.
Compiled app source commit: `1ac19c638e3f62dd48f7d4dedf17b285b961b079`.
Export verification commit: `043a43dca9b701c76891d2f81d078ed2df4d6d1d`.

The resource update changed two Game Center JSON files and `ultimate-lemmix-data-inventory.json`.
All other 2,298 resource files retain their exact hashes. No Swift compiler or engine test ran.
All eight unsigned executable files matched before and after development signing.
Apple export changed file layout outside the inspected sections. All 549 file-backed Mach-O code and data sections still match.
Distribution signatures, required entitlements, both architectures and the resource inventory passed verification. Apple reported no product errors.

Package size: 42,623,057 bytes.
Package SHA-256: `6bb2f828a6bbb677baccb6d68c95eb8684ef8305c325ade265521298636d70e2`.
Installer signer: `3rd Party Mac Developer Installer: Erik Veland (54WU29TRTY)`.

The prior Handoff package remains in `UltimateLemmix-Store-20261119/Superseded/Mac before Game Center namespace`.
Its SHA-256 is `124bacf89b97ef6bc39da05e19fdbe7fc10948b421413d5c7c3671de8fff2791`.
The [JSON receipt](mac-game-center-namespace.json) records full artifact paths and executable comparison hashes.

This change preserves the existing ranked catalogue. It does not add starter levels or expand ranked coverage.
App Store Connect board creation and signed-device Game Center acceptance remain separate checks.
