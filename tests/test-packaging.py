#!/usr/bin/env python3
"""Packaging, wrapper isolation, and protocol v1 tests for Omarchy VPNRouter plugin.

Uses Python standard library ONLY (no external test runners, live Omarchy, or network access).
Validates:
1. Setup script lifecycle (missing backend notice, local dir install into bin/backend/, backup-and-rename with rollback).
2. Prohibits ANY symlink in plugin; verifies zero symlinks exist after installation.
3. Manifest and host validator invoked AFTER final install; fails and rolls back if rejected.
4. Safe protocol handshake: ONLY over --stdio --data-dir <fresh private temporary directory>,
   bounded output reader and timeout, detecting v1 matching id result without tolerating error.
5. Wrapper isolation: executes only bin/backend/VPNRouter.Headless or system path,
   NO environment backdoor/override, NO PATH search, NO arbitrary flags/echo input.
   Locally generated --help; strict argument filtering (--stdio, --data-dir <ABSOLUTE_PATH>).
6. Data preservation invariants (~/.config/vpnrouter preserved during install, update, remove).
7. Security invariants: refuse active backend update without killing/signaling, fail-closed lock state.
8. Protocol v1 wire framing interactions with mock backends (normal, malformed, oversized).
9. Repository hygiene (GPL-3.0 license provenance, .gitignore, executable permissions).
"""

import json
import os
import pathlib
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent

# Python script representing a benign mock VPNRouter.Headless backend
FAKE_BACKEND_SCRIPT = """#!/usr/bin/env python3
import sys
import json
import os

MAX_FRAME_SIZE = 256 * 1024  # 256 KiB protocol limit

# Reject unauthorized arguments
i = 1
while i < len(sys.argv):
    arg = sys.argv[i]
    if arg == "--stdio":
        i += 1
    elif arg == "--data-dir":
        if i + 1 >= len(sys.argv) or not os.path.isabs(sys.argv[i+1]):
            sys.stderr.write("error: --data-dir requires absolute path\\n")
            sys.exit(2)
        i += 2
    else:
        sys.stderr.write(f"error: unauthorized argument '{arg}'\\n")
        sys.exit(2)

if "--stdio" not in sys.argv:
    sys.stderr.write("error: --stdio is required\\n")
    sys.exit(1)

# Stdio JSON-lines loop
while True:
    try:
        line_bytes = sys.stdin.buffer.readline()
    except Exception:
        break
    if not line_bytes:
        break

    if len(line_bytes) > MAX_FRAME_SIZE:
        err = {"v": 1, "id": "error", "error": {"code": "frame_too_large", "message": "Frame exceeds 256 KiB limit"}}
        sys.stdout.write(json.dumps(err) + "\\n")
        sys.stdout.flush()
        continue

    try:
        text = line_bytes.decode("utf-8")
        req = json.loads(text)
    except Exception as ex:
        err = {"v": 1, "id": "error", "error": {"code": "invalid_request", "message": "Malformed JSON frame"}}
        sys.stdout.write(json.dumps(err) + "\\n")
        sys.stdout.flush()
        continue

    req_v = req.get("v")
    req_id = req.get("id", "none")
    method = req.get("method")

    if req_v != 1:
        err = {"v": 1, "id": str(req_id), "error": {"code": "unsupported_protocol_version", "message": "Only protocol version 1 supported"}}
        sys.stdout.write(json.dumps(err) + "\\n")
        sys.stdout.flush()
        continue

    if method == "snapshot":
        resp = {
            "v": 1,
            "id": req_id,
            "result": {
                "state": "disconnected",
                "revision": "rev-mock-001",
                "backendVersion": "2.48.0-dev",
                "activeServer": "",
                "routingMode": "split",
                "routingAppsMode": "include",
                "configMode": "generated",
                "busy": False,
                "errorCode": None,
                "capabilities": {"connect": True, "killSwitch": False, "dnsLockdown": False}
            }
        }
        sys.stdout.write(json.dumps(resp) + "\\n")
        sys.stdout.flush()
    else:
        err = {"v": 1, "id": str(req_id), "error": {"code": "method_not_found", "message": f"Unknown method: {method}"}}
        sys.stdout.write(json.dumps(err) + "\\n")
        sys.stdout.flush()
"""

DATA_DIR_CHECKING_BACKEND = """#!/usr/bin/env python3
import sys
import json
import os

if "--stdio" not in sys.argv:
    sys.stderr.write("error: --stdio is required\\n")
    sys.exit(1)

if "--data-dir" not in sys.argv:
    sys.stderr.write("error: --data-dir is required during handshake\\n")
    sys.exit(1)

data_dir_idx = sys.argv.index("--data-dir") + 1
if data_dir_idx >= len(sys.argv) or not os.path.isabs(sys.argv[data_dir_idx]):
    sys.stderr.write("error: --data-dir requires an absolute path\\n")
    sys.exit(1)

data_dir_val = sys.argv[data_dir_idx]
# Handshake must use a private temporary directory, never touching default user config
if ".config/vpnrouter" in data_dir_val:
    sys.stderr.write("error: handshake touched default user configuration\\n")
    sys.exit(1)

line = sys.stdin.readline()
if line:
    req = json.loads(line)
    resp = {
        "v": 1,
        "id": req.get("id"),
        "result": {
            "state": "disconnected",
            "routingMode": "split"
        }
    }
    sys.stdout.write(json.dumps(resp) + "\\n")
    sys.stdout.flush()
"""

ERRORING_BACKEND = """#!/usr/bin/env python3
import sys
import json

line = sys.stdin.readline()
if line:
    req = json.loads(line)
    resp = {
        "v": 1,
        "id": req.get("id"),
        "error": {
            "code": "probe_failure",
            "message": "simulated handshake protocol error"
        }
    }
    sys.stdout.write(json.dumps(resp) + "\\n")
    sys.stdout.flush()
"""

