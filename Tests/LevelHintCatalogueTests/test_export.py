"""Check fresh hint export and reject changed routes without replacing the catalogue."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('exporter', type=Path)
parser.add_argument('ports', type=Path)
parser.add_argument('--played-route', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='lemmings-hint-export-') as temporary:
    directory = Path(temporary)
    output = directory / 'hints.json'
    solutions = directory / 'solutions.json'
    shutil.copy2(root / 'Resources/Hints/solutions.json', solutions)
    proofs = directory / 'Trolley'
    shutil.copytree(root / 'Resources/Trolley', proofs)
    fingerprint = (proofs / 'engine-fingerprint.txt').read_text().strip()
    command = [str(args.exporter.resolve()), str(args.ports.resolve() / 'lemmings_dos_1991-07-30'),
               str(proofs), str(output), fingerprint, str(args.ports.resolve()), str(solutions)]

    def run():
        return subprocess.run(command, cwd=root, capture_output=True, text=True)

    result = run()
    assert result.returncode == 0, result.stdout + result.stderr
    assert json.loads(output.read_text()) == json.loads((root / 'Resources/Hints/classic.json').read_text())
    before = output.read_bytes()
    routes = json.loads(solutions.read_text())
    fixture = json.loads((root / 'Tests/ClassicFamilyCompletionTests/Fixtures/ohNoMoreLemmings/tame-01.json').read_text())
    routes[fixture['initialStateHash']]['expected']['saved'] -= 1
    solutions.write_text(json.dumps(routes))
    result = run()
    assert result.returncode != 0, 'Changed winning outcome was accepted'
    assert output.read_bytes() == before, 'Failed export replaced the existing catalogue'
    shutil.copy2(root / 'Resources/Hints/solutions.json', solutions)

    if args.played_route:
        route = json.loads(args.played_route.read_text())
        catalogue_path = proofs / 'verified-maxima.json'
        catalogue = json.loads(catalogue_path.read_text())
        proof = next(p for p in catalogue['levels'] if p['gameID'] == 'lemmings' and p['rank'] == route['rank'] and p['number'] == route['number'])
        witness = proofs / proof['witness']['path']
        witness.write_text(json.dumps(route))
        proof['witness']['sha256'] = hashlib.sha256(witness.read_bytes()).hexdigest()
        catalogue_path.write_text(json.dumps(catalogue))
        result = run()
        assert result.returncode == 0, result.stdout + result.stderr
        level = next(p for p in json.loads(output.read_text())['levels'] if p['fingerprint'] == proof['conditions']['levelFingerprint'])
        assert level['opening'][0]['tick'] == next(e['tick'] for e in route['events'] if 'assign' in e['action'])
        print('PASS live input timing in checked hint export')
print('PASS reproducible Classic-family hint export and atomic rejection of changed winning outcomes')
