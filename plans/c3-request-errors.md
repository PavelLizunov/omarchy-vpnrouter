# C3: native app scenarios and request errors

Base: `2c5fce07874062731a81b635b4014998abc4e749`.

Restore disclosure, process search and reactive window-list scenarios in the
actual-QML interaction consumer. Keep the production Apps UI unchanged.
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
