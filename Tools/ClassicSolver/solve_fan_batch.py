"""Run bounded ClassicSolver searches on unscored fan levels with a resume ledger."""

import argparse
import json
import pathlib
import subprocess
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("audit", type=pathlib.Path)
    parser.add_argument("resources", type=pathlib.Path)
    parser.add_argument("solver", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument("--seconds", type=float, default=5)
    parser.add_argument("--width", type=int, default=48)
    parser.add_argument("--max-levels", type=int, default=0)
    parser.add_argument("--order", choices=("hash", "score"), default="hash")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    ledger_path = args.output / "attempts.jsonl"
    previous = {}
    if ledger_path.exists():
        for line in ledger_path.read_text().splitlines():
            entry = json.loads(line)
            previous[entry["hash"]] = entry
    rows = json.loads(args.audit.read_text())
    packs = {}
    for pack in (args.resources / "LevelPacks").glob("*.zip"):
        prefix = pack.name.split("-", 1)[0]
        if prefix.isdigit():
            packs["fan:lldb-" + str(int(prefix))] = pack
    attempted = solved = failed = 0
    ordering = ((lambda item: (item["profile"]["overallScore"], item["initialHash"] or ""))
                if args.order == "score" else (lambda item: item["initialHash"] or ""))
    for row in sorted(rows, key=ordering):
        if row["official"] or not row["playable"] or row["profile"]["confidence"] != "low":
            continue
        digest = row["initialHash"]
        if (args.output / (digest + ".json")).exists():
            continue
        old = previous.get(digest)
        if old and old["seconds"] >= args.seconds and old["width"] >= args.width:
            continue
        pack = packs.get(row["entry"]["identity"]["packID"])
        if pack is None:
            failed += 1
            continue
        command = [str(args.solver), "fan:" + str(pack),
                   str(row["entry"]["levelNumberSnapshot"]), str(args.output),
                   "--resources", str(args.resources), "--seconds", str(args.seconds),
                   "--width", str(args.width), "--hash-named"]
        started = time.monotonic()
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        record = {"hash": digest, "identity": row["entry"]["identity"],
                  "seconds": args.seconds, "width": args.width,
                  "elapsed": round(time.monotonic() - started, 2),
                  "solved": result.returncode == 0 and (args.output / (digest + ".json")).exists(),
                  "result": (result.stdout + result.stderr).strip()[-500:]}
        with ledger_path.open("a") as ledger:
            ledger.write(json.dumps(record, sort_keys=True) + "\n")
        attempted += 1
        solved += record["solved"]
        failed += not record["solved"]
        print(f"{attempted}: {record['result']}", flush=True)
        if args.max_levels and attempted >= args.max_levels:
            break
    print(f"Attempted {attempted}; solver wins {solved}; unresolved or load errors {failed}.")


if __name__ == "__main__":
    main()
