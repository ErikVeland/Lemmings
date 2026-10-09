#!/bin/zsh
# Validate release inputs that do not need commercial level data.
set -euo pipefail

project_dir="${0:A:h:h}"
allow_empty=0

while (( $# )); do
  case "$1" in
    --allow-empty-appcast) allow_empty=1 ;;
    --help|-h)
      print "Usage: zsh Scripts/check-1.2-release-inputs.sh [--allow-empty-appcast]"
      exit 0
      ;;
    *)
      print -u2 "Unknown option: $1"
      exit 2
      ;;
  esac
  shift
done

args=(--root "$project_dir")
(( allow_empty )) && args+=(--allow-empty-appcast)
python3 "$project_dir/Tools/ReleaseReadiness/automatic_updates.py" "${args[@]}"
git -C "$project_dir" diff --check
print "PASS data-independent 1.2 release checks"
