# Night 2 functional audit

Scope: trace each plugin action through Service and protocol v1 to Headless at
75ac570ce9140db0fca7320fd0d5f45479c930af; render inert combinations and run existing
checks. Worktree starts at 9e5657e. No VM/backend process, deployment, VPN lifecycle,
release, icon redesign or mascot change. Evidence lives in the owner's n2 cache.

Confirmed baseline findings:
- The subscription form now orders URL before optional Name, but native consumer
  checks still assume Name -> URL and submit using Return in URL. Correct the
  checks to exercise the actual URL -> eye -> Name -> Add path.
- Panel ignores the manifest mode preference. showLatency controls the bar text
  only, despite its bar/list label; list pills and tooltip ignore it.
- List calls replace the collection with only the first 50/100 records; no next
  page action exists. Enable/remove subscription does not refresh server rows.
- Ping discards reachable, so a completed failure/null is indistinguishable from
  never tested. Queue-full errors without callbacks are silently dropped.

Verification: existing Node and Python gates, real-QML inert action/keyboard
suites, three installed theme renders, extended state/preference matrix. Record
actual limitations; no live or backend-runtime acceptance is claimed by job B.


## Round 2 completion

Integrated the PR's routing/DNS copy and URL-first consumer fixes through
`d2218b0`; both `75cb30a` and `0c8ddc8` are ancestors of this task branch.
The subscription fixture conflict retains the PR's URL -> eye -> optional Name
keyboard checks and adds the reachable probe mock fields independently.

- `4a75788`: bounded request budgets, missing-helper/queue feedback, paginated
  collections, refreshed subscription server rows, explicit basic probe outcomes,
  verified free-pool admission, local error keys/arguments, same-operation error
  recovery, ignored late terminal frames, and empty quick-connect admission.
- `6053555`: initial display-mode preference, consistent latency visibility,
  custom configuration identity/navigation, advanced error notice and EN/RU docs.
- The consumer fixture explicitly initializes its advanced render mode after
  component construction; Home captures still choose Home through the real API.
  This avoids the newly honored initial preference changing labelled page captures.

The production sources passed all 13 Node suites, packaging 38/38, installed
host manifest validation, shell syntax validation, and qmllint (exit 0 with
existing static-analysis warnings). The full real-QML consumer campaign covers
40 interaction cases plus 57 theme/reference captures. A fresh expanded inert
campaign completed all 238 combinations from round 1. These use current plugin
sources, not a live VPN backend. Evidence commands, outcomes and source hashes
are retained in the owner's n2 `b-2-*` artifacts; visual inspection is recorded
separately from automated readiness/assertions.

Backend draft PR: https://github.com/PavelLizunov/VPNRouter/pull/622, base
`dsh/omarchy-mvp-2026-10-22`, exact head
`ddf97f806b192a879ef5e0df940c2d6f949103a4`.
The existing dotnet test workflow and manually dispatched Arch workflow both
succeeded at that SHA. Arch run `40074333153` produced
`vpnrouter-headless-arch-0.1.0.r25.gddf97f8-1`. No package was installed on a VM
or workstation by this job.

The Verify frontend deadline is 20 seconds from dispatch; the Core verifier's
12-second timer excludes setup. The additional eight seconds are an allowance,
not a proven worst-case bound under VM load. After a frontend timeout, late
success/error terminal frames are ignored without changing a newer operation;
only a successful retry of the same method clears its previous operation error.
Snapshot/list reads do not hide a failed verification.

No design-direction changes, mascot asset changes, live shell control, real VPN
lifecycle, route mutation, deployment, release or tag occurred in job B. Runtime
HY2 completion under shared VM load remains for a separately authorized live
check. Empty/unsupported subscription fetch success semantics, arbitrary backend
prose, and offset pagination without a snapshot token remain documented limits.
The independent Gemini review helper exited 1 without an answer/session; this is
coordinator source review plus automated consumer evidence, not independent signoff.
