# User and developer guide

[Front page](../README.md) · [Русский](guide.ru.md)

Run repository commands below from the repository root. Backend publish runs belong on CI or an isolated test worker.

## Open a section from a shortcut

The bar icon and `omarchy-shell shell toggle io.github.pavellizunov.vpnrouter '{}'`
open the panel. For a specific section, use the plugin's singleton navigation target:

```bash
omarchy-shell io.github.pavellizunov.vpnrouter.ui open '{"page":"servers"}'
omarchy-shell io.github.pavellizunov.vpnrouter.ui open '{"page":"servers","form":"import"}'
omarchy-shell io.github.pavellizunov.vpnrouter.ui open '{"page":"subscriptions","form":"add"}'
```

Pages: `home`, `servers`, `subscriptions`, `apps`, `rules`, `settings`,
`diagnostics`, `free`, `profiles`, `custom`. Forms only open a local draft;
they do not submit data. Unknown pages/forms and payloads over 1024 characters
return `invalid`. The host chooses the focused monitor. Omarchy 4.0.4 drops
payloads on the generic bar-widget summon route, so use this target for sections.
An optional `"locale":"en"`, `"ru"` or `"auto"` previews the panel language
for this shell session without saving shell configuration.
On hosts without `Commons.I18n`, automatic language follows `LANG`.

## Apps, first run and server sources

The home page keeps the Virtual Penguin Network title, original mascot, status
ring, connection button and routing segments. Controls use the installed Omarchy `Color`, `Style`, `Border`
and `Ui` components and host font. Connected/connecting use the theme accent, errors and
unavailable states use urgent. The bar uses filled Material shield glyphs with
native icon sizing and alignment; disconnected uses foreground and startup uses
muted. Neutral marks in the panel use muted. Popup background
luminance selects the original black or white mascot PNG; the asset bytes do not
change. The Omarchy panel owns fitting and lifecycle.

When the server and subscription lists are both empty, **Add a subscription** in
the connection card or Servers section opens the Subscriptions form. Opening the
form does not fetch anything. **Change** opens Servers, or Custom Config when a
custom configuration is active. The home list opens each
advanced section; its fixed back arrow returns to the originating row. One fitted
frame and internal scrolling keep the panel stable across sections and forms.
Tab traverses controls; Escape closes the panel. Enter submits single-line forms;
multiline server/configuration editors use Ctrl+Enter.

The Applications section uses optional `apps.list.runningApps` metadata for
display names, freedesktop icons and exact, case-sensitive process match names. The default list
shows apps with a desktop entry or an open Hyprland window
(matched by process name/window class, or PID when supplied by the backend).
Other processes are collapsed under a counted section. Search matches display
and process names across both sections and reveals matching processes.
Suggestions are capped at 200; manual process-name entry remains available.
Older backends without this metadata show manual entry and the selected list,
with an explanation instead of unclassified process suggestions.

Servers group by manual source or subscription name. Delete is offered only when
`removable=true`; older peers without source/removal metadata use an unknown-source
group without Delete. The backend remains authoritative for removal. Diagnostic
severity labels and first-launch setup notices are localized; other backend prose
is displayed verbatim. Kill switch is disabled with a Linux explanation; DNS
lockdown follows the backend capability and is omitted from writes when absent.

Routing uses explicit native choices: **Selected apps only / All traffic**.
In split mode, **Only selected apps use VPN / All except selected** chooses the
app list's meaning. The home page exposes Selected apps / All traffic;
Applications also controls the include/exclude policy.

The home page distinguishes service startup from a VPN connection. If reading
status fails, it keeps the reported error visible.

Subscription URLs are masked by default. Import forms keep input on failure and
clear it after success or Cancel; empty/invalid input produces inline feedback.
Each open form has one submit/cancel row; Cancel returns focus to Add or Import.
Settings provide **Revert changes**, which restores the last values returned by
the service. Invalid CIDRs are sent intact for service validation rather than
silently removed. Multiline editors scroll internally; Enter adds a line,
Ctrl+Enter submits, and Tab leaves the editor. Icon actions use localized native
hover hints; selectable feedback shows the theme accent edge when focused.

