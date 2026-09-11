#!/usr/bin/env python3
"""Decode Lemmix v1 input recordings as candidates for native verification."""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import struct

SKILLS = {3: 'digger', 4: 'climber', 7: 'builder', 8: 'basher',
          9: 'miner', 11: 'floater', 15: 'blocker', 18: 'bomber'}
RECORD = struct.Struct('<ciHBBiiiihhBBB')


def decode(path):
    data = path.read_bytes()
    if len(data) < 64 or data[:4] != b'LRB\x01':
        raise ValueError(f'{path}: expected a Lemmix v1 recording')
    size = struct.unpack_from('<I', data, 4)[0]
    start = struct.unpack_from('<I', data, 12)[0]
    count = struct.unpack_from('<H', data, 18)[0]
    if size != len(data) or start < 64 or start + count * RECORD.size != len(data):
        raise ValueError(f'{path}: inconsistent recording length')
    events, cues = [], []
    rate, delta, last = None, 0, 0
    for offset in range(start, len(data), RECORD.size):
        check, tick, flags, skill, _, rr, lemming, x, y, *_ = RECORD.unpack_from(data, offset)
        if check != b'R' or tick < last:
            raise ValueError(f'{path}: invalid record at byte {offset}')
        if delta and rate is not None:
            for frame in range(last + 1, tick + 1):
                rate = max(1, min(99, rate + delta))
                events.append({'tick': frame, 'action': {'releaseRate': {'_0': rate}}})
        if rr != rate:
            events.append({'tick': max(1, tick), 'action': {'releaseRate': {'_0': rr}}})
            rate = rr
        if flags & 8:
            delta = 1
        if flags & 16:
            delta = -1
        if flags & 32:
            delta = 0
        if flags & 128:
            if skill not in SKILLS or lemming < 0:
                raise ValueError(f'{path}: invalid skill assignment')
            cues.append({'tick': tick, 'id': lemming, 'skill': SKILLS[skill], 'x': x, 'y': y})
            events.append({'tick': tick, 'action': {'assign': {'lemmingID': lemming, 'skill': SKILLS[skill]}}})
        if flags & 256:
            events.append({'tick': tick, 'action': {'nuke': {}}})
        last = tick
    return {'title': data[32:64].decode('latin1').strip(), 'events': events, 'cues': cues,
            'origin': {'file': path.name, 'sha256': sha256(data).hexdigest()}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--output', type=Path,
                        default=Path('.build/classic-completion/reference/candidates'))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    files = sorted(p for p in args.directory.iterdir() if p.suffix.lower() == '.lrb')
    for path in files:
        result = decode(path)
        (args.output / (path.stem + '.json')).write_text(json.dumps(result, indent=2) + '\n')
    print(f'Decoded {len(files)} candidates. None is certified until the native replay gate passes.')


if __name__ == '__main__':
    main()
