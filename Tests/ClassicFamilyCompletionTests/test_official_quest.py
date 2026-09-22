"""Ensure failed official quest checks cannot replace a successful report."""
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile

if len(sys.argv) not in (3, 4) or (len(sys.argv) == 4 and sys.argv[3] != "--include-conversions"):
    raise SystemExit("Usage: test_official_quest.py TOOL PORTS [--include-conversions]")
tool, ports = map(str, map(Path, sys.argv[1:3]))
include_conversions = len(sys.argv) == 4
source = Path("Tests/ClassicDOSCompletionTests/Fixtures/fun-01.json")
original = json.loads(source.read_text())
with tempfile.TemporaryDirectory(prefix="official-quest-negative-") as directory:
    root = Path(directory)
    fixtures = root / "ClassicDOSCompletionTests/Fixtures"
    fixtures.mkdir(parents=True)
    report = root / "report.json"
    sentinel = b"previous successful evidence\n"
    environment = dict(os.environ, CLASSIC_QUEST_FIXTURES_ROOT=str(root))
    for case in ("missing", "changed outcome", "late input"):
        witness = json.loads(json.dumps(original))
        target = fixtures / source.name
        if case == "missing":
            expected_error = "file"
        else:
            if case == "changed outcome":
                witness["expected"]["saved"] -= 1
            else:
                event = dict(witness["events"][0])
                event["tick"] = witness["expected"]["ticks"] + 1
                event["afterTick"] = True
                witness["events"].append(event)
            target.write_text(json.dumps(witness))
            expected_error = "Session result differs"
        report.write_bytes(sentinel)
        result = subprocess.run([tool, ports, str(report)], env=environment,
                                text=True, capture_output=True)
        assert result.returncode != 0, f"{case}: invalid quest passed"
        assert expected_error in result.stderr, (case, result.stderr)
        assert report.read_bytes() == sentinel, f"{case}: evidence was replaced"
        print(f"PASS official quest rejects {case} and preserves prior evidence")

    if include_conversions:
        # A failure in the conversion chapter must not publish partial evidence.
        shutil.rmtree(fixtures)
        shutil.copytree(source.parent, fixtures)
        family = root / "ClassicFamilyCompletionTests/Fixtures"
        shutil.copytree(Path("Tests/ClassicFamilyCompletionTests/Fixtures"), family)
        target = family / "ohYesMoreLemmings/mega drive sunsoft-30.json"
        original_conversion = target.read_text()
        for case in ("missing conversion", "changed conversion outcome", "late conversion input"):
            if case == "missing conversion":
                target.unlink()
                expected_error = "file"
            else:
                witness = json.loads(original_conversion)
                if case == "changed conversion outcome":
                    witness["expected"]["saved"] -= 1
                else:
                    event = dict(witness["events"][0])
                    event["tick"] = witness["expected"]["ticks"] + 1
                    event["afterTick"] = True
                    witness["events"].append(event)
                target.write_text(json.dumps(witness))
                expected_error = "Session result differs"
            report.write_bytes(sentinel)
            result = subprocess.run([tool, ports, str(report), "--include-conversions"],
                                    env=environment, text=True, capture_output=True)
            assert result.returncode != 0, f"{case}: invalid quest passed"
            assert expected_error in result.stderr, (case, result.stderr)
            assert report.read_bytes() == sentinel, f"{case}: evidence was replaced"
            print(f"PASS Classic quest rejects {case} and preserves prior evidence")
