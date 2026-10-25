# VPNRouter Plugin for Omarchy Quattro

Native QML and Quickshell plugin for Omarchy Quattro, providing desktop shell integration for VPNRouter.

- **Manifest Identifier:** `io.github.pavellizunov.vpnrouter`
- **License:** GNU General Public License v3.0 (GPL-3.0)
- **Upstream Repository:** [PavelLizunov/VPNRouter](https://github.com/PavelLizunov/VPNRouter)
- **Protocol Contract:** Protocol v1 (`plans/omarchy-protocol-v1.md` in VPNRouter)

---

## Development Status & Scope

> **DRAFT STATUS NOTICE:** This repository and plugin are an early development draft and are **NOT intended for production use**.

This repository provides the Omarchy Quattro shell plugin interface, packaging lifecycle, and launcher wrapper.

- **Backend contract:** The plugin follows `VPNRouter.Headless` at `29dcca1a29a670f0a45cf44a72fa639231427040` in upstream [PR #616](https://github.com/PavelLizunov/VPNRouter/pull/616). Optional round-four metadata is documented below. UI checks include the running test VM with Omarchy 4.0.4 / Quickshell 0.3.1 and offscreen rendering against the newer installed host. VPN connection and traffic routing remain unverified.
- **Availability:** Connect stays disabled unless the backend reports `capabilities.connect=true`. The hero translates optional `unavailableReasonCode` values and falls back to `unavailableReason` for older peers. A missing backend shows an installation hint for `vpnrouter-headless` and stops automatic retries. Other process failures retry after 2–30 seconds; only a successful snapshot response resets the delay.
- **Verification:** Server and free-pool verification show success, latency or failure details in their respective views. Kill switch and DNS lockdown remain unavailable on Linux; a saved DNS-lockdown preference is neither shown as active nor resubmitted when unsupported.

---

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
ring, connection button and routing segments. All colours, typography, spacing
and control geometry come from the installed Omarchy `Color`, `Style`, `Border`
and `Ui` components. Connected/connecting use the theme accent, errors and
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

## Security & Architecture Invariants

The packaging and launcher scripts enforce explicit safety boundaries:

1. **Zero Credential Harvesting & Unprivileged Operation:**
   The plugin and setup scripts never prompt for root passwords, invoke `sudo -S`, edit `/etc/sudoers.d/`, or configure `NOPASSWD` entries.
   **Engine Elevation & Privileged Firewall Route Filtering Status:**
   The unprivileged nature of the setup script and launcher wrapper is **not proof that the engine cannot elevate**: existing `VPNRouter.Core` implementations on Linux may invoke `pkexec` for privileged operations. Architectural design approval for a dedicated privileged broker/helper service is still **PENDING**. Privileged firewall route filtering (`killSwitch` and `dnsLockdown`) is **NOT** finished and remains pending that approved broker/helper service (tracked upstream in [plans/OPEN-DEFECTS.md](https://github.com/PavelLizunov/VPNRouter/blob/main/plans/OPEN-DEFECTS.md)). The headless daemon currently reports `capabilities.killSwitch: false` and `capabilities.dnsLockdown: false`. Route filtering via Polkit is not implemented; setup does not configure or claim working firewall kill-switch rules.

2. **Bounded Deterministic Execution (No PATH Injection, No Env Backdoors, Zero Symlinks):**
   The launcher wrapper `bin/vpnrouter-headless` executes only bounded paths:
   - Packaged backend payload: `<plugin_dir>/bin/backend/VPNRouter.Headless`
   - System installation: `/usr/lib/vpnrouter-headless/VPNRouter.Headless`
   The wrapper never searches `$PATH`, rejects symlink targets, and contains no environment variable overrides or testing backdoors. If no backend is found, it terminates with exit code 127 without downloading external files.

3. **Strict Protocol v1 Argument Filtering & Local Help:**
   The launcher wrapper forwards only contract-authorized arguments (`--stdio`, `--data-dir <ABSOLUTE_PATH>`). Optional help (`--help`, `-h`) is generated locally without executing the backend. All unauthorized flags (including `--version`) and arbitrary echo/piped inputs are rejected with exit code 2.

4. **Refusal of Active Backend Updates (No Active Update Race Claims):**
   Setup detects whether an active backend process is currently running. If an active backend is detected, setup refuses the update with an error and terminates. It **never** sends `SIGTERM` or `SIGKILL` and **never** kills active processes. Running services must be stopped deliberately by the operator before running setup. Setup does not claim active update race freedom while a daemon is running; updates require an inactive backend.

5. **Single Payload Directory & Backup-and-Rename (Zero Symlinks, Safe Staging):**
   The Omarchy validator strictly prohibits ANY symlinks inside a plugin. Setup packages all backend materials into a single plugin-relative payload directory (`bin/backend/`). Build materials containing symlinks, files with leading hyphens, or files with trailing dots are strictly rejected. Setup stages materials in a sibling temporary directory, backs up any existing `bin/backend/`, and renames the new directory into place. (Directory replacement is backup-then-rename with rollback on validation or signal failure, not an atomic update of active processes.)

6. **Fail-Closed Session Lock Verification:**
   On a live host running `omarchy-shell`, setup queries session lock status. If the lock query fails, times out, returns unparseable output, or indicates a locked session, setup fails closed immediately. Lock status verification strictly requires Python 3 (no weak `jq` fallback).

7. **Post-Install Manifest & Plugin Validation with Rollback:**
   Manifest structure, zero-symlink integrity, and host plugin validation (`omarchy plugin validate`) are executed strictly AFTER final installation into `bin/backend/`. If validation fails, setup aborts and rolls back to the previous installation.

8. **Safe Protocol Handshake (No Production Helper on User Config):**
   Setup verifies Protocol v1 compatibility over `--stdio` using a fresh private temporary directory passed to `--data-dir`, avoiding launching the helper against the default user configuration. Handshake uses a bounded selector reading stdout and stderr with monotonic timeout, checking the 256 KiB limit before memory accumulation, discarding stderr without exposing secrets, and strictly validating protocol version (integer 1), request ID, result/error objects, and rejecting unknown fields.

9. **Preservation of User Configuration:**
   User profiles, routing rules, and credentials reside in `~/.config/vpnrouter`. Setup, update, and removal operations never modify or delete user configuration files.

10. **No Implicit Activation:**
    Running setup does not enable the plugin or start VPN tunnels. Activation requires an explicit user command.

---

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
In your local checkout of `VPNRouter`:
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
Verify installation and protocol compatibility without modifying files:
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
Run the packaging test suite using Python standard library (no external dependencies, network access, or live shell required):
```bash
python3 tests/test-packaging.py
```
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
  python3 -B tests/render-theme-matrix.py --evidence-dir /tmp/vpnrouter-theme-review
```

The runner generates theme files with Omarchy's installed template generator in
private directories. The renderer reads them through unchanged host `Color`
startup FileViews in an isolated HOME. It captures Catppuccin Latte, Tokyo Night
and Hackerman in EN/RU, six home states, Servers, Settings and home navigation.
The built-in Bluetooth reference uses inert device fixtures. Only the layer-shell
window is adapted to an Item; host controls and plugin content are real QML.

### Isolated QML Component Tests (Offscreen Shim)
The automated QML test runner executes isolated syntax, component loading, and UI model tests offscreen:
```bash
tests/qml-test-runner.sh
```
These tests run against an offscreen Qt/QuickShell harness using an offscreen `KeyboardPanel` shim adapter. They are **NOT real host acceptance tests** in an interactive Omarchy Quattro desktop session, and they do not prove live shell IPC integration or live desktop operation.

---

### Real published backend check (Linux, opt-in)

With a trusted local publish directory and its required .NET runtime available:
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

GNU General Public License v3.0 (GPL-3.0). See [LICENSE](LICENSE) for full text and provenance details.
