# Bottom-fall death sounds

Classic, Lemmings 2 and Lemmings 3 share the Audio setting **Bottom Falls — Play death sound**. It defaults to on, including when loading settings saved before the option existed. Turning it off affects bottom deaths only. Global mute, sound-source silence and effects volume still apply.

Classic uses the Macintosh `Die` recording. Amiga audio uses that recording as a fallback because the Amiga death sample has not been identified among its unnamed samples. Lemmings 2 retains its native fall-out sample and distinguishes bottom exits from other boundaries. Lemmings 3 uses its native `I_LEMDIE.PAT` voice with a separate bottom-death cue.

Validation passed on Apple silicon:

- Classic sound cues and real bottom-fall simulation; settings migration and saved opt-out.
- L2 runtime regression suite, including a bottom-fall fixture.
- L3 sound decoding, rescue timing and bottom-fall fixture.
- Playback admission tests for default, opt-out, re-enable, other deaths and mute across Macintosh, Amiga fallback, L2 and L3. Run with `Scripts/run-bottom-fall-audio-tests.sh`.
- App integration with the hints scope; rendered Audio setting on and off, with control target and click checks.

Logs and screenshots are under `.build/bottom-falls`, `.build/bottom-falls-integration.log` and `.build/typography/screens`. These changes follow beta 28; its signed archive has not been replaced. No Intel hardware or listening session was used for this change. Direct Swift compilation passed; the local Swift Package Manager manifest failed to link against its PackageDescription runtime.
