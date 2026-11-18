"""Collect pinned authored metadata without packaging game payloads."""
import base64
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PIN = ROOT / 'Resources/AlternativeAssets/feature-data-source.json'
FORBIDDEN = {'terrain', 'terraindata', 'sprites', 'leveldata', 'bytes', 'pcm', 'rgba', 'pixels',
             'objects', 'steel', 'rawdata', 'audiodata', 'archivedata', 'levelbytes',
             'initialstate', 'classicstate', 'mapdata'}


def encoded(value):
    """Write stable provenance without machine-specific paths."""
    return (json.dumps(value, indent=2, ensure_ascii=False) + '\n').encode()


def inspect_metadata(value):
    """Reject embedded payload fields, raw byte arrays and encoded binary blobs."""
    if isinstance(value, dict):
        if any(key.lower() in FORBIDDEN for key in value):
            raise ValueError('Feature metadata contains a game payload field.')
        for child in value.values():
            inspect_metadata(child)
    elif isinstance(value, list):
        if len(value) >= 128 and all(type(item) is int and 0 <= item <= 255 for item in value):
            raise ValueError('Feature metadata contains a raw byte array.')
        for child in value:
            inspect_metadata(child)
    elif isinstance(value, str) and len(value) >= 512:
        try:
            base64.b64decode(value, validate=True)
        except (ValueError, UnicodeError):
            return
        raise ValueError('Feature metadata contains an encoded payload.')


def collect():
    """Copy only reviewed exact bytes and stamp the current recovery identity."""
    pin_data = PIN.read_bytes()
    pin = json.loads(pin_data)
    if pin.get('gamePayloadsIncluded') is not False or pin.get('kind') != 'repository-authored-feature-data':
        raise ValueError('The authored feature-data scope changed.')
    files = {}
    for row in pin['files']:
        name = row['path']
        path = PurePosixPath(name)
        allowed = (path.parts[0] in ('Progression', 'Hints') and len(path.parts) == 2 and path.suffix == '.json'
                   or name in ('GameCenter/leaderboards.json', 'GameCenter/app-store-connect-boards.json',
                               'Trolley/engine-fingerprint.txt', 'Trolley/verified-maxima.json')
                   or len(path.parts) == 3 and path.parts[:2] == ('Trolley', 'witnesses') and path.suffix == '.json')
        if not allowed or path.is_absolute() or '..' in path.parts or name in files:
            raise ValueError('The feature-data pin contains an unsupported path.')
        source = ROOT / 'Resources' / name
        if any(item.is_symlink() for item in (source, *source.parents) if item != ROOT):
            raise ValueError('Feature-data sources must not contain links.')
        data = source.read_bytes()
        if len(data) != row['bytes'] or hashlib.sha256(data).hexdigest() != row['sha256']:
            raise ValueError('A pinned feature-data source changed: ' + name)
        if path.suffix == '.json':
            inspect_metadata(json.loads(data))
        files[name] = data
    proofs = json.loads(files['Trolley/verified-maxima.json'])
    for row in proofs['levels']:
        witness = row.get('witness')
        if witness:
            name = 'Trolley/' + witness['path']
            if name not in files or hashlib.sha256(files[name]).hexdigest() != witness['sha256']:
                raise ValueError('A feature-data witness differs from its certificate.')
    fingerprint = subprocess.check_output(
        [sys.executable, ROOT / 'Tools/TrolleyVerification/catalogue.py', 'fingerprint'], text=True).strip()
    if len(fingerprint) != 64 or any(character not in '0123456789abcdef' for character in fingerprint):
        raise ValueError('The current recovery fingerprint is invalid.')
    files['Trolley/engine-fingerprint.txt'] = (fingerprint + '\n').encode()
    files['Provenance/feature-data-source.json'] = pin_data
    files['Provenance/feature-data-audit.json'] = encoded({
        'schemaVersion': 1, 'kind': 'repository-authored-feature-data', 'gamePayloadsIncluded': False,
        'runtimeEngineFingerprint': fingerprint, 'certificateEngineFingerprint': proofs['engineSourceFingerprint'],
        'certificatesMatchCurrentEngine': fingerprint == proofs['engineSourceFingerprint'],
        'certificateBytesRelabelled': False, 'witnessHashesVerified': True,
        'staleProofBehaviour': 'Retain original certificates. Loaders fail closed; generic practice hints remain available.'})
    return files
