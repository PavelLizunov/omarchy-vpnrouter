# Current status

The plugin is a development draft targeting full Linux feature parity. It has
native Home and advanced views, EN/RU catalogs, bounded helper transport, paged
lists, editable routing/settings and explicit probe outcomes.

The 2026-10-25 hygiene pass starts from
`8800d6910c5f540ae589a6c567f0e28943230b17`. Historical round reports were removed
from this tree; recover any with `git show <base>:plans/<filename>`.

Known limits: Linux kill switch and DNS lockdown are unavailable; search covers
loaded pages, offset pagination has no snapshot token, arbitrary backend prose
is not translated. Older backend builds may not report subscription refresh
failures explicitly.
The previous VM audit observed an intermittent HY2 Verify LocalSpawn failure.
Full Linux parity, VPN lifecycle/traffic routing, physical egress/leak behavior,
native keyboard and screen-reader acceptance remain unverified by this pass.

The density candidate branch remains a separate owner decision. This hygiene
work does not install or activate the plugin.

Hygiene outcome (2026-10-25): 22 historical reports and six obsolete QML fixtures
or runners were removed; current tests use behavior names. English/Russian front
pages were shortened, with details moved to docs. Validation passed: 13 Node suites,
38 packaging cases, 97 actual-QML interaction/theme cases, qmllint and plugin
validation. These are isolated checks, not live installation or VPN acceptance.
Exact commands, deletion reasons and inspection limits are in the C1 report.

C2 follow-up scope: fix confirmed probe/setup/restart wording and recover an
open panel after helper failure, using local and inert offscreen checks only.

C2 outcome (2026-10-25): reachable probes without reliable latency now use
protocol-neutral EN/RU text; measured zero remains valid. Setup checks the fixed
system runtime path and leaves trust/capability authorization to the backend.
All four install sequences warn that restarting the shell drops the VPN.
Focused Home navigation rows stay visible after later content growth/shrink.
A validated startup snapshot now notifies an open panel to reload its data; recovery does
not reconnect the VPN. The closed panel makes no recovery reads. Structured
subscription refresh failures now have EN/RU feedback and retain displayed servers.

C2 isolated checks passed: 13 Node suites, 39 packaging cases and 97 QML
interaction/theme cases, plus qmllint and plugin validation. An earlier QML run
exposed the Home focus defect; the new growth/shrink regression passes after
its fix. Source checks matched 38 methods/parameter sets, 12 snapshot fields,
six states and 299 EN/RU keys with placeholders. No live backend, shell restart,
VPN operation or deployment was performed; the runtime limits above remain.

E1 outcome (2026-10-25, workstation, backend r33): `setup --status` no longer
creates its probe directory inside the watched plugin tree, which had reloaded the
plugin and restarted the helper; a late Process `started` signal on a destroyed
service is ignored. Both have regressions.

C3 outcome (2026-10-25, isolated checks): native disclosure, process search and
reactive window-list scenarios are restored in the current QML consumer. Eight
backend error codes now have EN/RU messages (307 matching catalog keys).
Manual app names survive rejection until a successful acknowledgement; delayed
focus callbacks tolerate destroyed controls. A terminal error reconciles stale
busy/lifecycle state with one snapshot when the final state event is absent.
All 38 request wrappers have wire-error regressions; native form failures check
released controls and one notice. The final local gate passed 13 Node suites,
40 packaging cases, 99 QML cases, qmllint and plugin validation. No live backend,
VM, shell restart, VPN operation or deployment was used for C3.

View fixes (2026-10-25): V2-02/03/04/06/I1/09 and V1-01/05/06 are implemented; V2-01 Home is fixed and Servers is partial on dsh/omarchy-plugin-f1-visual-2026-10-25; final UI commit 8c1598a.
V2-05 fixes Notice/Delete/Hero/StatusBadge ink; 23 installed theme palettes give at least 6.30:1 for these active foregrounds. BarWidget shield ink remains outside the F1 file scope.
Every retained fix has exact-commit checks: 13 Node suites, 40 packaging cases in bwrap, qmllint and plugin validation exit 0; the final UI all-mode matrix passes 109 QML cases. Qmllint warnings remain; exact-SHA CI is green.
Actual-QML regressions cover disclosure, full names on hover/focus, pending/failed/empty reads, row probes and deadlines, stable latency rows, and pinned Settings actions with unobscured focus. Evidence and 21 inspected before/after crop pairs: /home/slovn/.cache/vpnrouter-f1/.
Deferred as requested: V2-08 Home density, V1-02 Free Pool search, and V1-03 diagnostic localization. V2-01 Servers action-before-details ordering needs F2-owned Panel.qml; V3-L02 and BarWidget contrast also remain for service/host follow-up; independent lead review is pending.
Not installed, loaded, or published. Only inert offscreen consumers were used; workstation UI, busy VM, real VPN/backend and subscription data were untouched. PR 3, its branch/index, mascot art and host theme/font roles are preserved.

F2 outcome (2026-10-25): failed starts/deadlines retry; unacknowledged writes are capped at 1,310,720 bytes and pause on timeout without stopping the helper; the idle watchdog stops.
Nine sections load on first visit and retain drafts. V3 harness on d30144d, five paired trials: Panel creation medians 147.7→24.8 ms (2 servers), 465.3→24.1 ms (100); not shell cold-start.
EN/RU docs describe unsandboxed execution, backend shutdown and complete removal. The unchanged mascot reference moved to tests/fixtures and is excluded from documented archive installs.
The fix commits passed 13 Node suites, up to 41 packaging and 109 QML cases, qmllint and plugin validation (exit 0); CI passed on each pushed fix SHA.
No workstation display, VM, real VPN, subscription edit, activation, release, tag or merge was used; live lifecycle and traffic behavior remain unverified.
AGENTS.md is preserved for agent tooling; its Marketplace inclusion remains the owner's decision. Git-clone installs still include the test-only mascot fixture.

Visual integration (2026-10-25): lazy-page probe tests now visit Free Pool and recover after deadlines; helper recovery wording, nonbreaking latency, Servers action ordering and measured danger/bar ink fallbacks are fixed.
All six fix SHAs passed 13 Node suites, 41 packaging cases in bwrap, qmllint, plugin validation and exact-SHA CI; the final code head 0e92c22 passes 146 actual-QML cases. Qmllint retains 1204 warnings and no errors.
On omarchy-test with r33, EN/RU Tokyo Night/Latte pages, nine lazy sections, pinned Settings actions, full Free Pool names, Test/Verify and Back focus were checked; one helper SIGTERM recovered with exit 0 shown only in Diagnostics. The shell restarted once.
Across 50 UI cycles, whole-shell RSS was 1088136→1282708 KiB and Headless 94732→262476 KiB; during 180 seconds with the panel closed, CPU was 0.0333%/0.0056% of one core and final RSS 1174588/265104 KiB.
Memory-leak attribution and long soak remain unverified; long error details were checked offscreen only. The VM keeps r33 and candidate code, Tokyo Night, scale 1 and AUTO locale; no VPN connection, subscription edit or publication was performed.
