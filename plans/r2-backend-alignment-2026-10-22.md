# Backend alignment, 2026-10-22

## Scope and source

Continue draft PR #3 from plugin `6bcf4d3b81d1bb350696ed9d14e136bcb672b5de`.
Backend source inspected read-only: `PavelLizunov/VPNRouter`, commit
`29dcca1a29a670f0a45cf44a72fa639231427040` (PR #616).
No plugin installation, activation, live shell restart, second Quickshell,
VPN connection or merge is part of this batch.

## Behavior

- Preserve snapshot/state-event `unavailableReason` (string or null) and show it
  verbatim when connection is unavailable. Both connect targets are disabled.
- The wrapper reports a missing backend with exit 127. Show the localized package
  installation hint and stop retries for that condition.
- Retry process failures after 2, 3, 4.5 seconds and so on, capped at 30 seconds.
  Starting a process or receiving a state event does not reset this delay;
  a valid successful `snapshot` response does.
- Show `servers.verify` (`id, ok, latencyMs, error`) and `free.verify`
  (`id, ok, latencyMs, status`) results and protocol failures in their views.
- Acknowledge cancel only when `cancelled=true`; await the target's terminal
  response. Clear stale `busy=true` on successful ordinary completion.
- Parse backend errors with `id:null`. Bound accumulator frames independently,
  including reads containing multiple legal frames and oversized-frame recovery.
- Read resolved `settings.get.dnsMode` when `dnsModeOverride=null`. Keep DNS mode
  read-only. Unsupported DNS lockdown is unchecked, disabled and omitted from
  saves; no kill-switch toggle exists.
- Move plugin-owned UI text into en/ru catalogs. Preserve backend reason/error
  prose and protocol/product identifiers. Qualify palette references with
  `Commons.Color`, matching installed clock and avoiding QtQuick.Color in Qt 6.12.

Method names and request parameters already match the backend switch/allowlists;
no endpoint renaming or invented capability method was needed.

## Verification

Seven Node suites execute protocol/model logic and actual QML function bodies.
The new backend suite covers the unavailable capability, missing binary, repeated
fast exits, successful/malformed handshake, retry cap, verify success/failure,
cancel acknowledgement and unsupported protection bindings. Locale tests check
UI lookup presence, en/ru key parity and placeholders. Packaging tests cover the
wrapper's missing-backend exit. Installed-import qmllint, JSON, manifest, shell
syntax and Python checks are run separately.

Native preview uses the installed Qt renderer's static Quickshell module adapter,
not a Quickshell process. Actual HeroCard, ServersView, FreePoolView and
SettingsView are rendered in en/ru with inert service fixtures. The fixture with
saved DNS lockdown=true and capability=false must show the control off/disabled.
This establishes fixture layout, not live clicks, focus, lifecycle or traffic.

The full command/exit log, mismatch table, exact final plugin SHA, screenshots
and machine-specific installation handoff are in the requested external
`r2-plugin.md` report. No live plugin or backend acceptance is claimed.

## Backend-owned limits

Progress events currently carry a resource ID or no ID; dispatcher enrichment
only handles dictionaries, while feature events use anonymous objects. The UI
therefore does not treat progress.id as a request ID. Backend-side request ID
stamping would be needed for causal association across overlapping operations.

`unavailableReason` describes runtime policy failure; ownership/session-only
rejections of connect may still have a null reason. The plugin uses localized
unavailable text when no backend reason exists.

`servers.list` includes enabled subscription servers, while `servers.remove`
searches only local manual servers. Rows expose no source/removable field, so
reliable per-row deletion gating needs a backend metadata field or consistent
unified-ID removal behavior. This remains a backend-owned mismatch.
