#!/usr/bin/env python3
"""Package catalogue paths and sequel variants for the existing music players."""
import argparse
import json
from pathlib import Path
import shutil


def package(catalogue, source, target, game):
    payload=json.loads(catalogue.read_text())
    if game != 'all':
        payload['tracks']=[t for t in payload['tracks'] if t['game']==game]
        for track in payload['tracks']:
            for variant in track['variants']:
                original=source/variant['path']
                if not original.is_file(): raise FileNotFoundError(original)
                output=target/variant['path']
                output.parent.mkdir(parents=True,exist_ok=True)
                if not output.exists() or original.stat().st_mtime_ns > output.stat().st_mtime_ns:
                    shutil.copy2(original,output)
    for track in payload['tracks']:
        for variant in track['variants']:
            path=Path(variant['path'])
            if path.suffix.lower()=='.wav' and (target/path.with_suffix('.m4a')).exists():
                variant['path']=path.with_suffix('.m4a').as_posix()
            if not (target/variant['path']).is_file(): raise FileNotFoundError(target/variant['path'])
    target.mkdir(parents=True,exist_ok=True)
    (target/'catalogue.json').write_text(json.dumps(payload,indent=2,ensure_ascii=False)+'\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalogue',type=Path)
    parser.add_argument('source',type=Path)
    parser.add_argument('target',type=Path)
    parser.add_argument('game',choices=['all','lemmings2','lemmings3'])
    args=parser.parse_args()
    package(args.catalogue,args.source,args.target,args.game)
