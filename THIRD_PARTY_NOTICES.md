# Third-party notices

## Classic DOS file-format research

The classic DAT, level, campaign-order, graphics, and related format work is
informed by the public Lemmings reverse-engineering community, including:

- ccexplore and rt's binary format documentation, archived by The Lemmings
  Archive: <https://www.camanis.net/lemmings/tools.php>
- Thomas Zeugner's MIT-licensed `lemmings.js` / `lemmings.ts` work:
  <https://github.com/tomsoftware/lemmings.ts>
- VorticonCmdr's MIT-licensed format documentation and independent decoder
  verification: <https://github.com/VorticonCmdr/lemmings>
- LemmixPlayer's DOS-compatible behavior reference:
  <https://github.com/AaronKelley/LemmixPlayer>
- DOSBox Staging's VGA DAC behavior reference:
  <https://github.com/dosbox-staging/dosbox-staging>

The MIT notice applicable to the referenced Thomas Zeugner work follows:

> MIT License
>
> Copyright (c) 2017 Thomas Zeugner
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

The LemmixPlayer source describes itself as freeware that must remain
noncommercial. This project uses it as a behavioral cross-check. It does not
include copied LemmixPlayer source or assets.

## Sequel format research

The native Lemmings 2 and 3 readers use format research by GuyPerfect,
geoo89, and Mindless. Private beta packages include supplied game data.
Those files retain their original ownership and are not covered by the source
code licences listed here. Public distribution requires the relevant rights
or a player-import workflow, as described below.
See [SequelInterpreters.md](Documentation/SequelInterpreters.md) for the exact
references and the current implementation boundary.
The Chronicles graphics format was also investigated using the `lem3edit`
format readers by Carl Reinke and Kieran Millar as a reference. This project
does not bundle the editor or its source code.
The L2 airborne-motion implementation also uses the behaviour documented by
exit and RavenNine in their DOSBox physics investigation:
<https://www.lemmingsforums.net/index.php?topic=5886.0>.
Original-engine recordings are local test material and are not distributed.

## NeoLemmix format research

The NeoLemmix parser is informed by the published format specification and the
NeoLemmix Community Edition source:

- <https://www.lemmingsforums.net/index.php?topic=4336.0>
- <https://github.com/Willicious/NeoLemmixCommunityEdition>

NeoLemmix Community Edition is published under a Creative Commons
Attribution-NonCommercial licence. This project does not include its source,
styles, levels, or other assets.

No third-party game-data files or NeoLemmix content should be added to a
redistributable build without the relevant rights. The application should ask
players to import data they lawfully possess.

## resource_dasm format reference

The Macintosh SHPD and Presage LZSS decoder follows the format implementation in
https://github.com/fuzziqersoftware/resource_dasm (SpriteDecoders/Lemmings-PrinceOfPersia-SHPD.cc
and DataCodecs/Presage-LZSS.cc). Original game artwork remains supplied game data.

The MIT License (MIT)

Copyright (c) 2023 Martin Michelsen

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Amiga artwork import formats

The Amiga importer uses the CAPS/SPS decoder as a separately installed,
import-time tool. It is not linked or bundled with the game. Decoder source:
https://www.kryoflux.com/download/spsdeclib_5.1_source.zip

The CAPS ABI, Amiga MFM checksums, and Psygnosis B track layout were checked
against Keir Fraser's Disk Utilities and Greaseweazle, released into the public
domain (Unlicense):
https://github.com/keirf/disk-utilities and https://github.com/keirf/greaseweazle

ByteKiller decoding follows Ancient's ByteKillerDecompressor implementation:
https://github.com/temisu/ancient

BSD 2-Clause License

Copyright (c) 2017-2026, Teemu Suutari
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
