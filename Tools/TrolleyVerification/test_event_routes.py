"""Check that rescue certification consumes new L2 event routes strictly."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('verifier', type=Path)
    parser.add_argument('resources', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    original = json.loads((root / 'Tests/Lemmings2CompletionTests/Fixtures/outdoor-01.json').read_text())
    assert original['version'] == 2
    with tempfile.TemporaryDirectory(prefix='lemmings-certificate-events-') as temporary:
        project = Path(temporary)
        for name in ['Sources', 'Tools', 'Resources']:
            (project / name).symlink_to(root / name, target_is_directory=True)
        fixtures = project / 'Tests/Lemmings2CompletionTests/Fixtures'
        fixtures.mkdir(parents=True)
        fixture = fixtures / 'outdoor-01.json'

        def run(name, value):
            fixture.write_text(json.dumps(value))
            output = project / name
            env = dict(os.environ, TROLLEY_RESOURCES=str(args.resources.resolve()), TROLLEY_OUTPUT=str(output))
            result = subprocess.run([str(args.verifier.resolve()), 'l2', '--shard=70/120'],
                                    cwd=project, env=env, capture_output=True, text=True)
            assert result.returncode == 0, result.stdout + result.stderr
            audit = json.loads((output / 'l2-70.json').read_text())
            row = next(r for r in audit['levels'] if r['population'] == original['population'])
            assert row['rank'] == 'Outdoor' and row['number'] == 1
            return row, output

        row, output = run('valid', original)
        witness = row['witness']
        assert witness['saved'] == original['expectedSaved'] and witness['ticks'] == original['expectedTicks']
        replay = json.loads((output / witness['path']).read_text())
        assert replay['version'] == 2 and replay['events'] == original['events']
        print('PASS version 2 route retained its events and exact winning outcome')

        invalid = json.loads(json.dumps(original))
        invalid['events'].insert(0, {'tick': 0, 'event': {'assign': {'skill': 9999, 'lemming': 0}}})
        row, _ = run('refused', invalid)
        assert any('rejectedInput' in n for n in row['notes']), row
        assert row.get('witness') is None or row['witness']['ticks'] != original['expectedTicks']
        print('PASS refused L2 event cannot become a winning certificate')

        unused = json.loads(json.dumps(original))
        unused['events'].append({'tick': 999999, 'event': {'nuke': {}}})
        row, _ = run('unused', unused)
        assert any('before all inputs' in n for n in row['notes']), row
        print('PASS unused late L2 event cannot become a winning certificate')


if __name__ == "__main__":
    main()
