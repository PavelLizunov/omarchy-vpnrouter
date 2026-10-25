# E1 status probe and service lifetime regression

Scope: plugin checkpoint based on `a9eddaa`, with backend Arch r33
(`5470a8bcae3ee9ee66a939c291d73b1f223b3dfa`). No VPN connection tests.

## Confirmed defects

Running the deployed `setup --status` changed the shell-owned Headless PID while
the shell PID stayed unchanged. The probe created its private data directory
inside `bin/.probe_tmp.*`; writes there trigger the host's plugin watcher.
A concurrent service teardown also produced `Service.qml:391: TypeError: Cannot
read property 'backendStarted' of null` from a late Process `started` signal.
No active VPN existed during reproduction; impact on an active VPN was not tested.

## Change and acceptance

- Keep handshake data in a regular system temporary directory outside the plugin.
- Ignore a Process `started` signal whose owning QML service has been destroyed.
- Execute the real setup with a fake backend which writes probe data; assert that
  the data directory is outside the plugin tree and removed after the handshake.
- Execute the actual QML `onStarted` handler with destroyed and living owners.
- Repeat installed `setup --status` and confirm that the shell-owned helper keeps
  its PID; preserve mihomo, configuration and network state.

Both new regressions fail against the original production code and pass with the
fix. Commands, runtime outcomes, image provenance and remaining live UI limits
are recorded in the E1 worker report outside this repository. Full native click,
keyboard, screenshot and VPN routing acceptance remain separate from offscreen
QML assertions and protocol-level server probes.
