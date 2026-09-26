#!/bin/zsh
# Launch a packaged app as a new user and fail on a launch-time fault.
# The integration tests compile the app sources again. This test runs the
# signed bundle that ships.
set -euo pipefail

app="${1:?Usage: run-launch-smoke-test.sh APP [SECONDS]}"
seconds="${2:-${LAUNCH_SMOKE_SECONDS:-15}}"
app="${app:A}"
executable="$app/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")"

fail() {
  print -u2 "FAILED: $*"
  exit 1
}

[[ -x "$executable" ]] || fail "No executable in $app"

# Hardened runtime does not load code from a different team. codesign
# --verify --deep does not detect this, so compare each nested item.
team_of() {
  codesign -dv "$1" 2>&1 | sed -n 's/^TeamIdentifier=//p'
}
app_team="$(team_of "$app")"
if [[ -n "$app_team" && "$app_team" != "not set" ]]; then
  for code in "$app"/Contents/Frameworks/*(N) "$app"/Contents/Frameworks/*.framework/Versions/Current/{XPCServices/*.xpc,Autoupdate,Updater.app}(N); do
    [[ "$(team_of "$code")" == "$app_team" ]] ||
      fail "${code#$app/} is not signed by team $app_team"
  done
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/lemmings-launch-smoke.XXXXXX")"
log="$scratch/launch.log"
pid=""
cleanup() {
  [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  rm -rf "$scratch"
}
trap cleanup EXIT

# An empty home gives the first-launch path. AppKit logs an exception from
# a delegate callback and then continues with a partly launched app.
# NSApplicationCrashOnExceptions makes it stop instead, also when hardened
# runtime hides the log. OS_ACTIVITY_DT_MODE sends the log to stderr where
# the signature permits it.
mkdir -p "$scratch/home"
CFFIXED_USER_HOME="$scratch/home" OS_ACTIVITY_DT_MODE=YES LEMMINGS_LAUNCH_TRACE=1 \
  "$executable" -NSApplicationCrashOnExceptions YES > "$log" 2>&1 &
pid=$!

for (( elapsed = 0; elapsed < seconds; elapsed++ )); do
  sleep 1
  kill -0 "$pid" 2>/dev/null || break
done

faults='uncaught exception|Assertion failure|NSInternalInconsistencyException|NSRangeException|Library not loaded|Fatal error'
if ! kill -0 "$pid" 2>/dev/null; then
  wait "$pid" && code=0 || code=$?
  pid=""
  grep -E "$faults" "$log" | head -5 >&2 || true
  fail "The app quit during launch (exit $code): $app"
fi
if grep -qE "$faults" "$log"; then
  grep -E -A 12 "$faults" "$log" | head -30 >&2
  fail "The app reported a fault during launch: $app"
fi
python3 - "$log" "${LAUNCH_READY_SECONDS:-5}" <<'PYTIMING'
import pathlib, sys
rows = [line.split() for line in pathlib.Path(sys.argv[1]).read_text().splitlines()
        if line.startswith('LAUNCH ')]
times = {row[2]: float(row[1]) for row in rows}
if 'first-frame' not in times or 'music-start' not in times:
    raise SystemExit('FAILED: launch did not present its first frame and start music')
if times['first-frame'] > float(sys.argv[2]):
    raise SystemExit(f"FAILED: first frame took {times['first-frame']:.3f}s")
if times['music-start'] < times['first-frame']:
    raise SystemExit('FAILED: music started before the first frame')
print(f"PASS first frame {times['first-frame']:.3f}s; music starts after the frame")
PYTIMING
print "PASS launch smoke test ($seconds s, empty home): $app"
