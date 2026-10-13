#!/bin/zsh
# Run shared regressions without the owner's ignored game data and artwork.
set -euo pipefail
project_dir="${0:A:h:h}"
export LEMMINGS_TEST_AUDIO=muted
export LEMMINGS_TEST_WINDOWS=offscreen
cd "$project_dir"
data_checks='BeastMixTests|ZipArchiveTests/everyBundledPackDecodesLikeUnzip|FanPackUpdaterTests/installsOnlyMissingValidPacks|RecoveryPerformanceTests/deferredHashUsesImmutableClassicAndSequelStates|MobileCatalogueTests|FanPackCorpusTests|MobileProgressionBuilderTests|MobileFanCountStoreTests|MobileArtworkTests|MobileExplosionParityTests|MobileBombCountdownTests|MobileFavouritesTests/favouritesSpanPacksAndPlayInTheirOwnSession|MobileShuffleAllTests|MobileLearningTests/curatedJourneyStartsWithoutScanningFuturePacks'
print "Source gate excludes game-data corpus and artwork checks: $data_checks"
print "Run the full local release audit with bundled data before publication."
zsh Scripts/run-swift-tests.sh --disable-sandbox \
  --filter 'NxlvKitTests|LemmingsMobileCoreTests|LemmingsAppCoreTests' \
  --skip "$data_checks" "$@"
