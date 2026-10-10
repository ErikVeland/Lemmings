#!/bin/zsh
set -euo pipefail
cd /Users/veland/Lemmings
APPCAST_PATH="$PWD/.build/delta-1.9.1/appcast.xml" DOWNLOAD_URL_PREFIX=https://github.com/ErikVeland/Lemmings/releases/download/v1.9.1/ zsh Scripts/generate-appcast.sh "$PWD/.build/delta-1.9.1" > .build/delta-1.9.1/pipeline-generate.log 2>&1
cp .build/delta-1.9.1/appcast.xml appcast.xml
cp .build/delta-1.9.1/pipeline-generate.log Documentation/ReleaseReadiness/1.9.1-build76/delta/
git fetch origin main
git merge-base --is-ancestor origin/main HEAD
gh release upload v1.9.1 '.build/delta-1.9.1/UltimateLemmings-build76-from75.delta' --repo ErikVeland/Lemmings --clobber
python3 .build/delta-1.9.1/publish-delta.py asset
gh release delete-asset v1.9.1 Ultimate.Lemmings76-75.delta --repo ErikVeland/Lemmings --yes
git add Scripts/generate-appcast.sh Scripts/publish-github-release.sh Tools/ReleaseReadiness/automatic_updates.py Tools/ReleaseReadiness/delta_updates.py Tests/ReleaseReadinessTests/test_delta_updates.py Tests/ReleaseReadinessTests/test_release_publication.py Documentation/AutomaticUpdates.md Documentation/ReleaseReadiness/1.9.1Build76Distribution.md Documentation/ReleaseReadiness/1.9.1-build76/delta Documentation/ReleaseReadiness/1.9.1-build76/evidence-manifest.json appcast.xml
git commit -m 'Restore signed incremental Sparkle updates for 1.9.1'
git push origin HEAD:main
python3 .build/delta-1.9.1/publish-delta.py feed
git add Documentation/ReleaseReadiness/1.9.1-build76/delta/delta-publication.json Documentation/ReleaseReadiness/1.9.1-build76/evidence-manifest.json
git commit -m 'Record verified public 1.9.1 delta delivery'
git push origin HEAD:main
