# 1.0 work ownership

Codex leads integration from `/Users/veland/Lemmings-recovery`, branch
`feature/one-zero-recovery`. Integrate only tested changes into the shared
checkout. Keep release builds frozen and separate from ongoing work.

- Codex: save recovery, L2 practice checkpoints, Hot Seat start/resume UX,
  controls/accessibility, and release readiness documentation.
- Reserved for Claude, following its latest handoff: campaign route search,
  `Tools/ClassicCompletion`, campaign verification scripts and route fixtures.

Codex will not change route tooling or fixtures. Keep build outputs in each
worktree. Run GUI tests through the repository's serial UI test runner. Do not
package a release from a checkout while another agent is editing it.

Existing beta 20 archives remain frozen. Integration must preserve later shared
changes and record the actual tested commit.
