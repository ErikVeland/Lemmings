#!/bin/zsh
# Compile the source artwork into every standard macOS icon size.
set -euo pipefail

project_dir="${0:A:h:h}"
iconset_dir="$project_dir/.build/AppIcon.iconset"
output_path="${1:-$project_dir/.build/AppIcon.icns}"
source_path="$project_dir/Resources/AppIcon/AppIcon.png"
mkdir -p "$iconset_dir" "${output_path:h}"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$source_path" \
    --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
  retina_size=$((size * 2))
  sips -z "$retina_size" "$retina_size" "$source_path" \
    --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$iconset_dir" -o "$output_path"
