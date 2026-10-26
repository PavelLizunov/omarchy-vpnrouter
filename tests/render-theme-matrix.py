#!/usr/bin/env python3
"""Render real plugin/host QML with installed themes; never open the live shell.

Requires the installed qml-preview-mcp renderer (0.3+) and bwrap for inert checks.
Run from a network-isolated invocation, e.g. bwrap --unshare-net --bind / / ... .
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
HOST = Path('/usr/share/omarchy/shell')
THEMES = ['catppuccin-latte', 'tokyo-night', 'hackerman', 'miasma']
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--evidence-dir', required=True, type=Path)
parser.add_argument('--renderer-root', type=Path, default=ROOT.parent / 'qml-preview-mcp')
parser.add_argument('--references-only', action='store_true')
parser.add_argument('--case-suffix', help='Render only case names ending in this suffix')
parser.add_argument('--suites', help='Optional comma-separated native suites')
parser.add_argument('--width', type=int, default=440, help='Logical card width')
parser.add_argument('--height', type=int, default=764, help='Logical card height')
parser.add_argument('--dpr', type=int, choices=[1, 2], default=2, help='Physical pixels per logical unit')
parser.add_argument('--mode', choices=['render', 'check', 'all'], default='all')
args = parser.parse_args()
base = args.evidence_dir.resolve()
base.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(args.renderer_root / 'tests'))
from smoke import Client  # existing stdio client, not a second shell


def sha(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()


def stage():
    host = base / 'host'
    shutil.copytree(HOST, host, dirs_exist_ok=True, ignore=shutil.ignore_patterns('plugins'))
    shutil.copy2(ROOT / 'tests/fixtures/KeyboardPanel.qml', host / 'Ui/KeyboardPanel.qml')
    (host / 'shell.qml').write_text('import QtQuick\nItem {}\n')
    plugin = host / 'vpnrouter'
    plugin.mkdir(exist_ok=True)
    for file in ROOT.glob('*.qml'):
        shutil.copy2(file, plugin / file.name)
    for directory in ['ui', 'lib', 'assets', 'locales']:
        shutil.copytree(ROOT / directory, plugin / directory, dirs_exist_ok=True)
    (plugin / 'tests').mkdir(exist_ok=True)
    for file in ['qml-interactions-consumer.qml', 'qml-native-reference.qml']:
        shutil.copy2(ROOT / 'tests' / file, plugin / 'tests' / file)
    imports = base / 'imports'
    imports.mkdir(parents=True, exist_ok=True)
    quickshell = imports / 'Quickshell'
    if not quickshell.exists():
        shutil.copytree('/usr/lib/qt6/qml/Quickshell', quickshell, symlinks=True)
    # Keep all installed visual code. Replace only the three hardware model
    # bindings in the reference copy, so no owner device names enter captures.
    reference = plugin / 'native-bluetooth'
    reference.mkdir(exist_ok=True)
    installed = HOST / 'plugins/panels/bluetooth'
    shutil.copy2(installed / 'Model.js', reference / 'Model.js')
    source = (installed / 'Panel.qml').read_text()
    adapters = {
        'readonly property var adapter: Bluetooth.defaultAdapter': 'property var adapter: null',
        'readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []': 'property var devices: []',
        'readonly property var pipewireNodes: Pipewire.nodes ? Pipewire.nodes.values : []': 'readonly property var pipewireNodes: []'
    }
    for before, after in adapters.items():
        assert source.count(before) == 1, before
        source = source.replace(before, after)
    (reference / 'Panel.qml').write_text(source)
    themes = {}
    for theme in THEMES:
        home = base / 'themes' / theme
        directory = home / '.local/state/omarchy/current/next-theme'
        directory.mkdir(parents=True, exist_ok=True)
        # Match theme-set's stock then user overlay, without applying a theme.
        for source in [Path('/usr/share/omarchy/themes') / theme,
                       Path.home() / '.config/omarchy/themes' / theme]:
            if source.is_dir():
                for file in source.iterdir():
                    if file.is_file():
                        shutil.copy2(file, directory / file.name)
        command = ['/usr/share/omarchy/bin/omarchy-theme-set-templates']
        result = subprocess.run(command, env={**os.environ, 'HOME': str(home),
            'XDG_STATE_HOME': str(home / '.local/state'), 'OMARCHY_PATH': '/usr/share/omarchy'},
            capture_output=True, text=True)
        (home / 'generation.log').write_text(result.stdout + result.stderr)
        assert result.returncode == 0, (theme, result.stderr)
        themes[theme] = directory
    return host, imports, themes


host, imports, themes = stage()
# Include host sources, adapter and theme bytes, not just plugin HEAD.
dependencies = [*ROOT.glob('*.qml'), *ROOT.glob('ui/*.qml'), ROOT / 'ui/qmldir',
    *ROOT.glob('lib/*.js'), *ROOT.glob('locales/*.json'), *ROOT.glob('assets/*.png'),
    ROOT / 'tests/qml-interactions-consumer.qml', ROOT / 'tests/qml-native-reference.qml',
    *host.glob('Commons/*'), *host.glob('Ui/*'),
    *Path('/usr/share/omarchy/shell/plugins/panels/bluetooth').glob('*'),
    host / 'vpnrouter/native-bluetooth/Panel.qml', ROOT / 'tests/render-theme-matrix.py',
    *[d / file for d in themes.values() for file in ['colors.toml', 'shell.toml']]]
dependencies = [file for file in dependencies if file.is_file()]
(base / 'source-hashes.json').write_text(json.dumps({str(p): sha(p) for p in dependencies}, indent=2))
manifest = []
# The renderer subprocess gets a private HOME. Every Color instance uses the
# unchanged host startup FileViews at ~/.local/state/omarchy/current/theme.
isolated_home = base / 'renderer-home'
current = isolated_home / '.local/state/omarchy/current'
current.mkdir(parents=True, exist_ok=True)
for relative in ['.config/fontconfig/fonts.conf', '.config/omarchy/shell.toml']:
    source = Path.home() / relative
    if source.is_file():
        target = isolated_home / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
wrapper = base / 'renderer-wrapper.py'
wrapper.write_text("import os,sys\nos.execve(sys.executable, [sys.executable, '-B', "
    + repr(str(args.renderer_root.resolve() / 'mcp-qml-preview.py'))
    + "], {**os.environ, 'HOME': " + repr(str(isolated_home))
    + ", 'XDG_CONFIG_HOME': " + repr(str(isolated_home / '.config')) + "})\n")
client = Client(base, wrapper=wrapper)


def render(name, theme, properties, reference=False, width=None, height=None):
    width = args.width if width is None else width
    height = args.height if height is None else height
    if args.case_suffix and not name.endswith(args.case_suffix):
        return
    theme_link = current / 'theme'
    if theme_link.is_symlink():
        theme_link.unlink()
    theme_link.symlink_to(themes[theme])
    properties = {**properties, 'width': width, 'height': height}
    qml = host / 'vpnrouter' / ('tests/qml-native-reference.qml' if reference else 'tests/qml-interactions-consumer.qml')
    response = client.call({'qmlPath': str(qml), 'outputPath': str(base / (name + '.png')),
        'width': width, 'height': height, 'dpr': args.dpr, 'timeoutMs': 10000,
        'importPaths': [str(host), str(imports)], 'readyProperty': 'previewReady',
        'initialProperties': properties, 'imageMode': 'path',
        'measureObjects': [] if reference else ['vpnContentViewport', 'vpnSectionHeader', 'vpnHero', 'vpnEmblem', 'vpnConnect', 'vpnHomeServerName', 'vpnStateTitle', 'vpnHomeNavigationViewport']})
    (base / (name + '.json')).write_text(json.dumps(response, indent=2))
    result = response['result']
    meta = result.get('structuredContent', {})
    diagnostics = meta.get('diagnosticRecords', [])
    unexpected = [d for d in diagnostics if not ('HYPRLAND_INSTANCE_SIGNATURE' in d['message']
        or d['message'].startswith(('QML_READY', 'QML_PASS', 'QML_RESULT', 'QML_MOTION', 'NATIVE_READY')))]
    ready = 'NATIVE_READY' if reference else 'QML_READY'
    passed = not result.get('isError') and not unexpected and any(d['message'].startswith(ready) for d in diagnostics)
    if properties.get('suite'):
        passed = passed and any(d['message'].startswith('QML_RESULT') for d in diagnostics)
    manifest.append({'name': name, 'theme': theme, 'properties': properties,
        'passed': passed, 'sha256': meta.get('sha256'), 'inspected': False})
    (base / 'manifest.json').write_text(json.dumps(manifest, indent=2))
    print(name, 'PASS' if passed else 'FAIL', unexpected if not passed else '', flush=True)
    assert passed, result if result.get('isError') else unexpected


try:
    if args.mode in ['all', 'check']:
        suites = ['compactLayout', 'settingsFooter', 'errorDetails', 'helperRecovery', 'dangerContrast', 'barContrast', 'rowProbes', 'loading', 'names', 'lazySections', 'serviceQueue', 'sessionLifetime', 'sessionDataReattach', 'brand', 'states', 'routing', 'summary', 'geometry', 'subscriptions',
                  'servers', 'custom', 'rules', 'settings', 'appsDiscovery', 'actions', 'keyboard', 'pointerForms',
                  'layoutFit', 'focusCues', 'homeReturn', 'probesAndPreferences']
        if args.suites:
            suites = args.suites.split(',')
        for locale in ['en', 'ru']:
            for suite in suites:
                render(f'qml-check-{locale}-{suite}', 'catppuccin-latte',
                       {'locale': locale, 'theme': 'catppuccin-latte', 'suite': suite, 'capture': ''})
        for locale in ['en', 'ru']:
            for suite in ([] if args.suites else ['geometry', 'routing', 'keyboard']):
                render(f'qml-check-small-{locale}-{suite}', 'tokyo-night',
                       {'locale': locale, 'theme': 'tokyo-night', 'suite': suite, 'capture': ''}, width=400, height=560)
    if args.mode in ['all', 'render']:
        for theme in THEMES:
            render(f'qml-reference-{theme}', theme, {}, reference=True)
            for locale in ([] if args.references_only else ['en', 'ru']):
                for state in ['first-run', 'disconnected', 'connecting', 'connected', 'error', 'unavailable']:
                    render(f'qml-{theme}-{locale}-{state}', theme,
                        {'locale': locale, 'theme': theme, 'stateName': 'disconnected' if state == 'first-run' else state,
                         'capture': 'first-run' if state == 'first-run' else 'home'})
                render(f'qml-{theme}-{locale}-transport-stalled', theme,
                       {'locale': locale, 'theme': theme, 'capture': 'transport-stalled', 'stateName': 'connected'})
                for tab in ['servers', 'settings']:
                    render(f'qml-{theme}-{locale}-{tab}', theme,
                        {'locale': locale, 'theme': theme, 'tab': tab})
                render(f'qml-{theme}-{locale}-import-error', theme,
                    {'locale': locale, 'theme': theme, 'capture': 'server-import-error', 'tab': 'servers'})
                render(f'qml-{theme}-{locale}-home-bottom', theme,
                    {'locale': locale, 'theme': theme, 'capture': 'home-bottom', 'scrollBottom': True})
finally:
    client.close()
