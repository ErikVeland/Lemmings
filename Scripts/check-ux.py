#!/usr/bin/env python3
"""Run the UX redesign checkpoints on macOS and retain the evidence for each run."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
CHECKS = {
    "home": [
        "HomeContinueTests/homeIsContinueThenFourDestinations",
        "HomeContinueTests/withoutContinuePlayIsPrimary",
        "HomeContinueTests/playKeepsEveryRouteAndGame",
        "ContinueResolverTests/newestMidLevelAttemptWins",
        "ContinueResolverTests/noCandidatesOffersJourneyWhenAvailable",
        "AnonymousTelemetryTests/testFreshProfileThenOptionalOfflineConsentAndRelaunch",
    ],
    "hud": [
        "MobileStatusSlotTests/testCompleteFieldRectanglesAtDigitBoundaries",
        "StatusStripRenderTests/testSpeedAndRateMouseTargetsStayFixed",
        "MacSpeedTierTests/testStripTargetsAndRenders",
        "MacSpeedTierTests/testShiftNumberSelectsAndSurvivesKeyRelease",
        "MobilePortraitHUDTests/delayedPauseAndResumeNeverOpenTheMenu",
        "MobilePortraitHUDTests/choosingSpeedCancelsHeldInputAndHonoursTheMode",
        "RewindCueTests/cueUsesGameSecondsForEachEngineRate",
        "RewindCueTests/rapidPressesRaiseTheShownSpeed",
        "NeoLemmixMobileDataTests/fanPanelPreservesTargetsAcrossSpeedAndTimeChanges",
    ],
    "hot-seat": [
        "HomeContinueTests/hotSeatNamesTheNextPlayer",
        "SavedHotSeatPageTests/previousSyncedRostersHaveDistinctVisibleResumeTargets",
        "MobileHotSeatTests/sessionsSurviveSavingAndKeepTheirRule",
        "MobileHotSeatTests/resultChoicesFollowTheHouseRule",
    ],
    "music": ["ResultMusicFadeTests/testFinishingOnceAndRetiringBeforeAnotherTrackStarts"],
}
AUDITS = ("first-player", "rounded-hud", "grid-hud", "hot-seat-flow")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("group", nargs="?", default="all", choices=["all", *CHECKS, "renders"])
    parser.add_argument("--resources", type=Path, default=os.environ.get("LEMMINGS_MOBILE_BUNDLED_RESOURCES",
                        "/Applications/Ultimate Lemmings.app/Contents/Resources"),
                        help="Game resources containing NeoLemmix and Ports")
    args = parser.parse_args()
    os.chdir(ROOT)
    resources = args.resources.resolve()
    cache = ROOT / ".build" / "ModuleCache"
    cache.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="ux-check-", dir=ROOT / ".build"))
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output(["git", "status", "--porcelain"], text=True)
    print(f"Evidence: {output}", flush=True)
    summary = [f"Revision {revision}" + (" (working tree modified)" if dirty else ""), f"Group {args.group}"]
    report = output / "summary.txt"
    report.write_text("\n".join(summary) + "\n")
    env = dict(os.environ, LEMMINGS_TEST_WINDOWS="offscreen", LEMMINGS_TEST_AUDIO="muted",
               CLANG_MODULE_CACHE_PATH=str(cache), SWIFTPM_MODULECACHE_OVERRIDE=str(cache),
               LEMMINGS_MOBILE_BUNDLED_RESOURCES=str(resources))
    runner = [sys.executable, "Tools/UITestRunner/run.py"]
    failed = False

    def record(ok, label):
        nonlocal failed
        failed |= not ok
        line = ("PASS " if ok else "FAIL ") + label
        print(line, flush=True)
        with report.open("a") as evidence:
            evidence.write(line + "\n")

    def run(label, command):
        print(f"Running {label}", flush=True)
        path = output / (label + ".log")
        with path.open("w") as log:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            print(f"Exit {result.returncode}. See {path}", flush=True)
        return result.returncode == 0, path.read_text(errors="replace")

    if args.group != "renders":
        groups = CHECKS if args.group == "all" else {args.group: CHECKS[args.group]}
        tests = [test for group in groups.values() for test in group]
        ok, log = run("tests", runner + ["swift", "test", "--disable-sandbox", "--jobs", "4",
                                        "--filter", "|".join(map(re.escape, tests))])
        for group, cases in groups.items():
            missing = []
            for case in cases:
                suite, name = map(re.escape, case.split("/"))
                passed = rf"(?:\.{suite} {name}\]' passed|\bTest {name}\(\) passed)"
                if not re.search(passed, log):
                    missing.append(case)
            record(not missing, group + (" — no passing result for " + ", ".join(missing) if missing else ""))
        if not ok:
            record(False, "Swift test process")

    if args.group in ("all", "renders"):
        artwork = ROOT / ".build/mac-artwork/export/lemmings"
        classic = resources / "Ports/lemmings_dos_1991-07-30"
        ok, _ = run("build-menu-audit", ["swift", "build", "--disable-sandbox", "--jobs", "4",
                                         "--product", "LemmingsMobileMenuAudit"])
        if ok:
            binary_dir = subprocess.check_output(["swift", "build", "--disable-sandbox", "--show-bin-path"],
                                                 env=env, text=True).strip()
            for audit in AUDITS:
                ok, _ = run(audit, runner + [str(Path(binary_dir) / "LemmingsMobileMenuAudit"), str(artwork),
                                             str(classic), str(output / audit), "--" + audit])
                record(ok, audit)
        else:
            record(False, "Build menu audit")
    with report.open("a") as evidence:
        evidence.write("Run failed\n" if failed else "Run complete\n")
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
