# Round L: retain the VPN session across UI lifetime

Integrate the user-service candidate onto 1246ac4, retaining the startup,
backpressure and VPN-conflict fixes. The wrapper starts only the packaged user
unit and execs an attach relay. Teardown stops only that relay, and a fresh
snapshot restores the live server, state and optional session telemetry.

Snapshot reads must preserve backend busy=true while an operation from a detached
controller is still running. Connection duration uses the backend timestamp;
byte totals come from the owned TUN. A visible connected panel samples every two
seconds without overlapping its ordinary request; closed panels do not poll.

Verification: existing Node and packaging suites, qmllint, native inert QML cases,
plugin validation, exact-SHA CI, then locked VM connect/rescan/shell restart and
Disconnect with screenshots, PID, exit IP, TUN and policy-rule evidence.

## Reattach while Connecting

A live r45 detach/rescan during an admitted connect preserved the VPN, but the
panel's ordinary collection reads received busy and were never retried. After
Disconnect, Home displayed stale busy feedback, missing subscription metadata
and a disabled Connect button. Panel now waits for the fresh snapshot before
loading data and defers those reads until the service's busy flag clears. Native
QML regression fails on 9c77a39 with an early servers.list, then checks restored
source metadata and an enabled next Connect action without reopening the panel.
