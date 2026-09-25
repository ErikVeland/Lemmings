#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/controller-qol-unit"
module_cache="$build_dir/ModuleCache"
mkdir -p "$module_cache"
cd "$project_dir"
# Run these pure input checks even when the installed SwiftPM manifest runtime is unavailable.
python3 - "$build_dir/main.swift" <<'PY'
from pathlib import Path
import re, sys
source = Path('Tests/NxlvKitTests/ControllerBindingsTests.swift').read_text()
methods = re.findall(r'@Test func (\w+)\(', source)
source = source.replace('import Testing\n', '').replace('@testable import NxlvKit\n', '')
source = source.replace('@Test ', '').replace('#expect(', 'precondition(')
source += '\nlet suite = ControllerBindingsTests()\n'
source += '\n'.join(f'suite.{method}()' for method in methods)
source += '\nprint("PASS controller bindings, menu chords, RT tap/hold/rapid exit and interrupted input")\n'
Path(sys.argv[1]).write_text(source)
PY
swiftc -swift-version 6 -module-cache-path "$module_cache" Sources/NxlvKit/GameplaySpeed.swift Sources/NxlvKit/ControllerBindings.swift \
  "$build_dir/main.swift" -o "$build_dir/ControllerTests"
"$build_dir/ControllerTests"
