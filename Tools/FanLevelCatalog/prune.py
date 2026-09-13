#!/usr/bin/env python3
"""Remove reviewed broken DAT records while preserving surviving slot identities."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sections(data):
    result, offset = [], 0
    while offset < len(data):
        if offset + 10 > len(data):
            raise ValueError("Truncated DAT header")
        size = struct.unpack_from(">H", data, offset + 8)[0]
        if size <= 10 or offset + size > len(data):
            raise ValueError("Invalid DAT section length")
        result.append(data[offset:offset + size])
        offset += size
    return result


def prune(data, removals):
    by_member = {}
    for item in removals:
        slots = by_member.setdefault(item["member"], set())
        if item["slot"] in slots:
            raise ValueError("Duplicate removal")
        slots.add(item["slot"])
    output, mappings = io.BytesIO(), {}
    with zipfile.ZipFile(io.BytesIO(data)) as source:
        names = source.namelist()
        if len(names) != len(set(names)) or "classic-section-slots.json" in names:
            raise ValueError("Ambiguous or already mapped source archive")
        if not set(by_member).issubset(names):
            raise ValueError("Removal member is absent")
        with zipfile.ZipFile(output, "w") as target:
            for entry in source.infolist():
                content = source.read(entry)
                if entry.filename in by_member:
                    records = sections(content)
                    removed = by_member[entry.filename]
                    if not removed.issubset(range(len(records))):
                        raise ValueError("Removal slot is absent")
                    keep = [i for i in range(len(records)) if i not in removed]
                    if not keep:
                        raise ValueError("Whole-member removal needs separate review")
                    # Keep each compressed record byte-for-byte. DAT parts are independent.
                    content = b"".join(records[i] for i in keep)
                    mappings[entry.filename] = keep
                elif entry.filename.lower().endswith(".dat") and not Path(entry.filename).name.lower().startswith(("ground", "vgagr", "vgaspec")):
                    mappings[entry.filename] = list(range(len(sections(content))))
                target.writestr(entry, content)
            entry = zipfile.ZipInfo("classic-section-slots.json", (2026, 9, 13, 0, 0, 0))
            entry.external_attr = 0o100644 << 16
            target.writestr(entry, json.dumps(mappings, sort_keys=True, separators=(",", ":")) + "\n")
    return output.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    manifest = json.loads((ROOT / "Documentation/FanLevelPruning.json").read_text())
    changed = 0
    for pack in manifest["packs"]:
        path = args.folder / pack["pack"]
        data = path.read_bytes()
        if digest(data) == pack["prunedSHA256"]:
            continue
        if digest(data) != pack["originalSHA256"]:
            raise ValueError("Unreviewed archive: " + pack["pack"])
        if not args.apply:
            raise ValueError("Unpruned archive: " + pack["pack"])
        result = prune(data, pack["remove"])
        if digest(result) != pack["prunedSHA256"]:
            raise ValueError("Pruned archive differs from reviewed result: " + pack["pack"])
        temporary = path.with_suffix(".pruning")
        temporary.write_bytes(result)
        temporary.replace(path)
        changed += 1
    print(f"PASS {len(manifest['packs'])} pruned fan archives; {changed} updated")


if __name__ == "__main__":
    main()