MISMATCHED_ID_BACKEND = """#!/usr/bin/env python3
import sys
import json

line = sys.stdin.readline()
if line:
    resp = {
        "v": 1,
        "id": "wrong-id",
        "result": {"state": "disconnected"}
    }
    sys.stdout.write(json.dumps(resp) + "\\n")
    sys.stdout.flush()
"""


class PackagingTestBase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory(prefix="vpnrouter-pkg-test-")
        self.test_root = pathlib.Path(self.temp_dir.name)

        # Create isolated workspace mimicking plugin repo
        self.plugin_copy = self.test_root / "omarchy-vpnrouter"
        shutil.copytree(
            REPO_ROOT,
            self.plugin_copy,
            ignore=shutil.ignore_patterns(
                "__pycache__", ".git", "VPNRouter.Headless", ".vpnrouter-*", "versions", "current", "backend"
            ),
        )

        # Make sure setup and wrapper are executable in the copy
        for script_name in ["setup", "bin/vpnrouter-headless"]:
            p = self.plugin_copy / script_name
            if p.exists():
                p.chmod(p.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

        # Isolated user home and config directory: ~/.config/vpnrouter
        self.home_dir = self.test_root / "home"
        self.home_dir.mkdir(parents=True, exist_ok=True)
        self.user_config_dir = self.home_dir / ".config" / "vpnrouter"
        self.user_config_dir.mkdir(parents=True, exist_ok=True)

        # Hermetic bin stubs for unit tests: prevent live Omarchy session discovery
        self.stub_bin_dir = self.test_root / "hermetic_bin"
        self.stub_bin_dir.mkdir(parents=True, exist_ok=True)

        # Default hermetic omarchy-shell: returns real accepted unlocked status JSON
        stub_shell = self.stub_bin_dir / "omarchy-shell"
        stub_shell.write_text(
            '#!/bin/sh\n'
            'if [ "$1" = "lock" ] && [ "$2" = "status" ]; then\n'
            '  printf \'{"locked": false, "requested": false, "pending": false, "sessionLocked": false, "secure": false, "realScreens": 1, "passwordPam": true, "fingerprint": false, "authenticating": false, "lastEvent": "unlocked", "lastEventAt": 0}\\n\'\n'
            '  exit 0\n'
            'fi\n'
            'if [ "$1" = "lock" ] && [ "$2" = "isLocked" ]; then\n'
            '  printf \'false\\n\'\n'
            '  exit 0\n'
            'fi\n'
            'exit 0\n',
            encoding="utf-8",
        )
        stub_shell.chmod(0o755)

        # Default hermetic omarchy plugin validate: passes by default
        stub_omarchy = self.stub_bin_dir / "omarchy"
        stub_omarchy.write_text(
            '#!/bin/sh\n'
            'if [ "$1" = "plugin" ] && [ "$2" = "validate" ]; then\n'
            '  exit 0\n'
            'fi\n'
            'exit 0\n',
            encoding="utf-8",
        )
        stub_omarchy.chmod(0o755)

        self.env = os.environ.copy()
        self.env["HOME"] = str(self.home_dir)
        self.env["XDG_CONFIG_HOME"] = str(self.home_dir / ".config")
        self.env["PATH"] = f"{self.stub_bin_dir}:/usr/bin:/bin"
        # Clear any environment overrides
        self.env.pop("VPNROUTER_HEADLESS_BIN", None)
        self.env.pop("VPNROUTER_BACKEND_DIR", None)
        self.env.pop("VPNROUTER_NO_SYMLINKS", None)

    def tearDown(self):
        self.temp_dir.cleanup()

    def create_fake_backend(self, dest_dir: pathlib.Path, script: str = FAKE_BACKEND_SCRIPT) -> pathlib.Path:
        dest_dir.mkdir(parents=True, exist_ok=True)
        bin_path = dest_dir / "VPNRouter.Headless"
        bin_path.write_text(script, encoding="utf-8")
        bin_path.chmod(0o755)
        profiles = dest_dir / "profiles"
        profiles.mkdir(exist_ok=True)
        for name in ("default.json", "default-linux.json"):
            (profiles / name).write_text(json.dumps({"profiles": [{"name": name, "processes": []}]}), encoding="utf-8")
        return bin_path


class TestSetupLifecycle(PackagingTestBase):
    def test_setup_missing_backend_notice_and_safe_failure(self):
        """When no backend exists, setup must not invent download URLs or fake success."""
        backend_in_plugin = self.plugin_copy / "bin" / "backend" / "VPNRouter.Headless"
        if backend_in_plugin.exists():
            backend_in_plugin.unlink()

        res = subprocess.run(
            ["./setup"],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )

        self.assertEqual(res.returncode, 1)
        self.assertIn("VPNRouter.Headless", res.stdout)
        self.assertIn("https://github.com/PavelLizunov/VPNRouter", res.stdout)
        self.assertIn("--backend-dir", res.stdout)
        self.assertIn("NEVER invents unverified download URLs", res.stdout)

    def test_setup_status_command(self):
        """Setup --status must report development status when absent, and details when present."""
        res_absent = subprocess.run(
            ["./setup", "--status"],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_absent.returncode, 0)
        self.assertIn("Backend status: NOT INSTALLED", res_absent.stdout)
        self.assertIn("io.github.pavellizunov.vpnrouter", res_absent.stdout)
        self.assertIn(str(self.user_config_dir), res_absent.stdout)

        build_dir = self.test_root / "build_output"
        self.create_fake_backend(build_dir)
        subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            check=True,
            capture_output=True,
        )

        res_present = subprocess.run(
            ["./setup", "--status"],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_present.returncode, 0)
        self.assertIn("Backend status: INSTALLED", res_present.stdout)
        self.assertIn("bin/backend/VPNRouter.Headless", res_present.stdout)
        self.assertIn("Wire Protocol: v1", res_present.stdout)
        self.assertIn(str(self.user_config_dir), res_present.stdout)

    def test_setup_install_from_backend_dir_and_verifies_no_symlinks(self):
        """Setup copies build materials to bin/backend/ payload directory with ZERO symlinks."""
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)

        dummy_singbox = build_dir / "sing-box"
        dummy_singbox.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        dummy_singbox.chmod(0o755)

        dummy_so = build_dir / "libmsquic.so"
        dummy_so.write_text("dummy-so", encoding="utf-8")

        dummy_dll = build_dir / "VPNRouter.Core.dll"
        dummy_dll.write_text("dummy-dll", encoding="utf-8")

        dummy_json = build_dir / "VPNRouter.Headless.runtimeconfig.json"
        dummy_json.write_text("{}", encoding="utf-8")

        res = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0, msg=f"Setup failed: {res.stderr}")

        backend_dir = self.plugin_copy / "bin" / "backend"
        self.assertTrue(backend_dir.exists())
        self.assertTrue(backend_dir.is_dir())
        self.assertFalse(backend_dir.is_symlink())

        installed_bin = backend_dir / "VPNRouter.Headless"
        self.assertTrue(installed_bin.exists())
        self.assertTrue(os.access(installed_bin, os.X_OK))
        self.assertEqual(installed_bin.stat().st_mode & 0o777, 0o755)

        # Verify staged dependencies are present in payload directory
        self.assertTrue((backend_dir / "sing-box").exists())
        self.assertTrue((backend_dir / "libmsquic.so").exists())
        self.assertTrue((backend_dir / "VPNRouter.Core.dll").exists())
        self.assertTrue((backend_dir / "VPNRouter.Headless.runtimeconfig.json").exists())
        for name in ("default.json", "default-linux.json"):
            self.assertEqual((backend_dir / "profiles" / name).read_bytes(),
                             (build_dir / "profiles" / name).read_bytes())

        # Crucial Invariant: Omarchy prohibits ANY symlinks in plugin; verify ZERO symlinks exist
        for root, dirs, files in os.walk(str(self.plugin_copy)):
            for name in dirs + files:
                p = pathlib.Path(root) / name
                self.assertFalse(p.is_symlink(), f"Prohibited symlink detected in plugin tree: {p}")

        # Verify explicit activation notice (no implicit enable)
        self.assertIn("omarchy plugin enable io.github.pavellizunov.vpnrouter", res.stdout)

    def test_setup_backup_and_rename_with_rollback_on_failure(self):
        """Setup backs up old dir then renames new, rolling back to previous backend if update fails."""
        # 1. Install initial good backend v1
        build_dir_v1 = self.test_root / "build_v1"
        self.create_fake_backend(build_dir_v1)
        marker_v1 = build_dir_v1 / "v1_marker.txt"
        marker_v1.write_text("VERSION_1", encoding="utf-8")
        # include as allowed dat file
        allowed_v1 = build_dir_v1 / "version.dat"
        allowed_v1.write_text("VERSION_1_DAT", encoding="utf-8")

        res1 = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir_v1)],
            cwd=str(self.plugin_copy),
            env=self.env,
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res1.returncode, 0)
        installed_dat = self.plugin_copy / "bin" / "backend" / "version.dat"
        self.assertTrue(installed_dat.exists())
        self.assertEqual(installed_dat.read_text(encoding="utf-8"), "VERSION_1_DAT")

        # 2. Prepare broken build v2 that fails protocol handshake
        build_dir_v2 = self.test_root / "build_v2"
        self.create_fake_backend(build_dir_v2, script=ERRORING_BACKEND)

        res2 = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir_v2)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res2.returncode, 1)
        self.assertIn("staged backend validation failed", res2.stderr)

        # 3. Verify rollback: old version 1 remains intact
        self.assertTrue(installed_dat.exists())
        self.assertEqual(installed_dat.read_text(encoding="utf-8"), "VERSION_1_DAT")

        # Verify no temporary backup or staging directories left behind
        bin_dir = self.plugin_copy / "bin"
        for item in bin_dir.iterdir():
            self.assertFalse(item.name.startswith(".backend_backup_"), f"Uncleaned backup dir: {item}")
            self.assertFalse(item.name.startswith(".stage_backend."), f"Uncleaned stage dir: {item}")

    def test_setup_manifest_validation_invoked_after_final_install_and_rolls_back(self):
        """Manifest/host validator is invoked AFTER final install; fails and rolls back if rejected."""
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)

        # Mock 'omarchy plugin validate' command that records evidence of backend directory presence
        mock_bin_dir = self.test_root / "mock_bin"
        mock_bin_dir.mkdir(parents=True, exist_ok=True)
        omarchy_mock = mock_bin_dir / "omarchy"
        witness_file = self.test_root / "validator_witness.json"

        mock_script = f"""#!/bin/sh
# Record whether bin/backend/VPNRouter.Headless exists at the time validator is called
if [ -f "{self.plugin_copy}/bin/backend/VPNRouter.Headless" ]; then
    echo '{{"backend_present_during_validation": true}}' > "{witness_file}"
else
    echo '{{"backend_present_during_validation": false}}' > "{witness_file}"
fi
# Reject validation to test rollback
exit 1
"""
        omarchy_mock.write_text(mock_script, encoding="utf-8")
        omarchy_mock.chmod(0o755)

        env_with_mock = self.env.copy()
        env_with_mock["PATH"] = f"{mock_bin_dir}:{env_with_mock['PATH']}"

        res = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=env_with_mock,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertIn("'omarchy plugin validate' failed", res.stderr)
        self.assertIn("rolling back", res.stderr)

        # Verify witness: validator was indeed executed AFTER the final install placed the binary
        self.assertTrue(witness_file.exists(), "Validator was not invoked")
        witness_data = json.loads(witness_file.read_text(encoding="utf-8"))
        self.assertTrue(witness_data.get("backend_present_during_validation"),
                        "Validator was not invoked after final install")

        # Verify rollback: because validation failed, bin/backend must have been rolled back / removed
        self.assertFalse((self.plugin_copy / "bin" / "backend").exists(),
                         "Failed install was not rolled back after validator rejection")

    def test_setup_refuses_active_backend_update_without_signal(self):
        """Setup must refuse to update if an active backend is running, without killing/signaling it."""
        build_dir = self.test_root / "local_build"
        fake_backend = self.create_fake_backend(build_dir)

        # Launch the fake backend in the background as a running process
        proc = subprocess.Popen(
            [sys.executable, str(fake_backend), "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            # Allow process to start
            time.sleep(0.2)
            self.assertIsNone(proc.poll(), "Backend process should be active")

            # Attempt to run setup while backend is active
            res = subprocess.run(
                ["./setup", "--backend-dir", str(build_dir)],
                cwd=str(self.plugin_copy),
                env=self.env,
                capture_output=True,
                text=True,
            )

            # Setup must fail closed
            self.assertEqual(res.returncode, 1)
            self.assertIn("active backend process detected", res.stderr)
            self.assertIn("Setup will not signal or kill running processes", res.stderr)

            # Crucial invariant: active backend was NOT signaled or killed!
            self.assertIsNone(proc.poll(), "Active backend must NOT be killed or signaled")
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except Exception:
                proc.kill()
            if proc.stdin:
                proc.stdin.close()
            if proc.stdout:
                proc.stdout.close()
            if proc.stderr:
                proc.stderr.close()

    def test_setup_lock_state_fails_closed_on_live_host(self):
        """When omarchy-shell reports unknown/locked/failed status, setup must fail closed."""
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)

        mock_bin_dir = self.test_root / "mock_bin"
        mock_bin_dir.mkdir(parents=True, exist_ok=True)
        shell_mock = mock_bin_dir / "omarchy-shell"

        env_with_mock = self.env.copy()
        env_with_mock["PATH"] = f"{mock_bin_dir}:{env_with_mock['PATH']}"

        # 1. omarchy-shell returns non-zero error / empty
        shell_mock.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
        shell_mock.chmod(0o755)

        res_err = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=env_with_mock,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_err.returncode, 1)
        self.assertIn("failing closed", res_err.stderr)

        # 2. omarchy-shell returns locked session
        locked_script = '#!/bin/sh\nprintf \'{"locked": true, "requested": false, "secure": false}\\n\'\n'
        shell_mock.write_text(locked_script, encoding="utf-8")
        shell_mock.chmod(0o755)

        res_locked = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=env_with_mock,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_locked.returncode, 1)
        self.assertIn("session is locked", res_locked.stderr)

        # 3. omarchy-shell returns accepted unlocked JSON status
        unlocked_script = (
            '#!/bin/sh\n'
            'printf \'{"locked": false, "requested": false, "pending": false, "sessionLocked": false, '
            '"secure": false, "realScreens": 1, "passwordPam": true, "fingerprint": false, '
            '"authenticating": false, "lastEvent": "unlocked", "lastEventAt": 0}\\n\'\n'
        )
        shell_mock.write_text(unlocked_script, encoding="utf-8")
        shell_mock.chmod(0o755)

        res_unlocked = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=env_with_mock,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_unlocked.returncode, 0)
        self.assertIn("Installation complete", res_unlocked.stdout)

    def test_setup_rejects_symlinks_in_build_materials(self):
        """Build materials must not contain symlinks (path traversal prevention)."""
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)

        symlink_target = self.test_root / "secret.txt"
        symlink_target.write_text("secret-data", encoding="utf-8")
        symlink_in_build = build_dir / "malicious_link.so"
        symlink_in_build.symlink_to(symlink_target)

        res = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertIn("symlinks forbidden in build materials", res.stderr)

    def test_setup_rejects_unsafe_profile_payload_preserving_old_backend(self):
        for case in ("missing", "symlink-file", "symlink-dir", "fifo", "oversize"):
            with self.subTest(case=case):
                build = self.test_root / ("profiles-" + case)
                self.create_fake_backend(build)
                catalog = build / "profiles" / "default-linux.json"
                if case == "missing":
                    catalog.unlink()
                elif case == "symlink-file":
                    catalog.unlink()
                    catalog.symlink_to(build / "profiles" / "default.json")
                elif case == "symlink-dir":
                    (build / "profiles").rename(build / "external-profiles")
                    (build / "profiles").symlink_to(build / "external-profiles", target_is_directory=True)
                elif case == "fifo":
                    catalog.unlink()
                    os.mkfifo(catalog)
                else:
                    catalog.write_bytes(b"x" * (1024 * 1024 + 1))
                old = self.plugin_copy / "bin" / "backend"
                old.mkdir(exist_ok=True)
                marker = old / "preserved.dat"
                marker.write_bytes(b"old-payload")
                result = subprocess.run(["./setup", "--backend-dir", str(build)],
                                        cwd=self.plugin_copy, env=self.env,
                                        capture_output=True, text=True, timeout=8)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("missing or unsafe published profiles", result.stderr)
                self.assertNotIn("Validating staged backend", result.stdout)
                self.assertEqual(marker.read_bytes(), b"old-payload")
                self.assertFalse(list((self.plugin_copy / "bin").glob(".stage_backend.*")))

    def test_setup_rejects_top_level_fifo_without_blocking(self):
        build = self.test_root / "fifo-build"
        self.create_fake_backend(build)
        os.mkfifo(build / "dependency.dll")
        result = subprocess.run(["./setup", "--backend-dir", str(build)],
                                cwd=self.plugin_copy, env=self.env,
                                capture_output=True, text=True, timeout=8)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("non-regular file", result.stderr)
        self.assertFalse((self.plugin_copy / "bin" / "backend").exists())

    def test_setup_rejects_unsupported_artifact_option(self):
        """Unverified artifact archives are rejected in favor of explicit offline local dir install."""
        res = subprocess.run(
            ["./setup", "--artifact", "/path/to/archive.tar.gz"],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertIn("--artifact is not supported", res.stderr)
        self.assertIn("--backend-dir", res.stderr)

    def test_setup_remove_preserves_user_config(self):
        """Setup --remove removes installed backend binaries while preserving config in ~/.config/vpnrouter."""
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)
        subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            check=True,
            capture_output=True,
        )
        self.assertTrue((self.plugin_copy / "bin" / "backend").exists())

        # Populate actual user configuration directory: ~/.config/vpnrouter
        config_file = self.user_config_dir / "config.yaml"
        config_file.write_text("Vless:\n  Servers: []\n", encoding="utf-8")
        keys_file = self.user_config_dir / "secret.key"
        keys_file.write_text("user-private-key-material\n", encoding="utf-8")

        res_remove = subprocess.run(
            ["./setup", "--remove"],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_remove.returncode, 0)
        self.assertFalse((self.plugin_copy / "bin" / "backend").exists())

        # Invariant: user data in ~/.config/vpnrouter must remain untouched
        self.assertTrue(self.user_config_dir.exists())
        self.assertTrue(config_file.exists())
        self.assertEqual(config_file.read_text(encoding="utf-8"), "Vless:\n  Servers: []\n")
        self.assertTrue(keys_file.exists())
        self.assertEqual(keys_file.read_text(encoding="utf-8"), "user-private-key-material\n")
        self.assertIn("DATA PRESERVATION ASSURANCE", res_remove.stdout)
        self.assertIn(str(self.user_config_dir), res_remove.stdout)

    def test_setup_rejects_leading_hyphen_and_trailing_dot_files(self):
        """Setup staging strictly refuses files with leading hyphens or trailing dots."""
        # Case 1: leading hyphen
        build_dir_hyphen = self.test_root / "build_hyphen"
        self.create_fake_backend(build_dir_hyphen)
        bad_file_hyphen = build_dir_hyphen / "-malicious-flag.so"
        bad_file_hyphen.write_text("bad", encoding="utf-8")

        res_hyphen = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir_hyphen)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_hyphen.returncode, 1)
        self.assertIn("leading hyphen or trailing dot prohibited", res_hyphen.stderr)

        # Case 2: trailing dot
        build_dir_dot = self.test_root / "build_dot"
        self.create_fake_backend(build_dir_dot)
        bad_file_dot = build_dir_dot / "malicious."
        bad_file_dot.write_text("bad", encoding="utf-8")

        res_dot = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir_dot)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_dot.returncode, 1)
        self.assertIn("leading hyphen or trailing dot prohibited", res_dot.stderr)

    def test_setup_requires_python3_before_mutation(self):
        """Setup strictly requires python3 and refuses mutation if python3 is missing."""
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)

        env_no_python = self.env.copy()
        bin_no_py = self.test_root / "bin_no_py"
        bin_no_py.mkdir(parents=True, exist_ok=True)
        for cmd in ["bash", "sh", "mktemp", "mkdir", "rm", "mv", "cp", "chmod", "cat", "find", "dirname", "basename"]:
            target = shutil.which(cmd)
            if target:
                (bin_no_py / cmd).symlink_to(target)
        env_no_python["PATH"] = str(bin_no_py)

        res = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=env_no_python,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertIn("python3 is required for setup operations", res.stderr)

    def test_setup_validates_zero_symlinks_in_plugin_tree_post_install(self):
        """Setup post-install validation catches any symlink introduced in the plugin tree and rolls back."""
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)

        # Introduce an unauthorized symlink into the plugin directory
        target = self.test_root / "target.txt"
        target.write_text("target", encoding="utf-8")
        bad_link = self.plugin_copy / "ui" / "symlink.qml"
        bad_link.symlink_to(target)

        res = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertIn("prohibited symlink detected", res.stderr)
        self.assertIn("rolling back", res.stderr)
        # Backend should have been rolled back
        self.assertFalse((self.plugin_copy / "bin" / "backend").exists())


