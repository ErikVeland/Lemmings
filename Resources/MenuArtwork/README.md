# Menu artwork

`lemmings-chronicles.pcx` is the unchanged US title screen from
`Sources/Ports/LEM3CD-2/FRONT/LOGO.PCX`. The shared Home renderer decodes its
original indexed pixels and palette, makes palette index 0 transparent and crops
the logo to (55, 61, 222, 144). Mac, iOS and tvOS packages copy this file into
`MenuArtwork`. US devices use this logo. Other regions use the original
`Ports/LEM3CD/FRONT/LOGO.PCX` artwork.

See `provenance.json` for the Ultimate badge.
