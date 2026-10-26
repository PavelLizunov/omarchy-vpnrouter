# N4-X independent review

Review 1246ac4..b5eaee1 against the service/socket backend and the legacy upgrade
path. Confirmed documentation gap: old stdio helpers must stop before package
replacement, and plugin-local payloads override the installed service backend.
Update EN/RU instructions and the lifetime note without changing UI or assets.

Verification: existing Node and packaging suites, link/command source review,
plugin CI and final VM deploy/validate/cold restart smoke coordinated with the
backend. Backend task journal: phase-n4-x-review-2026-10-26.md in VPNRouter.
No release, tag, merge or owner's workstation deployment. Lead reviews new edits.
Rollback: reinstall the previous plugin revision while disabled, after stopping
the service; use the matched backend package. Outcome is recorded in X.md.

Live r33/1246ac4 reproduced a DNS password dialog while HY2 was Connected.
Stopping that stdio helper left its old table-2022 rules after the TUN vanished.
The guide now checks both TUN and rules and uses a one-time reboot if legacy
cleanup is incomplete; no automatic deletion of another client's shared rules
is added. The shared VM's task-created old rules were removed by exact recorded
priorities after its core exited, preserving the Suflyor session.
