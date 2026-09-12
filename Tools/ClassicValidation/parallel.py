#!/usr/bin/env python3
"""Audit disjoint fan-pack partitions, then enforce the full corpus gate."""
import collections
import json
import os
from pathlib import Path
import subprocess
import sys

from report import report


def merge(parts, output):
    rows, packs = {}, {}
    for part in parts:
        for line in (part / "levels.jsonl").read_text().splitlines():
            row = json.loads(line)
            key = (row["collection"], row["source"])
            if key in rows:
                if row["collection"] == "fan" or rows[key] != row:
                    raise ValueError("Duplicate or conflicting level evidence: " + str(key))
            rows[key] = row
        for pack in json.loads((part / "packs.json").read_text()):
            if pack["pack"] in packs:
                raise ValueError("Duplicate pack partition: " + pack["pack"])
            packs[pack["pack"]] = pack
    counts = collections.defaultdict(collections.Counter)
    for row in rows.values():
        counts[row["collection"]][row["status"]] += 1
    (output / "levels.jsonl").write_text("".join(json.dumps(rows[key], sort_keys=True) + "\n" for key in sorted(rows)))
    (output / "packs.json").write_text(json.dumps(list(packs.values()), indent=2) + "\n")
    (output / "summary.json").write_text(json.dumps(counts, indent=2) + "\n")


def main():
    executable, resources, output, fixtures = map(lambda x: Path(x).resolve(), sys.argv[1:5])
    jobs = int(sys.argv[5]) if len(sys.argv) == 6 else 4
    if not 1 <= jobs <= 8:
        raise ValueError("Use one to eight audit processes")
    output.mkdir(parents=True, exist_ok=True)
    processes, parts, logs = [], [], []
    try:
        for index in range(jobs):
            part = output / f"part-{index}"
            part.mkdir(exist_ok=True)
            log = (part / "run.log").open("w")
            env = dict(os.environ, CLASSIC_AUDIT_PARTS=str(jobs), CLASSIC_AUDIT_PART=str(index))
            processes.append(subprocess.Popen([str(executable), str(resources), str(part), str(fixtures)], env=env, stdout=log, stderr=subprocess.STDOUT))
            parts.append(part)
            logs.append(log)
        statuses = [process.wait() for process in processes]
        if any(status not in (0, 1) for status in statuses):
            raise RuntimeError("Audit process failed: " + repr(statuses))
        merge(parts, output)
        return 0 if report(resources, output) else 1
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
                process.wait()
        for log in logs:
            log.close()


if __name__ == "__main__":
    sys.exit(main())
