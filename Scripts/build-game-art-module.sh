#!/bin/zsh
# Retain the existing entry point for scripts and external callers.
set -euo pipefail
project_dir="${0:A:h:h}"
exec zsh "$project_dir/Scripts/build-shared-modules.sh" "$@"
