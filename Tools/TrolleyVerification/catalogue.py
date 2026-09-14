#!/usr/bin/env python3
"""Package completed native-engine audits. Unknown bounds stay unknown."""
import argparse
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
import shutil

PROJECT = Path(__file__).resolve().parents[2]
EXPECTED = {
    "lemmings": 120, "xmasLemmings1991": 4, "ohNoMoreLemmings": 100,
    "xmasLemmings1992": 4, "lemmings2": 120, "holidayLemmings1993": 32,
    "ohYesMoreLemmings": 60, "lemmings3": 90, "holidayLemmings1994": 32,
}
NAMES = {
    "lemmings": "Lemmings", "xmasLemmings1991": "Xmas Lemmings 1991",
    "ohNoMoreLemmings": "Oh No! More Lemmings", "xmasLemmings1992": "Xmas Lemmings 1992",
    "lemmings2": "Lemmings 2: The Tribes", "holidayLemmings1993": "Holiday Lemmings 1993",
    "ohYesMoreLemmings": "Oh Yes! More Lemmings", "lemmings3": "All New World of Lemmings",
    "holidayLemmings1994": "Holiday Lemmings 1994",
}


# These files route input or store presentation preferences. Replays bypass them.
PRESENTATION_FILES = set(json.loads((Path(__file__).with_name("presentation-files.json")).read_text()))


def fingerprint():
    files = {p.name: sha256(p.read_bytes()).hexdigest()
             for p in (PROJECT / "Sources/NxlvKit").glob("*.swift")
             if not p.name.startswith(("Trolley", "Arcade")) and p.name not in PRESENTATION_FILES}
    return sha256(json.dumps(files, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, sort_keys=True, indent=2, ensure_ascii=False) + "\n")


def witness_file(root, row):
    witness = row["witness"]
    path = Path(witness["path"])
    if path.is_absolute() or path.parts[0] != "witnesses" or ".." in path.parts:
        raise ValueError("Invalid witness path")
    file = root / path
    if sha256(file.read_bytes()).hexdigest() != witness["sha256"]:
        raise ValueError(f"Witness hash mismatch: {file}")
    return file


def is_population_proof(row):
    c, w = row.get("conditions"), row.get("witness")
    return bool(c and w and row["status"] == "VERIFIED"
                and row["population"] == c["population"] == row.get("maximumSaveable")
                == w["saved"] == w["released"]
                and row.get("minimumSacrifices") == w["lost"] == w["retainedReserves"] == 0
                and w["completed"] and w["didWin"]
                and c.get("startingSkills", {}).get("cloner", 0) == 0)


def is_rescue_record(row):
    c, w = row.get("conditions"), row.get("witness")
    return bool(c and w and row["status"] == "REPLAY_RECORD"
                and row["population"] == c["population"] == w["released"]
                and row.get("maximumSaveable") is None and row.get("minimumSacrifices") is None
                and c["rescueRequirement"] <= w["saved"] < w["released"]
                and 0 <= w["lost"] <= w["released"] - w["saved"] and w["retainedReserves"] == 0
                and w["completed"] and w["didWin"] and c.get("startingSkills", {}).get("cloner", 0) == 0)


def validate_catalogue(root):
    data = json.loads((root / "verified-maxima.json").read_text())
    if data["schemaVersion"] != 1:
        raise ValueError("Unsupported catalogue version")
    identities = set()
    for row in data["levels"]:
        if not (is_population_proof(row) or is_rescue_record(row)):
            raise ValueError("Catalogue contains an unproven maximum")
        identity = json.dumps(row["conditions"], sort_keys=True)
        if identity in identities:
            raise ValueError("Duplicate proof conditions")
        identities.add(identity)
        witness_file(root, row)
    return data


def require_retained_targets(rows, published):
    current = {json.dumps(row["conditions"], sort_keys=True): row
               for row in rows if row.get("conditions")}
    for previous in published:
        row = current.get(json.dumps(previous["conditions"], sort_keys=True))
        if not row or not row.get("witness") or row["witness"]["saved"] < previous["witness"]["saved"]:
            raise ValueError("Published rescue target was not reproduced: "
                             + previous.get("title", previous["conditions"]["levelID"]))


