"""Generate one-command timing probes from bounded Classic solver near-wins."""

import argparse
import copy
import hashlib
import json
from pathlib import Path


def identity(row):
    item = row["entry"]["identity"]
    return item["packID"], item["levelID"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("solver_output", type=Path)
    parser.add_argument("audit", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--minimum", type=int, default=1)
    parser.add_argument("--radius", type=int, default=60)
    parser.add_argument("--pair-radius", type=int, default=0)
    parser.add_argument("--pair-max-events", type=int, default=5)
    parser.add_argument("--pairs-only", action="store_true")
    args = parser.parse_args()
    if args.minimum < 1 or args.radius < args.minimum or args.pair_radius < 0 or args.pair_max_events < 2:
        parser.error("require 1 <= minimum <= radius; pair radius must be non-negative")
    if args.pairs_only and not args.pair_radius:
        parser.error("pairs-only requires a positive pair radius")

    rows = json.loads(args.audit.read_text())
    by_directory = {
        hashlib.sha256("\0".join(identity(row)).encode()).hexdigest()[:12]: row
        for row in rows if not row["official"]
    }
    args.output.mkdir(parents=True, exist_ok=True)
    selected = {}
    variants = []
    for path in sorted((args.solver_output / "per-level").glob("*/*.partial.json")):
        if path.parent.name not in by_directory:
            continue
        row = by_directory[path.parent.name]
        replay = json.loads(path.read_text())
        if replay["initialStateHash"] != row["initialHash"]:
            raise ValueError(f"partial route has a different initial state: {path}")
        selected[identity(row)] = row
        assignments = [index for index, event in enumerate(replay["events"])
                       if "assign" in event["action"]]
        if not args.pairs_only:
            for index in assignments:
                for distance in range(args.minimum, args.radius + 1):
                    for shift in (-distance, distance):
                        tick = replay["events"][index]["tick"] + shift
                        if tick < 0:
                            continue
                        candidate = copy.deepcopy(replay)
                        candidate["events"][index]["tick"] = tick
                        name = (f"{replay['initialStateHash']}-{path.parent.name}-event{index}"
                                f"-{'m' if shift < 0 else 'p'}{distance}.json")
                        destination = args.output / name
                        destination.write_text(json.dumps(candidate, separators=(",", ":")))
                        variants.append({"identity": row["entry"]["identity"], "partial": str(path),
                                         "edits": [[index, shift]], "candidate": str(destination)})
        if args.pair_radius and 2 <= len(assignments) <= args.pair_max_events:
            offsets = [shift for distance in range(1, args.pair_radius + 1)
                       for shift in (-distance, distance)]
            for left in range(len(assignments)):
                for right in range(left + 1, len(assignments)):
                    first, second = assignments[left], assignments[right]
                    for first_shift in offsets:
                        for second_shift in offsets:
                            first_tick = replay["events"][first]["tick"] + first_shift
                            second_tick = replay["events"][second]["tick"] + second_shift
                            if first_tick < 0 or second_tick < 0:
                                continue
                            candidate = copy.deepcopy(replay)
                            candidate["events"][first]["tick"] = first_tick
                            candidate["events"][second]["tick"] = second_tick
                            sign = lambda value: ("m" if value < 0 else "p") + str(abs(value))
                            name = (f"{replay['initialStateHash']}-{path.parent.name}"
                                    f"-pair{first}{second}-{sign(first_shift)}-{sign(second_shift)}.json")
                            destination = args.output / name
                            destination.write_text(json.dumps(candidate, separators=(",", ":")))
                            variants.append({"identity": row["entry"]["identity"], "partial": str(path),
                                             "edits": [[first, first_shift], [second, second_shift]],
                                             "candidate": str(destination)})
    (args.output.parent / "input-audit.json").write_text(
        json.dumps([selected[key] for key in sorted(selected)], indent=2) + "\n"
    )
    (args.output.parent / "retime-manifest.json").write_text(json.dumps(variants, indent=2) + "\n")
    print(f"Prepared {len(variants)} timing variants for {len(selected)} solver near-wins.")


if __name__ == "__main__":
    main()
