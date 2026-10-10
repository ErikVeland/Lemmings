#!/bin/zsh
# Extract the NeoLemmix CE levels, DMA styles and stock gadget samples.
#
# Usage: prepare-neolemmix-content.sh [CE_CHECKOUT]
#
# CE_CHECKOUT is a clone of NeoLemmix Community Edition at the pinned commit.
# Without it, the script clones the pinned commit into .build/neolemmix-ce.
#
# CE License.txt permits the community styles to be copied only to run
# NeoLemmix. The script copies only the styles that License.txt assigns to DMA.
# The app already ships DMA's original assets with the owner's approval.
# Levels that need other styles stay unavailable until the player adds a
# NeoLemmix styles folder. Executables, music and CE interface graphics
# stay out of the app. The nine stock gadget WAV files retain CE notices.
set -euo pipefail

project_dir="${0:A:h:h}"
commit="38d0449f87501798e78ac668a9494848f4aa9649"
repository="https://github.com/Willicious/NeoLemmixCommunityEdition.git"
checkout="${1:-$project_dir/.build/neolemmix-ce}"
target="$project_dir/Content/NeoLemmix"

if [[ -z "${1:-}" && ! -d "$checkout/.git" ]]; then
  print "==> Cloning NeoLemmix CE at $commit"
  git clone --quiet --filter=blob:none --no-checkout "$repository" "$checkout"
  git -C "$checkout" checkout --quiet "$commit"
fi
[[ "$(git -C "$checkout" rev-parse HEAD)" == "$commit" ]] || {
  print -u2 "FAILED: $checkout is not at the pinned CE commit $commit."
  exit 1
}
[[ -z "$(git -C "$checkout" status --porcelain -- data/external License.txt)" ]] || {
  print -u2 "FAILED: $checkout has local changes in data/external or License.txt."
  exit 1
}
external="$checkout/data/external"

staging="$target.partial"
rm -rf "$staging"
mkdir -p "$staging/styles"
rsync -a --exclude=.DS_Store "$external/levels/" "$staging/levels/"
cp "$checkout/License.txt" "$staging/License.txt"

python3 - "$checkout" "$staging" "$commit" <<'PREPARE'
import hashlib, json, pathlib, re, shutil, sys
checkout, staging, commit = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
owners, owner = {}, None
for line in (checkout / 'License.txt').read_text(errors='replace').splitlines():
    match = re.match(r'^- ([^:]+):\s+(\S+)\s*$', line)
    if match:
        owner = match.group(1).strip()
        owners[match.group(2).lower()] = owner
        continue
    match = re.match(r'^\s{10,}(\S+)\s*$', line)
    if match and owner:
        owners[match.group(1).lower()] = owner
dma = sorted(style for style, name in owners.items() if name == 'DMA')
if len(dma) != 26:
    sys.exit(f'FAILED: expected 26 DMA styles in License.txt, found {len(dma)}.')
source = checkout / 'data/external/styles'
for style in dma:
    if not (source / style).is_dir():
        sys.exit(f'FAILED: DMA style {style} is missing from the checkout.')
    shutil.copytree(source / style, staging / 'styles' / style,
                    ignore=shutil.ignore_patterns('.DS_Store'))

# Stock samples used by the bundled DMA gadgets. Community samples stay supplied by players.
stock_sounds = ['chain', 'electric', 'fire', 'slurp', 'teleporter', 'tenton', 'thud', 'thunk', 'weedgulp']
sound_target = staging / 'sound'
sound_target.mkdir()
sound_hashes = {}
for name in stock_sounds:
    sample = checkout / 'data/external/sound' / (name + '.wav')
    if not sample.is_file():
        sys.exit(f'FAILED: stock gadget sample {sample.name} is missing.')
    shutil.copy2(sample, sound_target / sample.name)
    sound_hashes[sample.name] = hashlib.sha256(sample.read_bytes()).hexdigest()

levels = staging / 'levels'
packs, available = [], 0
for pack in sorted(p for p in levels.iterdir() if p.is_dir()):
    total = ready = 0
    for level in pack.rglob('*.nxlv'):
        total += 1
        text = level.read_text(errors='replace')
        refs = {m.lower() for m in re.findall(r'(?im)^\s*(?:THEME|STYLE|COLLECTION)\s+(\S+)', text)}
        ready += bool(refs) and refs <= set(dma)
    packs.append({'directory': pack.name, 'levels': total, 'dmaStyleLevels': ready})
    available += ready
manifest = {
    'repository': 'https://github.com/Willicious/NeoLemmixCommunityEdition',
    'commit': commit,
    'styles': dma,
    'soundSHA256': sound_hashes,
    'packs': packs,
    'levels': sum(p['levels'] for p in packs),
    'dmaStyleLevels': available,
}
(staging / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f"{len(packs)} packs, {manifest['levels']} levels, {available} with DMA styles only, {len(dma)} styles")
PREPARE

rm -rf "$target"
mv "$staging" "$target"
print "Prepared $target"
