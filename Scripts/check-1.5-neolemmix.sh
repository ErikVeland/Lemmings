#!/bin/zsh
# Validate the 1.5 NeoLemmix source and optional reference-corpus gates.
set -euo pipefail

project_dir="${0:A:h:h}"
oracle_version="NeoLemmix Community Edition 1.2.0"
oracle_commit="38d0449f87501798e78ac668a9494848f4aa9649"
ce_root=""
replays_root=""
require_ce_corpus=0
require_runnable_corpus=0

usage() {
  print -u2 "Usage: zsh Scripts/check-1.5-neolemmix.sh [--ce-root PATH] [--replays-root PATH] [--require-ce-corpus] [--require-runnable-corpus]"
}

while (( $# > 0 )); do
  case "$1" in
    --ce-root)
      (( $# >= 2 )) || { usage; exit 2; }
      ce_root="${2:A}"
      shift 2
      ;;
    --replays-root)
      (( $# >= 2 )) || { usage; exit 2; }
      replays_root="${2:A}"
      shift 2
      ;;
    --require-ce-corpus)
      require_ce_corpus=1
      shift
      ;;
    --require-runnable-corpus)
      require_ce_corpus=1
      require_runnable_corpus=1
      shift
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

cd "$project_dir"

developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
if [[ "$developer_dir" == "/Library/Developer/CommandLineTools" \
    && -d /Applications/Xcode.app/Contents/Developer ]]; then
  developer_dir=/Applications/Xcode.app/Contents/Developer
fi
export DEVELOPER_DIR="$developer_dir"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$project_dir/.build/module-cache/neolemmix-1.5}"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

if ! xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
  print -u2 "FAILED: A matching macOS SDK and Swift 6 toolchain are required."
  exit 1
fi

print "Oracle contract: $oracle_version at $oracle_commit"
zsh Scripts/run-nxlv-style-resolver-tests.sh
zsh Scripts/run-nxlv-renderer-tests.sh
zsh Scripts/run-neolemmix-simulation-tests.sh
zsh Scripts/run-neolemmix-replay-tests.sh
zsh Scripts/run-neolemmix-end-to-end.sh
print "PASS 1.5 parser, style, renderer, simulation, replay-import and end-to-end source gates"

if [[ -n "$ce_root" ]]; then
  [[ -d "$ce_root/data/external/levels" && -d "$ce_root/data/external/styles" ]] || {
    print -u2 "FAILED: $ce_root does not contain the CE levels and styles directories."
    exit 1
  }
  actual_commit="$(git -C "$ce_root" rev-parse HEAD)"
  if [[ "$actual_commit" != "$oracle_commit" ]]; then
    print -u2 "FAILED: CE oracle commit is $actual_commit; expected $oracle_commit."
    exit 1
  fi
  grep -Eq 'MAJOR_VERSION = 1;' "$ce_root/LemVersion.pas"
  grep -Eq 'MINOR_VERSION = 2;' "$ce_root/LemVersion.pas"
  grep -Eq 'HOTFIX_VERSION = 0;' "$ce_root/LemVersion.pas"
  corpus_arguments=(
    "$ce_root/data/external/levels"
    "$ce_root/data/external/styles"
  )
  if (( require_runnable_corpus )); then
    corpus_arguments+=(--require-runnable)
  fi
  zsh Scripts/run-nxlv-corpus-diagnostics.sh "${corpus_arguments[@]}"
  print "PASS pinned CE 1.2.0 level import, render and supported-simulation corpus gate"
else
  if (( require_ce_corpus )); then
    print -u2 "FAILED: --require-ce-corpus needs --ce-root PATH."
    exit 1
  fi
  print "OPEN CE level corpus gate: rerun with --ce-root PATH --require-ce-corpus"
fi

if [[ -n "$replays_root" ]]; then
  zsh Scripts/run-nxrp-corpus-diagnostics.sh "$replays_root"
  print "PASS supplied NXRP import corpus gate"
else
  print "OPEN reference replay corpus and native replay-result comparison"
fi
