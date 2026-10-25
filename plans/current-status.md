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
service is ignored. Both have regressions. Known test gap: the removed r5 fixture's
native disclosure, search and live window-list refresh scenarios were not ported.
