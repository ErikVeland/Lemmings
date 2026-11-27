"""Carry forward only the previously audited preservation-edition loading modules."""
import hashlib
import json
from pathlib import Path
import sys

manifest, source, target = map(Path, sys.argv[1:])
contents = {}
for entry in json.loads(manifest.read_text())["files"]:
    name = entry["name"]
    path = source / name
    if Path(name).name != name or not name.endswith(".mod") or name in contents or path.is_symlink():
        raise SystemExit("Invalid loading module filename.")
    data = path.read_bytes()
    if (len(data) != entry["bytes"] or hashlib.sha256(data).hexdigest() != entry["sha256"]
            or data[1080:1084] not in (b"M.K.", b"M!K!", b"4CHN", b"FLT4")):
        raise SystemExit(f"Loading module does not match its published manifest: {name}")
    contents[name] = data
credits = (source / "Cracktro credits.md").read_bytes()
if len(contents) != 11 or sum(map(len, contents.values())) != 224_498:
    raise SystemExit("Unexpected loading music inventory.")
target.mkdir(exist_ok=True)
for name, data in contents.items():
    (target / name).write_bytes(data)
(target / "Cracktro credits.md").write_bytes(credits)
print(f"Verified {len(contents)} previously published loading modules.")