Rules export returns saved rules as selectable text in a separate read-only area;
it preserves unsaved edits and does not create a file. Diagnostics export shows
the service's full selectable, wrapping output path and clears stale feedback
before a retry.

Diagnostic rows keep each result message and severity. Repeated `HealthCheck`
headings are omitted when a message is present; descriptive check names remain.

## Display language

The panel follows the Omarchy shell language (`Commons.I18n.language`) by default.
The header language control cycles through EN/RU overrides and AUTO to return to
following the shell. Overrides are saved in the widget's `locale` setting.
The plugin ships English and Russian catalogs.
Local service errors follow language changes; diagnostic prose from the backend
remains verbatim. A successful retry clears the previous error for that operation.

The widget's `mode` preference chooses the initial Home (`simple`) or Servers
(`advanced`) view. `showLatency` controls latency badges in the bar, tooltip and
server/free-pool lists. Home does not show a latency badge. Basic tests report a
measured value (including 0 ms), an unmeasured result or a failure; an unmeasured
result does not establish that the server is offline. Verification is a separate
HTTP test through a temporary local SOCKS proxy, without a TUN connection.

Server, subscription and free-pool lists load 100 rows at a time; **Load more**
opens the next page. Refreshing a server list discards its previous basic latency
measurements. Enabling/removing a subscription refreshes the server list too.
Free-pool latency badges appear only for successful basic or verified probes; rejected probe timings stay hidden after a list refresh.
Free-pool **Apply** requires a successful verification. Application list editing
waits for each acknowledged update to avoid replacing an in-flight change.
Service errors are also shown in the open advanced section. Requests fail
immediately when the helper is absent, so forms do not remain pending forever.
After a backend restart, an open panel reloads its lists and current section.
Reconnecting the VPN still requires an explicit Connect action.

## Dependencies

### System Requirements
- Linux kernel with TUN module
- Omarchy Quattro shell with Quickshell
- `iproute2` (`ip` utility)
- Python 3 (required for setup lifecycle operations; no weak `jq` fallback)
- *Firewall route filtering status:* `killSwitch` and `DNS lockdown` route filtering via firewall are pending a dedicated privileged broker (`capabilities.killSwitch: false`, `capabilities.dnsLockdown: false`).

### Backend requirements

The Arch `vpnrouter-headless` package supplies `/usr/lib/vpnrouter-headless/VPNRouter.Headless` and its .NET dependencies. Its runtime is `/usr/lib/vpnrouter-headless/runtime/sing-box`; the package install hook applies file capabilities. The backend verifies runtime ownership, permissions and capabilities before allowing connect. A plugin-local publish directory alone does not provision that system runtime. Kill switch and DNS lockdown remain unavailable on Linux.

---

## Installation & Setup

With the `vpnrouter-headless` package already installed, copy the plugin's committed files into a real directory (not a symlink):

With the coordinated lifetime-candidate backend, the plugin starts the systemd
user service and attaches to its private socket. A shell restart detaches the
UI while the service retains the session. With an older package or plugin-local
payload, stdio fallback still stops the backend and drops an active connection.
Connected-session survival across restart remains unverified. See the
[candidate contract](../plans/session-lifetime-candidate.md).

```bash
plugin_dir="$HOME/.config/omarchy/plugins/io.github.pavellizunov.vpnrouter"
mkdir -p "$plugin_dir"
git archive HEAD | tar -x -C "$plugin_dir"
omarchy plugin validate "$plugin_dir"
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.pavellizunov.vpnrouter --section right
omarchy restart shell
omarchy plugin list --json
```

Run these commands from this repository at the reviewed commit. The wrapper uses the system backend when no plugin-local payload exists, so `setup --backend-dir` is unnecessary for this route. Shell logs: `journalctl --user -t omarchy-shell -b -f`. These are installation instructions; development checks do not install or enable the plugin.

For a locally published backend instead, use the optional setup flow below.

