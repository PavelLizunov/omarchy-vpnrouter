# Implementation Plan & Packaging Architecture: Omarchy VPNRouter Plugin

- **Plugin Identifier:** `io.github.pavellizunov.vpnrouter`
- **Target Desktop Shell:** Omarchy Quattro (QML / Quickshell)
- **License:** GNU General Public License v3.0 (GPL-3.0), matching upstream VPNRouter
- **Approved Protocol Contract:** `plans/omarchy-protocol-v1.md` (in `VPNRouter` repository)
- **Task Scope:** Packaging, setup lifecycle (`setup`), binary wrapper (`bin/vpnrouter-headless`), test suite (`tests/test-packaging.py`), documentation (`README.md`, `README.ru.md`), `.gitignore`, `LICENSE`.
- **Companion Worker Scope:** Native QML components, user interface views, and root plugin manifest.

---

## 1. Development Status & Upstream Seams

### Current Status
Active pre-release development. The packaging scaffolding, launcher wrapper, setup automation, test harness, and documentation are implemented in this repository (`omarchy-vpnrouter`).

### Lack of Shipped Upstream Binary
The native backend executable `VPNRouter.Headless` is developed in the upstream main repository (`https://github.com/PavelLizunov/VPNRouter`) under `src/VPNRouter.Headless`. As of this milestone, no pre-built binary release or public package has been published upstream.

In compliance with the project security invariants:
- The setup script **does not invent release download URLs** or attempt automatic HTTP downloads from the public internet.
- The backend binary must be supplied explicitly by the operator either as a locally compiled directory (`./setup --backend-dir <PATH>`) or as a verified, pinned local archive with checksum validation (`./setup --artifact <FILE> --sha256 <HASH>`).
- Running `./setup` without a supplied backend detects the absence of `VPNRouter.Headless`, outputs an informative development status report with build instructions, checks system dependencies, and exits cleanly without false completion claims.

---

## 2. Safe Architecture & Security Constraints

The plugin adheres strictly to the security doctrine outlined in `omarchy-plugin-patterns`:

1. **Zero Credential Harvesting & No Root Prompts:**
   - The plugin UI and setup scripts never prompt the user for a root/sudo password.
   - No `sudo -S` stdin piping, no modification of `/etc/sudoers.d/`, and no `NOPASSWD` grants.
   - Privileged networking actions (TUN device creation, routing policy adjustments via `nftables` or `iproute2`) are delegated downstream to system Polkit agents and service brokers, never driven through arbitrary root shell execution.

2. **Bounded Deterministic Execution (No PATH Injection):**
   - The launcher `bin/vpnrouter-headless` executes only deterministic, verified filesystem paths:
     1. Local packaged binary: `<plugin_dir>/bin/VPNRouter.Headless`
     2. System binary: `/usr/lib/vpnrouter-headless/VPNRouter.Headless`
     3. (Testing override): Absolute path specified via `VPNROUTER_HEADLESS_BIN`
   - The wrapper **never searches `$PATH`**, preventing execution of untrusted binaries from arbitrary search paths.
   - If the backend is missing, `bin/vpnrouter-headless` outputs a descriptive error message to `stderr` and terminates with exit code 1; it never attempts automatic downloads or privilege elevation.

3. **Protocol v1 Contract Enforcement & Flag Filtering:**
   - The wrapper acts as an argument filter.
   - Only contract-authorized flags are permitted:
     - `--stdio`: Standard I/O communication mode (default and mandatory).
     - `--data-dir <PATH>`: Validated to ensure `<PATH>` is an absolute path.
     - `--version`: Emits backend version and exits.
     - `--help`: Emits help message and exits.
   - Any unknown, arbitrary, or dangerous flags (e.g. `--injected`, shell metacharacters, or arbitrary options) are rejected immediately with exit code 2.
   - The wrapper uses `exec` to hand over process control directly to the backend, ensuring proper signal propagation (SIGTERM/SIGINT) and stream management.

4. **Strict Configuration Preservation:**
   - User VPN configurations, keys, profiles, and routing rules reside in `$XDG_DATA_HOME/vpnrouter` (defaulting to `~/.local/share/vpnrouter`).
   - The setup script and wrapper treat user configuration as user-owned data:
     - `setup` on install never touches existing user configuration.
     - `setup` on update replaces only the backend binary, leaving user configuration intact.
     - `setup --remove` removes only packaged binary files, explicitly preserving all user configuration and credentials.

5. **Atomic Binary Replacement:**
   - Binary replacement uses temporary staging (`mktemp` in `bin/`) and atomic replacement (`mv -f`).
   - If an active backend helper is running, a `SIGTERM` signal is delivered to its PID to allow graceful termination before the shell relaunches the service.

