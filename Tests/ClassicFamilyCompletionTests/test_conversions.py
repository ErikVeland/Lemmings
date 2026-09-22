"""Verify conversion artwork selection, route import and rejection of bad evidence."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("verifier", type=Path)
parser.add_argument("ports", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
verifier = str(args.verifier.resolve())
data = "conversion:" + str(args.ports.resolve())
with tempfile.TemporaryDirectory(prefix="conversion-gate-") as temporary:
    temporary = Path(temporary)
    fixtures = temporary / "fixtures"
    shutil.copytree(root / "Tests/ClassicFamilyCompletionTests/Fixtures/ohYesMoreLemmings", fixtures)
    environment = dict(os.environ, CLASSIC_COMPLETION_FIXTURES=str(fixtures))

    def run(mode, *extra, source=data):
        result = subprocess.run([verifier, mode, source, *map(str, extra)], cwd=root,
                                env=environment, capture_output=True, text=True)
        return result.returncode, result.stdout + result.stderr

    code, output = run("verify-known")
    assert code == 0, output
    # A missing route must fail even after every conversion has been solved.
    missing = fixtures / "lemmings versus-01.json"
    preserved = missing.read_bytes()
    missing.unlink()
    code, output = run("verify")
    assert code != 0 and "UNVERIFIED Lemmings Versus 1:" in output, output
    missing.write_bytes(preserved)
    for level, name in [(1, "lemmings versus-01.json"),
                        (26, "oh no! more lemmings versus-06.json"),
                        (31, "mega drive sunsoft-01.json")]:
        file = fixtures / name
        original = file.read_bytes()
        replay = json.loads(original)
        replay["expected"]["saved"] -= 1
        file.write_text(json.dumps(replay))
        code, output = run("verify", level)
        assert code != 0 and "outcome mismatch" in output, output
        replay = json.loads(original)
        replay["events"].append({"tick": replay["expected"]["ticks"] + 1,
                                 "afterTick": True, "action": {"releaseRate": {"_0": 99}}})
        file.write_text(json.dumps(replay))
        code, output = run("verify", level)
        assert code != 0 and "unconsumed inputs" in output, output
        candidates = temporary / str(level)
        candidates.mkdir()
        (candidates / name).write_bytes(original)
        file.unlink()
        code, output = run("recorded", level, candidates)
        assert code == 0 and "RECORDED" in output, output
        assert json.loads(file.read_bytes()) == json.loads(original), "Import changed the route"

    # Partial installed content must not shrink a 60-level release gate.
    partial = temporary / "ports"
    partial.mkdir()
    (partial / "Genesis-Sunsoft").symlink_to(args.ports.resolve() / "Genesis-Sunsoft", target_is_directory=True)
    code, output = run("verify-known", source="conversion:" + str(partial))
    assert code != 0 and "incomplete conversion campaign" in output, output
print("PASS conversion routes, recorded import, changed outcomes, late inputs and missing-rank rejection")
