# Current status

The plugin is a development draft targeting full Linux feature parity. It has
native Home and advanced views, EN/RU catalogs, bounded helper transport, paged
lists, editable routing/settings and explicit probe outcomes.

The 2026-10-25 hygiene pass starts from
`8800d6910c5f540ae589a6c567f0e28943230b17`. Historical round reports were removed
from this tree; recover any with `git show <base>:plans/<filename>`.

Known limits: Linux kill switch and DNS lockdown are unavailable; search covers
loaded pages, offset pagination has no snapshot token, arbitrary backend prose
is not translated, and subscription refresh can lack a structured fetch failure.
The previous VM audit observed an intermittent HY2 Verify LocalSpawn failure.
Full Linux parity, VPN lifecycle/traffic routing, physical egress/leak behavior,
native keyboard and screen-reader acceptance remain unverified by this pass.

The density candidate branch remains a separate owner decision. This hygiene
work does not install or activate the plugin. Exact check results and the
deletion inventory are delivered in the coordinator's C1 report.
