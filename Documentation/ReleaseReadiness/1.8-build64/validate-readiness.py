from pathlib import Path
import json
r=Path(__file__).resolve().parent
original=json.loads((r/'audit/results.json').read_text())
assert not original['sourceDrift']
optional={'replay-movies','mac-app-integration','local-performance-measurement','sequel-views','arcade-records'}
mandatory=[c for c in original['checks'] if c['name'] not in optional]
assert len(mandatory)>=48 and all(c['status']=='passed' for c in mandatory)
failed={c['name'] for c in original['checks'] if c['status']=='failed'}
assert failed=={'replay-movies','mac-app-integration','local-performance-measurement','arcade-records'},failed
assert 'PASS player add-to-Hot-Seat, automatic edits, deletion cleanup' in (r/'arcade-records-current-schema.log').read_text()
assert 'PASS game-font replay controls' in (r/'replay-movies-rerun.log').read_text()
app=(r/'app-regression-rerun.log').read_text()
assert 'PASS CRT dimensions, shader coordinates, held rate, release and minimap drag' in app
assert 'PASS checked hints, confirmed winning ghosts' in app
assert 'Desktop activation requires LEMMINGS_TEST_WINDOWS=foreground.' in app
assert 'Benchmark did not run the simulation: ticks 0' in (r/'audit/logs/local-performance-measurement.log').read_text()
assert 'PASS release UI:' in (r/'release-ui-candidate.log').read_text()
result={'sourceCommit':(r/'source-commit.txt').read_text().strip(),'mandatoryChecksPassed':len(mandatory),'originalAuditFailures':sorted(failed),'resolved':{'replay-movies':'Corrected dependency runner passes.','mac-app-integration CRT input':'Updated test target coordinates pass; remaining suite blocked by desktop activation.'},'unverified':['Complete broad app integration suite','Performance benchmark'],'releaseUI':'passed against final candidate resources','testAudio':'muted','testWindows':'offscreen','releaseDecision':'Proceed with the minor-release gate and focused regression checks; retain extended-suite limitations.'}
(r/'candidate-checks.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
