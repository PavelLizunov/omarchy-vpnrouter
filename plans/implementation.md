# Plugin architecture

Approved scope: full Linux feature parity with VPNRouter. Current limitations
are tracked in [current-status.md](current-status.md); this is not a parity claim.

- Root [manifest](../manifest.json) declares `bar-widget` and `service`.
  [BarWidget.qml](../BarWidget.qml) loads [Panel.qml](../Panel.qml) inside the
  existing Omarchy shell and obtains the shared [Service.qml](../Service.qml).
- The service owns one streaming helper. [Protocol.js](../lib/Protocol.js)
  bounds JSON-lines frames to 256 KiB, JSON depth to 32 and the ordinary request
  queue to eight entries. Cancellation and disconnect have a control path.
- Native controls use the installed host Color/Style roles and font. Original
  mascot assets remain in [assets](../assets/README.md).
- [The launcher](../bin/vpnrouter-headless) resolves only a plugin-local payload
  under bin/backend or the system installation under /usr/lib/vpnrouter-headless.
  It forwards `--stdio` and an optional absolute `--data-dir`; it has no PATH
  search, backend environment override, download or elevation step.
- [Setup](../setup) accepts a local publish directory with `--backend-dir`.
  It checks the protocol in a private temporary data directory, refuses updates
  while a helper is active, stages a complete payload and rolls back if final
  validation fails. It does not signal running helpers or enable the plugin.
  `--status` checks installation; `--remove` removes only the local payload.
- User configuration belongs to the backend. Plugin packaging does not remove
  it. A local payload does not provision the system sing-box runtime.

The backend owns Core behavior and the wire contract; see its
[Headless documentation](https://github.com/PavelLizunov/VPNRouter/blob/dsh/omarchy-mvp-2026-10-22/VPNRouter.Headless/README.md).
Contributor rules remain in [AGENTS.md](../AGENTS.md).

## Lifetime candidate transport

Service.qml uses the wrapper's `--auto` mode. With the coordinated installed
user unit, the wrapper starts the unit and execs the backend `--attach` relay;
the shell only owns that relay. Otherwise it retains the stdio path described
above. See [candidate ownership](session-lifetime-candidate.md).
