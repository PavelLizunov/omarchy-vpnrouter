# Omarchy version and update-source investigation

## Intent and boundaries

The owner sees different VPNRouter interfaces and bar icons on two Omarchy
computers after an update. Identify installed bytes, source commits, release
channels and installer pins before proposing a rollout. Read-only investigation;
no plugin replacement, activation, shell restart, backend update or VPN action.
Preserve both the newer penguin UI and the owner's unrelated working changes.

## Verified source map

| Source | Plugin identity | Bar icon | Backend | Header image filtering |
| --- | --- | --- | --- | --- |
| Bootstrap profile on current main | `a9eddaa`, manifest 0.1.0 | Shield glyph | Pinned r37, `2cc9e7e` | No DPR sourceSize or mipmaps |
| Release v0.1.0 | `3d25256`, manifest 0.1.0 | Shield glyph | Not bundled | No DPR sourceSize or mipmaps |
| Release v0.1.1 | `c6036aa`, manifest 0.1.1 | Pixel penguin | Bundled r57, `fbae13f` | No DPR sourceSize or mipmaps |
| Release v0.1.2 | `4e66c9e`, manifest 0.1.2 | Pixel penguin | Bundled r59, `f6b39db` | No DPR sourceSize or mipmaps |
| Current plugin main | `11feb675`, manifest 0.1.2 | Same pixel penguin | Same r59 | DPR sourceSize, smooth, mipmaps |
| This workstation now | v0.1.2 source receipt plus two previously updated images | Same pixel penguin | Installed r59 | Header/Hero match main |

Plugin ID throughout: `io.github.pavellizunov.vpnrouter`. The plugin source is
`PavelLizunov/omarchy-vpnrouter`; backend source is `PavelLizunov/VPNRouter`.
Plugin and backend versions are different numbering systems.

## Installed-workstation evidence

- `.bootstrap-source.json` records plugin source `4e66c9eb3558d552bed744f2b85e8818018118b9`.
- All 85 tracked v0.1.2 files are installed: 83 match and only Header.qml and
  HeroCard.qml differ, from the earlier two-file delivery recorded in
  [the icon task](phase-mascot-regression-2026-11-05.md). The extra file is the
  bootstrap receipt. Against current main, code matches; README/media/evidence
  files were not delivered by that narrow update.
- The general bar icon files BarWidget.qml and ui/PenguinMark.qml exactly match
  v0.1.2 and current main. They are different from the bootstrap-pinned shield.
- `pacman -Qkk vpnrouter-headless`: 153 files, zero altered files. SHA-256
  comparison of 71 installed backend payload files against the released package
  found zero differences. Package manifest source is `f6b39db` (r59).
- The active shell uses `/usr/share/omarchy/shell`; its registry's user plugin
  directory is `~/.config/omarchy/plugins`. No alternative installed VPNRouter
  manifest or plugin-local backend was found in the inspected source locations.

## Update paths and confirmed findings

- **P2 VERSION-CHANNEL-DRIFT, open:** release v0.1.2 and current main have the
  same manifest version but different image filtering. Plugin Control defaults
  to stable when no watched branch is selected. It therefore resolves v0.1.2,
  while native git-managed `omarchy plugin update` fetches origin HEAD. A release
  update does not mean the later main commit was installed.
- **P2 BOOTSTRAP-STALE-PIN, open:** bootstrap plugins.json still pins
  plugin `a9eddaa28868aab6701a922ae4199d76645b3582` with backend r37. Its installer
  strips .git, writes a receipt and leaves existing plugin IDs unchanged. A
  rerun is missing-only provisioning, not an updater. Native plugin update
  refuses a copied installation without .git. Do not infer that this is the
  second computer's actual path without inspecting that machine.
- **P2 BAR-ICON-ALIASING, open:** PenguinMark.qml is a 12x13 cell sprite (13/16
  cell canvas) rendered with `antialiasing: false` and GeometryRenderer, added
  by `5755260` and adjusted by `fc191ec`. Stepped geometry is separate from PNG
  downscaling in Header/Hero. PR #8 and the PR #9 source guard only address those
  PNG consumers; they do not prove the bar icon or the owner's current visual
  complaint fixed. Merely toggling antialiasing does not remove stepped geometry.
- Plugin PR #7 (`0272c0d`) changes application groups and declares 0.1.2 too;
  it does not change the bar icon or bundled backend. It is not an explanation
  for a shield-versus-penguin difference by itself.

Source owners: bootstrap plugins.json/bootstrap.py, Plugin Control
workbench/workspace/hub/src/updates.rs, native omarchy-plugin-update and this
plugin's BarWidget.qml/ui/PenguinMark.qml. Installed Plugin Control update-source
code matches the bootstrap snapshot; this workstation has no saved VPNRouter
branch override. Cached update observations are dated 2026-11-02, not fresh
proof of a completed update.

## Unknowns and verification

Second computer: installed commit, backend and exact update command remain
unverified. Read-only machine linking and an update-method question were offered.
Until that evidence arrives, shield/old bootstrap or release-channel behavior
are identified explanations, not a claimed remote-machine diagnosis.

No builds or full local suites were run. Investigation used GitHub source/tag
metadata, source inspection, SHA-256 comparisons and read-only package checks.
The earlier PR #9 code head `59007d8` has green CI; this report makes no new
rendering, loaded-QML pixel, live VPN continuity or release-readiness claim.
