"""Manifest for preserved Lemmings 2 routes and population carry-over variants."""
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
import sys


def chain_counts(fixtures, variants):
    result = {}
    for tribe in sorted({f['tribe'] for f in fixtures}):
        expected, chained = 60, 0
        for number in range(1, 11):
            matching = [f for f in fixtures + variants
                        if f['tribe'] == tribe and f['level'] == number
                        and f['startingPopulation'] == expected]
            if not matching:
                break
            if len(matching) != 1:
                raise ValueError(f'Ambiguous carry-over route: {tribe} {number}, {expected}')
            route = matching[0]
            chained += 1
            expected = route['saved']
        result[tribe] = chained
    return result


def read_routes(source, project):
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
    return fixtures


def main():
    project = Path(__file__).resolve().parents[2]
    output = project / 'Documentation/Lemmings2Completion/evidence.json'
    root = project / 'Tests/Lemmings2CompletionTests'
    fixtures = read_routes(root / 'Fixtures', project)
    variants = read_routes(root / 'Chains', project)
    identities = {(f['tribe'], f['level'], f['levelSHA256']) for f in fixtures}
    assert all((f['tribe'], f['level'], f['levelSHA256']) in identities for f in variants), 'Orphan carry-over witness'
    chained_levels = chain_counts(fixtures, variants)
    manifest = {'schemaVersion': 2,
                'coverage': dict(Counter(f['tribe'] for f in fixtures)),
                'quality': {'bareSurvivals': sum(f['saved'] == 1 and f['startingPopulation'] > 1 for f in fixtures)},
                'chainedLevels': chained_levels,
                'fullyChainedTribes': sum(n == 10 for n in chained_levels.values()),
                'fixtures': fixtures, 'chainFixtures': variants}
    if '--check' in sys.argv:
        assert output.exists() and json.loads(output.read_text()) == manifest, \
            'Lemmings 2 fixtures changed, disappeared or lack a matching manifest.'
        print(f'PASS {len(fixtures)} Lemmings 2 fixture hashes and {len(variants)} carry-over fixture hashes')
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(manifest, indent=2) + '\n')
        print(json.dumps({'coverage': manifest['coverage'], 'chainedLevels': chained_levels}))


if __name__ == '__main__':
    main()
