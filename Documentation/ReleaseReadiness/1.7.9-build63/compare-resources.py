from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parent

def manifest(folder):
 return {str(p.relative_to(folder)): hashlib.file_digest(p.open('rb'),'sha256').hexdigest() for p in folder.rglob('*') if p.is_file() and p.name!='.DS_Store'}
prepared=root/'prepared/Ultimate Lemmings.app/Contents/Resources'
shipping=root/'standard/Ultimate Lemmings.app/Contents/Resources'
a,b=manifest(prepared),manifest(shipping)
diff=[p for p in sorted(set(a)|set(b)) if a.get(p)!=b.get(p)]
report={'testedResourceFiles':len(a),'shippingResourceFiles':len(b),'differences':diff}
# These two focused view suites used the primary checkout's unchanged artwork assets.
primary=Path('/Users/veland/Lemmings/.build/local/Ultimate Lemmings.app/Contents/Resources')
report['focusedArtworkAssetsMatch']={folder:manifest(primary/folder)==manifest(shipping/folder) for folder in ('NeoLemmix','MacArtwork','AmigaArtwork')}
(root/'resource-comparison.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
assert not diff and all(report['focusedArtworkAssetsMatch'].values())
