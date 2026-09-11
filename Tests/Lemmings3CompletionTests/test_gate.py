"""A missing or invalid selected-level witness must fail closed."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

binary = str(Path(sys.argv[1]).resolve())
source = Path('Tests/Lemmings3CompletionTests/Fixtures/001.json')
original = json.loads(source.read_text())
with tempfile.TemporaryDirectory(prefix='l3-replay-negative-') as directory:
    file = Path(directory) / '001.json'
    env = dict(os.environ, L3_COMPLETION_FIXTURES=directory)
    def run(value, expected):
        if value is None:
            if file.exists(): file.unlink()
        else:
            file.write_text(json.dumps(value))
        result = subprocess.run([binary, 'verify', '1'], env=env, capture_output=True)
        assert (result.returncode == 0) == expected, result.stdout.decode(errors='replace')[-300:]
    run(original, True)
    run(None, False)
    for change in ['population', 'level', 'number', 'outcome', 'actor', 'ordering']:
        changed = copy.deepcopy(original)
        if change == 'population': changed['population'] += 1
        elif change == 'level': changed['levelSHA256'] = '0' * 64
        elif change == 'number': changed['level'] += 1
        elif change == 'outcome': changed['expected']['saved'] += 1
        elif change == 'actor': changed['inputs'][0]['lemming'] = 999
        else: changed['inputs'].append(dict(changed['inputs'][0], tick=0))
        run(changed, False)
print('PASS L3 missing fixture, population, level hash, level number, outcome, rejected input and ordering gates')
