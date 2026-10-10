#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/beta-regressions"
app_dir="$project_dir/.build/local/Ultimate Lemmings.app"
mkdir -p "$build_dir/modules"
cd "$project_dir"
swiftc -swift-version 6 -O -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
suites=(ClassicGameFlowTests ClassicSettingsTests ClassicSoundCueTests AudioMatrixTests
  NeoLemmixSimulationTests NxlvRendererTests NxlvStyleResolverTests ClassicDOSSimulationRegressions
  ClassicDOSRewindTests ClassicDOSReplayTests ProTrackerTests PercussionTests AdaptiveDJDirectorTests
  FLICTests Lemmings2RuntimeTests Lemmings2IntroTests Lemmings3RuntimeTests Lemmings3SoundTests UnifiedGameTests ClassicSagaTests
  PlatformProfileTests AmigaSoundTests BundledGameResourcesTests PlatformExclusiveTests NeoLemmixEndToEnd)
failed=0
for suite in "${suites[@]}"; do
  flags=()
  args=()
  case "$suite" in
    NxlvRendererTests|NxlvStyleResolverTests) flags=(-parse-as-library) ;;
  esac
  case "$suite" in
    ClassicGameFlowTests|ClassicDOSSimulationRegressions|ClassicDOSRewindTests|ClassicDOSReplayTests)
      args=("$project_dir/Content/lemming1.pc") ;;
    Lemmings2RuntimeTests|Lemmings2IntroTests) args=("$project_dir/Sources/Ports/Lemm2") ;;
    Lemmings3RuntimeTests) args=("$project_dir/Sources/Ports/LEM3CD") ;;
    UnifiedGameTests) args=("$app_dir/Contents/Resources") ;;
    BundledGameResourcesTests) args=("$app_dir") ;;
  esac
  if swiftc -swift-version 6 -O "${flags[@]}" \
    -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
    -Xlinker -rpath -Xlinker "$build_dir" \
    -o "$build_dir/$suite" "Tests/$suite/main.swift" > "$build_dir/$suite.log" 2>&1 \
    && "$build_dir/$suite" "${args[@]}" >> "$build_dir/$suite.log" 2>&1; then
    echo "PASS $suite"
  else
    echo "FAIL $suite: $build_dir/$suite.log"
    failed=$((failed + 1))
  fi
done
(( failed == 0 ))
zsh Scripts/run-slim-packaging-tests.sh
zsh Scripts/run-crt-probe.sh
zsh Scripts/run-lemmings2-viewport-tests.sh
zsh Scripts/run-precision-zoom-tests.sh
zsh Scripts/run-dialog-cursor-tests.sh
zsh Scripts/run-playfield-draw-tests.sh
zsh Scripts/run-lemmings3-targeting-tests.sh
CAMPAIGN_TEST_LIBRARY_DIR="$build_dir" zsh Scripts/verify-campaign-completion.sh
echo "All ${#suites} beta regression suites passed."