class TestBackendHandshakeSafety(PackagingTestBase):
    def test_setup_handshake_uses_private_temp_data_dir(self):
        """Setup handshake passes fresh private temporary data directory, never default configuration."""
        build_dir = self.test_root / "data_dir_check_build"
        self.create_fake_backend(build_dir, script=DATA_DIR_CHECKING_BACKEND)

        res_install = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_install.returncode, 0, msg=res_install.stderr)
        self.assertIn("Wire Protocol: v1", res_install.stdout)

    def test_setup_handshake_detects_error_without_tolerating(self):
        """Setup fails closed if the backend returns a protocol error during handshake."""
        build_dir = self.test_root / "error_build"
        self.create_fake_backend(build_dir, script=ERRORING_BACKEND)

        res = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertIn("returned protocol error", res.stderr)

    def test_setup_handshake_detects_mismatched_id_without_tolerating(self):
        """Setup fails closed if the backend returns an ID that does not match the request probe."""
        build_dir = self.test_root / "mismatch_build"
        self.create_fake_backend(build_dir, script=MISMATCHED_ID_BACKEND)

        res = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertIn("response id mismatch", res.stderr)

    def test_setup_handshake_flood_stdout_bounded_before_accumulator(self):
        """Setup bounds stdout reading before memory accumulation, stopping flood immediately."""
        script = """#!/usr/bin/env python3
import sys
chunk = b"A" * 65536
try:
    while True:
        sys.stdout.buffer.write(chunk)
        sys.stdout.buffer.flush()
except (BrokenPipeError, OSError):
    pass
"""
        build_dir = self.test_root / "flood_stdout_build"
        self.create_fake_backend(build_dir, script=script)

        t0 = time.monotonic()
        res = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        duration = time.monotonic() - t0
        self.assertEqual(res.returncode, 1)
        self.assertIn("exceeded maximum frame limit", res.stderr)
        self.assertLess(duration, 2.5, "Flood should be bounded immediately before timeout")

    def test_setup_handshake_flood_stderr_discarded_without_exposure(self):
        """Setup discards stderr stream without exposing contents or secrets."""
        secret_marker = "SUPER_SECRET_TOKEN_XYZ_987654321"
        script = f"""#!/usr/bin/env python3
import sys
for _ in range(500):
    sys.stderr.write("{secret_marker}\\n")
sys.stderr.flush()
sys.exit(42)
"""
        build_dir = self.test_root / "flood_stderr_build"
        self.create_fake_backend(build_dir, script=script)

        res = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertIn("exited with status 42", res.stderr)
        self.assertNotIn(secret_marker, res.stdout)
        self.assertNotIn(secret_marker, res.stderr)

    def test_setup_handshake_timeout_with_deterministic_cleanup(self):
        """Setup enforces monotonic timeout and reaps backend process deterministically."""
        script = """#!/usr/bin/env python3
import time
time.sleep(10)
"""
        build_dir = self.test_root / "timeout_build"
        self.create_fake_backend(build_dir, script=script)

        t0 = time.monotonic()
        res = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        duration = time.monotonic() - t0
        self.assertEqual(res.returncode, 1)
        self.assertIn("timed out after 3s", res.stderr)
        self.assertGreaterEqual(duration, 2.8)
        self.assertLess(duration, 5.0)

    def test_setup_handshake_error_secret_not_exposed(self):
        """Setup discards stderr on process exit without echoing sensitive logs or errors."""
        secret_content = "PRIVATE_KEY_MATERIAL_NEVER_LOG"
        script = f"""#!/usr/bin/env python3
import sys
sys.stderr.write("Fatal crash with secret: {secret_content}\\n")
sys.exit(1)
"""
        build_dir = self.test_root / "secret_stderr_build"
        self.create_fake_backend(build_dir, script=script)

        res = subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertIn("exited with status 1", res.stderr)
        self.assertNotIn(secret_content, res.stdout)
        self.assertNotIn(secret_content, res.stderr)

    def test_setup_handshake_strict_version_and_unknown_fields_contract(self):
        """Strict v int1 and unknown top-level field rejection contract enforcement."""
        cases = [
            ('{"v": true, "id": "setup-probe", "result": {}}', "protocol version mismatch"),
            ('{"v": 1.0, "id": "setup-probe", "result": {}}', "protocol version mismatch"),
            ('{"v": "1", "id": "setup-probe", "result": {}}', "protocol version mismatch"),
            ('{"v": 2, "id": "setup-probe", "result": {}}', "protocol version mismatch"),
            ('{"v": 1, "id": "setup-probe", "result": {}, "unexpected": "extra"}', "violates contract (unknown or invalid fields)"),
            ('{"v": 1, "id": "setup-probe", "result": "not-a-dict"}', "missing result object"),
            ('{"v": 1, "id": "setup-probe"}', "violates contract (unknown or invalid fields)"),
        ]
        for payload, expected_err in cases:
            script = f"""#!/usr/bin/env python3
import sys
sys.stdin.readline()
sys.stdout.write('{payload}\\n')
sys.stdout.flush()
"""
            build_dir = self.test_root / f"strict_contract_{abs(hash(payload))}"
            self.create_fake_backend(build_dir, script=script)
            res = subprocess.run(
                ["./setup", "--backend-dir", str(build_dir)],
                cwd=str(self.plugin_copy),
                env=self.env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 1, msg=f"Payload {payload} should have failed")
            self.assertIn(expected_err, res.stderr, msg=f"Payload {payload} error mismatch: {res.stderr}")


