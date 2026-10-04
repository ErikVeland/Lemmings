#!/bin/zsh
set -euo pipefail
cd /Users/veland/.codex/worktrees/release-1-7-9/Lemmings
root="$PWD/.build/release-1.7.9"
[[ "$(git rev-parse HEAD)" == "$(cat "$root/source-commit.txt")" ]]
python3 - "$root" <<'PY'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]);records=json.loads((root/'signed-candidates.json').read_text())
for row in records:
 p=Path(row['archive']);assert p.stat().st_size==row['bytes'];assert hashlib.file_digest(p.open('rb'),'sha256').hexdigest()==row['sha256']
print('PASS preserved submission hashes')
PY
for prefix in slim notary; do
  response="$root/$prefix-submission.json"
  [[ ! -s "$response" ]] || { print -u2 "Inspect existing submission response: $response"; exit 1; }
  xcrun notarytool submit "$root/$prefix-submission.zip" --keychain-profile lemmings-beta --output-format json --no-progress > "$response"
  python3 - "$response" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]));print('Submitted preserved ZIP:',p['id'])
PY
done
