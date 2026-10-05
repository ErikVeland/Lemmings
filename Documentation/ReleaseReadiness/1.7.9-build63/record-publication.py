from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parent
repo=root.parent.parent
pub=json.loads((root/'publication.json').read_text())
feed=json.loads((root/'feed-verification.json').read_text())
audit=json.loads((root/'audit/results.json').read_text())
assert not audit['sourceDrift']
assert all(c['status']!='failed' for c in audit['checks'])
assert all(c['status']=='passed' or c['status']=='not-run' for c in audit['checks'])
assert 'PASS release UI:' in (root/'release-ui.log').read_text()
assert 'selected Golems wins' in (root/'golems-final.log').read_text()
assert not json.loads((root/'resource-comparison.json').read_text())['differences']
source=(root/'source-commit.txt').read_text().strip()
assert pub['sourceCommit']==source
passed=sum(c['status']=='passed' for c in audit['checks'])
not_run=[c['name'] for c in audit['checks'] if c['status']=='not-run']
golems=(root/'golems-final.log').read_text().splitlines()[-1]
limits=[
 'Lemmings 2 and 3 remain Preview. NeoLemmix remains Beta. Native winning replays do not prove complete source-engine physics parity.',
 'No foreground shipping-app launch, audible test, physical Intel/minimum-macOS test or installed Sparkle upgrade was run.',
 'The regression audit compiled the frozen source against prepared resources. Finished package resources match those resources byte for byte. Focused artwork tests used unchanged primary-checkout artwork assets, verified against the finished package.',
 'Five optional audit scopes were not run: '+', '.join(not_run)+'. Separate release UI and playfield checks cover the current source.',
 'The all-campaign closure gate remains open for sequels. This is a minor release with full Classic and retained L3 replay checks.',
 'The release publishes full and slim universal macOS archives. Separate Monterey and Game Center archives are not published.'
]
checks={
 'version':'1.7.9','build':63,'sourceCommit':source,'status':'published-and-verified',
 'publication':pub['url'],
 'passed':[
 '34 release-tool tests and 350 stored solution fixtures',
 '352 Classic/conversion quest wins, 1056 recoveries, 352 progress resumes, six transitions and final result; negative evidence checks',
 '251 exact-condition rescue certificates and 17 rescue targets after 562-level/574-configuration audit',
 '352 verified hint routes and 292 generated learning lessons',
 '41 retained L3 wins and negative input/evidence checks',
 golems,
 '160 Redux levels: 149 Mac terrain scenes and 393 Mac gadgets; original pixels, masks and simulation configuration unchanged',
 'Native playfield rendering, Mac switching, cursor badges, 0/1/8/10/21-skill panels, four widths, CRT source and input targets',
 'Fan text terrain source-coordinate regression',
 f'{passed} regression audit checks, zero source drift',
 'Release UI: welcome render and Continue, cross-game pause, dialogs, nuke, saved-run recovery, all 292 lessons, Solo and Hot Seat sessions',
 'All 18 soundtrack library ZIPs and member hashes; all 495 versions covered once; public sizes, digests and ZIP responses match',
 'Finished full package resources match prepared test resources; slim and full executable code matches',
 'Universal arm64/x86_64 binaries; macOS 12.3 minimum; Developer ID signatures and same nested signing team',
 'Both Apple submissions Accepted; logs match exact submitted ZIPs; tickets stapled; strict signatures, final ZIP integrity and quarantined Gatekeeper checks',
 f'Sparkle Ed25519 signature verifies; all {feed["priorEnclosuresPreserved"]} previous feed enclosures and signatures preserved; slim excluded from Sparkle',
 'Public tag, latest release, both asset hashes and sizes, live ZIP URLs and raw signed feed verified'
 ],'pending':[],'knownLimits':limits,'testResolutions':'test-resolutions.json'
}
(root/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
resolution=json.loads((root/'test-resolutions.json').read_text())
resolution['golems']['resolution']='Verifier checked the original file hash and decoded equality for Cliffhanger before strict playback. The full selected Golems rerun passed. No replay, score, profile or expected outcome was changed.'
(root/'test-resolutions.json').write_text(json.dumps(resolution,indent=2)+'\n')
evidence=repo/'Documentation/ReleaseReadiness/1.7.9-build63';evidence.mkdir(parents=True,exist_ok=False)
for p in root.iterdir():
 if p.name not in {'checks-pending.json', 'notary-preflight.json', 'notary-resume-history.json', 'notary-auth-recheck.json', 'notary-login-keychain-check.json', 'notary-stable-check.json', 'notary-clt-check.json'} and p.is_file() and (p.suffix in {'.json','.log','.xml','.zsh','.py','.swift'} or p.name in {'source-commit.txt','ReleaseNotes-1.7.9-build63.md'}):
  shutil.copy2(p,evidence/p.name)
for name in ('inputs.json','results.json','report.md'):
 dest=evidence/'audit'/name;dest.parent.mkdir(exist_ok=True);shutil.copy2(root/'audit'/name,dest)
shutil.copytree(root/'audit/logs',evidence/'audit/logs')
shutil.copytree(root/'golems',evidence/'golems',ignore=shutil.ignore_patterns('verify'))
shutil.copy2(repo/'.build/trolley/release-welcome.png',evidence/'release-welcome.png')
shutil.copytree(repo/'.build/neolemmix-panel-regression',evidence/'neo-panel')
(evidence/'README.md').write_text('''# 1.7.9 build 63 release evidence

`checks.json` records final results and validation limits. `publication.json`
records the public release and downloads. `SHA256.json` hashes every other
retained file. The Apple logs and final archive records identify the exact
notarised binaries.

Raw failed checks remain alongside their passing reruns. `test-resolutions.json`
explains the missing soundtrack fixtures and the replay byte-format mismatch.
No game code, stored replay, difficulty score or expected outcome was changed
to resolve them. The first standalone Golems helper compile used the wrong
Swift entry-point filename; the corrected compile and all subsequent logs remain.

Verifier scripts record this isolated checkout's procedure. Their absolute paths
refer to the preserved release directory. Native UI tests ran offscreen through
Tools/UITestRunner/run.py with audio muted.
''')
archives={a['name']:a for a in pub['archives']}
slim=archives['UltimateLemmings-1.7.9-build63-slim.zip'];full=archives['UltimateLemmings-1.7.9-build63.zip']
doc=f'''# 1.7.9 build 63 distribution verification

Published at {pub['publishedAt']}:
[Ultimate Lemmings 1.7.9]({pub['url']}).
Frozen source and tag: `{source}`. Release base: v1.7.8.

The release adds Macintosh artwork and Classic pixel controls to NeoLemmix,
expands Classic fan evidence to 2,401 wins, and corrects L3 extra direction and
selected stair contacts. See the [release notes](../ReleaseNotes-1.7.9-build63.md)
and [retained evidence](1.7.9-build63/checks.json).

## Downloads

Both apps are universal arm64/x86_64 with a macOS 12.3 minimum.

| Purpose | Archive | Bytes | Soundtracks |
| --- | --- | ---: | --- |
| Fresh installation | `{slim['name']}` | {slim['size']:,} | 54 essential versions; 18 optional libraries |
| Sparkle update | `{full['name']}` | {full['size']:,} | All 495 versions |

Previously downloaded libraries remain available. The slim archive is linked
first in the release notes. Only the full archive is offered through Sparkle.

- Slim SHA-256: `{slim['sha256']}`.
- Full SHA-256: `{full['sha256']}`.
- Published feed SHA-256: `{pub['appcastSHA256']}`.

## Verification

Apple accepted both submissions without issues. Their logs match the exact
submitted archive hashes. Both tickets were stapled. Strict code signatures,
ZIP integrity and fresh quarantined Gatekeeper checks passed. The full archive's
Ed25519 signature verifies against the app's embedded Sparkle public key.
All {feed['priorEnclosuresPreserved']} historical feed enclosures remain unchanged.
Public asset hashes and sizes match the local final archives. Both URLs return
ZIP data. The tag names the frozen source, GitHub marks 1.7.9 latest, and the raw
main feed matches the signed local feed byte for byte.

All 352 Classic/conversion routes, 1,056 saved-run recoveries, 352 progress
resumes, six transitions and the final quest passed. All 41 retained L3 routes
and their negative checks passed. Rescue verification retained 251 certificates
and 17 best-known targets. Hint export verified 352 routes.

{golems}.
The historical helper's Cliffhanger digest check used reformatted JSON. The
corrected check verifies the original file bytes and decoded equality before
strict playback. No stored witness or expected result changed.

All 160 Redux levels passed Macintosh rendering parity checks, covering 149
terrain scenes and 393 gadgets. Native bitmap and input checks cover artwork
switching, cursor badges, 0/1/8/10/21 skills, four widths and CRT source rendering.
The welcome page was reviewed as a bitmap and Continue passed its input check.
Release UI also checked pause, dialogs, nuke timing, recovery, all 292 learning
lessons, and Solo/Hot Seat flows across the three engines.

The minor regression audit passed {passed} checks with zero source drift.
All 18 soundtrack archives and member hashes passed after supplying the missing
ignored fixtures. Their public metadata and download responses also passed.
Raw failures and resolutions are retained. Finished package resources match
the tested resources byte for byte.

## Validation limits

'''+ '\n\n'.join(limits)+'\n'
(repo/'Documentation/ReleaseReadiness/1.7.9Build63Distribution.md').write_text(doc)
p=repo/'Documentation/ReleaseScope.md';s=p.read_text();start=s.index('The current public macOS release');end=s.index('Automated checks support',start)
s=s[:start]+'''The current public macOS release is 1.7.9 build 63. The
[1.7.9 distribution record](ReleaseReadiness/1.7.9Build63Distribution.md) records
the notarised slim download, full-soundtrack update, signed feed and validation
limits. This release adds Macintosh artwork and Classic pixel controls for
NeoLemmix, expands fan replay evidence, and corrects L3 extra direction and
selected stair contacts. The slim download is recommended for fresh installations.
The full Sparkle update preserves bundled music. L2 and L3 remain Preview and
NeoLemmix remains Beta. Separate target archives are not published.
Foreground shipping-app launch and audible checks were not run for 1.7.9.
Updated 4 October 2026 for this release.
'''+s[end:];p.write_text(s)
manifest={str(p.relative_to(evidence)):{'bytes':p.stat().st_size,'sha256':hashlib.file_digest(p.open('rb'),'sha256').hexdigest()} for p in sorted(evidence.rglob('*')) if p.is_file()}
(evidence/'SHA256.json').write_text(json.dumps(manifest,indent=2)+'\n')
post=Path('/Users/veland/Documents/Ultimate Lemmings/Posts/ThreadsUpdate-1.7.9-since-1.7.1.txt')
post.write_text(post.read_text().removeprefix('DRAFT — ready to post after 1.7.9 is published.\n\n'))
print('Recorded published distribution and',len(manifest),'evidence files')
