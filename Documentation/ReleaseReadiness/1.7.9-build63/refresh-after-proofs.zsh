#!/bin/zsh
set -euo pipefail
cd /Users/veland/.codex/worktrees/release-1-7-9/Lemmings
root="$PWD/.build/release-1.7.9"
lib="$PWD/.build/trolley-verification"
ports="$PWD/.build/local/Ultimate Lemmings.app/Contents/Resources/Ports"
swiftc -O -swift-version 6 -I "$lib/modules" -L "$lib" -lNxlvKit -Xlinker -rpath -Xlinker "$lib" Tools/ClassicCompletion/main.swift -o "$root/ClassicVerify"
"$root/ClassicVerify" verify "$ports/lemmings_dos_1991-07-30" > "$root/classic-verify.log" 2>&1
python3 Tools/ClassicCompletion/report.py > "$root/classic-manifest.log" 2>&1
CAMPAIGN_TEST_LIBRARY_DIR="$lib" OFFICIAL_QUEST_REPORT="$root/classic-quest.json" zsh Scripts/verify-official-classic.sh --include-conversions > "$root/classic-quest.log" 2>&1
L3_TEST_LIBRARY_DIR="$lib" zsh Scripts/verify-l3-completion.sh > "$root/l3-completion.log" 2>&1
python3 Tools/SolutionReplays/generate.py --check
engine_fingerprint="$(python3 Tools/TrolleyVerification/catalogue.py fingerprint)"
swiftc -O -swift-version 6 -I "$lib/modules" -L "$lib" -lNxlvKit -Xlinker -rpath -Xlinker "$lib" Tools/LevelHints/main.swift -o "$root/ExportHints"
"$root/ExportHints" "$ports/lemmings_dos_1991-07-30" Resources/Trolley Resources/Hints/classic.json "$engine_fingerprint" > "$root/hints.log" 2>&1
python3 Tools/TrolleyVerification/catalogue.py check
