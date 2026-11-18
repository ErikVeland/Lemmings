#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
action=build
case "${1:-}" in
  --check) shift; exec python3 "$project_dir/Tools/Publication/publication.py" check "$@" ;;
  --sync) shift; exec python3 "$project_dir/Tools/Publication/publication.py" sync "$@" ;;
  --dry-run) shift; action=plan ;;
esac
exec python3 "$project_dir/Tools/Publication/publication.py" "$action" "$@"
