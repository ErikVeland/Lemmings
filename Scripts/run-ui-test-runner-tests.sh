#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
build_dir="$project_dir/.build/ui-test-runner"
mkdir -p "$build_dir"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -framework AppKit -framework AVFoundation -o "$build_dir/placement-tests" Tests/UITestRunnerTests/main.swift
LEMMINGS_TEST_WINDOWS=offscreen python3 Tools/UITestRunner/run.py "$build_dir/placement-tests"
LEMMINGS_TEST_WINDOWS=offscreen python3 Tools/UITestRunner/run.py arch "-$(uname -m)" "$build_dir/placement-tests"
set +e
LEMMINGS_TEST_WINDOWS=offscreen python3 Tools/UITestRunner/run.py "$build_dir/placement-tests" --activate
result=$?
set -e
[[ "$result" == 2 ]] || { print -u2 "FAILED: desktop activation was not rejected ($result)"; exit 1; }
print "PASS quiet tests reject desktop activation"
