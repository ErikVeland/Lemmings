# Lemmings modern edition — evaluation brief

Maintained evaluation approach, updated 19 October 2026. Proposed collaboration,
not an authorised product announcement. No contact or submission is recorded here.

## First contact

Start with an enquiry about remit and interest. Establish whether the recipient
considers externally developed projects involving the original games, and who
handles that question. Do not make the recipient assess a complete business
proposal to answer a routing question.

Use Exient's current official contact channel and ask for the publishing or
business-development contact responsible for Lemmings. A personal introduction
is useful if one is available. Do not assume an old press contact still holds
the relevant role. Do not contact multiple employees with the same pitch.

Identify the work honestly as an unofficial native project. Describe its
preservation focus and modern controls briefly. Ask whether an exploratory
conversation would be relevant. Include a demonstration only if it helps the
recipient understand the enquiry. Do not attach source, commercial assets or a
large unsolicited deck.

If there is interest, establish rights and platform scope before preparing a
commercial proposal. If there is no reply, make one brief follow-up after a
reasonable interval, then leave the enquiry open. Do not imply silence grants
permission. Actual outreach requires the owner's explicit instruction.

## Engineering preparation

Use the [developer handover](DeveloperHandover.md) and
[dependency inventory](HandoverDependencies.md) before offering an evaluation.
The receiving developer should be able to reproduce the source workflow and
inspect the implementation without the author's game files or credentials.
Agree a fixed scope and source snapshot before discussing completion dates.

The value proposition is work the recipient can inspect and potentially reuse.
Do not claim they could not build their own version. Let their engineers assess
adoption effort, correctness, provenance and support needs. A paid, bounded
technical evaluation is one possible next step if they want to proceed.

## Proposition

A modern edition can preserve the satisfaction of the original puzzles while removing avoidable friction: precise controls, instant retry and rewind, flexible speed, optional guidance, readable presentation and reliable play across devices.

The Mac application demonstrates a unified library for the original games and
native sequel interpreters. It combines original presentation with modern
keyboard and controller controls, local records and replay movies. Players can
choose modern defaults or an old-school experience. The current source and
package limits belong in [release scope](ReleaseScope.md).

## Demonstration

1. Start with the original presentation, then enable modern effects without changing the puzzle rules.
2. Play a level with keyboard/mouse and a controller. Show skill cycling, target focus, hold-to-speed-up and immediate return to normal speed.
3. Open a difficult original level. Reveal a nudge, then an approach, then three opening assignments from a verified route. Each tier requires a deliberate action.
4. Demonstrate pause on interruption, a retry, rewind where supported and a replay with recorded sound.
5. Show the original 120-level winning-replay gate, including how it rejects missing or incorrect evidence.
6. Show the sequel work with its current beta/preview labels and the remaining coverage visible.

## Evidence offered

- A reproducible Mac source/build snapshot and automated regression results.
- Verified replay routes for all original 120 levels, plus separately counted additional campaign routes.
- Source and asset provenance, third-party notices and a clear separation of original material from port code.
- The [release plan](ModernReleasePlan.md), hardware test matrix and explicit open gates.
- Existing iPhone/iPad and Apple TV source, with package and device acceptance
  distinguished from implementation. Windows and Linux need separate platform
  work. Consoles are not a current target.

## Decisions for an official collaboration

Agree which games and features belong in the first release, the intended audience, preservation/fidelity requirements, supported devices and accessibility targets. Confirm the supplied assets and permitted distribution, then establish development access, engineering ownership, review milestones and platform delivery responsibilities.

The application provides evidence of the experience and engineering approach.
Use the current release gates for sequel coverage, hardware, mobile lifecycle
and distribution limits. Source compilation does not establish platform
acceptance. Code ownership, commercial content rights and contributor
permissions remain separate evaluation questions.
