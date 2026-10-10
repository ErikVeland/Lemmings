# NeoLemmix replay capture oracle

`neolemmix-replay-capture-v1` compares the native full-world render with CE at
specific replay ticks. It covers live terrain, gadget layers and animation
states, moving backgrounds, and lemming sprites without including the skill
panel, cursor, helpers, overlays or display scaling.

Create the native frames with:

```sh
zsh Scripts/run-neolemmix-replay-capture.sh \
  /path/to/level.nxlv /path/to/replay.nxrp /path/to/styles \
  /tmp/native-capture standard
```

`standard` captures event transitions, command windows, the entrance cycle,
one-second checkpoints and the terminal state. Explicit ticks may be supplied
instead; they must be unique and ascending. A tick is the simulation state
after that many physics updates, using the same source-compatible replay command
timing as the paired-corpus gate. PNGs are the exact level dimensions at one
source pixel per output pixel. The manifest binds them to the replay SHA-256,
level ID, level version and raw RGBA hash.

An independent CE capture directory uses the same manifest shape and filenames.
Its producer must start with `ce:`, for example `ce:1.2+capture.1`. Crop CE
captures to the level world only, retain the original level dimensions, disable
helpers and cursor overlays, and do not rescale or interpolate pixels. Capture
the same post-update replay ticks. A native manifest must not be relabelled as
CE evidence.

Compare the directories with:

```sh
zsh Scripts/run-neolemmix-capture-compare.sh \
  /tmp/native-capture /tmp/ce-capture
```

The comparator requires identical replay and level identity, dimensions and
tick coverage. It rejects non-CE oracle provenance and changed PNG hashes. A
frame passes only when every pixel visible in both engines has identical RGB.
Alpha-only differences are reported because CE commonly renders an opaque
level background while the native world bitmap preserves transparency.

Select ticks that cover each transition under test: immediately before and
after assignments, destructive-mask application, constructive terrain changes,
trap and teleporter trigger frames, button/exit changes, entrance opening,
secondary animation state changes, and the recorded completion frame. The
release gate requires real CE captures; native self-comparison is only a tool
test and is not compatibility evidence.

## Verified CE capture

On 28 September 2026, an independently instrumented NeoLemmix CE 1.2.0 build
captured Lemmings Redux `Gentle 6`, `A task for bombers`, from the replay whose
SHA-256 is
`3db858f14ce46dd74f86422942396ec40779fa5d63a367b769ed0502abecfa2e`.
The producer is `ce:NeoLemmixCE-1.2.0-deterministic-instrumented-capture`.
Native and CE frames at ticks `0, 35, 104, 105, 291, 292, 433` have zero
mutually visible RGB differences. Reported alpha-only differences come from
CE's opaque world background and the native transparent canvas.

The comparison exposed and now guards three CE rendering details: Walker uses
all eight visible animation frames despite its four-frame physics cycle,
lemmings use CE's priority order, and equal priorities use Delphi's hybrid
quicksort permutation, including invisible removed entries.

The completed matrix adds real replay captures for Digger, Floater, Blocker,
Miner, Climber, Basher, Builder and Trap. Two deterministic advanced fixtures
cover Walker, Jumper, Shimmier, Reacher, Slider, Swimmer, Glider, Disarmer,
Stoner, Stacker, Platformer, Laserer, Fencer and Cloner while respecting CE's
limit of ten active skill types per level. Together with the Bomber scenario,
the matrix covers all 21 current skills.

The real replay cases pass 41 selected frames and the advanced fixtures pass
27 selected frames (`18 + 9`). The distinct cases cover seven style families
and include a triggered trap with secondary animation and `NO_OVERWRITE`
layers. Every comparison has zero mutually visible RGB differences. Alpha-only
background differences remain outside the RGB parity contract.
