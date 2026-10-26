# Bundled backend package (2026-10-26)

## Intent

The owner wants `omarchy plugin add <repo> --enable` to be the whole install,
like other Omarchy plugins that ship a prebuilt binary (omarchy-discord). Owner
decision: ship the backend inside the plugin repository.

## Design

- `backend/` holds the CI-built `vpnrouter-headless` Arch package from VPNRouter
  main and `bundle.json` (file, version, sha256, source commit, CI run).
- `bin/vpnrouter-backend check` reports missing/outdated/current by comparing
  `pacman -Q` with the bundled version (vercmp).
- `bin/vpnrouter-backend install` verifies the sha256 and runs
  `pkexec pacman -U --noconfirm` on the bundled package. The Omarchy shell is the
  polkit agent, so the password prompt is the shell's own dialog. The package
  keeps owning capabilities, the polkit DNS rule and the systemd user unit.
- Service.qml runs `check` at start and exposes the install state; HeroCard
  turns the main button into "Install VPN component" when the backend is
  missing and offers "Update VPN component" when the bundle is newer.
  Installation runs only on that explicit click.
- `tools/bundle-backend.sh <run-id>` refreshes `backend/` from a VPNRouter CI run.

## Verification

- Static: bash -n, omarchy plugin validate, existing CI suite.
- Live: fresh install and upgrade on omarchy-test.

## Outcome

Merged to main on 2026-10-26 together with the owner-chosen penguin bar mark
(ui/PenguinMark.qml: side-view penguin on a tile, no contour; split tunnel fills
the lower-right half, all traffic fills the tile, badge for problems).
Checked: bash -n, omarchy plugin validate, qmllint, node UI tests, offscreen
QML render of every mark state. Not live-tested: the pkexec prompt through the
shell agent and the Install/Update buttons; the owner tests on their laptop.
