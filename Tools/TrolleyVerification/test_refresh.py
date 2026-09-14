"""Check explicit outcome refresh without weakening published rescue targets."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('verifier', type=Path)
    parser.add_argument('resources', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix='classic-certificate-refresh-') as directory:
        project = Path(directory)
        for name in ['Sources', 'Tools', 'Tests']:
            (project / name).symlink_to(root / name, target_is_directory=True)
        proof_root = project / 'Resources/Trolley'
        shutil.copytree(root / 'Resources/Trolley', proof_root)
        catalogue_path = proof_root / 'verified-maxima.json'
        catalogue = json.loads(catalogue_path.read_text())
        row = next(r for r in catalogue['levels'] if r['conditions']['gameID'] == 'lemmings'
                   and r['conditions']['levelID'] == 'level-63')
        witness_path = proof_root / row['witness']['path']
        replay = json.loads(witness_path.read_text())
        # A changed stored outcome is rejected by the default audit even when
        # its input sequence still wins. Keep its byte hash valid for this test.
        replay['expected']['ticks'] += 1
        witness_path.write_text(json.dumps(replay))
        from hashlib import sha256
        row['witness']['sha256'] = sha256(witness_path.read_bytes()).hexdigest()
        catalogue_path.write_text(json.dumps(catalogue))

        def run(name, refresh):
            output = project / name
            env = dict(os.environ, TROLLEY_RESOURCES=str(args.resources.resolve()),
                       TROLLEY_OUTPUT=str(output))
            command = [str(args.verifier.resolve()), 'classic', '--shard=63/120']
            if refresh:
                command.append('--refresh-outcomes')
            result = subprocess.run(command, cwd=project, env=env, capture_output=True, text=True)
            assert result.returncode == 0, result.stdout + result.stderr
            audit = json.loads((output / 'classic-63.json').read_text())
            return next(r for r in audit['levels'] if r['gameID'] == 'lemmings'), output

        current, _ = run('strict', False)
        assert current.get('witness') is None and current['notes'], current
        current, output = run('refresh', True)
        assert current['witness']['saved'] >= row['witness']['saved']
        print('PASS explicit refresh reproduces a current outcome; default audit rejects stale outcomes')
        row['witness']['saved'] = row['population'] + 1
        catalogue_path.write_text(json.dumps(catalogue))
        current, _ = run('regression', True)
        assert any('rescue target regressed' in n for n in current['notes']), current
        assert current['witness']['saved'] < row['witness']['saved']
        print('PASS explicit refresh cannot lower a published rescue target')


if __name__ == '__main__':
    main()
