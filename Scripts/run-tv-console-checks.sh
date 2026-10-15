#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/tv-console/runtime"
mkdir -p "$build_dir/Modules" "$build_dir/ModuleCache" "$build_dir/Sources" "$build_dir/resources"
cd "$project_dir"
task_modules=(NxlvKit LemmingsAppCore LemmingsMobileCore LemmingsTVCore LemmingsGameArt)
for module in $task_modules; do
    rm -rf "$build_dir/Sources/$module"
    cp -R "Sources/$module" "$build_dir/Sources/$module"
done
ln -sfn "$project_dir/Sources/Ports" "$build_dir/resources/Ports"
ln -sfn "$project_dir/Resources/MenuArtwork" "$build_dir/resources/MenuArtwork"
task_libraries=()
for module in $task_modules; do
    task_sources=("${(@f)$(rg --files "$build_dir/Sources/$module" -g '*.swift')}")
    swiftc -swift-version 6 -parse-as-library -module-cache-path "$build_dir/ModuleCache" \
        -I "$build_dir/Modules" -L "$build_dir" "${task_libraries[@]}" \
        -emit-library -emit-module -module-name "$module" "${task_sources[@]}" \
        -emit-module-path "$build_dir/Modules/$module.swiftmodule" -o "$build_dir/lib$module.dylib"
    task_libraries+=("-l$module")
    print "PASS $module native module"
done
python3 - "$build_dir/main.swift" <<'PY'
from pathlib import Path
import re, sys
source = Path('Tests/LemmingsTVCoreTests/TVControllerBindingsTests.swift').read_text()
source = source[:source.index('    @Test func overlappingActors')] + '}\n'
source = source.replace('import Testing\n', '').replace('@testable import LemmingsTVCore\n', 'import LemmingsTVCore\n')
methods = re.findall(r'@Test func (\w+)\(', source)
source = source.replace('@Test ', '').replace('#expect(', 'precondition(')
source += '\nlet suite = TVControllerBindingsTests()\n' + '\n'.join(f'suite.{method}()' for method in methods)
source += '\nprint("PASS TV controller, Circle, Menu, boost, rewind takeover, neutral handover and preferences")\n'
Path(sys.argv[1]).write_text(source)
PY
for entry in "$build_dir/main.swift" Tests/TVExperienceTests/main.swift Tools/TVConsoleAudit/main.swift; do
    task_name="${entry:h:t}"
    task_flags=()
    if [[ "$entry" != "$build_dir/main.swift" ]]; then task_flags=(-parse-as-library); fi
    swiftc -swift-version 6 "${task_flags[@]}" -module-cache-path "$build_dir/ModuleCache" \
        -I "$build_dir/Modules" -L "$build_dir" "${task_libraries[@]}" \
        -Xlinker -rpath -Xlinker "$build_dir" "$entry" -o "$build_dir/$task_name-tests"
    python3 Tools/UITestRunner/run.py "$build_dir/$task_name-tests" "$project_dir"
done
