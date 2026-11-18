#!/usr/bin/env python3
"""Compare Original presentation with and without the clean-distribution flag."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess

ROOT = Path(__file__).resolve().parents[2]



def check_mobile_media(build):
    """Execute the import callback's actual selection branch without audio or UIKit."""
    build.mkdir(parents=True, exist_ok=True)
    source = (ROOT / 'Sources/LemmingsMobileUI/MobileLibraryViewController.swift').read_text()
    callback = source[source.index('private func receiveResources('):]
    callback = callback[:callback.index('MobileLixArtwork.activate()')]
    marker = 'if mobileSettings.soundtrack =='
    branch = ''
    if marker in callback:
        start = callback.index(marker)
        opening = callback.index('{', start)
        depth, end = 1, opening + 1
        while depth:
            depth += (callback[end] == '{') - (callback[end] == '}')
            end += 1
        branch = callback[start:end]
    fixture = (ROOT / 'Tests/UltimateLemmixAssetParity/PresentationMedia.swift').read_text()
    test = build / 'MediaSelection.swift'
    test.write_text(fixture + '\n@MainActor func restoreImportedMedia() {\n' + branch + '\n}\n')
    executable = build / 'media-selection'
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '6', '-warnings-as-errors', '-parse-as-library',
                    '-module-cache-path', str(build / 'ModuleCache'), '-o', str(executable), str(test)], check=True)
    subprocess.run([str(executable)], check=True, env={**os.environ, 'LEMMINGS_TEST_AUDIO': 'muted'})


def run(arguments):
    build = arguments.output.resolve()
    build.mkdir(parents=True, exist_ok=True)
    modules = arguments.modules.resolve()
    library = arguments.libraries.resolve()
    # Compile only the changed presentation files. Existing dependency modules
    # supply the unchanged resource loader, typography, stone and logo renderers.
    source = (ROOT / 'Sources/LemmingsGameArt/PanelGlyphArt.swift').read_text()
    (build / 'PanelGlyphArt.swift').write_text('import LemmingsGameArt\n' + source)
    decoder = ROOT / 'Sources/LemmingsGameArt/OwnedClassicPanelArt.swift'
    sources = [build / 'PanelGlyphArt.swift', ROOT / 'Sources/LemmingsLocal/PanelGlyphs.swift',
               ROOT / 'Tests/UltimateLemmixAssetParity/Presentation.swift']
    if decoder.exists():
        sources.append(decoder)
    recovery_flags = ['-D', 'OWNED_PANEL_RECOVERY'] if decoder.exists() else []
    for name, flags in [('baseline', []), ('store', ['-D', 'ULTIMATE_LEMMIX_STORE'])]:
        executable = build / name
        command = ['xcrun', 'swiftc', '-swift-version', '6', '-warnings-as-errors', '-parse-as-library',
                   '-target', platform.machine() + '-apple-macos12.3', '-module-cache-path', str(build / 'ModuleCache'),
                   '-I', str(modules), '-L', str(library), '-lNxlvKit', '-lLemmingsAppCore', '-lLemmingsMobileCore',
                   '-lLemmingsTVCore', '-lLemmingsGameArt', '-Xlinker', '-rpath', '-Xlinker', str(library),
                   '-framework', 'AppKit', *flags, *recovery_flags, '-o', str(executable), *map(str, sources)]
        subprocess.run(command, check=True, cwd=ROOT)
        subprocess.run([str(executable), str(arguments.bundle.resolve()), str(build / (name + '.json'))],
                       check=True, cwd=ROOT, env={**os.environ, 'LEMMINGS_TEST_AUDIO': 'muted'})
    baseline = json.loads((build / 'baseline.json').read_text())
    store = json.loads((build / 'store.json').read_text())
    failures = [key for key in baseline if baseline[key] != store.get(key) or baseline[key] == 'MISSING']
    report = {'states': len(baseline), 'different': failures,
              'bundle': str(arguments.bundle.resolve()),
              'sourceSHA256': {str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path):
                               hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}}
    (build / 'comparison.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'states': len(baseline), 'different': failures}, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--modules', type=Path, required=True)
    parser.add_argument('--libraries', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=ROOT / '.build/ultimate-lemmix-presentation-parity')
    parser.add_argument('--media-only', action='store_true')
    arguments = parser.parse_args()
    if arguments.media_only:
        arguments.output.mkdir(parents=True, exist_ok=True)
        check_mobile_media(arguments.output)
    else:
        check_mobile_media(arguments.output)
        run(arguments)
