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
