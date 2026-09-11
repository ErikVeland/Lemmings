"""Manifest for preserved campaign inputs, independent of discovery candidates."""
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
import sys

project = Path(__file__).resolve().parents[2]
output = project / 'Documentation/CampaignCompletion/evidence.json'
fixtures = []
for base in ['Tests/ClassicFamilyCompletionTests/Fixtures', 'Tests/Lemmings3CompletionTests/Fixtures']:
    for path in sorted((project / base).rglob('*.json')):
        data = path.read_bytes()
        value = json.loads(data)
        l3 = 'Lemmings3CompletionTests' in path.parts
        expected = value['expected']
        fixtures.append({'fixture': str(path.relative_to(project)), 'sha256': sha256(data).hexdigest(),
                         'game': 'lemmings3' if l3 else path.parent.name,
                         'level': value['level'] if l3 else f"{value['rank']} {value['number']}",
                         'saved': expected['saved'], 'lost': expected['lost'] if l3 else expected['released'] - expected['saved'],
                         'reserves': expected['reserves'] if l3 else 0,
                         'ticks': expected['ticks']})
manifest = {'schemaVersion': 1, 'coverage': dict(Counter(f['game'] for f in fixtures)), 'fixtures': fixtures}
if '--check' in sys.argv:
    assert json.loads(output.read_text()) == manifest, 'Campaign fixtures changed, disappeared or lack a matching manifest.'
    print(f'PASS {len(fixtures)} campaign fixture hashes and coverage manifest')
else:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest['coverage']))
