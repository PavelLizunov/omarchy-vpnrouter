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

## Requested visual preview (2026-10-27)

The owner asked to see the candidate. Render the actual ProfilesView with inert
service data and installed native visual components, not the production shell.
The first render exposed nested Repeater model data as a QML array-like object:
Array.isArray was false although length was 1 and JSON contained ["Discord"].
The guard therefore discarded every process list and displayed the backend
update hint. Normalize this boundary to a plain JS array and rerender.
The initial PNG is retained as failure evidence; it is not the intended design.
AT-SPI bridge warnings prevent strict renderer acceptance; no input/a11y claim.

Corrected the actual candidate boundary with Array.prototype.slice.call and
rerendered the same consumer with full Linux catalog/demo selection. Inspected
PNG groups-ru-corrected.png: Discord 1/1, Messengers 2/3, AI_Tools 3/3; concrete
process toggles are visible and states differ. QML diagnostics contain no source
warnings; the AT-SPI warnings persist, so report policy was used explicitly,
not a strict-warning PASS. Renderer 0.3.0, Qt 6.12.0 software/offscreen, logical
540x1000, DPR2 (1080x2000). Current palette #2c2525/#e6d9db/#f38d70.
Evidence: /tmp/vpnrouter-groups-preview-00ivk2ps/ (fixture, host visual adapters,
initial failure, metadata and final PNG). Host Style process hooks were removed
and theme I/O replaced by captured style strings only in the fixture adapters.
The product ProfilesView/Toggle/Button are the actual candidate copies.

Visual limits: groups retain technical English catalog names/descriptions and
all apps are expanded, producing a long list. No full-panel placement, click,
keyboard, accessibility, real backend or live VPN verification was performed.
The developer preview does not change main, bundle r59 or the installed shell.
