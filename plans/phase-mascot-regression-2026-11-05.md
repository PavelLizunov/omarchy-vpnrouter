# Mascot filtering regression

## Intent and evidence

The owner reported jagged mascot icons on this Omarchy workstation. Installed
runtime sources match plugin `4e66c9e`; current main is `11feb675`, whose PR #8
already fixes both mascot consumers with DPR-aware sourceSize and mipmaps.
Both revisions declare 0.1.2, so the version label alone cannot prove delivery.
Backend r59 source `f6b39db` is the current upstream VPNRouter main, not an
unmerged backend. Plugin PR #7 and upstream PR #632 are separate open changes.

## Scope and invariants

Record the filtering rule in AGENTS.md and assets/README.md; extend the existing
brand regression to cover every mascot consumer. Restore the two published main
QML files to the installed copy with backups outside the watched plugin tree.
Preserve original asset bytes, backend, configuration, routes and service owner.
No shell restart, package upgrade, merge, tag or release. Rollback restores the
two backed-up files. Existing dirty changes in the original worktree stay intact.

## Verification gates and outcome

- Build: N/A, no compiled sources change.
- Tests: focused brand check passes; all six missing-property negative controls
  and the pre-fix installed pair fail as expected. Exact-head GitHub CI pending.
- Documentation: this record, AGENTS.md and asset rules.
- Review: scoped source review; no independent review claimed for this small fix.
- UI: published PR #8 has isolated QML evidence; new live visual acceptance is
  unverified. Compare installed bytes and service PID without desktop capture.
- Integration: compare installed runtime consumers against public main and
  record exact backend/plugin provenance. No other branch is merged implicitly.

## Local delivery

Installed Header.qml and HeroCard.qml now match public main `11feb675` exactly.
Backup and receipt: `~/.local/state/vpnrouter-ui-backups/20261105T193733Z/`.
The active user service retained PID 3371 and active/running state before and
after the file replacement. No shell restart or backend/package mutation ran.
This proves file delivery and unchanged service ownership, not live pixel quality
or dataplane continuity. The source regression protects filtering declarations;
the earlier PR #8 record owns isolated rendering evidence. No fresh render claimed.
