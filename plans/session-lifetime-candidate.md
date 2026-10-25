# Session lifetime candidate

The coordinated backend candidate is
`dsh/omarchy-session-lifetime-2026-10-25` in VPNRouter. This plugin branch starts
the packaged systemd user unit and attaches over the same NDJSON protocol.
Backend/session ownership belongs to that unit; closing the panel, disabling
the plugin or restarting the shell only terminates its relay client.

`bin/vpnrouter-headless --auto` uses the unit only with the installed system
backend and no data-directory override. Plugin-local payloads, explicit --stdio,
and systems without the unit use the existing stdio spawn. A failed installed
unit is reported and retried with backoff; it never starts a second backend.
Service startup waits at most ten seconds for systemctl and five seconds for
the socket. No automatic mutation replay is added.

The service allows one controlling client. A second receives controller_busy;
after the old client detaches, reattach receives a fresh snapshot. A running
operation belongs to the service and can retain ordinary admission until it
settles. Snapshot remains available; disconnect/cancel are explicit controls.
Quit and systemctl --user stop terminate the session service. No VPN connection
is authorized for candidate verification; live connected-session survival is
still unverified. Stdio fallback still drops a connection when the shell exits.

Verification: existing Node suites, packaging isolation, qmllint, full offscreen
theme matrix and plugin validation; exact CI backend package plus this plugin
on omarchy-test, preserving service PID and selected inert server across shell
restart. Outcomes are recorded in the lead's D3 report.

Confirmed transport defect before editing: a valid error response delivered
through createChunkAccumulator produced frames=0/errors=1, because the
accumulator mistook response.error for a parse error. This blocks typed socket
controller errors and correlated operation failures alike. Route parsed
response frames through the normal callback and test feedChunk end to end.

Live follow-up: holding the controller while reopening Home replaced the
controller_busy text with backend.notRunning (EN screenshot was actionable;
RU navigation then issued listServers on the detached relay). Keep the typed
controller reason across offline reads/retries and clear it only after a valid
snapshot handshake. Cover navigation reads and failed startup in the actual
Service.qml function test before repeating the VM scenario.