### 1. Build the Backend from Upstream Source
On CI or an isolated test worker, from the `VPNRouter` checkout:
```bash
dotnet publish VPNRouter.Headless/VPNRouter.Headless.csproj \
  -c Release \
  -r linux-x64 \
  --self-contained \
  -o /tmp/vpnrouter-headless-build
```

### 2. Run Plugin Setup
Point the setup script to your local build directory:
```bash
./setup --backend-dir /tmp/vpnrouter-headless-build
```
Setup stages materials in a sibling temp directory, validates protocol framing via a private temporary directory, backs up existing `bin/backend/`, installs the new payload, and invokes manifest/host validation post-install with automatic rollback on failure. The supplied publish directory must include `profiles/default.json` and `profiles/default-linux.json`; setup preserves these paths and bytes. Missing catalogs, symlinks, special files or catalogs larger than 1 MiB are rejected before the backend handshake. Other subdirectories are not recursively copied.

### 3. Check Status
Check installation and protocol compatibility using temporary probe files:
```bash
./setup --status
```

### 4. Enable the copied plugin

After copying into the user plugin directory and rescanning as above:
```bash
omarchy plugin enable io.github.pavellizunov.vpnrouter
```

---

## Updating & Removal

### Updating the Backend
Before updating, ensure any active backend process has been stopped. Then re-run setup pointing to the new build directory:
```bash
./setup --backend-dir /path/to/updated-build
```
Setup verifies no active backend is running, stages in a sibling temp folder, tests protocol framing, backs up the old `bin/backend/`, renames the new payload into place, and validates the plugin structure post-install (rolling back on failure). User configuration in `~/.config/vpnrouter` is preserved.

### Removing the Backend
To remove the packaged backend binaries:
```bash
./setup --remove
```
This removes `bin/backend/`. Your VPN profiles, certificates, and routing settings in `~/.config/vpnrouter` remain strictly intact.

---

## Launcher and setup behavior

The launcher resolves the executable in the plugin-local payload first, then
under /usr/lib/vpnrouter-headless. It does not search PATH or accept an environment
override. A missing executable exits 127. After resolution, it accepts `--auto`, `--stdio`,
an optional absolute `--data-dir`, and local `--help`/`-h`; other flags exit 2.
It forwards the protocol stream through `exec`, without inspecting stdin as CLI
arguments. Help does not execute the backend, but still requires resolution.

Setup accepts `--backend-dir`, not archives or download URLs. It refuses a
payload update/removal while an existing helper is active; it does not stop that
helper. A running Omarchy session must answer the lock query as unlocked before
installation/removal. The private protocol probe has a three-second read budget
and a 256 KiB stdout budget, discards stderr, checks the version/request ID/result
shape, and terminates its own child on timeout. Post-install validation failure
restores the previous payload. Setup does not enable the plugin or provision
privileged TUN/firewall access. User configuration defaults to ~/.config/vpnrouter
and is preserved; XDG_CONFIG_HOME can select another default directory.

## Protocol Validation

The setup tool inspects protocol compatibility safely:
- **Wire Protocol Version:** Validates compliance with the Protocol v1 framing specification (`v:1` newline-delimited JSON over `--stdio`) using bounded reading and timeout against a fresh private temporary directory passed to `--data-dir`.
- **Coordinator Ownership:** Setup does not invent arbitrary `--version` probes or fallback flags.

---

## DNS settings

The draft DNS controls and UI hints describe editable configuration settings and user preferences, **NOT the live active DNS state** or kernel routing rules of the host system.

DNS mode is read from the selected profile and shown as read-only. Current Core
rejects a DNS-mode write through `settings.set`, so the plugin omits that field.
Strict DNS and full-tunnel settings still affect the explanation shown in the UI.
Unavailable DNS-lockdown controls are not resubmitted or silently disabled.

## Testing

All test suites reflect an isolated **draft development state**, not verified production readiness.

