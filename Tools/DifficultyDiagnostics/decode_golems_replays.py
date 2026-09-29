"""Decode cached LLDB Golems solutions into unverified Classic replay candidates.

The output is input for the native replay verifier. A published solution does
not count as a bundled-level win until that verifier accepts it.
"""

import argparse
import base64
import hashlib
import json
import re
import struct
import zlib
from collections import defaultdict
from pathlib import Path


SKILLS = {
    2: "climber", 3: "floater", 4: "bomber", 5: "blocker",
    6: "builder", 7: "basher", 8: "miner", 9: "digger",
}


def source_bytes(page, record_index):
    """Read the indexed replay fragment from a cached public level page."""
    fragments = list(dict.fromkeys(re.findall(r"#s=([^\"']+)", page.read_text())))
    fragment = fragments[record_index]
    encoded = fragment.lstrip("~")
    compressed = base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4))
    return compressed if fragment.startswith("~") else zlib.decompress(compressed, -15)


def decode(raw, abandon_as_nuke=False):
    """Return exact Golems cycles and actions from its four-byte header and steps."""
    if len(raw) < 4 or (len(raw) - 4) % 6:
        raise ValueError("invalid Golems replay length")
    cycle = -1
    rate = 0
    events = []
    for offset in range(4, len(raw), 6):
        cycle_delta, rate_delta, action, golem_index, _xy = struct.unpack_from(
            "<HBBBB", raw, offset)
        cycle += cycle_delta + 1
        rate = (rate + rate_delta) % 256
        if rate_delta:
            events.append({"tick": cycle, "afterTick": True,
                           "action": {"releaseRate": {"_0": rate}}})
        if action in SKILLS:
            events.append({"tick": cycle, "afterTick": True,
                           "action": {"assign": {"lemmingID": golem_index,
                                                 "skill": SKILLS[action]}}})
        elif action == 1 or (action == 10 and abandon_as_nuke
                             and offset == len(raw) - 6):
            events.append({"tick": cycle, "afterTick": True,
                           "action": {"nuke": {}}})
        elif action != 0:
            raise ValueError(f"unsupported Golems action {action}")
    return events


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("audit", type=Path)
    parser.add_argument("cache", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--abandon-as-nuke", action="store_true",
                        help="try a native nuke for a terminal Golems abandon action")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    rows = {json.dumps(row["entry"]["identity"], sort_keys=True): row
            for row in json.loads(args.audit.read_text())}
    pages = defaultdict(list)
    for page in args.cache.glob("lldb-*/*.html"):
        pages[page.name].append(page)
    candidates = []
    failures = []
    for record in json.loads(args.manifest.read_text()):
        identity = record["identity"]
        row = rows.get(json.dumps(identity, sort_keys=True))
        if row is None or row["profile"]["confidence"] != "low" or not row["playable"]:
            continue
        match = re.search(r"/level/(\d+)/(\d+)", record["url"])
        if match is None:
            failures.append({"identity": identity, "error": "invalid source URL"})
            continue
        page_name = "-".join(match.groups()) + ".html"
        for page in pages[page_name]:
            try:
                raw = source_bytes(page, record["recordIndex"])
                if hashlib.sha256(raw).hexdigest() != record["sourceReplaySHA256"]:
                    continue
                if (raw[0] & 15, raw[1], int.from_bytes(raw[2:4], "little")) != (
                    record["gameMode"], record["sourceSaved"], record["sourceTicks"]
                ):
                    raise ValueError("source header does not match manifest")
                replay = {
                    "rank": identity["packID"],
                    "number": row["entry"]["levelNumberSnapshot"],
                    "title": row["entry"]["levelNameSnapshot"],
                    "initialStateHash": row["initialHash"],
                    "events": decode(raw, abandon_as_nuke=args.abandon_as_nuke),
                }
                name = row["initialHash"] + "-" + record["sourceReplaySHA256"] + ".json"
                target = args.output / name
                target.write_text(json.dumps(replay, separators=(",", ":")) + "\n")
                translated = args.abandon_as_nuke and any(
                    raw[offset + 3] == 10 for offset in range(4, len(raw), 6))
                candidates.append({**record, "candidate": str(target),
                                   "translation": "terminal abandon to nuke" if translated else "exact actions"})
                break
            except (IndexError, ValueError, zlib.error) as error:
                failures.append({"identity": identity, "error": str(error)})
                break
        else:
            failures.append({"identity": identity, "error": "cached source replay not found"})
    (args.output / "manifest.json").write_text(json.dumps(candidates, indent=2) + "\n")
    (args.output / "failures.json").write_text(json.dumps(failures, indent=2) + "\n")
    print(f"Decoded {len(candidates)} source replays; {len(failures)} failed. Native wins remain unverified.")


if __name__ == "__main__":
    main()
