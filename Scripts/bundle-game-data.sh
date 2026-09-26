#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
music_bundle="${MUSIC_BUNDLE:-full}"
if [[ "$music_bundle" != main && "$music_bundle" != full ]]; then
  echo "MUSIC_BUNDLE must be main or full." >&2
  exit 1
fi
if (( $# != 2 )) || [[ "$2" != all && "$2" != l2 && "$2" != l3 ]]; then
  echo "Usage: bundle-game-data.sh /absolute/App.app/Contents/Resources all|l2|l3" >&2
  exit 1
fi
resources_dir="${1:A}"
if [[ "$resources_dir" != *.app/Contents/Resources ]]; then
  echo "Game data must be copied into an app's Contents/Resources directory." >&2
  exit 1
fi
for required in LEVELS/LEVEL000.DAT STYLES/CLASSIC.DAT VLEMMS.DAT MASKS.DAT INTERN.DAT FONT.DAT PANEL.DAT ICONS.DAT FRONTEND/GFXIFFS/MENU.IFF FRONTEND/SCREENS/MENU.DAT; do
  if [[ "$2" != l3 && ! -f "$project_dir/Sources/Ports/Lemm2/$required" ]]; then
    echo "Missing L2 source asset: $required" >&2
    exit 1
  fi
done
mkdir -p "$resources_dir/Ports" "$resources_dir/Music"
mkdir -p "$resources_dir/Hints"
cp "$project_dir/Resources/Hints/classic.json" "$resources_dir/Hints/classic.json"
cp "$project_dir/Resources/Hints/solutions.json" "$resources_dir/Hints/solutions.json"
# Event sounds that no original bank supplies, named after the event.
mkdir -p "$resources_dir/Sounds"
rsync -a --exclude=.DS_Store "$project_dir/Resources/Sounds/" "$resources_dir/Sounds/"
# Assets stay in the ignored app bundle. Original executable engines, machine
# settings and development overlays are not needed by the native interpreters.
copy_options=(-a --exclude=.DS_Store --exclude='*.[Ee][Xx][Ee]' --exclude='*.[Cc][Oo][Mm]'
  --exclude='*.[Bb][Aa][Tt]' --exclude='*.[Rr][Kk][Oo]' --exclude='*.[Rr][Kk][Bb]'
  --exclude='*.[Ii][Nn][Ii]' --exclude='*.[Ss][Aa][Vv]' --exclude='LEM3CD-2/')
case "$2" in
  all)
    if [[ ! -f "$project_dir/Content/LevelPacks/packs.json" ]]; then
      echo "Missing embedded fan level packs in Content/LevelPacks." >&2
      exit 1
    fi
    mkdir -p "$resources_dir/LevelPacks"
    python3 "$project_dir/Tools/FanLevelCatalog/prune.py" "$project_dir/Content/LevelPacks"
    rsync -a --include='*.zip' --include='*.json' --exclude='*' \
      "$project_dir/Content/LevelPacks/" "$resources_dir/LevelPacks/"
    rsync "${copy_options[@]}" "$project_dir/Sources/Ports/" "$resources_dir/Ports/"
    zsh "$project_dir/Scripts/prepare-holiday-data.sh" "$resources_dir"
    python3 "$project_dir/Tools/MacArtwork/prepare.py" "$resources_dir/MacArtwork"
    python3 "$project_dir/Tools/AmigaArtwork/prepare.py" "$resources_dir/AmigaArtwork"
    mkdir -p "$project_dir/.build/asset-packager"
    swiftc -swift-version 6 -warnings-as-errors "$project_dir/Tools/BundleGameAssets/main.swift" \
      -o "$project_dir/.build/asset-packager/CopyResourceForks"
    "$project_dir/.build/asset-packager/CopyResourceForks" "$project_dir/Sources/Ports" "$resources_dir/Ports"
    ;;
  l2)
    mkdir -p "$resources_dir/Ports/Lemm2" "$resources_dir/Music/lemmings_2_music_mod_tsyu"
    rsync "${copy_options[@]}" "$project_dir/Sources/Ports/Lemm2/" "$resources_dir/Ports/Lemm2/"
    ;;
  l3)
    mkdir -p "$resources_dir/Ports/LEM3CD" "$resources_dir/Music/lemmings_3_music_mod_tsyu"
    rsync "${copy_options[@]}" "$project_dir/Sources/Ports/LEM3CD/" "$resources_dir/Ports/LEM3CD/"
    ;;
esac

music_game=all
[[ "$2" == l2 ]] && music_game=lemmings2
[[ "$2" == l3 ]] && music_game=lemmings3
python3 "$project_dir/Tools/MusicCatalogue/library.py" bundle \
  --output "$resources_dir/Music" --game "$music_game" --scope "$music_bundle"
# Upgrades replace the app bundle, so an update must carry the full soundtrack
# that earlier builds bundled. Ship AAC copies to stay below 2 GiB.
if [[ "$music_bundle" == full ]]; then
  zsh "$project_dir/Scripts/compact-bundled-music.sh" "$resources_dir/Music"
  python3 "$project_dir/Tools/MusicCatalogue/library.py" playback --output "$resources_dir/Music"
fi

# Standalone sequel players share the in-game profile and Trolley artwork.
if [[ "$2" == l2 || "$2" == l3 ]]; then
  python3 "$project_dir/Tools/MacArtwork/prepare.py" "$resources_dir/MacArtwork"
fi

if [[ "$2" == all || "$2" == l2 ]]; then
  python3 "$project_dir/Tools/Lemmings2Reference/prepare-assets.py" \
    "$project_dir/Sources/Ports/Lemm2" "$resources_dir/Ports/Lemm2"
fi

python3 "$project_dir/Tools/TrolleyVerification/catalogue.py" bundle "$resources_dir/Trolley"

mkdir -p "$resources_dir/GameCenter"
cp "$project_dir/Resources/GameCenter/leaderboards.json" "$resources_dir/GameCenter/leaderboards.json"
