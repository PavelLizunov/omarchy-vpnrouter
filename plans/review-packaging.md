# Code Review: Omarchy VPNRouter Packaging, Launcher & Lifecycle Integration

**Date:** 2026-09-17  
**Scope:** `setup`, `bin/vpnrouter-headless`, `tests/test-packaging.py`, `manifest.json`, `README.md`, `README.ru.md`, and `VPNRouter.Core.csproj` friend change on branch `dsh/omarchy-plugin-2026-09-17`.  
**Review Lenses:** Correctness, Security, Architecture Invariants, Lifecycle, and Test Parity.

---

## Executive Summary

The packaging and launcher subsystem introduces a cleanly structured, dependency-bounded installer (`setup`) and deterministic launcher wrapper (`bin/vpnrouter-headless`) alongside an extensive test harness (`tests/test-packaging.py`). The implementation successfully respects core isolation boundaries: it eschews network downloads, rejects arbitrary command-line injection, enforces a 256 KiB protocol framing ceiling, and avoids elevated helper shells.

However, deep cross-repository source review against `VPNRouter.Core` and `VPNRouter.Headless` revealed 8 concrete prioritized defects. Most critically, `setup` stages `sing-box` into `bin/backend/sing-box` while `VPNRouter.Core` hardcodes runtime discovery to `AppPaths.SingBoxExePath` (`~/.config/vpnrouter/bin/sing-box`), causing silent startup failures and false-positive readiness reporting. Additionally, subprocess output buffering before allocation exposes setup to memory exhaustion, signal interruptions destroy rollback backups, lock status verification relies on synthetic IPC commands and fabricated issue references, and documentation overstates Polkit privilege handling for firewall filtering.

---

## Prioritized Findings (Max 8)

### Finding 1: Sing-Box Runtime Path Mismatch Breaks Connection Lifecycle
- **Severity:** HIGH / FUNCTIONAL BLOCKER
- **Status:** Confirmed
- **Source Anchors:**
  - `omarchy-vpnrouter/setup:261-265, 421-425`
  - `omarchy-vpnrouter/README.md:71-72` / `README.ru.md:71-72`
  - `VPNRouter.Core/AppPaths.cs:55-56`
  - `VPNRouter.Core/Services/SingBoxManager.Lifecycle.cs:56-70`
  - `VPNRouter.Headless/Lifecycle/PlatformCapabilityVerifier.cs:76-79`
- **Counterevidence & Analysis:**
  In `setup:422-425`, `sing-box` is copied into `$stage_dir/sing-box` and installed into the plugin-relative directory `$plugin_dir/bin/backend/sing-box`. Lines 261-265 check if `$plugin_dir/bin/backend/sing-box` is executable or if `sing-box` exists on `$PATH`, outputting `[OK] sing-box: present`. `README.md` documents `sing-box (supplied with backend or via system package)`.
  However, in `VPNRouter.Core`, `SingBoxManager` resolves `exePath` on Linux strictly via `AppPaths.SingBoxExePath`, which evaluates to `Path.Combine(AppPaths.BinDir, "sing-box")` -> `~/.config/vpnrouter/bin/sing-box`. It never checks `$plugin_dir/bin/backend/sing-box`, `AppContext.BaseDirectory`, or `$PATH`. Similarly, `PlatformCapabilityVerifier.VerifyCanConnect` (line 76) checks `File.Exists(AppPaths.SingBoxExePath)`.
- **Impact:**
  `setup --status` reports `sing-box: present`, but when the backend executes, `capabilities.connect` in the protocol snapshot is `false`. Attempting to connect or run deep verification throws `FileNotFoundException: sing-box not found at: ~/.config/vpnrouter/bin/sing-box`. The plugin cannot start a VPN tunnel out-of-the-box.
- **Fix:**
  Update `setup` to copy or install `sing-box` into `~/.config/vpnrouter/bin/sing-box` (or `AppPaths.BinDir`), or update `VPNRouter.Headless` to locate `sing-box` relative to its own application base directory (`AppContext.BaseDirectory`) or `$PATH` and configure `AppPaths` accordingly before engine initialization.

---

### Finding 2: Unbounded Subprocess Output Reading Before Allocation in Setup Handshake
- **Severity:** HIGH
- **Status:** Confirmed
- **Source Anchors:**
  - `omarchy-vpnrouter/setup:153-176`
  - `omarchy-vpnrouter/setup:52`