### Packaging and Isolation Tests
Run the packaging fixtures with Python standard library. On an Omarchy host, isolate process detection and mask the installed system helper so the missing-backend cases test their intended input:
```bash
bwrap --unshare-pid --unshare-net --bind / / \
  --dev /dev --proc /proc --tmpfs /usr/lib/vpnrouter-headless -- \
  python3 -B tests/test-packaging.py
```
In CI without an installed helper, `python3 -B tests/test-packaging.py` suffices.
The test suite validates missing backend notices, directory-copied benign mock backends without environment backdoors, verification of zero symlinks after install, post-install manifest/host validation with automatic rollback, safe private temporary `--data-dir` handshake without touching user config, active backend update refusal without signaling, fail-closed lock verification, configuration preservation in `~/.config/vpnrouter`, and wrapper argument filtering.

### UI logic and native offscreen review

Run each `tests/test-ui-*.js` file with Node. `tests/test-ui-metadata.js` exercises the
production model and QML functions for metadata, legacy fallback, sources,
availability reasons, first-run navigation and form validation.
`tests/qml-interactions-consumer.qml` loads the real Panel, Service and locale files with
`processDisabled=true` and inert protocol responses. With the external `qml-render`
tool and a layer-shell-to-Item adapter, it checks actual Qt mouse/key events and
captures the real consumer with installed Omarchy themes. It does not test the
compositor, VPN or network operations.

`node tests/test-ui-theme.js` rejects hex colours and fixed font families in
production QML/JS, and checks every `ui/qmldir` export. With the external
[qml-preview-mcp](https://github.com/PavelLizunov/qml-preview-mcp) renderer available, run the full offscreen
interaction and theme matrix without starting Quickshell:

```bash
bwrap --unshare-net --bind / / --dev /dev --proc /proc -- \
  env NO_AT_BRIDGE=1 QT_LINUX_ACCESSIBILITY_ALWAYS_ON=0 \
  python3 -B tests/render-theme-matrix.py --mode all \
  --evidence-dir /tmp/vpnrouter-theme-review
```

The runner generates theme files with Omarchy's installed template generator in
private directories. The renderer reads them through unchanged host `Color`
startup FileViews in an isolated HOME. It captures Catppuccin Latte, Tokyo Night
and Hackerman in EN/RU, six home states, Servers, Settings and home navigation.
The built-in Bluetooth reference uses inert device fixtures. Only the layer-shell
window is adapted to an Item; host controls and plugin content are real QML.

### Real published backend check (Linux, opt-in)

On a CI runner or isolated test worker with a trusted publish directory and its required .NET runtime:
```bash
PYTHONDONTWRITEBYTECODE=1 python3 tests/check-published-backend.py /path/to/trusted/publish
```
This executes the supplied backend inside a temporary plugin copy with stubbed
Omarchy commands. It checks setup, the production wrapper, `profiles.list`,
read-only data and EOF teardown. The first scenario uses unchanged published
catalogs; a second adds a unique name only to the disposable Linux catalog to
prove platform selection. The supplied publish directory is never changed.
It does not test live shell integration, binary authenticity or a VPN connection.

## License

GNU General Public License v3.0 (GPL-3.0). See [LICENSE](../LICENSE) for full text and provenance details.

## Independent session service candidate

The coordinated backend package ships `vpnrouter-headless.service` as a systemd
user unit. After upgrading the package, run `systemctl --user daemon-reload`.
The plugin starts the unit on demand; it is not enabled at boot and has no
graphical-session stop dependency. Closing the UI or restarting the shell
detaches the relay. The next attachment receives a fresh snapshot.
`systemctl --user stop vpnrouter-headless.service` explicitly tears down the
session; ordinary plugin removal leaves a running service alone. An enabled plugin
retries and starts a lost service again, so disable the plugin before stopping
the unit if it should remain stopped.
A second controller receives `controller_busy`. Socket errors never trigger
stdio fallback when the installed unit exists. Without the unit, or with a
plugin-local payload, stdio behavior remains unchanged. No kill-switch, crash
recovery, lingering, or automatic reconnect is added. See the
[candidate contract](../plans/session-lifetime-candidate.md).
