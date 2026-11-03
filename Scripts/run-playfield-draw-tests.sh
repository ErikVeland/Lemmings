#!/bin/zsh
# Compile the real app modules so the playfield checks follow shared dependencies.
set -euo pipefail
project_dir="${0:A:h:h}"
export TEST_SCOPE=playfield
exec zsh "$project_dir/Scripts/run-app-integration-tests.sh"
