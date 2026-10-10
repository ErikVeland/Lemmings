#!/bin/zsh
# Sign the notarised update archives and write the public appcast.
set -euo pipefail

project_dir="${0:A:h:h}"
sparkle_version="2.7.3"
build_root="${LEMMINGS_BUILD_ROOT:-$project_dir/.build/dependencies}"
distribution_root="${SPARKLE_DISTRIBUTION_PATH:-$build_root/Sparkle-$sparkle_version}"
updates_dir="${1:-$project_dir/.build/updates}"
download_url_prefix="${DOWNLOAD_URL_PREFIX:-}"
appcast_path="${APPCAST_PATH:-$project_dir/appcast.xml}"

[[ -d "$updates_dir" ]] || {
  print -u2 "FAILED: update archive directory does not exist: $updates_dir"
  exit 1
}
[[ -n "$download_url_prefix" ]] || {
  print -u2 "FAILED: set DOWNLOAD_URL_PREFIX to the public HTTPS release URL."
  exit 1
}
[[ "$download_url_prefix" == https://* ]] || {
  print -u2 "FAILED: DOWNLOAD_URL_PREFIX must use HTTPS."
  exit 1
}

if [[ "$appcast_path" != "$updates_dir/appcast.xml" && -f "$appcast_path" ]]; then
  cp "$appcast_path" "$updates_dir/appcast.xml"
fi

if [[ ! -x "$distribution_root/bin/generate_appcast" ]]; then
  framework_path="$(LEMMINGS_BUILD_ROOT="$build_root" zsh "$project_dir/Scripts/ensure-sparkle.sh")"
  distribution_root="${framework_path:h:h:h}"
fi
generator="$distribution_root/bin/generate_appcast"
[[ -x "$generator" ]] || {
  print -u2 "FAILED: Sparkle generate_appcast was not found: $generator"
  exit 1
}

args=(
  --download-url-prefix "$download_url_prefix"
  --release-notes-url-prefix "$download_url_prefix"
  --link "https://github.com/ErikVeland/Lemmings/releases"
  --embed-release-notes
  -o "$appcast_path"
)
if [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  [[ -r "${SPARKLE_PRIVATE_KEY_FILE:A}" ]] || {
    print -u2 "FAILED: Sparkle private key file is not readable."
    exit 1
  }
  args+=(--ed-key-file "${SPARKLE_PRIVATE_KEY_FILE:A}")
fi

"$generator" "${args[@]}" "$updates_dir"
python3 - "$appcast_path" <<'PYAPPCAST'
import sys
from xml.etree import ElementTree

sparkle = "http://www.andymatuschak.org/xml-namespaces/sparkle"
root = ElementTree.parse(sys.argv[1]).getroot()
items = root.findall("./channel/item")
if not items:
    raise SystemExit("FAILED: generated appcast has no update items.")
for item in items:
    enclosure = item.find("enclosure")
    if enclosure is None:
        raise SystemExit("FAILED: generated appcast item has no enclosure.")
    if not enclosure.get("url", "").startswith("https://"):
        raise SystemExit("FAILED: generated appcast contains a non-HTTPS download URL.")
    if not enclosure.get("{%s}edSignature" % sparkle):
        raise SystemExit("FAILED: generated appcast contains an unsigned update.")
PYAPPCAST
print "Wrote signed appcast: $appcast_path"
