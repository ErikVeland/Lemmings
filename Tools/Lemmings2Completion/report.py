"""Manifest for preserved Lemmings 2 routes, independent of the runtime suite."""
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
import sys

project = Path(__file__).resolve().parents[2]
output = project / 'Documentation/Lemmings2Completion/evidence.json'
source = project / 'Tests/Lemmings2CompletionTests/Fixtures'
fixtures = []
for path in sorted(source.glob('*.json')):
    data = path.read_bytes()
    value = json.loads(data)
    tribe, number = path.stem.rsplit('-', 1)
    fixtures.append({'fixture': str(path.relative_to(project)),
                     'sha256': sha256(data).hexdigest(),
                     'tribe': tribe, 'level': int(number),
                     'levelSHA256': value['levelSHA256'],
                     'startingPopulation': value['population'],
                     'saved': value['expectedSaved'],
                     'ticks': value['expectedTicks']})
bare = sum(1 for f in fixtures if f['saved'] == 1)
manifest = {'schemaVersion': 1,
            'coverage': dict(Counter(f['tribe'] for f in fixtures)),
            'quality': {'bareSurvivals': bare},
            'fixtures': fixtures}
if '--check' in sys.argv:
    assert output.exists() and json.loads(output.read_text()) == manifest, \
        'Lemmings 2 fixtures changed, disappeared or lack a matching manifest.'
    print(f'PASS {len(fixtures)} Lemmings 2 fixture hashes and coverage manifest')
else:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest['coverage']))
