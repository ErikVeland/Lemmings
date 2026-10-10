from pathlib import Path
import hashlib,json
r=Path('.build/release-1.9.1'); baseline=Path('.build/release-1.9/standard/Ultimate Lemmings.app/Contents/Resources/MacMusic')
files={str(p.relative_to(baseline)):hashlib.sha256(p.read_bytes()).hexdigest() for p in baseline.rglob('*') if p.is_file()}
assert sum(name.endswith('.m4a') for name in files)==31
for variant in ['standard','slim']:
 root=r/variant/'Ultimate Lemmings.app/Contents/Resources/MacMusic'
 assert {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}==files
print('PASS all 31 original Macintosh music files and metadata retained byte for byte in both downloads')
(r/'mac-music-assets.json').write_text(json.dumps(files,indent=2)+'\n')
