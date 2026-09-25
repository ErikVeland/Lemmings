#!/bin/zsh
project_dir="${0:A:h:h}"
exec "$project_dir/Scripts/check-release-inputs.sh" "$@"
