#!/bin/zsh
# Run shared regressions without the owner's ignored game data and artwork.
set -euo pipefail
project_dir="${0:A:h:h}"
export LEMMINGS_TEST_AUDIO=muted
export LEMMINGS_TEST_WINDOWS=offscreen
cd "$project_dir"
data_checks='BeastMixTests|ZipArchiveTests/everyBundledPackDecodesLikeUnzip|FanPackUpdaterTests/installsOnlyMissingValidPacks|RecoveryPerformanceTests/deferredHashUsesImmutableClassicAndSequelStates|MacMonochromeTests|MacMonochromeBackpackTests|MacArrowWrapTests|MacExitDoorTests|MobileCatalogueTests|FanPackCorpusTests|MobileProgressionBuilderTests|MobileFanCountStoreTests|MobileArtworkTests|MobileExplosionParityTests|MobileBombCountdownTests|MobileFavouritesTests/favouritesSpanPacksAndPlayInTheirOwnSession|MobileShuffleAllTests|MobileLearningTests/curatedJourneyStartsWithoutScanningFuturePacks'
responsiveness_check='CloudLibraryTests/slowCredentialServicesLeaveTheMainActorResponsive'
print "Source gate excludes game-data corpus and artwork checks: $data_checks"
print "Follow Documentation/ReleaseSchedule.md for candidate-specific release checks."
zsh Scripts/run-swift-tests.sh --disable-sandbox \
  --filter 'NxlvKitTests|LemmingsMobileCoreTests|LemmingsAppCoreTests|LemmingsTVCoreTests' \
  --skip "$data_checks|$responsiveness_check" "$@"
# Run the response-time check without competing main-actor test work.
zsh Scripts/run-swift-tests.sh --disable-sandbox \
  --filter "$responsiveness_check" "$@"