def merge(results, shards):
    paths = [results / f"classic-{i}.json" for i in range(shards)]
    paths += [results / f"{name}.json" for name in ("ports", "l2", "l3")]
    audits = [json.loads(p.read_text()) for p in paths]
    engine = fingerprint()
    if any(a["engineSourceFingerprint"] != engine for a in audits):
        raise ValueError("Engine sources changed. Replay the audit before packaging proofs.")
    rows = []
    for path, audit in zip(paths, audits):
        # Earlier audit versions enumerated the converted pack with the classics.
        # Its dedicated audit supplies the actual asset-loading check.
        rows.extend(r for r in audit["levels"]
                    if not (path.name.startswith("classic-") and r["gameID"] == "ohYesMoreLemmings"))
    identities = [(r["gameID"], r["rank"], r["number"], r["population"]) for r in rows]
    if len(set(identities)) != len(identities):
        raise ValueError("Duplicate level/population configurations")
    unique = {(r["gameID"], r["rank"], r["number"]) for r in rows}
    coverage = dict(Counter(game for game, _, _ in unique))
    if coverage != EXPECTED:
        raise ValueError(f"Incomplete campaign coverage: {coverage}, expected {EXPECTED}")
    order = {game: i for i, game in enumerate(EXPECTED)}
    rows.sort(key=lambda r: (order[r["gameID"]], r["rank"], r["number"], -r["population"]))
    report_dir = PROJECT / "Documentation/TrolleyVerification"
    proof_dir = PROJECT / "Resources/Trolley"
    if (proof_dir / "verified-maxima.json").exists():
        require_retained_targets(rows, validate_catalogue(proof_dir)["levels"])
    report_dir.mkdir(parents=True, exist_ok=True)
    proof_dir.mkdir(parents=True, exist_ok=True)
    for row in rows:
        if row.get("witness"):
            source = witness_file(results, row)
            destination = report_dir / row["witness"]["path"]
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
        if row["status"] == "VERIFIED" and not is_population_proof(row):
            raise ValueError("An audit claims verification without a population-bound proof")
    proof_rows = [r for r in rows if is_population_proof(r)]
    records = json.loads((PROJECT / "Documentation/ClassicCompletion/evidence.json").read_text())
    targets = {(r["fixture"].split("/")[-1].split("-")[0], int(r["fixture"].split("-")[-1].split(".")[0])): r for r in records["fixtures"]}
    record_rows = []
    for row in rows:
        if row["gameID"] != "lemmings" or row["status"] != "OBSERVED":
            continue
        reference = targets[(row["rank"].lower(), row["number"])]
        candidate = dict(row, status="REPLAY_RECORD")
        if not is_rescue_record(candidate) or row["witness"]["saved"] != reference["publishedDOSRecord"]:
            raise ValueError("Classic rescue record does not match its native witness")
        record_rows.append(candidate)
    for row in proof_rows + record_rows:
        destination = proof_dir / row["witness"]["path"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(witness_file(results, row), destination)
    common = {"schemaVersion": 1, "generatedAt": max(a["generatedAt"] for a in audits),
              "engineSourceFingerprint": engine, "exhaustive": False}
    write_json(report_dir / "audit.json", {**common, "levels": rows})
    write_json(proof_dir / "verified-maxima.json", {**common, "levels": proof_rows + record_rows})
    (proof_dir / "engine-fingerprint.txt").write_text(engine + "\n")
    validate_catalogue(proof_dir)

    primary = [r for r in rows if r["gameID"] != "lemmings2" or r["population"] == 60]
    counts = Counter(r["status"] for r in primary)
    lines = ["# Rescue maximum verification", "",
             f"This audit covered {len(primary)} bundled level identities. It produced {counts['VERIFIED']} proven maxima "
             f"and {counts['OBSERVED']} completed solutions without optimality proofs. It collected no winning witness for "
             f"{counts['UNKNOWN']} levels. Classic Lemmings has a winning replay for every level. Coverage of the other campaigns remains incomplete.", "",
             "See the [level-by-level results](levels.md) for every campaign level and the [full evidence data](audit.json) for exact conditions and notes.", "",
             f"The audit tried {sum(r['testedCandidates'] for r in rows):,} candidate runs. Failed searches do not establish an optimum.", "",
             "Maximum saveable means the population minus unavoidable sacrifices. A successful solution "
             "proves that its saved count is achievable. It does not prove that its deaths are necessary. "
             "The bundled certificates currently require a completed, repeatable rescue of the entire finite population.", "",
             "| Campaign | Levels | Maximum proven | Winning witness | No witness collected |",
             "| --- | ---: | ---: | ---: | ---: |"]
    for game, expected in EXPECTED.items():
        count = Counter(r["status"] for r in primary if r["gameID"] == game)
        lines.append(f"| {NAMES[game]} | {expected} | {count['VERIFIED']} | {count['OBSERVED']} | {count['UNKNOWN']} |")
    carry_over = [r for r in rows if r["gameID"] == "lemmings2" and r["population"] != 60]
    lines += ["", f"Tribes uses 60 Lemmings for the campaign audit. Preserved fixtures also cover {len(carry_over)} "
              "carry-over configurations. Each certificate applies only to its exact population.", "",
              "Chronicles keeps unreleased Lemmings in reserve. They are survivors, not sacrifices. "
              "Fixed-input L3 completion fixtures are checked twice with their level hashes, exact starting population, "
              "accepted inputs, terminal state and retained reserves. Uncovered levels receive a no-input check. See "
              "[the completion fixtures](../../Tests/Lemmings3CompletionTests/Fixtures) and "
              "[verification tools](../../Tools/Lemmings3Completion).", "",
              "All 120 Classic Lemmings levels now have saved winning replays on the native engine. "
              "The strict completion gate checks every assignment and repeats each result from a fresh simulation. "
              "These replays are imported into this rescue audit. See "
              "[the completion report](../ClassicCompletion/README.md) and "
              "[the replay fixtures](../../Tests/ClassicDOSCompletionTests/Fixtures). "
              "The older 510-tick smoke test remains a separate load-and-movement check.", "",
              "The converted Oh Yes! pack resolves artwork by source rank. Sunsoft ground metadata and its special "
              "picture override the shared original graphics. Its audit uses the same lookup as the app.", "",
              "Classic searches sample one skill assignment to the first Lemming at ticks 36 through 600, "
              "in steps of eight, and abandon new candidates at the first death. This searches for zero-loss rescues "
              "and can miss ordinary winning solutions. Cached winning replays are checked again. Tribes replays the existing runtime "
              "fixtures, including recorded fan inputs. All full-rescue witnesses are replayed twice before certification. "
              "Search failure never establishes an unavoidable sacrifice.", "",
              "The [community maximum-saved records](https://www.lemmingsforums.net/index.php?topic=1383.0) "
              "provide reference targets for the original releases, including 100% for every DOS Tribes level. "
              "Those records include port and glitch differences. They are not imported as native-engine proofs.", "",
              "## Proven campaign targets", "",
              "| Campaign | Level | Saveable | Necessary sacrifices | Replay |",
              "| --- | --- | ---: | ---: | --- |"]
    for row in primary:
        if row["status"] == "VERIFIED":
            label = f"{row['rank']} {row['number']}: {row['title']}".replace("|", "\\|")
            lines.append(f"| {NAMES[row['gameID']]} | {label} | {row['maximumSaveable']}/{row['population']} "
                         f"| 0 | [Witness]({row['witness']['path']}) |")
    lines += ["", "## Reproduce", "", "Run `zsh Scripts/verify-trolley-maxima.sh` from the repository. "
              "The bundled game data must already exist in `.build/local/Ultimate Lemmings.app`. "
              "Set `TROLLEY_AUDIT_JOBS` to control the number of Classic audit processes (default: 8).", "",
              "The script compiles the current engines, replays solutions, checks all 562 level identities, "
              "and packages valid certificates. `audit.json` contains every level and its evidence status. "
              "The `witnesses` folder preserves completed solutions. Rejected candidates do not become records.", "",
              "App builds stamp the current engine sources. Certificates require an exact stamp and exact "
              "level conditions. Changed engine sources, level data, population, skills, time, or modifiers "
              "cannot inherit a certificate. Expired bundled evidence is removed from current targets, "
              "while historical attempt snapshots remain unchanged. Minimum pass requirements and optional retries remain unchanged.", ""]
    (report_dir / "README.md").write_text("\n".join(lines))
    detail = ["# Level-by-level rescue audit", "",
              "A dash means this pass did not establish the value. No witness collected does not mean no known solution or an unsolvable level. "
              "The pass omits existing scripted completion cases and rejects new Classic search candidates at the first death. "
              "Best rescued refers only to witnesses collected by this pass, not all prior demonstrations. "
              "The pass goal remains the engine's minimum requirement. Chronicles reserves are survivors and do not count as sacrifices.", "",
              "See [method and limitations](README.md) and [exact conditions and evidence](audit.json).", ""]
    for game in EXPECTED:
        detail += [f"## {NAMES[game]}", "",
                   "| Level | Population | Pass goal | Best rescued | Verified maximum | Minimum sacrifices | Evidence |",
                   "| --- | ---: | ---: | ---: | ---: | ---: | --- |"]
        for row in rows:
            if row["gameID"] != game:
                continue
            label = f"{row['rank']} {row['number']}: {row['title']}".replace("|", "\\|")
            if game == "lemmings2" and row["population"] != 60:
                label += " (carry-over)"
            status = "No witness collected" if row["status"] == "UNKNOWN" else row["status"].capitalize()
            if row.get("witness"):
                status = f"[{status}]({row['witness']['path']})"
            detail.append(f"| {label} | {row['population']} | {row['required']} | {row.get('bestSaved', '—')} "
                          f"| {row.get('maximumSaveable', '—')} | {row.get('minimumSacrifices', '—')} | {status} |")
        detail.append("")
    (report_dir / "levels.md").write_text("\n".join(detail))
    print(f"Audited {len(primary)} levels ({len(rows)} configurations): {dict(counts)}")
    print(f"Packaged {len(proof_rows)} exact-condition certificates and {len(record_rows)} best-known rescue targets.")


def bundle(destination):
    source = PROJECT / "Resources/Trolley"
    destination.mkdir(parents=True, exist_ok=True)
    data = validate_catalogue(source)
    shutil.copytree(source, destination, dirs_exist_ok=True)
    current = fingerprint()
    (destination / "engine-fingerprint.txt").write_text(current + "\n")
    if data["engineSourceFingerprint"] != current:
        print("Trolley certificates are stale for this engine. The app will leave those targets unverified.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("fingerprint")
    p = commands.add_parser("merge")
    p.add_argument("--results", type=Path, default=PROJECT / ".build/trolley-verification/results")
    p.add_argument("--shards", type=int, default=8)
    p = commands.add_parser("bundle")
    p.add_argument("destination", type=Path)
    commands.add_parser("check")
    args = parser.parse_args()
    if args.command == "fingerprint":
        print(fingerprint())
    elif args.command == "merge":
        merge(args.results, args.shards)
    elif args.command == "bundle":
        bundle(args.destination)
    else:
        data = validate_catalogue(PROJECT / "Resources/Trolley")
        if data["engineSourceFingerprint"] != fingerprint():
            raise ValueError("Certificates do not match the current engine sources")
        print(f"PASS {sum(is_population_proof(r) for r in data['levels'])} proofs, {sum(is_rescue_record(r) for r in data['levels'])} rescue records, and replay hashes")
