"""Exercise carry-over validation with real Egyptian campaign replays."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

verifier, data_root = map(lambda p: str(Path(p).resolve()), sys.argv[1:3])
project = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='lemmings2-chain-gate-') as directory:
    root = Path(directory)
    fixtures, chains = root / 'Fixtures', root / 'Chains'
    fixtures.mkdir()
    chains.mkdir()
    for name in ['egyptian-01.json', 'egyptian-02.json']:
        shutil.copy2(project / 'Tests/Lemmings2CompletionTests/Fixtures' / name, fixtures / name)
    route = chains / 'egyptian-02.json'
    original = (project / 'Tests/Lemmings2CompletionTests/Chains/egyptian-02.json').read_bytes()
    route.write_bytes(original)
    env = dict(os.environ, L2_COMPLETION_FIXTURES=str(fixtures), L2_COMPLETION_CHAINS=str(chains))

    def run(*arguments):
        return subprocess.run([verifier, data_root, *arguments], env=env, capture_output=True, text=True)

    valid = run()
    assert valid.returncode == 0 and 'CHAIN egyptian: 2/10 levels' in valid.stdout, valid.stdout + valid.stderr
    strict = run('--require-all')
    assert strict.returncode != 0 and 'Strict completion requires all twelve continuous tribe runs.' in strict.stdout, strict.stdout + strict.stderr
    print('PASS incomplete campaign rejected in strict mode')
    for field, value in [('levelSHA256', '0' * 64), ('expectedSaved', 15), ('version', 99), ('population', 0)]:
        fields = json.loads(original)
        fields[field] = value
        route.write_text(json.dumps(fields))
        result = run()
        assert result.returncode != 0, f'Accepted changed carry-over {field}'
        print(f'PASS changed carry-over {field} rejected')
    route.write_bytes((fixtures / 'egyptian-02.json').read_bytes())
    assert run().returncode != 0, 'Accepted duplicate starting population'
    print('PASS duplicate starting population rejected')
    route.write_bytes(original)
    (chains / 'egyptian-03.json').write_bytes(original)
    assert run().returncode != 0, 'Accepted orphan carry-over witness'
    print('PASS orphan carry-over witness rejected')
print('PASS valid carry-over route accepted, strict gaps and six damaged cases rejected')