- **Counterevidence & Analysis:**
  In `validate_backend_executable` (`setup:160`):
  ```python
  stdout_bytes, stderr_bytes = proc.communicate(input=req.encode("utf-8"), timeout=3)
  ```
  `proc.communicate()` buffers the entire process output stream into memory until EOF. If a backend binary emits gigabytes of data or writes `/dev/zero` to stdout within the 3-second timeout window, Python buffers all bytes into memory. The boundary check:
  ```python
  if len(stdout_bytes) > 256 * 1024:
  ```
  is evaluated *after* unbounded allocation has already occurred. Similarly, `setup:52` executes `status="$(timeout 3s omarchy-shell lock status 2>/dev/null)"` which reads unbounded output into shell memory. Contrast with `setup:218`, which correctly truncates at the OS pipe level via `head -c 262144` before command substitution.
- **Impact:**
  Denial of Service via host memory exhaustion (OOM crash) when validating an untrusted, corrupted, or malfunctioning backend binary.
- **Fix:**
  In Python, read bounded chunks from `proc.stdout` using a capped reader (e.g. `proc.stdout.read(256 * 1024 + 1)`) and terminate the process immediately if the byte count exceeds 256 KiB before buffering. In bash, pipe through `head -c` prior to command substitution.

---

### Finding 3: Interruption During Post-Install Validation Permanently Destroys Backup
- **Severity:** HIGH
- **Status:** Confirmed
- **Source Anchors:**
  - `omarchy-vpnrouter/setup:38-45, 458-485`
- **Counterevidence & Analysis:**
  The `cleanup()` trap registered on `EXIT INT TERM` contains:
  ```bash
  if [[ -n "$backup_tmp" && -e "$backup_tmp" ]]; then
    local target_backend_dir="$plugin_dir/bin/backend"
    if [[ ! -d "$target_backend_dir" ]]; then
      mv "$backup_tmp" "$target_backend_dir" 2>/dev/null || true
    else
      rm -rf "$backup_tmp" 2>/dev/null || true
    fi
  fi
  ```
  During an update, `target_backend_dir` is renamed to `backup_dir`, then `stage_dir` is renamed to `target_backend_dir`. At line 475, `validate_plugin_structure` is invoked. If an operator cancels the operation (`SIGINT` / Ctrl-C) or the process is killed (`SIGTERM`) while validation is running:
  1. `$target_backend_dir` already exists on disk (containing unverified payload).
  2. The `cleanup` trap executes the `else` branch: `rm -rf "$backup_tmp"`.
- **Impact:**
  The previous known-good backend backup is permanently deleted instead of restored, leaving the system with an unverified or interrupted installation.
- **Fix:**
  Introduce an explicit transaction state variable (e.g., `install_phase="staging"`, `"swapping"`, `"validating"`, `"committed"`). In `cleanup()`, unless `install_phase == "committed"`, if `$backup_tmp` exists, remove `$target_backend_dir` and restore `$backup_tmp`.

---

### Finding 4: Incomplete PID Detection Misses Framework-Dependent .NET and Fails Closed on Unrelated Commands
- **Severity:** MEDIUM
- **Status:** Confirmed
- **Source Anchors:**
  - `omarchy-vpnrouter/setup:103-126`
  - `omarchy-vpnrouter/tests/test-packaging.py:446-492`
- **Counterevidence & Analysis:**
  `check_no_active_backend()` inspects processes via `pgrep -f "VPNRouter\.Headless"` and checks `/proc/$pid/exe` and `cut -d '' -f 1..2 /proc/$pid/cmdline`:
  1. Framework-dependent execution: When `VPNRouter.Headless` runs via `dotnet exec /path/to/VPNRouter.Headless.dll`, `/proc/$pid/exe` points to `/usr/bin/dotnet`, `arg0` is `dotnet`, `arg1` is `exec`, and `arg2` is `VPNRouter.Headless.dll`. The checks `[[ "$exe" == */VPNRouter.Headless ]]` and `[[ "$arg1" == */VPNRouter.Headless ]]` fail to match, allowing `setup` to overwrite files under an active running process.
  2. False-positive refusal: `cut -d '' -f 2` matches any process where the first argument is `VPNRouter.Headless` (e.g., `cat VPNRouter.Headless`, `less VPNRouter.Headless`, or a compilation script).
  3. Scope collision: Basename matching detects any `VPNRouter.Headless` on the machine, even if running from a different directory or under another user.
  4. Missing fallback: If `pgrep` is not installed, the function exits cleanly without performing any check.
