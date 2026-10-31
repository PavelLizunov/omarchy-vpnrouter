# Marketplace delivery review — 2026-11-01

## Candidate and scope

Base: `4e66c9eb3558d552bed744f2b85e8818018118b9` (plugin 0.1.2).
Task branch: `dsh/marketplace-review-2026-10-31`. The original worktree/index are
unchanged. This candidate adds explicit display-density decode sizes and mipmap
filtering to both original mascot consumers; asset bytes and layout are unchanged.

Loaded skills: omarchy, omarchy-plugin, omarchy-plugin-patterns and ponytail.
This is scoped delivery/source/visual checking, not a complete audit or a
production VPN acceptance claim.

## Executed checks

- Native `omarchy plugin validate`: exit 0. JSON parses; no plugin-tree symlinks.
  Declares bar-widget + service; Panel is internal. Permanent ID:
  `io.github.pavellizunov.vpnrouter`.
- `bash -n setup bin/vpnrouter-headless bin/vpnrouter-backend`: exit 0.
- All 13 `tests/test-ui-*.js` suites: exit 0; EN/RU catalogs contain 327 matching
  keys. Checks include malformed/oversized protocol inputs and callback recovery.
- Isolated Python packaging suite: 42 tests, OK. PID/network namespaces and
  hidden installed helper used for deterministic missing-helper cases.
- Actual QML matrix: 68 interaction cases passed in EN/RU, including constrained
  layouts. A combined rendering run reached 142 successful cases before its
  240-second host deadline; it is not a complete matrix pass. A separate error
  capture run passed all 16 error/import-error cases.
- After the final sourceSize change: 16 disconnected renders passed across four
  themes, both languages and DPR 1/2. Representative full-panel and tour frames
  were inspected inline. Native-size header is smoother with explicit image
  decoding at the display pixel budget; no replacement artwork was generated.
- `qmllint -I /usr/share/omarchy/shell *.qml ui/*.qml`: exit 0, WITH warnings
  (unqualified accesses and dynamic Loader properties). Not warning-free.
- Qt 6.12.0; qml-preview 0.3.0, software/offscreen renderer SHA256
  `779c33b56b756bcf1cd8a02740574b31b5362c81a31d53b98485133a72079cac`.

Evidence directories (local, not public runtime claims):
`/tmp/vpnrouter-marketplace-review-20261031`,
`/tmp/vpnrouter-marketplace-error-20261031`,
`/tmp/vpnrouter-icon-final-dpr1`, `/tmp/vpnrouter-icon-final-dpr2`.

## Installation and package evidence

The exact native add implementation cloned public main into a private fresh HOME,
validated it, retained executable helpers and the bundled archive, and dispatched
rescan/enable. Shell IPC was deliberately stubbed; actual loaded UI is unverified.
A second add refused the existing ID and preserved a marker. Installed HEAD:
`4e66c9eb3558d552bed744f2b85e8818018118b9` (before this cosmetic patch).
Result: `/home/slovn/.cache/agent-tmp/vpnrouter-native-install-_lq98496/result.json`.
Native add follows mutable repository HEAD, not an exact Marketplace SHA.

Bundle SHA256: `504056becc8b8db342a093ed58964da888b07f53ff68787bf202fd91fa4a9739`.
The 21,716,083-byte archive is tracked and byte-identical (`cmp`, exit 0) to
artifact `vpnrouter-headless-arch-0.1.0.r59.gf6b39db-1` from successful upstream
CI run 40348520604 at `f6b39dbfc4d4de6e064b470037ea6b5a312c5a4c`.
This binds distribution bytes to that CI artifact, NOT an independently reproduced
build. Archive metadata and .INSTALL were read. The package installs a user unit
and applies network capabilities to its root-owned sing-box runtime; upgrades
coordinate masking/stopping/resuming user services. It requires .NET runtime 10.

The plugin's package action is explicit, checksum-checked `pkexec pacman -U`.
This is a real review capability, not a hidden download or a privilege exploit.
No root shell, password field or passwordless sudoers grant is introduced.

## Source review admission

A read-only Gemini investigation covered a deliberately limited file snapshot.
Its claims that the archive and BarWidget were absent are rejected: those files
were excluded from leaf inputs, but exist in the complete tracked repository.
The independent findings are NOT accepted wholesale or a certification.
The transport deadline behavior is confirmed: admission stays closed until
helper restart, preserving write credit and avoiding killing an active stdio
VPN owner. This is documented/tested behavior with a recovery usability limit,
not repaired speculatively in this publication task.
Plugin-local stdio precedence, unsupported firewall protection and missing
reported-laptop upgrade acceptance remain explicitly documented limits.

## Video and publication

EN/RU 24-second videos capture actual QML frames and navigation, using inert
sample responses. All nine advanced destinations plus Home and subscription
entry are shown. No real VPN connection or desktop recording is claimed.
Representative frames were inspected; eight recording runs emitted no unexpected
warnings. Publish with the sample-data disclosure. Videos are under `docs/media/`.

Live Marketplace registry/catalog contained no entry for this repository or ID
when checked. Search result #5460 belongs to another author/repository and is
unrelated. No duplicate submission has been created. New submission requires
maintainer review of installer/package/privilege/service capabilities.
Marketplace approval and live card/copy installation remain pending.

## Remaining limits

Direct SSH to omarchy-test and site-and-git timed out. The available harness-test
Tailnet address rejected this workstation's key. No VM changes, live activation,
route changes, production-site deployment or package installation were performed.
Physical VPN routing/leak protection, screen-reader use, independent reproducible
build and all-theme pixel inspection remain unverified.
