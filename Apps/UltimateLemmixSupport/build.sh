#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h:h}"
platform="${1:?Choose ios or tvos.}"
shift
exec zsh "$project_dir/Scripts/build-publication.sh" ultimate-lemmix "$platform" "$@"