- **Impact:**
  Framework-dependent .NET instances are not detected, resulting in update races and runtime corruption. Unrelated CLI processes viewing repository files trigger false-positive installation aborts.
- **Fix:**
  Iterate `/proc/$pid/cmdline` splitting on NUL bytes, inspect all arguments for both `VPNRouter.Headless` and `VPNRouter.Headless.dll`, resolve paths with `readlink -f` to verify ownership under `$plugin_dir/bin/backend/`, and provide a `/proc` scanning fallback if `pgrep` is absent.

---

### Finding 5: Misleading Documented Claims Regarding Polkit Privilege Handling for Route Filtering
- **Severity:** MEDIUM
- **Status:** Confirmed
- **Source Anchors:**
  - `omarchy-vpnrouter/README.md:26-28, 67`
  - `omarchy-vpnrouter/README.ru.md:26-28, 67`
  - `omarchy-vpnrouter/setup:267-271`
  - `VPNRouter.Core/Platform/Linux/LinuxFirewallManager.cs:40-42, 628`
  - `VPNRouter.Headless/Lifecycle/PlatformCapabilityVerifier.cs:99-105`
  - `VPNRouter/plans/OPEN-DEFECTS.md:22`
- **Counterevidence & Analysis:**
  `README.md` and `README.ru.md` state:
  *"Privileged networking tasks (TUN setup, route filtering) are handled downstream via Polkit and system authorization agents."*
  And `setup:267` checks for `polkit-agent` or `pkexec`.
  In reality:
  - `LinuxFirewallManager.cs:628` executes `/usr/bin/sudo -n nft ...` and requires a `NOPASSWD` sudoers rule. It does not use Polkit.
  - `PlatformCapabilityVerifier.cs:99-105` explicitly sets `ProbeLinuxNftWithoutPassword` to return `false` because no Polkit adapter exists for nftables.
  - OPEN-DEFECTS.md tracks this as open P2 defect `OMARCHY-PRIVILEGES`.
  - `command -v polkit-agent` is an invalid executable probe; standard distributions run desktop agents under daemon paths, not as an executable named `polkit-agent`.
- **Impact:**
  Users are given false security assurances that route filtering and leak protection work via Polkit without sudoers modification. In reality, firewall kill-switch capabilities are either disabled or fail open unless undocumented `NOPASSWD` sudo rules are installed.
- **Fix:**
  Harmonize documentation to accurately state that Linux firewall kill-switch is currently disabled/unsupported under headless mode pending a dedicated privileged helper, and remove misleading Polkit claims for route filtering.

---

### Finding 6: Synthetic Lock Verification Fails Open When Host Binary Is Absent and References Fabricated Defects
- **Severity:** MEDIUM
- **Status:** Confirmed
- **Source Anchors:**
  - `omarchy-vpnrouter/setup:49-70`
  - `omarchy-vpnrouter/tests/test-packaging.py:493-533`
- **Counterevidence & Analysis:**
  `ensure_shell_unlocked()` calls `timeout 3s omarchy-shell lock status` and expects JSON:
  `{"locked": false, "requested": false, "secure": false}`.
  Counterevidence:
  1. Live Omarchy shell implementations in adjacent plugins use `omarchy-shell lock isLocked` (e.g., `komagata_screen-lens/src/lens.py:303`, `qs-bitwarden-cli/Panel.qml:5487`), which returns booleans, not the expected 3-field JSON object.
  2. The error message references `"Omarchy issue #9441"`, which is a fabricated issue number.
  3. At `setup:50`, `if command -v omarchy-shell >/dev/null 2>&1; then`: if `omarchy-shell` is missing (e.g. headless setup, remote provision, or SSH session), the check silently skips, violating the invariant "unknown or unverifiable session lock states fail closed on live hosts".
  4. `check_dependencies` does not verify `jq`, though `jq` is mandatory when `omarchy-shell` is detected.
  5. `test-packaging.py` tests this via a mock script that emits the synthetic JSON, asserting false parity.
- **Impact:**
  Setup will fail closed on real Omarchy systems where `omarchy-shell` lacks the synthetic `lock status` sub-command, while failing open in headless or CI environments where `omarchy-shell` is not in `$PATH`.
- **Fix:**
  Align lock state queries with real Omarchy commands (`omarchy-shell lock isLocked`), check `jq` in `check_dependencies`, remove fictional issue references, and explicitly specify whether headless installation outside an active shell session is permitted.

