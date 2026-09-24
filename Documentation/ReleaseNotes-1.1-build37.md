# Ultimate Lemmings 1.1 build 37

Build: 37
Release commit: 957a8135e8f5366bd0b74dfc83ed7a81de14df75
Release base: c69663be994a642eff12450db055a3aa5000f498

## Changes since the previous release
- a3fad8f Fix Monterey and portability compatibility issues
- c5ac59d Merge 1.1 QoL targeting, transport, and artwork updates into the Monterey build
- 2563996 Remove gameplay hover help popups
- f6800d7 Suppress system cursor inside game views
- 13c20f7 Prevent Classic destruction masks removing steel
- b3ddf7c Complete cross-port DJ soundtrack coverage
- fedac1a Modernise music mixing and seasonal playback
- 958cef2 Accept shifted punctuation transport keys
- 2f086ed Use adjacent keys for timeline scrubbing
- f063059 Add unrecoverable run funeral mood
- 7d6b37d Expose sequel forward rewind controls
- 4f42903 Add sequel forward rewind transport
- aa5251a Align rewind transport visuals across engines
- f26b7bc Keep solution replay canvas in sync
- 08d5b24 Show sequel rewind transport state
- d7b8b49 Complete rewind origin cancellation
- 5ef1c40 Add sequel rewind audio cues
- 0bda489 Add deterministic sequel rewind transport
- 801b667 Add transport controls to solution replay
- 514c4b8 Capture mixed effect audio during rewind
- 921a22b Add skill cursor badge and forward transport
- 2b48dda chore: Bump SequelMacArtwork revision to 6
- 62a44c8 feat: Implement liquid body filling below existing columns
- 0424db1 Add sprite-masked assignment pulse
- 17403f6 Add rewind transport presentation
- dbb57b2 Add subtle lemming target glow
- 57d7340 Prepare macOS 1.1 targeting release
- 1e7d2ce l2-seeded-search: Refine Lemmings 3 targeting logic
- d65d0f6 Lemmings 2: gate approaching-lemming targeting on facing mismatch, fix input parity
- fc2eb83 Classic: gate approaching-lemming targeting on a facing mismatch
- ab092e4 Lemmings 3: extract a testable targeting helper and prefer the approaching lemming
- 7fa6672 Lemmings 2: prefer the approaching lemming when a click is ambiguous
- ae82a7a Classic: add a Settings toggle for approaching-lemming targeting
- d93e170 Classic: prefer the approaching lemming when a click is ambiguous
- d0d11d1 Add the favorApproachingLemmings setting
- d8b77ca Merge beta 36 saved-run fix and RC1 release notes into the Monterey build
- 3ef3ba7 Merge beta 35 Oh No! rules and complete Classic routes into the Monterey build
- 20424d7 Merge beta 34 players, saves and Oh No! routes into the Monterey build
- d9b6f01 Merge l2-seeded-search route work and crop-alignment fix for beta 33
- 8bc92fb Merge beta 32 gameplay and route work into the Monterey build
- 34ed633 Lower the minimum macOS version to 12.3

## Source files
M	Sources/LemmingsLocal/AdaptiveDJPlayer.swift
M	Sources/LemmingsLocal/CRTView.swift
M	Sources/LemmingsLocal/ExplosionHDR.swift
A	Sources/LemmingsLocal/FailureMood.swift
A	Sources/LemmingsLocal/GameCursor.swift
M	Sources/LemmingsLocal/GameSession.swift
M	Sources/LemmingsLocal/GameplayController.swift
M	Sources/LemmingsLocal/GameplayKeyboard.swift
A	Sources/LemmingsLocal/LemmingAssignmentPulse.swift
M	Sources/LemmingsLocal/LemmingFocusHighlight.swift
M	Sources/LemmingsLocal/Lemmings2PlayWindow.swift
M	Sources/LemmingsLocal/Lemmings2SoundPlayer.swift
M	Sources/LemmingsLocal/Lemmings3PlayWindow.swift
A	Sources/LemmingsLocal/Lemmings3Targeting.swift
A	Sources/LemmingsLocal/MusicFileDeck.swift
M	Sources/LemmingsLocal/MusicPlayer.swift
M	Sources/LemmingsLocal/PanelView.swift
M	Sources/LemmingsLocal/PlayfieldView.swift
M	Sources/LemmingsLocal/ResultCelebrationView.swift
A	Sources/LemmingsLocal/RewindForwardKeyTransport.swift
A	Sources/LemmingsLocal/RewindTransportCue.swift
M	Sources/LemmingsLocal/RunRecovery.swift
M	Sources/LemmingsLocal/SettingsWindow.swift
A	Sources/LemmingsLocal/SkillCursorBadge.swift
M	Sources/LemmingsLocal/SolutionReplay.swift
M	Sources/LemmingsLocal/SoundEffectPlayer.swift
M	Sources/LemmingsLocal/SoundtrackPlayer.swift
M	Sources/LemmingsLocal/main.swift
M	Sources/NxlvKit/ArchivalAudioRegistry.swift
M	Sources/NxlvKit/ClassicDOSSimulation.swift
M	Sources/NxlvKit/ClassicSettings.swift
M	Sources/NxlvKit/Lemmings2Level.swift
M	Sources/NxlvKit/Lemmings2MacArtwork.swift
M	Sources/NxlvKit/Lemmings2Runtime.swift

## Package targets
- Developer ID standard: notarised.
- macOS 12 Monterey: notarised.
- Game Center: development-signed for registered devices; not notarised.
