# C3: native app scenarios and request errors

Base: `2c5fce07874062731a81b635b4014998abc4e749`.

Restore disclosure, process search and reactive window-list scenarios in the
actual-QML interaction consumer. Keep the production Apps layout unchanged.
Localize the eight unmapped backend error codes with EN/RU catalog parity.
Trace every request success/error callback after error frames began reaching
handlers; fix only demonstrated failures with inert transport regressions.
Rebase the separate session-lifetime candidate onto PR 3 and remove the duplicate
protocol fix without merging either candidate.

Verification after each batch: all 13 Node suites, isolated packaging, qmllint,
plugin validation, isolated full render-theme-matrix, and CI at pushed commits.
No VM, live shell restart, VPN operation, mihomo change or workstation install.
The lead reviews and integrates the C3 branch; density stays owner-controlled.

Confirmed during step 1: the full native actions suite emitted a delayed-focus
TypeError when a request refreshed/destroyed its focused delegate. `Focus.reveal`
now ignores a null item. The direct production-JS null regression failed before
this guard; living focused/forced scrolling remains covered.

Step 1 passed 13 Node suites, 40 isolated packaging cases, 99 actual-QML cases,
qmllint and plugin validation. Commit `9440d7c` CI `40184054983` succeeded.
Step 2 maps all eight previously unmapped backend errors with EN/RU keys.
Split-chunk regressions cover global feedback and caller-owned error callbacks.
Translation uses the bundled localization fallback and anti-slop wording review;
no independent fluent-human translation approval is claimed.

Step 3 source review covered all 38 Service request wrappers and the UI callbacks.
The manual Apps field cleared before acknowledgement; the production-handler
regression failed with an empty draft while the request had not succeeded.
It now clears on success only, including the already-configured no-op case.
The shared native fixture now sends responses through feedChunk; held form
rejections check released controls, retained input, one notice and retry.
All-wrapper wire regressions check single error callbacks where exposed, no
success-only refreshes, empty pending/urgent queues and ignored duplicate
terminal responses.

A second wire regression reproduced stale busy/lifecycle state when the final
state event is omitted. Backend ProtocolOutputQueue explicitly permits dropping
or evicting state events under backpressure, while error responses have no
snapshot. Errors now trigger one reconciliation snapshot when busy is still set
or a lifecycle operation failed; snapshot errors never recursively refresh.
No dropped-event occurrence on a live backend is claimed.

Step 2 passed the same local gate (99 QML cases); commit `39bc395` CI
`40184375983` succeeded. Source inventory found 307 keys in each catalog, matching
placeholders, and mappings for all 20 RouterException error codes.

The final step 3 local gate passed: 13 Node suites, 40 isolated packaging cases,
99 actual-QML cases, qmllint and plugin validation. The intermediate wrapper
expectation was updated for the new lifecycle reconciliation read; only the final
all-green run is acceptance evidence. Live backend/event loss remains untested.
