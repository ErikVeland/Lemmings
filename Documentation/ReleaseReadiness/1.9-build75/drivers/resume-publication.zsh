#!/bin/zsh
set -euo pipefail
cd /Users/veland/Lemmings
root="$PWD/.build/release-1.9"
revision="$(cat "$root/source-commit.txt")"
[[ "$(git rev-parse HEAD)" == "$revision" ]]
export RELEASE_TAG=v1.9 RELEASE_VERSION=1.9 RELEASE_COMMIT="$revision" RELEASE_NOTES_PATH="$root/ReleaseNotes-1.9-build75.md" DOWNLOAD_ZIP="$root/downloads/UltimateLemmings-1.9-build75-slim.zip"
zsh Scripts/publish-github-release.sh --check "$root/updates/UltimateLemmings-1.9-build75.zip"
git fetch origin main
git merge-base --is-ancestor origin/main "$revision"
git push origin "${revision}:refs/heads/main"
RELEASE_APPROVED=1 zsh Scripts/publish-github-release.sh "$root/updates/UltimateLemmings-1.9-build75.zip"
python3 "$root/verify-live.py"