---

### Finding 7: Incomplete Symlink Validation and Launcher Symlink Traversal Risk
- **Severity:** MEDIUM
- **Status:** Confirmed
- **Source Anchors:**
  - `omarchy-vpnrouter/setup:410-414, 72-101`
  - `omarchy-vpnrouter/bin/vpnrouter-headless:27-30`
  - `omarchy-vpnrouter/tests/test-packaging.py:341-345`
- **Counterevidence & Analysis:**
  `setup:411` checks `[[ -L "$item" ]]` exclusively on top-level entries within `$abs_bdir`.
  1. `validate_plugin_structure()` does not check for symlinks within the plugin directory. The recursive symlink walk in `test-packaging.py:342` exists only in the test suite, not in `setup`.
  2. In `bin/vpnrouter-headless:27`, `[[ -f "$packaged_bin" && -x "$packaged_bin" ]]` follows symlinks. If `bin/backend/VPNRouter.Headless` is replaced with a symlink pointing to an arbitrary executable, `vpnrouter-headless` will execute it without restriction.
- **Impact:**
  The advertised invariant ("Omarchy validator prohibits ANY symlink in plugin; zero symlinks enforced") is only checked by the test suite, not by `setup` during actual installation. The launcher wrapper does not prevent executing symlink targets.
- **Fix:**
  Add a recursive check `find "$plugin_dir" -type l` in `validate_plugin_structure()`, and add `[[ ! -L "$packaged_bin" ]]` in `bin/vpnrouter-headless`.

---

### Finding 8: Unhedged Command Arguments in Staging File Operations (Option Injection Risk)
- **Severity:** LOW / HYGIENE
- **Status:** Confirmed
- **Source Anchors:**
  - `omarchy-vpnrouter/setup:423, 424, 427, 428`
- **Counterevidence & Analysis:**
  In `setup`:
  ```bash
  cp "$item" "$stage_dir/$item_base"
  chmod 755 "$stage_dir/$item_base"
  chmod 644 "$stage_dir/$item_base"
  ```
  Neither `cp` nor `chmod` includes the `--` argument terminator. If a build output directory contains a file whose basename starts with a hyphen (e.g. `-rf`, `--help`, or a malformed library name), `cp` and `chmod` will interpret `$item_base` as command-line flags.
- **Impact:**
  Unexpected command option parsing or staging failures when processing non-standard filenames.
- **Fix:**
  Use `cp -- "$item" "$stage_dir/$item_base"` and `chmod 755 -- "$stage_dir/$item_base"`.

---

## Coverage and Untested Boundaries

| Subsystem / Requirement | Tested by `test-packaging.py`? | Live Runtime Parity? | Untested Boundary / Gap |
|---|---|---|---|
| Launcher Wrapper Isolation | Mock backend via Python | High for CLI parsing | Real .NET 10 binary execution, SIGTERM/SIGQUIT propagation |
| Setup Backup and Rollback | Simulated failures in Python | Medium | Signal interruption (`SIGINT`/`SIGTERM`) between swap and validation |
| Protocol v1 Framing | Mock Python JSON-lines server | High for wire syntax | Real `VPNRouter.Headless` backend framing and Clash API interaction |
| Sing-Box Lifecycle Integration | Untested (dummy `/bin/sh` mock) | NONE | Real `sing-box` execution via `AppPaths.SingBoxExePath` vs `bin/backend/` |
| Session Lock Verification | Mocked `omarchy-shell` shell script | NONE | Live `omarchy-shell` IPC, `isLocked` vs `lock status`, absence of `jq` |
| Linux Firewall / Kill-switch | Untested | NONE | `sudo -n nft` vs Polkit integration; unverified capability handling |
| Active Process Detection | Python mock named `VPNRouter.Headless` | Low | Framework-dependent `dotnet exec VPNRouter.Headless.dll` |
| Symlink Enforcement | Tested in Python unit test only | Low | Real `setup` execution never verifies recursive symlink absence |

---

## Verification Verdict

**Verdict: CHANGES_REQUIRED**

While the architecture and protocol bounds of the launcher and packaging scripts are sound and adhere to the project's zero-download and zero-unauthorized-elevation principles, the functional disconnection in `sing-box` location, the rollback backup destruction hazard, and the false documentation regarding Polkit firewall handling require remediation prior to integration approval.
