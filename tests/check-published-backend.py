#!/usr/bin/env python3
"""Opt-in Linux publish/setup/wrapper proof. Never installs into the live shell.

Run with an explicitly trusted local Headless publish directory. Executes that
binary; this is not an artifact-authenticity check or a VPN connection test.
"""
import argparse
import json
import os
from pathlib import Path
import runpy
import selectors
import subprocess
import time


def read_response(process, request_id):
    deadline = time.monotonic() + 8
    pending = bytearray()
    total = 0
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        while time.monotonic() < deadline:
            if not selector.select(max(0, deadline - time.monotonic())):
                break
            chunk = os.read(process.stdout.fileno(), 4096)
            if not chunk:
                raise AssertionError("Backend exited before profile response")
            total += len(chunk)
            assert total <= 1024 * 1024, "Unexpected excessive output"
            pending.extend(chunk)
            while b"\n" in pending:
                line, _, rest = pending.partition(b"\n")
                pending = bytearray(rest)
                assert len(line) <= 256 * 1024, "Oversized frame"
                frame = json.loads(line)
                assert type(frame.get("v")) is int and frame["v"] == 1
                if frame.get("id") == request_id:
                    assert "error" not in frame, "Profile request was rejected"
                    return frame["result"]
            assert len(pending) <= 256 * 1024, "Oversized incomplete frame"
    raise AssertionError("Profile response deadline exceeded")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("publish_dir", type=Path)
    args = parser.parse_args()
    publish = args.publish_dir.resolve(strict=True)
    assert os.uname().sysname == "Linux", "This check targets Linux catalogs"
    expected = json.loads((publish / "profiles/default-linux.json").read_text())
    expected_names = [profile["name"] for profile in expected["profiles"]]
    assert expected_names, "Published Linux catalog must not be empty"

    # Reuse the existing hermetic HOME and Omarchy stubs, not live host discovery.
    fixtures = runpy.run_path(str(Path(__file__).with_name("test-packaging.py")))
    fixture = fixtures["PackagingTestBase"]()
    fixture.setUp()
    process = None
    try:
        subprocess.run(["bash", str(fixture.plugin_copy / "setup"), "--backend-dir", str(publish)],
                       env=fixture.env, cwd=fixture.plugin_copy, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
        for name in ("default.json", "default-linux.json"):
            assert (fixture.plugin_copy / "bin/backend/profiles" / name).read_bytes() == (publish / "profiles" / name).read_bytes()
        wrapper = fixture.plugin_copy / "bin/vpnrouter-headless"
        for scenario in ("unmodified-publish", "platform-canary"):
            names = expected_names
            if scenario == "platform-canary":
                # Independent selection proof, not a correction applied to the
                # unmodified consumer check. Never change the supplied publish tree.
                canary = "LinuxCatalogSelectionCanary"
                assert canary not in expected_names
                catalog = json.loads((publish / "profiles/default-linux.json").read_text())
                catalog["profiles"].append({"name": canary, "processes": [], "dns_mode": "vpn_only"})
                (fixture.plugin_copy / "bin/backend/profiles/default-linux.json").write_text(json.dumps(catalog))
                names = expected_names + [canary]
            data_dir = fixture.test_root / scenario
            data_dir.mkdir()
            process = subprocess.Popen([str(wrapper), "--stdio", "--data-dir", str(data_dir)],
                                       cwd=fixture.plugin_copy, env=fixture.env,
                                       stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                       stderr=subprocess.DEVNULL, bufsize=0)
            request = {"v": 1, "id": "profile-proof", "method": "profiles.list", "params": {}}
            process.stdin.write((json.dumps(request) + "\n").encode())
            process.stdin.flush()
            result = read_response(process, request["id"])
            assert [row["name"] for row in result["items"]] == names, f"Catalog mismatch in {scenario}"
            process.stdin.close()
            assert process.wait(timeout=8) == 0, "Backend EOF teardown failed"
            process.stdout.close()
            assert not list(data_dir.iterdir()), "Read-only profile request wrote configuration"
            assert not list(fixture.user_config_dir.iterdir()), "Setup or wrapper touched default configuration"
            print(f"PASS: {scenario}: setup -> production wrapper -> profiles.list ({len(names)} profiles), read-only data, EOF teardown")
    finally:
        if process is not None:
            if process.poll() is None:
                process.kill()  # Only the exact test child, never a discovered host process.
                process.wait(timeout=5)
            for stream in (process.stdin, process.stdout):
                if stream is not None and not stream.closed:
                    stream.close()
        fixture.tearDown()


if __name__ == "__main__":
    main()
