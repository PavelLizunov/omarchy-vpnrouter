#!/usr/bin/env bash
# install.sh - Install or upgrade VPNRouter on Omarchy Quattro.
#
# Installs the vpnrouter-headless Arch package from a GitHub release of this
# repository (SHA256-verified) and the plugin as a git checkout of this
# repository, then enables the plugin and restarts the shell once.
#
#   curl -fsSL https://raw.githubusercontent.com/PavelLizunov/omarchy-vpnrouter/main/install.sh | bash
#
# VPNROUTER_TAG=<tag> selects a release instead of the latest one.
# Settings and subscriptions in ~/.config/vpnrouter are kept.
# An active VPN session is disconnected during the upgrade.

set -euo pipefail

repo=PavelLizunov/omarchy-vpnrouter
id=io.github.pavellizunov.vpnrouter
plugin_url="https://github.com/$repo.git"
plugin_dir="$HOME/.config/omarchy/plugins/$id"
if [[ -n "${VPNROUTER_TAG:-}" ]]; then
  release_url="https://github.com/$repo/releases/download/$VPNROUTER_TAG"
else
  release_url="https://github.com/$repo/releases/latest/download"
fi

say() { printf '==> %s\n' "$*"; }
fail() { printf 'install.sh: error: %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || fail "run as your normal user; sudo is requested for pacman only"
for tool in pacman sudo curl sha256sum git omarchy systemctl pgrep ip; do
  command -v "$tool" >/dev/null 2>&1 || fail "required command not found: $tool"
done
[[ "$(uname -m)" == x86_64 ]] || fail "only x86_64 is packaged"

work="$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/vpnrouter-install.XXXXXX")"
old_plugin=""
cleanup() {
  if [[ -n "$old_plugin" && -d "$old_plugin" && ! -e "$plugin_dir" ]]; then
    mv "$old_plugin" "$plugin_dir" && printf 'install.sh: restored the previous plugin\n' >&2
  fi
  rm -rf "$work"
}
trap cleanup EXIT

say "Downloading the backend package"
curl -fsSL --retry 3 -o "$work/SHA256SUMS" "$release_url/SHA256SUMS"
pkg="$(awk '$2 ~ /^vpnrouter-headless-.*-x86_64\.pkg\.tar\.zst$/ { print $2; exit }' "$work/SHA256SUMS")"
[[ -n "$pkg" ]] || fail "SHA256SUMS in the release names no package"
curl -fSL --retry 3 --progress-bar -o "$work/$pkg" "$release_url/$pkg"
(cd "$work" && grep -F "  $pkg" SHA256SUMS | sha256sum -c --quiet) || fail "package checksum mismatch"

say "Stopping the current VPNRouter backend"
if omarchy plugin list --json 2>/dev/null | grep -q "\"$id\""; then
  omarchy plugin disable "$id" >/dev/null 2>&1 || true
fi
systemctl --user stop vpnrouter-headless.service vpnrouter-headless.socket >/dev/null 2>&1 || true
# Older plugins ran the backend as a child of the shell over stdio.
stdio_pattern='(^|[ /])VPNRouter[.]Headless([.]dll)? --stdio( |$)'
if pids="$(pgrep -u "$(id -u)" -f "$stdio_pattern")"; then
  kill -TERM $pids 2>/dev/null || true
  for _ in $(seq 1 40); do
    pgrep -u "$(id -u)" -f "$stdio_pattern" >/dev/null || break
    sleep 0.5
  done
  ! pgrep -u "$(id -u)" -f "$stdio_pattern" >/dev/null ||
    fail "the old backend did not exit; disconnect the VPN, reboot and run this script again"
fi
if ip link show VPNRouter-TUN >/dev/null 2>&1; then
  fail "the VPNRouter-TUN interface is still up; reboot and run this script again"
fi

say "Installing $pkg (sudo password requested by pacman)"
sudo pacman -U --noconfirm "$work/$pkg"

say "Installing the plugin"
if [[ -d "$plugin_dir/.git" ]] &&
  [[ "$(git -C "$plugin_dir" remote get-url origin 2>/dev/null)" == "$plugin_url" ]]; then
  omarchy plugin update "$id" --yes
else
  if [[ -e "$plugin_dir" ]]; then
    # A copied plugin (or one with a plugin-local backend) is replaced by a git checkout.
    old_plugin="$work/previous-plugin"
    mv "$plugin_dir" "$old_plugin"
  fi
  omarchy plugin add "$plugin_url" --yes
fi
systemctl --user daemon-reload
omarchy plugin enable "$id" --section right

say "Restarting the Omarchy shell to load the plugin"
omarchy restart shell >/dev/null 2>&1 || true

say "Done: $(pacman -Q vpnrouter-headless), plugin $(git -C "$plugin_dir" rev-parse --short HEAD)"
say "Open VPNRouter from the bar and connect. Future upgrades: run this script again."
