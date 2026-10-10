#!/bin/zsh
set -euo pipefail
cd /Users/veland/.codex/worktrees/release-1-7-9/Lemmings
root="$PWD/.build/release-1.7.9"
[[ "$(git rev-parse HEAD)" == "$(cat "$root/source-commit.txt")" ]]
python3 Tools/ReleaseReadiness/update_notes.py "$root/ReleaseNotes-1.7.9-build63.md" "$root/updates/UltimateLemmings-1.7.9-build63.html"
DOWNLOAD_URL_PREFIX=https://github.com/ErikVeland/Lemmings/releases/download/v1.7.9/ SPARKLE_DISTRIBUTION_PATH=/Users/veland/Lemmings/.build/dependencies/Sparkle-2.7.3 APPCAST_PATH="$PWD/appcast.xml" zsh Scripts/generate-appcast.sh "$root/updates"
python3 - "$root" <<'PY'
from pathlib import Path
import re,sys
from xml.etree import ElementTree as ET
r=Path(sys.argv[1]);p=Path('appcast.xml');ns='http://www.andymatuschak.org/xml-namespaces/sparkle'
def key(s):
 i=ET.fromstring('<rss xmlns:sparkle="'+ns+'" xmlns:dc="http://purl.org/dc/elements/1.1/">'+s+'</rss>').find('item')
 return i.findtext('{'+ns+'}version') or i.find('enclosure').get('{'+ns+'}version')
old=re.findall(r'<item>.*?</item>',(r/'appcast-live-before.xml').read_text(),re.S)
new=p.read_text();present={key(s) for s in re.findall(r'<item>.*?</item>',new,re.S)}
missing=[s for s in old if key(s) not in present]
if missing:p.write_text(new.replace('</channel>','\n'.join(missing)+'\n    </channel>'))
print('Restored',len(missing),'historical feed items omitted by generator')
PY
swiftc "$root/verify-signature.swift" -o "$root/verify-signature"
python3 "$root/verify-feed.py"
zsh Scripts/check-release-inputs.sh
