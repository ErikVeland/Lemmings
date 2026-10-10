Proof and hint freshness passed for release 1.8.4.

Current engine fingerprint: `a23fc195617af7cd2d6b162d5244b44a0f45ad12be10ac9f013d4ad9e794fe86`.

The full audit covered 562 level identities and 574 population configurations. It retained all 251 maximum certificates and 261 known rescue records from v1.8.3. All 512 exact-condition targets and all 512 witness SHA256 values are unchanged. The 62 unknown level identities remain unknown.

All 350 hint decks were regenerated against this engine. Their deck bodies match v1.8.3. The headless catalogue check passed 196 release-rate contexts, event ordering and spoiler boundaries.

Strict stale-outcome rejection, explicit refresh retention, refused L2 events and unused late events passed. Policy tests passed 3/3. All mechanical runs used muted audio. No native UI, focus changes, audio device tests or sandbox escalation ran.

Only the fingerprint and audit timestamp fields changed in the four generated files listed in receipt.json. No fingerprint policy or witness outcome was manually changed. Module cache paths were inside the workspace. The shell emitted background-job niceness warnings; every worker completed successfully at ordinary priority.

This receipt and its small logs record completed command output. Creating this receipt did not repeat any test. Full audit logs remain under .build/trolley-verification. See receipt.json for the command summary.
