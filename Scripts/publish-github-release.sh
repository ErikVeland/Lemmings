#!/bin/zsh
# Publish a signed Sparkle update and its appcast to GitHub.
set -euo pipefail

project_dir="${0:A:h:h}"
update_zip="${1:?Usage: publish-github-release.sh UPDATE_ZIP}"
appcast_path="${APPCAST_PATH:-$project_dir/appcast.xml}"
release_notes="${RELEASE_NOTES_PATH:?Set RELEASE_NOTES_PATH to the release notes file.}"
release_tag="${RELEASE_TAG:?Set RELEASE_TAG to the GitHub release tag.}"
repository="${GITHUB_REPOSITORY:-ErikVeland/Lemmings}"
version="${RELEASE_VERSION:?Set RELEASE_VERSION to the application version.}"
source_revision="${RELEASE_COMMIT:-$(git -C "$project_dir" rev-parse HEAD)}"

fail() {
  print -u2 "FAILED: $*"
  exit 1
}

[[ -f "$update_zip" ]] || fail "Update archive does not exist: $update_zip"
[[ -f "$appcast_path" ]] || fail "Appcast does not exist: $appcast_path"
[[ -f "$release_notes" ]] || fail "Release notes do not exist: $release_notes"
[[ "$repository" == */* ]] || fail "GITHUB_REPOSITORY must be OWNER/REPOSITORY."
command -v gh >/dev/null 2>&1 || fail "The GitHub CLI is required for publishing."
gh auth status >/dev/null 2>&1 || fail "Authenticate the GitHub CLI before publishing."

if gh release view "$release_tag" --repo "$repository" >/dev/null 2>&1; then
  print "==> Updating GitHub release $release_tag"
  gh release upload "$release_tag" "$update_zip" --repo "$repository" --clobber
else
  print "==> Creating GitHub release $release_tag"
  gh release create "$release_tag" "$update_zip" \
    --repo "$repository" \
    --target "$source_revision" \
    --title "Ultimate Lemmings $version" \
    --notes-file "$release_notes"
fi

print "==> Publishing appcast.xml to the main branch"
remote_sha="$(gh api "repos/$repository/contents/appcast.xml?ref=main" --jq '.sha' 2>/dev/null || true)"
content="$(base64 < "$appcast_path" | tr -d '\n')"
request=(
  --method PUT
  "repos/$repository/contents/appcast.xml"
  -f "message=Publish $version update feed"
  -f "content=$content"
  -f "branch=main"
)
[[ -n "$remote_sha" ]] && request+=(-f "sha=$remote_sha")
gh api "${request[@]}"
print "Published $release_tag and appcast.xml to $repository"
