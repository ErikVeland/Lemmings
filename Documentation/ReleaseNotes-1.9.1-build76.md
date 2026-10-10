# Ultimate Lemmings 1.9.1 — Targeting, display and nuke hotfixes

Build: 76
Release base: v1.9

This update fixes crowded-wall targeting, clarifies Gameplay settings and restores
the nuke funeral music transition.

## Targeting

**Favor lemmings still approaching** uses nearby walls to favour eligible lemmings
facing into the work. This fixes Basher selection in crowds at the top of a
staircase. Classic also refreshes its hovered target when that lemming turns.
The shared correction covers Classic, NeoLemmix, Lemmings 2 and Lemmings 3.
Existing bomb, builder and manual direction preferences retain their priority.

All three targeting preferences now share one outlined group in Gameplay settings.

## Flat Panel

Selecting **Flat Panel** disables and greys out **Tube Strength** and **Pixel Width**.
Selecting Monitor or Television enables them again and retains their saved values.

## Nuke music

The funeral music slowdown starts at the **2→1 countdown**. Screen saturation
changes only when rescue becomes impossible, so colour continues to show the
actual game state. Music returns to normal over 2.4 seconds after the final
explosion. Classic, NeoLemmix and Lemmings 2 share this timing. Lemmings 3 has no
mass-nuke action.

## Compatibility and validation scope

Universal macOS app for Apple silicon and Intel, macOS 12.3 or later. Both full
and slim downloads retain the original Macintosh music from 1.9.
Lemmings 2: The Tribes remains Complete. Lemmings 3: Chronicles and NeoLemmix
remain Beta. The existing campaign, original-hardware and ending limits remain
recorded in the 1.9 release evidence.

Checks cover wall-facing selection, a real Classic Basher assignment, settings
renders and input targets, countdown timing, separate saturation, rewind and
music recovery. Native UI and audio checks run offscreen and muted. Audible
listening, foreground launch, physical Intel and minimum-macOS checks remain open.
