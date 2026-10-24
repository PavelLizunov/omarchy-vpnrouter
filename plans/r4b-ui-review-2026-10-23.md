# R4b UI review — 2026-10-23

Base: `59fc08be555359720062a1cfd66804e264c6676b`.

Addressed the lead review's six findings: one Nerd Font shield family for all
bar states and a separate animated loading glyph; content-sized hero capped at
176 units; native-style dimming and neutral borders for disabled actions; plain
service wording and Russian catalog cleanup; shell AppLibrary icon resolution
with Quickshell fallback; realistic lowercase executable names in fixtures.
The panel retains its frame, with stable navigation across tabs. Status content
can change hero height and give the page the remaining space.

The old screenshot's Firefox entry was not backed by an installed Firefox
desktop entry on this machine. The production code already called iconPath;
R4b additionally uses the shell's indexed AppLibrary lookup when available.
Offscreen Chromium and Steam use their actual installed icon names. A deliberately
missing icon separately proves fallback. Configured process names retain exact
case; only the fixtures were corrected.

Verification: eight Node suites, 38 isolated Python packaging tests, manifest
validation, shell syntax and diff checks pass. qmllint exits 0 with 488 dynamic
property/type warnings (baseline 484), not a warning-free verdict. Actual Qt input
checks disabled Connect, all tabs, Apps add/remove/search, field Tab, empty Enter
and Escape at 540x640 and 430x560. Old-snapshot negative controls reject the
fixed-height hero and implementation jargon. Twenty-two final EN/RU screenshots
were inspected through the image reader, including contact sheets. The loading
glyph changes rotation while the shield stays upright.

Applied skills: omarchy-plugin; omarchy-plugin-patterns (plugin-authoring,
design-review, visual-review, localization-review); omarchy-visual-verification;
anti-slop; ponytail; change-verification; repository-readme. Localization used the
bundled local fallback, with key/placeholder parity and actual QML captures.
No dependencies, backend protocol or networking behavior changed.

Private evidence: appended R4b section in r4-plugin.md; r4b-evidence.json,
r4b-checks.json, r4b-red-green.json, r4b-design-review.html and r4b-*.png in the
owner-specified scratchpad. Intermediate images are excluded from final manifests.

No live pass, installation, activation or running-shell access occurred. VPN
connections, server/subscription operations and real backend mutations were not
exercised. Git delivery is the explicitly requested network exception. Offscreen
verification does not establish loading in the owner's current shell.
