# Beta 14 release verification

Version 0.1, build 14. Beta 14 is the first beta that testers can use to check
worldwide rankings. It is not a 1.0 release.

Release notes: [beta 14](ReleaseNotes-beta14.md).

## Two archives

Apple does not allow Game Center under a Developer ID signature, so beta 14 ships
as two builds from the same source.

| Archive | Signature | Game Center | Gatekeeper |
| --- | --- | --- | --- |
| `UltimateLemmings-0.1-beta14.zip` | Developer ID, notarized and stapled | Off, local records only | Accepted |
| `UltimateLemmings-0.1-beta14-gamecenter.zip` | Apple Development, with profile | On, sandbox scores | Rejected, as expected |

- Developer ID notarization: `a2d15f57-f34b-42fe-907b-8ee6c4ab7550`, accepted.
  Gatekeeper accepted a fresh quarantined extraction.
- SHA-256, Developer ID: `c3b9bd3d52afcb01040be015b0dba54f6ce2618186a0b6a40679df31312a85ee`
- SHA-256, Game Center: `45c395ce3dc92a83109089ecba48784c086184c6b76e3d21f036a5a5d9430cb9`
- Both are universal `x86_64` and `arm64`, minimum macOS 13, about 406 MiB each.

The notary service accepts Developer ID signatures only. The Game Center archive
cannot be notarized, so Gatekeeper stops it and each tester clears the quarantine
flag by hand. That rejection is the expected result, not a packaging fault.

## Game Center archive checks

- `com.apple.developer.game-center` is present in the signature.
- The bundled catalogue reports `enabled: true` and `isValid: true`, 178 configurations.
- The archive embeds `Lemmings macOS Development`, expiring 11 September 2027.
- That profile lists both devices in the [tester roster](BetaTesters.md):
  `00006040-001650D21A00801C` and `00008103-000C65CE3C31001E`.

The packaging script fails the build when the entitlement is missing or the
catalogue is disabled. A tester whose Mac is not in the embedded profile cannot
open this archive. That failure appears at launch, not as a Game Center message.

## Limits

Game Center is newly testable and unproven. Network loss, account changes and
offline behavior have no recorded results. This verification covers the packages
only. It does not close any campaign, fidelity, accessibility, hardware or
publishing gate. Both registered Macs use Apple silicon, so physical Intel
coverage remains open. See the
[1.0 gap evaluation](ReleaseReadiness/OneZeroGapEvaluation.md).
