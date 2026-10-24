# Quattro integration, step 1 — 2026-10-22

The integration branch starts at `origin/main` (`175d9da93fb300c0e99cba1beb3cc0d10d888a70`)
and imports draft PR #2 (`e742c1d11ef5851e834a04b6dbe97748c9725036`). There were no
content conflicts. PRs #1 and #2 remain unchanged. This step does not install or
enable the plugin, start a second Quickshell, restart the host, or connect a VPN.

## Installed host comparison

Reference: `/usr/share/omarchy/shell/plugins/panels/clock/{manifest.json,BarWidget.qml,Panel.qml}`,
Omarchy `4.5.0rc1-1`, Quickshell `0.3.2.r7.g2b4501a-1`, Qt Declarative `6.12.0-1`.
The official development guide is <https://plugins.omarchy.org/develop.html>.

- The manifest correctly declares `bar-widget` and `service`, mapped to
  `BarWidget.qml` and `Service.qml`. `Panel.qml` is owned by the widget's Loader;
  it is not a separate manifest kind. The service kind is an intentional
  addition to the clock structure: one shared backend owner across bar instances.
- Fixed missing forwarding of widget settings to the nested panel and locale to
  the shared service. Service lookup uses the manifest ID through the scoped
  host `shell.serviceFor()` API; removed nonexistent widget `pluginId` fallbacks.
- Fixed panel switching to identify `hostWidget`, matching the installed clock.
  Existing open/close/toggle/opened, popout closing, keyboard focus and Escape
  forwarding remain in place. Lazy loading is intentional; the clock eagerly
  loads its calendar. Actual lifecycle execution remains untested.
- Declared `modelData` in the bound panel delegate; removed shadow declarations
  of the inherited Item `enabled` and `state` properties.

## Other small corrections

Wire request/direct-frame limits now count UTF-8 bytes. An absent snapshot error
is assigned as an empty QML string. The hero displays unavailable/error states
accurately. Rules success notices wait for a successful backend callback.
Setup status no longer suggests copying/linking sing-box as a verified connection
path. Both READMEs describe the current read-only profile DNS mode.

New tests execute actual QML JavaScript function bodies for host context,
locale propagation, panel switching and absent errors, plus multibyte wire limits.
They fail against the imported draft and pass against the corrected source.
They do not establish Qt binding or live host behavior. The existing service
suite includes a JavaScript simulator; it is not a real backend test.

## Static validation

Working directory: repository root. Each command exits 0 on the final source:

```sh
omarchy plugin --help
python3 -m json.tool manifest.json
python3 -m json.tool locales/en.json
python3 -m json.tool locales/ru.json
find . -type l -print
omarchy plugin validate /home/slovn/Work/omarchy-vpnrouter
bash -n setup bin/vpnrouter-headless tests/qml-test-runner.sh
node tests/test-ui-contract.js
node tests/test-ui-host.js
node tests/test-ui-i18n.js
node tests/test-ui-model.js
node tests/test-ui-protocol.js
node tests/test-ui-service.js
python3 tests/test-packaging.py
python3 -m py_compile tests/check-published-backend.py tests/test-packaging.py
python3 tests/check-published-backend.py --help
git diff --check
```

Kind/entry-point equality, safe relative paths and existence were independently
asserted with Python. Symlink search returns no entries. Packaging has 38 tests
using temporary fixture copies and mock Omarchy/backend executables.

Every QML file, including tests, is passed to `/usr/lib/qt6/bin/qmllint` with
`-I /usr/lib/qt6/qml -I /usr/share/omarchy/shell` and an external import root
mapping `qs` to `/usr/share/omarchy/shell` and `Quickshell` to
`/usr/lib/qt6/qml/Quickshell`. These external mappings are outside the plugin tree.
Do not use the preexisting local render import directory as lint evidence: it
contains Quickshell mocks. Lint exits 0 with warnings (dynamic host objects,
Style var tokens, unqualified delegate context and block-scope var declarations);
this is not a warning-free result or runtime certification.

## Checks not established

The installed `qml-render` QQuickView renderer cannot load the native Commons
module in this environment (`AudioNodes.qml: Singleton is not a type`). No
successful native preview or image inspection is claimed. No qml-preview MCP
capability is available. The QML test runner starts Quickshell and was not run.
`check-published-backend.py` requires a trusted local publish directory, which
was not supplied; only help and Python compilation were checked. No actual
backend protocol, tunnel, route, DNS, privileges or installed-plugin lifecycle
was exercised. The parallel backend branch's protocol document returned HTTP
404 during the read-only GitHub lookup; backend compatibility remains pending.
