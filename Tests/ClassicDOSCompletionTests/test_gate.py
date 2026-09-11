#!/usr/bin/env python3
"""Check that incomplete or invalid replay evidence fails the completion gate."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('verifier', type=Path)
parser.add_argument('data', type=Path)
args = parser.parse_args()
project = Path(__file__).resolve().parents[2]
command = [str(args.verifier.resolve()), 'verify', str(args.data.resolve())]
with tempfile.TemporaryDirectory(prefix='classic-completion-') as directory:
    fixtures = Path(directory) / 'Fixtures'
    shutil.copytree(project / 'Tests/ClassicDOSCompletionTests/Fixtures', fixtures)
    environment = dict(os.environ, CLASSIC_COMPLETION_FIXTURES=str(fixtures))

    def rejects(extra, message):
        result = subprocess.run(command + extra, cwd=project, env=environment,
                                capture_output=True, text=True, check=False)
        assert result.returncode != 0 and message in result.stdout, result.stdout + result.stderr

    last = fixtures / 'mayhem-30.json'
    last.unlink()
    rejects([], 'UNVERIFIED Mayhem 30')
    shutil.copy2(project / 'Tests/ClassicDOSCompletionTests/Fixtures/mayhem-30.json', last)
    first = fixtures / 'fun-01.json'
    original = first.read_text()
    replay = json.loads(original)
    replay['events'].append({'tick': 61, 'action': {'assign': {'lemmingID': 0, 'skill': 'floater'}}})
    first.write_text(json.dumps(replay))
    rejects(['1'], 'assignment did not apply')
    replay = json.loads(original)
    replay['expected']['saved'] -= 1
    first.write_text(json.dumps(replay))
    rejects(['1'], 'outcome mismatch')
    second = fixtures / 'fun-02.json'
    before = second.read_bytes()
    plan = Path(directory) / 'lower-rescue-plan.json'
    plan.write_text(json.dumps([{'id': 0, 'skill': 'floater', 'tick': 54}]))
    result = subprocess.run([str(args.verifier.resolve()), 'plan', str(args.data.resolve()),
                             '2', str(plan)], cwd=project, env=environment,
                            capture_output=True, text=True, check=False)
    assert result.returncode == 0 and 'saved 1 lost 9' in result.stdout, result.stdout + result.stderr
    assert second.read_bytes() == before, 'A lower rescue count replaced the best replay'
print('PASS invalid evidence fails; a lower-rescue winning plan cannot replace the best replay.')
