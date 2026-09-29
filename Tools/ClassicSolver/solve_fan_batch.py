"""Run bounded ClassicSolver searches on unscored fan levels with a resume ledger."""

import argparse
import hashlib
import json
import pathlib
import re
import shutil
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
    parser.add_argument("--rate", type=int)
    parser.add_argument("--fallback", type=int, default=170)
    parser.add_argument("--refire", type=int, default=120)
    parser.add_argument("--save-partials", action="store_true")
    parser.add_argument("--max-levels", type=int, default=0)
    parser.add_argument("--order", choices=("hash", "score", "near-win"), default="hash")
    parser.add_argument("--include-structural", action="store_true")
    args = parser.parse_args()
    if args.rate is not None and not 1 <= args.rate <= 99:
        parser.error("--rate must be between 1 and 99")
    args.output.mkdir(parents=True, exist_ok=True)
    solver_revision = hashlib.sha256(args.solver.read_bytes()).hexdigest()
    ledger_path = args.output / "attempts.jsonl"
    def identity(row):
        item = row["entry"]["identity"] if "entry" in row else row["identity"]
        return item["packID"], item["levelID"]

    def completed_search(row):
        return re.search(r"\b(?:UNSOLVED|SOLVED) fan:", row["result"]) is not None

    previous = {}
    if ledger_path.exists():
        for line in ledger_path.read_text().splitlines():
            entry = json.loads(line)
            key = identity(entry)
            if completed_search(entry) or key not in previous:
                previous[key] = entry
    rows = json.loads(args.audit.read_text())
    evidence_path = pathlib.Path(__file__).resolve().parents[2] / "Artifacts/LearningJourney/fan-evidence.json"
    verified_identities = set()
    if evidence_path.exists():
        verified_identities = {
            identity(row)
            for row in json.loads(evidence_path.read_text())
            if row["profile"]["confidence"] != "low"
        }
    limits_path = pathlib.Path(__file__).resolve().parents[2] / "Artifacts/DifficultyEvaluation/classic-structural-limits.json"
    structural_identities = {
        identity(row) for row in json.loads(limits_path.read_text())["records"]
    } if limits_path.exists() else set()
    packs = {}
    for pack in (args.resources / "LevelPacks").glob("*.zip"):
        prefix = pack.name.split("-", 1)[0]
        if prefix.isdigit():
            packs["fan:lldb-" + str(int(prefix))] = pack
    attempted = solved = failed = 0
    def ordering(item):
        if args.order == "score":
            return item["profile"]["overallScore"], item["initialHash"] or ""
        if args.order == "near-win":
            old = previous.get(identity(item), {})
            match = re.search(r"best saved (\d+)/(\d+)", old.get("result", ""))
            saved, required = map(int, match.groups()) if match else (0, 1)
            return (-saved / max(1, required), max(0, required - saved),
                    item["profile"]["overallScore"], item["initialHash"] or "")
        return item["initialHash"] or ""
    for row in sorted(rows, key=ordering):
        if (row["official"] or not row["playable"] or row["profile"]["confidence"] != "low"
                or identity(row) in verified_identities
                or (identity(row) in structural_identities and not args.include_structural)):
            continue
        digest = row["initialHash"]
        old = previous.get(identity(row))
        prior_search_ran = old and completed_search(old)
        if (prior_search_ran and old.get("solverRevision") == solver_revision
                and old.get("rate") == args.rate
                and old.get("fallback", 170) == args.fallback
                and old.get("refire", 120) == args.refire
                and (old.get("savePartials", False) or not args.save_partials)
                and old["seconds"] >= args.seconds and old["width"] >= args.width):
            continue
        pack = packs.get(row["entry"]["identity"]["packID"])
        if pack is None:
            failed += 1
            continue
        identity_digest = hashlib.sha256("\0".join(identity(row)).encode()).hexdigest()[:12]
        level_output = args.output / "per-level" / identity_digest
        level_output.mkdir(parents=True, exist_ok=True)
        candidate = level_output / (digest + ".json")
        command = [str(args.solver), "fan:" + str(pack),
                   str(row["entry"]["levelNumberSnapshot"]), str(level_output),
                   "--resources", str(args.resources), "--seconds", str(args.seconds),
                   "--width", str(args.width), "--fallback", str(args.fallback),
                   "--refire", str(args.refire), "--hash-named"]
        if args.rate is not None:
            command.extend(["--rate", str(args.rate)])
        if args.save_partials:
            command.append("--partial-out")
        started = time.monotonic()
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        did_solve = result.returncode == 0 and candidate.exists()
        if did_solve:
            shutil.copyfile(candidate, args.output / (digest + "-" + identity_digest + ".json"))
        record = {"hash": digest, "identity": row["entry"]["identity"],
                  "seconds": args.seconds, "width": args.width,
                  "rate": args.rate,
                  "fallback": args.fallback, "refire": args.refire,
                  "savePartials": args.save_partials,
                  "solverRevision": solver_revision,
                  "elapsed": round(time.monotonic() - started, 2),
                  "solved": did_solve,
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
