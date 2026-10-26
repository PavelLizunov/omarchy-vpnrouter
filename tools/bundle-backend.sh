#!/usr/bin/env bash
# bundle-backend.sh - Replace backend/ with the Arch package from a VPNRouter
# "Arch headless package" CI run and write backend/bundle.json.
#
#   tools/bundle-backend.sh <run-id>
#
# Requires gh with read access to PavelLizunov/VPNRouter.

set -euo pipefail

run_id="${1:?usage: tools/bundle-backend.sh <run-id>}"
repo=PavelLizunov/VPNRouter
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

gh run download "$run_id" -R "$repo" -D "$work"
pkg="$(find "$work" -name 'vpnrouter-headless-*-x86_64.pkg.tar.zst' -print -quit)"
[[ -n "$pkg" ]] || { echo "no package in run $run_id" >&2; exit 1; }
(cd "$(dirname "$pkg")" && sha256sum -c "$(basename "$pkg").sha256")
manifest="$(find "$work" -name manifest.json -print -quit)"

file="$(basename "$pkg")"
version="$(bsdtar -xOf "$pkg" .PKGINFO | awk -F' = ' '$1 == "pkgver" { print $2 }')"
sha="$(sha256sum "$pkg" | awk '{ print $1 }')"
commit="$(jq -r '.source_commit' "$manifest")"

rm -f "$root"/backend/vpnrouter-headless-*.pkg.tar.zst
mkdir -p "$root/backend"
cp "$pkg" "$root/backend/$file"
jq -n --arg package "$file" --arg version "$version" --arg sha256 "$sha" \
  --arg sourceCommit "$commit" --argjson ciRun "$run_id" \
  '{package: $package, version: $version, sha256: $sha256,
    source: "https://github.com/PavelLizunov/VPNRouter", sourceCommit: $sourceCommit, ciRun: $ciRun}' \
  > "$root/backend/bundle.json"
cat "$root/backend/bundle.json"
