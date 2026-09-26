#!/bin/zsh
# Publish a signed Sparkle update and its appcast to GitHub.
set -euo pipefail

project_dir="${0:A:h:h}"
check_only=0
if [[ "${1:-}" == --check ]]; then
  check_only=1
  shift
fi
update_zip="${1:?Usage: publish-github-release.sh [--check] UPDATE_ZIP}"
appcast_path="${APPCAST_PATH:-$project_dir/appcast.xml}"
release_notes="${RELEASE_NOTES_PATH:?Set RELEASE_NOTES_PATH to the release notes file.}"
release_tag="${RELEASE_TAG:?Set RELEASE_TAG to the GitHub release tag.}"
repository="${GITHUB_REPOSITORY:-ErikVeland/Lemmings}"
version="${RELEASE_VERSION:?Set RELEASE_VERSION to the application version.}"
source_revision="${RELEASE_COMMIT:-$(git -C "$project_dir" rev-parse HEAD)}"
approval="${RELEASE_APPROVED:-0}"
# Optional slim fresh-install archive. The appcast never offers it.
download_zip="${DOWNLOAD_ZIP:-}"

fail() {
  print -u2 "FAILED: $*"
  exit 1
}

[[ -f "$update_zip" ]] || fail "Update archive does not exist: $update_zip"
[[ -f "$appcast_path" ]] || fail "Appcast does not exist: $appcast_path"
[[ -f "$release_notes" ]] || fail "Release notes do not exist: $release_notes"
[[ "$repository" == */* ]] || fail "GITHUB_REPOSITORY must be OWNER/REPOSITORY."
if (( ! check_only )); then
  [[ "$approval" == 1 ]] || fail "Set RELEASE_APPROVED=1 only after the release checks are recorded."
fi
git -C "$project_dir" rev-parse --verify "$source_revision^{commit}" >/dev/null 2>&1 ||
  fail "RELEASE_COMMIT does not resolve to a local commit."
grep -Fqx "Release commit: $source_revision" "$release_notes" ||
  fail "The stamped release notes do not match RELEASE_COMMIT."
build_number="$(sed -n 's/^Build: //p' "$release_notes")"
[[ "$build_number" == <-> ]] || fail "The release notes need one numeric build number."
[[ "${update_zip:t}" == "UltimateLemmings-$version-build$build_number.zip" ]] ||
  fail "The update archive name does not match the release notes."
if [[ -n "$download_zip" ]]; then
  [[ -f "$download_zip" ]] || fail "The download archive does not exist: $download_zip"
  [[ "${download_zip:t}" == "UltimateLemmings-$version-build$build_number-slim.zip" ]] ||
    fail "The download archive name does not match the release notes."
  ! grep -Fq "${download_zip:t}" "$appcast_path" ||
    fail "The appcast must not offer the slim download."
fi
python3 - "$project_dir" "$appcast_path" "$version" "$build_number" \
  "$update_zip" "$source_revision" <<'CHECK_APPCAST' ||
import sys
from pathlib import Path
from urllib.parse import urlparse
from xml.etree import ElementTree

root, appcast, version, build, archive_path, commit = sys.argv[1:]
archive = Path(archive_path)
sys.path.insert(0, str(Path(root) / "Tools/ReleaseReadiness"))
from automatic_updates import SPARKLE_NAMESPACE, validate_appcast

validate_appcast(appcast, expected_release=(version, build))
items = ElementTree.parse(appcast).getroot().findall("./channel/item")
matching = []
for item in items:
    enclosure = item.find("enclosure")
    release_version = item.findtext(f"{{{SPARKLE_NAMESPACE}}}shortVersionString") or enclosure.get(
        f"{{{SPARKLE_NAMESPACE}}}shortVersionString"
    )
    release_build = item.findtext(f"{{{SPARKLE_NAMESPACE}}}version") or enclosure.get(
        f"{{{SPARKLE_NAMESPACE}}}version"
    )
    if (release_version, release_build) == (version, build):
        matching.append(item)
if len(matching) != 1:
    raise SystemExit("FAILED: the appcast needs exactly one entry for this build.")
item = matching[0]
enclosure = item.find("enclosure")
if Path(urlparse(enclosure.get("url")).path).name != archive.name:
    raise SystemExit("FAILED: the appcast does not point to this update archive.")
if enclosure.get("length") != str(archive.stat().st_size):
    raise SystemExit("FAILED: the appcast archive length does not match this update archive.")
if f"Release commit: {commit}" not in (item.findtext("description") or ""):
    raise SystemExit("FAILED: the appcast notes do not match the frozen commit.")
CHECK_APPCAST
  fail "The signed appcast does not match the release archive."
if (( check_only )); then
  print "PASS publication inputs for $version build $build_number at $source_revision"
  exit 0
fi
command -v gh >/dev/null 2>&1 || fail "The GitHub CLI is required for publishing."
gh auth status >/dev/null 2>&1 || fail "Authenticate the GitHub CLI before publishing."

if gh release view "$release_tag" --repo "$repository" >/dev/null 2>&1; then
  print "==> Updating GitHub release $release_tag"
  gh release upload "$release_tag" "$update_zip" ${download_zip:+"$download_zip"} --repo "$repository" --clobber
else
  print "==> Creating GitHub release $release_tag"
  gh release create "$release_tag" "$update_zip" ${download_zip:+"$download_zip"} \
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