class TestBackendWrapper(PackagingTestBase):
    def test_wrapper_executes_packaged_backend_over_stdio(self):
        """Wrapper executes packaged backend in bin/backend/VPNRouter.Headless over stdio."""
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)
        subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            check=True,
            capture_output=True,
        )

        wrapper_path = self.plugin_copy / "bin" / "vpnrouter-headless"
        proc = subprocess.Popen(
            [str(wrapper_path), "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=self.env,
        )
        req = {"v": 1, "id": "test-snap", "method": "snapshot", "params": {}}
        stdout, _ = proc.communicate(input=json.dumps(req) + "\n", timeout=5)
        self.assertEqual(proc.returncode, 0)
        lines = [line.strip() for line in stdout.splitlines() if line.strip()]
        self.assertTrue(len(lines) >= 1)
        resp = json.loads(lines[0])
        self.assertEqual(resp.get("v"), 1)
        self.assertEqual(resp.get("id"), "test-snap")
        self.assertEqual(resp.get("result", {}).get("backendVersion"), "2.48.0-dev")

    def test_wrapper_no_env_backdoor(self):
        """Wrapper must ignore VPNROUTER_HEADLESS_BIN and have NO environment backdoor."""
        # Install legitimate backend
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)
        subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            check=True,
            capture_output=True,
        )

        # Create imposter script
        imposter_dir = self.test_root / "imposter"
        imposter_dir.mkdir(parents=True, exist_ok=True)
        imposter = imposter_dir / "VPNRouter.Headless"
        imposter.write_text("#!/bin/sh\necho 'IMPOSTER_EXECUTED'\nexit 99\n", encoding="utf-8")
        imposter.chmod(0o755)

        env_with_backdoor = self.env.copy()
        env_with_backdoor["VPNROUTER_HEADLESS_BIN"] = str(imposter)

        wrapper_path = self.plugin_copy / "bin" / "vpnrouter-headless"
        proc = subprocess.Popen(
            [str(wrapper_path), "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env_with_backdoor,
        )
        req = {"v": 1, "id": "backdoor-test", "method": "snapshot", "params": {}}
        stdout, stderr = proc.communicate(input=json.dumps(req) + "\n", timeout=5)
        self.assertNotIn("IMPOSTER_EXECUTED", stdout)
        self.assertNotIn("IMPOSTER_EXECUTED", stderr)
        lines = [line.strip() for line in stdout.splitlines() if line.strip()]
        self.assertTrue(len(lines) >= 1)
        resp = json.loads(lines[0])
        self.assertEqual(resp.get("result", {}).get("backendVersion"), "2.48.0-dev")

    def test_wrapper_missing_backend_fails_safely(self):
        """Missing backend exits nonzero with guidance; never downloads or hangs."""
        backend_in_plugin = self.plugin_copy / "bin" / "backend" / "VPNRouter.Headless"
        if backend_in_plugin.exists():
            backend_in_plugin.unlink()

        wrapper_path = self.plugin_copy / "bin" / "vpnrouter-headless"
        res = subprocess.run(
            [str(wrapper_path)],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertIn("backend executable not found", res.stderr)
        self.assertIn("./setup --backend-dir", res.stderr)

    def test_wrapper_path_injection_immunity(self):
        """Wrapper MUST NOT search PATH or execute an executable placed on PATH."""
        attacker_dir = self.test_root / "attacker_bin"
        attacker_dir.mkdir(parents=True, exist_ok=True)
        imposter = attacker_dir / "VPNRouter.Headless"
        imposter.write_text("#!/bin/sh\necho 'MALICIOUS_PATH_EXECUTION'\nexit 99\n", encoding="utf-8")
        imposter.chmod(0o755)

        backend_in_plugin = self.plugin_copy / "bin" / "backend" / "VPNRouter.Headless"
        if backend_in_plugin.exists():
            backend_in_plugin.unlink()

        env_with_path = self.env.copy()
        env_with_path["PATH"] = f"{attacker_dir}:{env_with_path['PATH']}"

        wrapper_path = self.plugin_copy / "bin" / "vpnrouter-headless"
        res = subprocess.run(
            [str(wrapper_path)],
            cwd=str(self.plugin_copy),
            env=env_with_path,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertNotIn("MALICIOUS_PATH_EXECUTION", res.stdout)
        self.assertNotIn("MALICIOUS_PATH_EXECUTION", res.stderr)

    def test_wrapper_rejects_unauthorized_flags(self):
        """Wrapper strictly filters flags; rejects arbitrary flags, shell injection, and --version."""
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)
        subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            check=True,
            capture_output=True,
        )
        wrapper_path = self.plugin_copy / "bin" / "vpnrouter-headless"

        # Arbitrary flag rejected
        res = subprocess.run(
            [str(wrapper_path), "--arbitrary-dangerous-flag"],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 2)
        self.assertIn("rejected unauthorized argument", res.stderr)

        # --version rejected (wrapper forwards only --stdio, optional --data-dir; does not invent flags)
        res_ver = subprocess.run(
            [str(wrapper_path), "--version"],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_ver.returncode, 2)
        self.assertIn("rejected unauthorized argument", res_ver.stderr)

        # Shell command injection attempt rejected
        res_inject = subprocess.run(
            [str(wrapper_path), "; rm -rf / ;"],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_inject.returncode, 2)
        self.assertIn("rejected unauthorized argument", res_inject.stderr)

    def test_wrapper_validates_data_dir_argument(self):
        """Wrapper accepts absolute --data-dir, rejects relative or missing."""
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)
        subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            check=True,
            capture_output=True,
        )
        wrapper_path = self.plugin_copy / "bin" / "vpnrouter-headless"

        # Relative path -> rejected with exit 2
        res_rel = subprocess.run(
            [str(wrapper_path), "--data-dir", "relative/path"],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_rel.returncode, 2)
        self.assertIn("--data-dir path must be absolute", res_rel.stderr)

        # Missing argument -> rejected with exit 2
        res_missing = subprocess.run(
            [str(wrapper_path), "--data-dir"],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_missing.returncode, 2)

    def test_wrapper_help_generated_locally(self):
        """Wrapper generates --help and -h locally without executing the backend."""
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)
        subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            check=True,
            capture_output=True,
        )
        wrapper_path = self.plugin_copy / "bin" / "vpnrouter-headless"

        for help_flag in ["--help", "-h"]:
            res = subprocess.run(
                [str(wrapper_path), help_flag],
                cwd=str(self.plugin_copy),
                env=self.env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 0)
            self.assertIn("Usage: vpnrouter-headless", res.stdout)
            self.assertIn("--stdio", res.stdout)
            self.assertIn("--data-dir ABSOLUTE_PATH", res.stdout)
            self.assertIn("generated locally", res.stdout)

    def test_wrapper_rejects_symlink_backend(self):
        """Wrapper strictly refuses to execute a packaged backend that is a symlink."""
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)
        subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            check=True,
            capture_output=True,
        )

        wrapper_path = self.plugin_copy / "bin" / "vpnrouter-headless"
        backend_bin = self.plugin_copy / "bin" / "backend" / "VPNRouter.Headless"

        # Replace backend binary with a symlink pointing to an executable
        target_bin = self.test_root / "outside_executable"
        target_bin.write_text("#!/bin/sh\necho 'SYMLINK_EXECUTED'\n", encoding="utf-8")
        target_bin.chmod(0o755)

        backend_bin.unlink()
        backend_bin.symlink_to(target_bin)

        res = subprocess.run(
            [str(wrapper_path), "--stdio"],
            cwd=str(self.plugin_copy),
            env=self.env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertIn("must not be a symlink", res.stderr)
        self.assertNotIn("SYMLINK_EXECUTED", res.stdout)


class TestProtocolV1Interaction(PackagingTestBase):
    def setUp(self):
        super().setUp()
        build_dir = self.test_root / "local_build"
        self.create_fake_backend(build_dir)
        subprocess.run(
            ["./setup", "--backend-dir", str(build_dir)],
            cwd=str(self.plugin_copy),
            env=self.env,
            check=True,
            capture_output=True,
        )
        self.wrapper_path = self.plugin_copy / "bin" / "vpnrouter-headless"

    def test_normal_snapshot_frame(self):
        """Sending snapshot request over stdio returns valid protocol v1 snapshot frame."""
        proc = subprocess.Popen(
            [str(self.wrapper_path), "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=self.env,
        )
        req = {"v": 1, "id": "req-snap-1", "method": "snapshot", "params": {}}
        stdout, _ = proc.communicate(input=json.dumps(req) + "\n", timeout=5)

        lines = [line.strip() for line in stdout.splitlines() if line.strip()]
        self.assertTrue(len(lines) >= 1)
        resp = json.loads(lines[0])
        self.assertEqual(resp.get("v"), 1)
        self.assertEqual(resp.get("id"), "req-snap-1")
        self.assertIn("result", resp)
        self.assertEqual(resp["result"]["state"], "disconnected")
        self.assertEqual(resp["result"]["routingMode"], "split")

    def test_unsupported_protocol_version_handling(self):
        """Non-v1 protocol frame is rejected with an error response."""
        proc = subprocess.Popen(
            [str(self.wrapper_path), "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=self.env,
        )
        bad_req = {"v": 2, "id": "req-v2", "method": "snapshot", "params": {}}
        stdout, _ = proc.communicate(input=json.dumps(bad_req) + "\n", timeout=5)

        lines = [line.strip() for line in stdout.splitlines() if line.strip()]
        self.assertTrue(len(lines) >= 1)
        resp = json.loads(lines[0])
        self.assertEqual(resp.get("v"), 1)
        self.assertIn("error", resp)
        self.assertEqual(resp["error"]["code"], "unsupported_protocol_version")

    def test_malformed_json_handling(self):
        """Non-JSON frame is handled gracefully without crashing or leaking secrets."""
        proc = subprocess.Popen(
            [str(self.wrapper_path), "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=self.env,
        )
        garbage = "THIS_IS_NOT_JSON_DATA{{{\n"
        stdout, _ = proc.communicate(input=garbage, timeout=5)

        lines = [line.strip() for line in stdout.splitlines() if line.strip()]
        self.assertTrue(len(lines) >= 1)
        resp = json.loads(lines[0])
        self.assertIn("error", resp)
        self.assertEqual(resp["error"]["code"], "invalid_request")

    def test_oversized_frame_handling(self):
        """Frames exceeding the 256 KiB limit are rejected."""
        proc = subprocess.Popen(
            [str(self.wrapper_path), "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=self.env,
        )
        oversized = json.dumps({"v": 1, "id": "big", "method": "test", "params": {"data": "X" * (300 * 1024)}}) + "\n"
        stdout, _ = proc.communicate(input=oversized, timeout=5)

        lines = [line.strip() for line in stdout.splitlines() if line.strip()]
        self.assertTrue(len(lines) >= 1)
        resp = json.loads(lines[0])
        self.assertIn("error", resp)
        self.assertEqual(resp["error"]["code"], "frame_too_large")


class TestRepositoryHygiene(unittest.TestCase):
    def test_license_content_and_provenance(self):
        """LICENSE file must contain GPL-3.0 and explicit provenance linking to VPNRouter."""
        license_path = REPO_ROOT / "LICENSE"
        self.assertTrue(license_path.exists(), "LICENSE file missing")
        content = license_path.read_text(encoding="utf-8")
        self.assertIn("GNU GENERAL PUBLIC LICENSE", content)
        self.assertIn("Version 3, 29 June 2007", content)
        self.assertIn("io.github.pavellizunov.vpnrouter", content)
        self.assertIn("https://github.com/PavelLizunov/VPNRouter", content)

    def test_gitignore_tracks_wrapper_and_ignores_binaries(self):
        """.gitignore must exclude local compiled binaries in bin/* while tracking wrapper."""
        gitignore_path = REPO_ROOT / ".gitignore"
        self.assertTrue(gitignore_path.exists(), ".gitignore file missing")
        content = gitignore_path.read_text(encoding="utf-8")
        self.assertIn("bin/*", content)
        self.assertIn("!bin/vpnrouter-headless", content)
        self.assertIn("__pycache__", content)

    def test_scripts_executable_permissions(self):
        """Packaging entry points must have executable permissions."""
        for script in ["setup", "bin/vpnrouter-headless"]:
            p = REPO_ROOT / script
            self.assertTrue(p.exists(), f"{script} does not exist")
            is_exec = bool(p.stat().st_mode & stat.S_IXUSR)
            self.assertTrue(is_exec, f"{script} is not executable")


if __name__ == "__main__":
    unittest.main(verbosity=2)
