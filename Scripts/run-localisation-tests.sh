#!/bin/zsh
# Check the language catalogue and Mac picker without desktop focus or audio.
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
export LEMMINGS_TEST_WINDOWS=offscreen
export LEMMINGS_TEST_AUDIO=muted
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/localisation-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
python3 -m unittest discover -s Tools/Localisation -p 'test_*.py'
python3 Tools/Localisation/catalogue.py --check --audit
python3 Tools/Localisation/validate.py --report .build/localisation-tools/pack-validation.json
python3 Tools/UITestRunner/run.py swift test --disable-sandbox --jobs 2 \
  --filter 'InterfaceLocalisationTests|LanguagePickerTests' "$@"
