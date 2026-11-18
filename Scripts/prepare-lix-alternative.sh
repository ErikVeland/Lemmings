#!/bin/zsh
# Prepare the pinned Lix graphics without launching the game or playing audio.
set -euo pipefail
project_dir="${0:A:h:h}"
export LEMMINGS_TEST_AUDIO=muted
export LEMMINGS_TEST_WINDOWS=offscreen
descriptor="$project_dir/Resources/AlternativeAssets/lix-source.json"
needs_source=1
for argument in "$@"; do
  case "$argument" in --verify|--self-test|--archive|--archive=*|--help|-h) needs_source=0 ;; esac
done
if (( needs_source )); then
  archive_name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["archive"]["filename"])' "$descriptor")"
  archive_url="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["archive"]["url"])' "$descriptor")"
  archive="$project_dir/.build/dependencies/$archive_name"
  if [[ ! -f "$archive" ]]; then
    mkdir -p "${archive:h}"
    partial="$(mktemp "${archive}.partial.XXXXXX")"
    trap 'rm -f "$partial"' EXIT
    curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
      --connect-timeout 20 --max-time 180 --max-filesize 6081876 \
      --output "$partial" "$archive_url"
    python3 "$project_dir/Tools/AlternativeAssets/prepare_lix.py" --check-archive "$partial"
    mv "$partial" "$archive"
  fi
fi
exec python3 "$project_dir/Tools/AlternativeAssets/prepare_lix.py" "$@"
