# Handover dependencies

This inventory identifies inputs a receiving developer must account for. It
is not an ownership opinion or a licence grant. Detailed attribution stays in
[third-party notices](../THIRD_PARTY_NOTICES.md). Platform and release evidence
stays in [release scope](ReleaseScope.md).

| Input | Source-development requirement | Handover action |
| --- | --- | --- |
| Project Swift, Python and shell code | Tracked source | Confirm authorship, contributor permissions and intended licence or commercial transfer terms. The repository has no project-wide licence grant. Third-party notices do not license the entire project. |
| Referenced implementations and research | References in third-party notices | Distinguish format/behaviour research from copied code. Review any incorporated code and retain applicable notices. Do not claim a completed provenance audit. |
| Sparkle 2.7.3 | Pinned in `Package.swift` and `Package.resolved` | SwiftPM resolves it for Mac targets. Preserve its licence. Update-feed signing keys are release-operator inputs, not source dependencies. |
| Original game data, art, music and voices | Ignored `Sources/Ports`, `Sources/Music` and `Content` | Not required for the isolated source gate. Needed for full gameplay and content verification. Obtain lawful inputs and resolve distribution rights separately. |
| Fan packs, NeoLemmix content and styles | Optional content and packaging inputs | Review rights per contribution. Noncommercial licences and original-game derivatives cannot be treated as a commercial asset grant. |
| Tracked resources, fonts and test fixtures | Included in a source snapshot | Review provenance and permissions before external distribution. Git tracking does not establish ownership. Synthetic tests and original-game fixtures must remain distinguishable. |
| Signing and App Store Connect | Not needed for source tests | Use the recipient's authorised accounts and credentials for distribution. Never share private keys in a source archive. |
| Game Center and CloudKit | Optional platform services | Source compilation does not establish production entitlement or container access. Review configuration and account ownership with the recipient. Use temporary stores for mechanical tests. |
| Telemetry collector | Optional `Tools/Telemetry` service | Do not point evaluation builds at a production collector. Deployment, consent and operator credentials have their own [service documentation](PlayInsights.md). |
| Local preparation tools | Full asset packaging only | `unar`, ImageMagick and format-specific preparation tools are separate from the source test route. See each tool's notices and build checks. |

## Transfer boundary

Keep engine code, content packages, service configuration and release
credentials separate. A developer can evaluate the source workflow without a
commercial asset bundle or access to the author's accounts.

Before a transfer or publishing agreement, record who can grant rights in the
project code, which dependencies can be used commercially, which content the
recipient must supply, and who will operate online services. Record unresolved
items rather than describing the project as commercially cleared.

An independently branded edition and an official edition can share engine
work. Neither route removes the need to review code provenance and content
licences. See the [partner evaluation brief](PartnerEvaluation.md) for the
current evaluation approach.
