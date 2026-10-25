# VPNRouter for Omarchy Quattro

Native QML panel and bar widget for VPNRouter, running inside the Omarchy shell.
**Development draft; full Linux feature parity is not yet verified.**

[Русский](README.ru.md) · [Releases](https://github.com/PavelLizunov/omarchy-vpnrouter/releases) (no plugin release yet) · [Current status](plans/current-status.md)

The plugin runs **unsandboxed inside the shared `omarchy-shell` process with your
user permissions**. Its code and dependencies have that same access; Marketplace
validation is not a security audit. See the [Omarchy execution model](https://plugins.omarchy.org/develop.html).

## Install

Requires Omarchy Quattro and the `vpnrouter-headless` Arch package.
See the backend's [package instructions](https://github.com/PavelLizunov/VPNRouter/blob/dsh/omarchy-mvp-2026-10-22/packaging/arch/README.md).
From this repository at the reviewed commit:

Restarting the shell stops the VPNRouter backend and drops any active
VPNRouter connection.

```bash
id=io.github.pavellizunov.vpnrouter
plugin_dir="$HOME/.config/omarchy/plugins/$id"
mkdir -p "$plugin_dir"
git archive HEAD | tar --exclude='tests/fixtures/penguin_mascot_tile.png' -x -C "$plugin_dir"
omarchy plugin validate "$plugin_dir"
omarchy-shell shell rescanPlugins
omarchy plugin enable "$id" --section right
omarchy restart shell
omarchy plugin list --json
```

Use a real directory. The launcher uses the installed system backend when no
plugin-local payload exists. Copying files does not provision sing-box or enable
VPN connectivity. The optional [local backend setup](docs/guide.md#installation--setup)
requires Python 3 and a trusted publish directory; setup does not download binaries.

If the service reports missing network permissions, run this once in a terminal:

```bash
sudo setcap cap_net_admin,cap_net_raw+ep /usr/lib/vpnrouter-headless/runtime/sing-box
```

A filesystem without extended attributes cannot retain these permissions; install
the package on a filesystem that supports them. Use an up-to-date Headless package
for noninteractive DNS cleanup. Plugin setup and its launcher do not request root.

## Use

Click the bar icon to open Home. Add a subscription or import servers, select a
server, then use Connect when the backend reports that connection is available.
Home keeps the connection action, status and current server above its scrolling
navigation. Server rows scroll below a fixed search field; Settings keeps Save
and Revert at the bottom of the visible page. On short screens the extra Home
emblem is hidden and routing controls remain in the scrolling area.

Right-click the icon toggles the connection; middle-click refreshes status.
Advanced sections expose servers, subscriptions, apps, routing rules, profiles,
custom configs, settings, diagnostics and the free pool.

The language control switches EN/RU/AUTO. Tab moves focus; Escape closes the
panel. Multiline editors use Ctrl+Enter to submit. Basic Test and proxied HTTP
Verify are separate actions; a missing latency value does not mean offline.

See the [guide](docs/guide.md) for shortcuts, preferences, setup, updates,
removal and tests, and [architecture](plans/implementation.md) for ownership.

## Limits

Linux kill switch and DNS lockdown are unavailable. DNS controls describe saved
configuration, not active kernel state. Search covers loaded pages; lists load
100 rows at a time. Backend diagnostic prose can remain in its original language.

Automated checks use inert backend responses and an offscreen host adapter.
They do not certify live shell behavior, VPN traffic routing, leak protection
or full feature parity. See [current status](plans/current-status.md) for open limits.

## Remove

Disconnect the VPN, then remove the plugin:

```bash
omarchy plugin remove io.github.pavellizunov.vpnrouter
```

Unloading the plugin asks its shell-owned backend to stop. The system package,
saved VPN data and, for archive installs, a hidden plugin backup remain.
See [complete removal and backend shutdown](docs/guide.md#removing-the-plugin-and-stopping-the-backend).

## License

[GPL-3.0](LICENSE), preserving [VPNRouter](https://github.com/PavelLizunov/VPNRouter) provenance.
