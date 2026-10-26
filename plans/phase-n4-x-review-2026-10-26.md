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
