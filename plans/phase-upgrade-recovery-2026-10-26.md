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

Fresh exact-revision backend bundle and repository delivery are pending.
