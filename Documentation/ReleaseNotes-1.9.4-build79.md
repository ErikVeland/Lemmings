# Ultimate Lemmings 1.9.4 — Calmer celebrations and smoother play

Build: 79
Release base: v1.9.3

This Mac update softens solved-level effects and fixes saved journey navigation, replay information and rendering overhead.

## Calmer celebrations and smoother rendering

The golden lemming aura is at least 70% softer. Terrain and scenery receive a very faint golden haze when the rescue goal is secured. The effect fades gently and keeps original artwork sharp. Levels requiring every lemming retain their brief glow and current music.

Background haze builds off the main thread and reuses cached images during fast-forward. Both sequels reuse decoded bitmap pixels. The Tribes skips unchanged skill-panel image conversions.

## Saved journeys and controls

Golden Path Continue finds a saved journey after another solo or Hot Seat session. Resuming restores the saved session, players and turn while keeping the departing run saved.

Command-Z rewinds one step through the shared Mac gameplay controls.

## Clearer replays and level order

Solution and leaderboard action replays show remaining skills and the last three successful skill uses in the upper-right corner. Each use shows its exact tick. Chronicles shows tools held by active lemmings and names each recorded tool use.

Time waits for no Lemming and This Corrosion now appear near the end of Golden Path. Their known official and fan variants retain a late Expert placement. Identified routes based on engine quirks cannot enter Intermediate. Golden Path includes 295 lessons.

## Compatibility and validation scope

Universal macOS app for Apple silicon and Intel, macOS 12.3 or later. Full and slim downloads retain original Macintosh music. Automatic updates retain the full music library.

The Tribes remains Complete. Chronicles and NeoLemmix remain Beta. iOS 2.0 remains separate from this Mac release.

Public-release checks run headlessly with native UI windows offscreen and test audio muted. Package, update-feed and focused regression results are recorded in the distribution evidence. Physical HDR appearance, audible listening, physical Intel, minimum macOS and sustained high-speed hardware acceptance remain manual checks.

Release commit: 4cf2c500bf9f8759bfc0c01b00051e195775e533
