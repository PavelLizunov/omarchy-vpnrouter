# Application groups and Tailscale feedback (2026-10-26)

## Intent and source findings

Owner reports useless/unclear single-choice profiles and a possible Tailscale
conflict. ProfilesView currently sends a one-ID array and exposes only names.
Backend profiles.select does not change the explicit app list after Apps edits.
Fix the owning flow by reusing apps.set, not by adding a second synchronization
layer or presenting cosmetic multi-selection alone.

## Scope

Display profiles as independent application groups with their descriptions and
exact process names. Show mode applicability; groups edit VPN-selected apps,
not server configuration and not the exclude list. Preserve existing APIs and
localize explanatory text in EN/RU using the existing catalogs (local fallback;
no separate translation/anti-slop skills are available). Show backend-provided
system exclusions separately from the editable list, so Tailscale bypass is not
a hidden default. Coordinate with the matching VPNRouter task branch.

## Risk, rollback and limits

No live shell/VPN/Tailscale mutation or remote access. Use current source and
review the task-owned diff; tests, linters, captures and new test writing were
not requested. Runtime layout, profile application and the reporting host remain
unverified. Revert the scoped commits to roll back. Existing installed/released
packages do not gain backend fixes merely from this source checkpoint.

## Outcome

Replaced the radio-like profile selector with group and individual process
toggles backed by the shared apps.set include list. Multiple groups coexist;
individual selections and overlap are reflected directly. Mode hints distinguish
full/include/exclude semantics. Descriptions and concrete processes come from
the coordinated backend; older backends show an update hint instead of silently
activating an ineffective profile. Panel navigation loads both apps and groups.
System bypass metadata is retained and displayed separately in Applications.

EN/RU text uses existing I18n keys and positional placeholders, with direct local
meaning/style review; no external localization skill or model call. No tests,
linters, previews or runtime checks run. Task-owned source/diff reviewed.
Original worktree branches/index are untouched; main, release 0.1.2 and installed
backend r59 still contain the preceding code, not this fix.
Implementation checkpoint 40db2662ea6759d619f3fdc1efd2878ec0a8cb38 was pushed
and its exact remote commit observed; PR #7 automatic push/PR checks passed.
Coordinated backend PR #632 is at 715811d4: build/contracts pass, but one
general Linux process-identity child-liveness assertion remains failed. No
installable new package or working-target claim is made.
