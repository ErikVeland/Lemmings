# Heritage credits

The existing About tab loads `About/Heritage.md` from the app bundle. It remains
available offline and separate from the server-editable contributor and supporter
list. `Scripts/bundle-about.py` packages the source in
`Resources/About/Heritage.md`. No launch page or extra tab is added.

## Attribution evidence

The names and roles below follow the supplied original credits. They do not
assign roles to other contributors by inference.

| Claim | Local source |
| --- | --- |
| DMA Design created Lemmings; Psygnosis published it | `Tools/Telemetry/contributors.md`; the supplied DOS soundtrack package names DMA Design and Psygnosis as developer and publisher |
| Programming: Dave Jones | Original Amiga `code`, ASCII credit at `0x93b4` |
| Animation: Gary Timmons | Original Amiga `code`, ASCII credit at `0x93e0` |
| Graphics: Scott Johnston | Original Amiga `code`, ASCII credit at `0x940c` |
| Music: Brian Johnston and Tim Wright | Original Amiga `code`, ASCII credit at `0x9438` |
| Macintosh port: Presage, Inc. | Prepared original Macintosh `Lemmings.rsrc`, credit at `0x990` and Macintosh-version credit at `0x2a21b` |
| Original DOS music arrangements: Tony Williams | Supplied `Lemmings_Series_(IBM_PC_AT)/Lemmings Series.txt`, package version 1.10, notes beginning at line 73; the tracked music catalogue retains these credits |

The supplied Amiga source is `Sources/Ports/amiga_extracted/lemmings/code`, SHA-256
`3ad4ab5bb5178f238603255c80cc307cd78169c17a201e16065c0909d67f8c94`.
The prepared Macintosh resource is `.build/mac-artwork/original/Lemmings.rsrc`,
SHA-256 `0d9bc07abe5dddab34a3f4270cb411d0e5e55f0a28c379a71acc3b86357f749c`.
The DOS package notes have SHA-256
`ba143093cef4d3165b700f98d503dc84066e1580971dcf0676adf7c901e3f813`.
These are local source identities, not redistributable copies of commercial data.

Original artwork provenance is documented in [the unified game](UnifiedGame.md)
and [Macintosh monochrome artwork](MacintoshMonochrome.md). Generated graphics
remain identified as reconstructions. See [Macintosh-style sequel artwork](SequelMacArtwork.md)
and [NeoLemmix Macintosh artwork](NeoLemmixMacArtwork.md). Music identities and
arrangers remain in the [soundtrack source audit](MusicSourceAudit.md) and tracked
`Resources/Music/catalogue.json`. Research attribution remains in
[`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

## Validation

The packaging check verifies that the local heritage text reaches the bundle
unchanged while preserving the contributor fallback. Native About checks use
the shared bitmap reader at compact, standard and wide sizes, with scrollable
credits and unchanged Back, tab and supporter targets. Physical controller and
VoiceOver listening acceptance remain separate checks.
