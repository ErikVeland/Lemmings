#!/usr/bin/env python3
"""Migrate proof identity only when every replay-engine source file is unchanged."""
import argparse
import hashlib
import json
from pathlib import Path
from catalogue import PRESENTATION_FILES, fingerprint, validate_catalogue

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('verified_sources', type=Path, help='NxlvKit source directory used by the original audit')
parser.add_argument('--write', action='store_true')
args = parser.parse_args()

def hashes(folder):
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.glob('*.swift')
            if not p.name.startswith(('Trolley', 'Arcade'))}

def digest(files):
    return hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

base = hashes(args.verified_sources)
current = hashes(root / 'Sources/NxlvKit')
source = root / 'Resources/Trolley'
catalogue = validate_catalogue(source)
if digest(base) != catalogue['engineSourceFingerprint']:
    raise SystemExit('The supplied source snapshot does not match the original proof identity.')
base_engine = {k: v for k, v in base.items() if k not in PRESENTATION_FILES}
current_engine = {k: v for k, v in current.items() if k not in PRESENTATION_FILES}
if base_engine != current_engine:
    raise SystemExit('Replay-engine sources changed. Run the native replay audit instead.')
report = {'previousFingerprint': digest(base), 'physicsFingerprint': fingerprint(),
          'unchangedEngineFiles': len(base_engine), 'excludedPresentationFiles': sorted(PRESENTATION_FILES),
          'changedPresentationFiles': sorted(k for k in set(base) | set(current) if base.get(k) != current.get(k)),
          'witnesses': len(catalogue['levels']), 'witnessHashesValidated': True,
          'verifiedSourceSnapshot': str(args.verified_sources.resolve())}
print(json.dumps(report, indent=2))
if args.write:
    catalogue['engineSourceFingerprint'] = fingerprint()
    (source / 'verified-maxima.json').write_text(json.dumps(catalogue, sort_keys=True, indent=2) + '\n')
    (source / 'engine-fingerprint.txt').write_text(fingerprint() + '\n')
    (root / 'Documentation/TrolleyVerification/presentation-fingerprint-migration.json').write_text(json.dumps(report, indent=2) + '\n')
