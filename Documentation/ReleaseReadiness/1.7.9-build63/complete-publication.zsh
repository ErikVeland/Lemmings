#!/bin/zsh
set -euo pipefail
cd /Users/veland/.codex/worktrees/release-1-7-9/Lemmings
root="$PWD/.build/release-1.7.9"
while true; do
  if xcrun notarytool info 4b341a68-e113-4ad1-afe6-8ebb19edb915 --keychain-profile lemmings-beta --output-format json > "$root/standard-notary-status.next" 2> "$root/notary-poll-error.log"; then
    status_value="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["status"])' "$root/standard-notary-status.next")"
    mv "$root/standard-notary-status.next" "$root/standard-notary-status.json"
    print "$(date -u +%FT%TZ) Apple: $status_value"
    [[ "$status_value" == Accepted ]] && break
    [[ "$status_value" == 'In Progress' ]] || exit 1
  else
    print "$(date -u +%FT%TZ) Apple status access failed; retaining prior status"
  fi
  sleep 60
done
zsh "$root/finalise-standard.zsh" > "$root/finalise-standard.log" 2>&1
print 'PASS full archive finalised'
zsh "$root/prepare-feed.zsh" > "$root/feed-verification.log" 2>&1
print 'PASS signed feed prepared'
export RELEASE_TAG=v1.7.9 RELEASE_VERSION=1.7.9
export RELEASE_COMMIT=4d8cda805cd938df919776498193cdd10ff48714
export RELEASE_NOTES_PATH="$root/ReleaseNotes-1.7.9-build63.md"
export DOWNLOAD_ZIP="$root/downloads/UltimateLemmings-1.7.9-build63-slim.zip"
export RELEASE_EXPECTED_APPCAST_SHA=e57919019d29f435b4c7fc4842cf0f26a226b4cd
export RELEASE_APPROVED=1
zsh "$root/publish-guarded.zsh" --check "$root/updates/UltimateLemmings-1.7.9-build63.zip"
zsh "$root/publish-guarded.zsh" "$root/updates/UltimateLemmings-1.7.9-build63.zip" > "$root/publish.log" 2>&1
print 'PASS release and feed published'
python3 "$root/verify-public.py" > "$root/public-verification.log" 2>&1
print 'PASS public downloads and feed verified'
