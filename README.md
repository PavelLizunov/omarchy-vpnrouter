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

- **Backend Status:** The headless daemon (`VPNRouter.Headless`) and its bounded Omarchy adapter were delivered at commit `64e1e805` in upstream draft PR #296 (with 5 green CI checks). However, that PR is **not merged** and no release binaries have been published.
- **Frontend / Packaging Status:** Plugin packaging scripts, deterministic launcher wrapper, and test harness are implemented here in draft form. Native QML interface components and root manifest are maintained in parallel.
- **Connection Capability Limits:** A compiled backend binary alone is **NOT sufficient to connect**. A supported connection path has not been accepted: runtime binary selection/distribution, binary integrity and compatibility, and TUN privileges remain unresolved. This is not a guarantee that connection attempts cannot launch the engine on a provisioned host. The setup tool does not fake connection state or invent remote release URLs.

---

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
   The wrapper never searches `$PATH`, rejects symlink targets, and contains no environment variable overrides or testing backdoors. If no backend is found, it terminates with exit code 1 without downloading external files.

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

### Backend Requirements & Known Deployment Gap
- .NET 10 runtime (if running framework-dependent backend) or self-contained binary
- `sing-box` (supplied with backend build materials)
- **Deployment & Connection Gap Notice:** A compiled backend binary alone is **NOT enough to connect**. A backend binary does not establish a supported connection path: runtime binary selection/distribution, integrity/compatibility checks and TUN privileges remain unresolved:
  - Upstream `VPNRouter.Core` currently resolves its routing binary path strictly via `AppPaths.SingBoxExePath` (`~/.config/vpnrouter/bin/sing-box`), whereas `setup` stages files into `<plugin_dir>/bin/backend/`.
  - **Do NOT copy or deploy binaries into writable user data directories (such as `~/.config/vpnrouter/bin/`)** as a workaround. Doing so is not a safe, supported, or ready-to-connect deployment path.
  - Safe tunnel connection requires upstream support for secure binary location, integrity validation, and an approved privileged helper design for TUN interface management.

---

## Installation & Setup

Because pre-compiled backend binaries are not yet published upstream, the backend must be supplied locally from an explicit local build directory.

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

### 4. Enable Plugin in Omarchy Shell (Testing Reference Only)
> **Notice:** The following activation step is documented **strictly as a reference for separately authorized testing** in an isolated development environment. It is **NOT** a recommended production installation procedure, as this plugin is an early draft and live VPN connections are not yet supported.

Enable the plugin explicitly for testing:
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

Resetting DNS mode to the profile default clears the explicit override. That
choice survives a settings refresh and an unrelated save. Strict DNS and
full-tunnel policy still take precedence; the selected value is not a complete
description of runtime DNS routing. In custom-config mode the DNS mode selector
is disabled, but other settings can be saved. Unavailable DNS-lockdown controls
are not resubmitted or silently disabled; an existing requirement for unsupported
protection still prevents connection.

## Testing

All test suites reflect an isolated **draft development state**, not verified production readiness.

### Packaging and Isolation Tests
Run the packaging test suite using Python standard library (no external dependencies, network access, or live shell required):
```bash
python3 tests/test-packaging.py
```
The test suite validates missing backend notices, directory-copied benign mock backends without environment backdoors, verification of zero symlinks after install, post-install manifest/host validation with automatic rollback, safe private temporary `--data-dir` handshake without touching user config, active backend update refusal without signaling, fail-closed lock verification, configuration preservation in `~/.config/vpnrouter`, and wrapper argument filtering.

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
