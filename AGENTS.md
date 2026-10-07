# Omarchy VPNRouter contributor contract

Native QML/Quickshell plugin for Omarchy Quattro, backed by VPNRouter.Core via
VPNRouter.Headless. The owner approved full Linux feature parity, not a launcher
or a status-only prototype. Canonical approved task: VPNRouter repository
`plans/phase-omarchy-plugin-2026-09-17.md`; protocol contract:
`plans/omarchy-protocol-v1.md` in that repository.

- Work on task branches; never push directly to main, merge, tag or release.
- Keep GPL-3.0 provenance; do not relabel VPNRouter as MIT.
- Plugin ID `io.github.pavellizunov.vpnrouter`; manifest at repository root.
- User interface lives inside existing omarchy-shell. Never launch a second
  Quickshell or Avalonia. Use host Color/Style and existing popup lifecycle.
- Secrets never appear in command arguments, logs, telemetry or test fixtures.
- One service-owned helper, bounded JSON-lines, cancellation and explicit
  unavailable/error states. No fake connected state or decorative controls.
- Preserve configured process-name casing and Core routing semantics.
- No sudo password fields, NOPASSWD, root shell, auto-install or implicit network
  downloads from QML. System changes need separate owner authorization.
- No live shell restart, plugin activation, VPN connection or route mutation.
- omarchy-test is authorized for isolated exact-SHA tests and per-user SDK only.
- harness-test is control plane: no platform SDK installation/heavy builds here.
- Gemini workers own disjoint assigned files; no agents, commits or pushes from
  workers. Coordinator owns integration, source verification and Git.
- Plans and outcomes go under plans/. Tests must cover real interactions and
  failed/malformed/oversized inputs, not only source-string presence.
- Report untested runtime limits and incomplete feature parity explicitly.
