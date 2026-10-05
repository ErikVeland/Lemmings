#!/bin/zsh
set -euo pipefail
cd /Users/veland/.codex/worktrees/release-1-7-9/Lemmings
root="$PWD/.build/release-1.7.9"
python3 Tools/TrolleyVerification/catalogue.py check
python3 Tools/ClassicCompletion/report.py --check
python3 Tools/CampaignCompletion/report.py --check
python3 Tools/Lemmings2Completion/report.py --check
python3 - "$root" <<'PY'
from pathlib import Path
import hashlib,json,shutil,sys
root=Path.cwd();r=Path(sys.argv[1]);app=r/'prepared/Ultimate Lemmings.app';resources=app/'Contents/Resources'
compiled=json.loads((r/'compiled-source-inputs.json').read_text())
assert all(hashlib.sha256((root/p).read_bytes()).hexdigest()==digest for p,digest in compiled.items())
for rel in ('Hints/classic.json','Hints/solutions.json','Progression/learning.json','Progression/solutions.json','Trolley/verified-maxima.json','Trolley/engine-fingerprint.txt'):
 shutil.copy2(root/'Resources'/rel,resources/rel)
shutil.copytree(root/'Resources/Trolley', resources/'Trolley', dirs_exist_ok=True)
shutil.copy2(root/'Resources/Info.plist',app/'Contents/Info.plist')
proofs=json.loads((resources/'Trolley/verified-maxima.json').read_text());hints=json.loads((resources/'Hints/classic.json').read_text())
assert hints['engineFingerprint']==proofs['engineSourceFingerprint']
paths=[*root.glob('Sources/NxlvKit/*.swift'),*root.glob('Sources/LemmingsLocal/*.swift'),*root.glob('Resources/**/*')]
(r/'build-inputs.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.is_file()},indent=2)+'\n')
print('PASS source snapshot and prepared resources')
PY
git diff --check
git add Resources Sources/LemmingsLocal/ReleaseWelcome.swift Documentation/ClassicCompletion Documentation/TrolleyVerification Documentation/ReleaseNotes-1.7.9-build63.md Artifacts/LearningJourney
git commit -m 'Prepare 1.7.9 build 63 and refresh release proofs'
git rev-parse HEAD > "$root/source-commit.txt"
[[ -z "$(git status --porcelain --untracked-files=all)" ]]
python3 Tools/ReleaseReadiness/release_notes.py --draft Documentation/ReleaseNotes-1.7.9-build63.md --build 63 --base v1.7.8 --commit "$(cat "$root/source-commit.txt")" --output "$root/ReleaseNotes-1.7.9-build63.md"
export LEMMINGS_TEST_AUDIO=muted LEMMINGS_TEST_WINDOWS=offscreen
export SPARKLE_FRAMEWORK_PATH='/Users/veland/Lemmings/.build/dependencies/Sparkle-2.7.3/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework'
ENABLE_APPLE_CAPABILITIES=0 MUSIC_BUNDLE=full MUSIC_AAC_CACHE='/Users/veland/Lemmings/.build/music-aac' LEMMINGS_BUILD_DIR="$root/standard" zsh Scripts/build-local-app.sh > "$root/build.log" 2>&1
