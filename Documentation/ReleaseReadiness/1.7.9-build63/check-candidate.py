from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parent;repo=root.parent.parent
source=(root/'source-commit.txt').read_text().strip()
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()==source
assert not subprocess.check_output(['git','status','--porcelain','--untracked-files=all'],cwd=repo,text=True).strip()
a=json.loads((root/'audit/results.json').read_text());assert not a['sourceDrift'];assert not any(x['status']=='failed' for x in a['checks'])
need={'release-ui.log':'PASS release UI:', 'golems-final.log':'PASS 187 selected Golems wins','neo-mac.log':'PASS 160 Redux levels','playfield.log':'Playfield drawing tests passed.','classic-quest.log':'PASS Classic Full Quest: 352 wins, 1056 recoveries','l3-completion.log':'Verified 41 distinct L3 levels','music-libraries-with-fixtures.log':'PASS main + optional libraries cover all 495 versions exactly once'}
for name,marker in need.items():assert marker in (root/name).read_text(),name
resources=json.loads((root/'resource-comparison.json').read_text());assert not resources['differences'];assert all(resources['focusedArtworkAssetsMatch'].values())
assert len(json.loads((root/'public-music-libraries.json').read_text()))==18
s=json.loads((root/'build-inputs.json').read_text());assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in s.items())
report={'sourceCommit':source,'status':'passed','regressionAuditPasses':sum(x['status']=='passed' for x in a['checks']),'sourceDrift':[],'nativeWindows':'offscreen','testAudio':'muted','packaging':'ready for Developer ID signing and notarisation'}
(root/'candidate-checks.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