6. **No Implicit Activation:**
   - Running `./setup` does not automatically enable the plugin in the Omarchy shell or activate any VPN tunnel.
   - Activation requires an explicit, deliberate operator command: `omarchy plugin enable io.github.pavellizunov.vpnrouter`.

---

## 3. Protocol v1 & Version Checks

The backend and frontend communicate via Protocol v1 over standard I/O:
- **Wire Framing:** UTF-8 newline-delimited JSON. Every frame carries `"v": 1`.
- **Bounded Buffers:** Maximum input frame size 256 KiB; maximum JSON nesting depth 32; bounded output queues.
- **Separate Backend Version vs Protocol Version:**
  - **Backend Application Version:** Reports the version of `VPNRouter.Core` (e.g. `2.48.0` or git commit). Inspected via `VPNRouter.Headless --version` or snapshot field `backendVersion`.
  - **Protocol Wire Version:** Identifies the wire schema (`v:1`). Inspected by sending a snapshot probe `{"v":1,"id":"probe","method":"snapshot","params":{}}` and confirming the response frame has `"v": 1`.
  - `setup --status` checks and reports both versions independently to prevent confusion between protocol changes and application updates.

---

## 4. Lifecycle & Command Reference

### A. Compiling Backend Upstream
From the main `VPNRouter` repository checkout:
```bash
dotnet publish src/VPNRouter.Headless/VPNRouter.Headless.csproj \
  -c Release \
  -r linux-x64 \
  --self-contained \
  -o /tmp/vpnrouter-headless-build
```

### B. Installing from Local Directory
```bash
cd /var/lib/dsh/Project/omarchy-vpnrouter
./setup --backend-dir /tmp/vpnrouter-headless-build
```

### C. Installing from Pinned Artifact
```bash
./setup --artifact /path/to/vpnrouter-headless-linux-x64.tar.gz --sha256 <expected-sha256>
```

### D. Checking Installation & Dependency Status
```bash
./setup --status
```

### E. Removing Backend (Preserving User Config)
```bash
./setup --remove
```

### F. Activating Plugin in Omarchy Shell
```bash
omarchy plugin enable io.github.pavellizunov.vpnrouter
```

---

## 5. Dependencies

### Runtime System Dependencies
- **Omarchy Shell:** Omarchy Quattro environment with Quickshell.
- **Linux Kernel:** TUN driver (`CONFIG_TUN=m` or `=y`), `nftables`.
- **iproute2:** `ip` command for route/interface inspection.
- **Polkit:** Active desktop polkit authentication agent for privileged backend operations.

### Backend Dependencies
- **VPNRouter.Headless:** Upstream .NET 10 headless host.
- **sing-box:** Bundled with backend or installed via system package for dataplane routing.

---

## 6. Packaging Test Suite (`tests/test-packaging.py`)

A comprehensive Python standard library test suite verifies all packaging and lifecycle requirements without requiring a live Omarchy shell or network access:
1. Setup without arguments when backend is absent (checks development status notice, no network requests, safe exit code 1).
2. Setup with `--backend-dir` using a benign mock backend (checks atomic installation, 0755 mode, version/protocol probing).
3. Setup with `--artifact` and `--sha256` (verifies archive extraction and checksum mismatch rejection).
4. Setup `--remove` (verifies binary removal while verifying mock configuration directory preservation).
5. Setup `--status` (verifies detection of present vs absent backends).
6. Wrapper `bin/vpnrouter-headless`:
   - Enforces deterministic path resolution without searching PATH.
   - Rejects unauthorized or malformed arguments.
   - Validates absolute `--data-dir`.
   - Passes `--stdio` and `--version`.
   - Exits nonzero with clear error when backend is missing.
7. Protocol v1 Framing & Interaction:
   - Validates JSON-lines request/response streaming.
   - Validates oversized frame (>256 KiB) handling.
   - Validates malformed frame handling.
   - Validates non-v1 protocol version rejection.
8. License & Repository Hygiene:
   - Verifies `LICENSE` contains exact GPL-3.0 text and provenance to VPNRouter.
   - Verifies `.gitignore` tracks wrapper while ignoring compiled binaries in `bin/`.

---

## 7. Remaining Work & Incomplete Requirements

1. **Upstream Release Artifacts:** `VPNRouter.Headless` binary publishing in `PavelLizunov/VPNRouter` is pending.
2. **QML & Manifest Integration:** Companion worker is authoring `contents/ui/` components and `manifest.json`.
3. **End-to-End Target Testing:** Integration testing on authorized test hosts (`omarchy-test`) requires both workers' outputs and upstream backend build.
