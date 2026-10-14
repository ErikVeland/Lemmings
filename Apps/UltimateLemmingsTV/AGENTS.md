# iOS feature parity

Full parity with the iOS version is a requirement for this app. Use the current
local iOS implementation as the working baseline unless the user identifies a
different release. Read `IOSParity.md` before changing TV features or assessing
TV release readiness.

Match the iOS feature set, game rules, progression, saved-state ownership and
settings. Adapt presentation and input to television, Siri Remote and game
controllers. Reuse shared mobile core and bitmap presentation components.
Do not treat missing iOS features as optional TV follow-ups or claim parity
from a successful build or core-only engine tests.

The repository-level UI, cross-game and background-testing instructions still
apply. Changes to the shared TV modules under `Sources/LemmingsTVCore` and
`Sources/LemmingsTVUI` must also satisfy this requirement.
