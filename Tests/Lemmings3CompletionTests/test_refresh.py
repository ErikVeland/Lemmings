"""Check that same-level route refreshes revalidate source and replay evidence."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

verify, derive = map(lambda value: str(Path(value).resolve()), sys.argv[1:3])
source = Path('Tests/Lemmings3CompletionTests/Fixtures/113.json')
original = json.loads(source.read_text())

with tempfile.TemporaryDirectory(prefix='l3-refresh-') as directory:
    root = Path(directory)
    candidate = root / '113.json'
    refreshed = subprocess.run(
        [derive, '113', str(original['population']), str(source), str(candidate), '--refresh-engine'],
        env=os.environ, text=True, capture_output=True)
    assert refreshed.returncode == 0, refreshed.stderr
    result = json.loads(candidate.read_text())
    assert result['levelSHA256'] == original['levelSHA256']
    assert result['population'] == original['population']
    assert result['expected']['saved'] > 0
    assert 'REFRESHED L3 113' in refreshed.stdout

    verified = subprocess.run(
        [verify, 'verify', '113'],
        env=dict(os.environ, L3_COMPLETION_FIXTURES=str(root)),
        text=True, capture_output=True)
    assert verified.returncode == 0, verified.stderr

    changed = root / 'changed-level.json'
    invalid = dict(original, levelSHA256='0' * 64)
    changed.write_text(json.dumps(invalid))
    rejected_output = root / 'rejected.json'
    rejected = subprocess.run(
        [derive, '113', str(original['population']), str(changed), str(rejected_output), '--refresh-engine'],
        env=os.environ, text=True, capture_output=True)
    assert rejected.returncode != 0, 'Refresh accepted a changed level-data hash'
    assert 'level, data, population or input order differs' in rejected.stderr
    assert not rejected_output.exists(), 'Rejected refresh wrote a candidate'

print('PASS L3 same-level refresh, double replay, verifier integration and changed-source rejection')
