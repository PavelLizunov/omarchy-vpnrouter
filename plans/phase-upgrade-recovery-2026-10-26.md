# Upgrade recovery continuation (2026-10-26)

## Intent

Continue Claude session faa48ee2-cca3-48b1-b223-9580da496820: finish the local
69ad5fc update-ordering fix together with VPNRouter PR #630 and a fresh bundled
backend. The owner reports disconnected UI despite continuing background VPN
traffic after updating on another laptop. That laptop is not remotely accessible
in the recovered evidence; the runtime cause is not independently reproduced.

## Scope and invariants

- Service.qml waits for its old client/helper to exit before installing.
- A stop timeout aborts installation instead of replacing a still-running helper.
- The wrapper allows bounded legacy-runtime cleanup before service attachment.
- Initial snapshot timeout must cover the backend recovery budget.
- Refresh backend/ only from the exact accepted VPNRouter CI source revision.
- No UI redesign, live VPN connection, unrelated desktop changes or auto-reconnect.

## Verification and delivery

Review the task-owned source and diff; commit and push a dedicated checkpoint
while preserving the original worktree branch/index. No local tests, linters,
visual previews or target-machine verification were requested for continuation.
Existing CI may run automatically after the requested repository delivery.
Publishing/build status and live behavior will be reported separately.

## Risk and rollback

An update can terminate a superseded VPN session; the new service stays
disconnected. Revert the plugin task commits and restore the previous bundled
package to roll back. This does not authorize broad process termination.

## Outcome

Service.qml now aborts installation if its helper remains alive after 25 seconds
and reports the existing localized stop failure. The initial snapshot and service
socket budgets allow bounded legacy runtime recovery (26 seconds). No user-facing
copy, geometry or VPN connection behavior was otherwise changed. Task-owned
diff inspected; target-machine behavior and the upgrade dialog remain unverified.

VPNRouter PR #630 was squash-merged as f6b39dbfc4d4de6e064b470037ea6b5a312c5a4c.
Main Arch CI run 40348520604 completed successfully and produced package
0.1.0.r59.gf6b39db-1. The existing bundling script imported that package and
verified its CI sidecar; bundle.json records source revision and SHA256
504056becc8b8db342a093ed58964da888b07f53ff68787bf202fd91fa4a9739.
This is CI provenance, not a separate reproducible-build equivalence claim.

Automatic backend PR checks all passed at 56f87786; automatic plugin push/PR
checks passed at 1bacfaf. No additional local verification was run.
The plugin manifest is bumped to 0.1.2 for the coordinated update.
Plugin PR #6 passed automatic checks at a5c5431ccee8900ca9ac8cfe491a85ed251abfe8
and merged as 4e66c9eb3558d552bed744f2b85e8818018118b9. Release v0.1.2 is
published, not a draft/prerelease, and its tag points to that exact main commit:
https://github.com/PavelLizunov/omarchy-vpnrouter/releases/tag/v0.1.2
Assets: the 21,716,083-byte Arch package, vpnrouter-headless-manifest.json,
and SHA256SUMS. Remote task-branch, main and release tag SHAs were observed
with git ls-remote. The original active worktree branches/index were preserved.

Publication and source delivery are complete; local installation/loading and
the reporting-laptop upgrade/recovery were not performed. No new local tests,
linters, visual checks or additional model review were run. User-side update
requires both the native plugin update and the panel's Update VPN component
action; a backend package upgrade disconnects and requires explicit reconnect.
