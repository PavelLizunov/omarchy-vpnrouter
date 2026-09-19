# Draft plugin delivery verification

Baseline: 175d9da93fb300c0e99cba1beb3cc0d10d888a70 (LICENSE/.gitignore only).
Candidate: b48eaacb46e707098fe2ba4a149fb63b06e83e20.
Backend integration: VPNRouter draft PR296, commit64e1e805ad73b2bd523437f5ff9b8a933afb0f9f.

## Scope and checks

The 45-file candidate contains QML, Service, JavaScript libraries, RU/EN locales,
manifest, setup/wrapper, CI and tests. No binaries or historical local reports.
Executable source blobs match previous af58704f snapshot; README changes describe
draft limitations. Final delivery adds this report and README-only clarification
that lack of supported connection acceptance is not a technical guarantee that
the engine cannot launch on a provisioned host.

bash-125 exit0 on identity-checked omarchy-test:
- bash -n setup bin/vpnrouter-headless tests/qml-test-runner.sh
- PYTHONDONTWRITEBYTECODE=1 python3 tests/test-packaging.py:38 passed.
- node tests/test-ui-*.js (each file separately):5 suites passed,155 locale keys.
- bash tests/qml-test-runner.sh:normal success.
- VPNROUTER_QML_EXPECT_FAILURE=1 bash tests/qml-test-runner.sh:exit1 as expected.

Tests ran against an immutable exported snapshot. QML harness uses private
HOME/config/runtime and processDisabled=true. It substitutes KeyboardPanel with
an offscreen Item; scanner/scene warnings persist. Results do not prove real
popup/keyboard/scaling or live shell lifecycle. No activation, VPN connection,
root provisioning, release or merge performed.

Two Gemini lanes reviewed documentation and publication inventory. Coordinator
corrected overbroad connection-blocking prose and rejected untracked status as
a code defect. Python tests are invoked via python3 and do not require executable
mode. Actual shell entrypoints retain executable modes. This was scoped draft
review, not new whole-system security acceptance. Prior byte-identical source
reviews remain qualified by their recorded limits.

## Open acceptance gates

- Linux kill-switch/DNS protection and explicit source-only helper design approval.
- Compatible authenticated runtime binary distribution and consistent path.
- Real host UI and dataplane acceptance under separate authority.
- No precompiled release binaries or production installation claim.

The owner requested use/update of an Omarchy plugin skill. It was not available
in this session skill catalog or searched user/project skill directories; no
replacement skill was invented or modified. Exact skill name/path requested.
Potential additions once located: assertion-aware Qt verdict with negative
control, zero-symlink payload catalogs, and distinguishing offscreen from host
acceptance. These are observed lessons, not approved global instructions.
