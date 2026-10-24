# R7 — Virtual Penguin Network in the Omarchy panel

Base: `94e33f2a4a1b10b467538080000a57cbd897d77a`.
Target: `dsh/omarchy-plugin-mvp-2026-10-22` (the existing PR branch).

## Behavior and design contract

The owner's feedback was that the plugin did not look like the Windows and other
VPNRouter clients. The previous rounds optimized the host palette without
comparing the actual desktop product. This round uses the owner's desktop images,
SimplePage, HomeKit, Lists, Motion, ControlRoles and Tokens as the content reference.
The Omarchy frame, fitting, open/close lifecycle and bar glyph family remain host
owned. No changes are installed into the owner's running shell in this round.

Design read: compact product control panel; ENERGY 1 / RHYTHM 1 / MOTION 2.
The original mascot, state ring and full-width action carry product identity;
cyan is the desktop action role, green is tunnel state, red is error/destruction.
Cards group the connection and routing task; quiet chevron rows open details.
Connecting motion indicates an in-flight state and stops for reduced motion.

- Home starts with the exact brand name, mascot tile and VPN chip. No Linux
  Zapret or Telegram badges are invented.
- The 136/114/92/70 emblem, 34 shield badge, 22 state title, 48 action and 14 card
  radius follow the desktop. Existing host spacing scaling remains effective.
- Home shows the selected server and type; Change opens Servers. First run offers
  Add a subscription in that card and opens the actual form. Connect stays gated
  by capability, state and setup; no connection is exercised by these UI tests.
- A desktop pill group selects apps/full routing. It shows actual selected process
  names, respects include/exclude semantics and retains confirmed state on failure.
- Nine quiet rows replace the first-screen tab grid. A fixed back arrow/title
  opens the same section implementations, returning focus to the originating row.
- One fitted 440×764 preference is shared by home and details, with internal
  scrolling and a 400×560 constrained check. These are logical fixture dimensions,
  not proof of compositor placement.
- 47 light/dark color pairs match Tokens.axaml exactly. Linear sRGB luminance of
  the host background below 0.5 selects dark. Content selects installed Inter,
  Segoe UI, Noto Sans, Liberation Sans or DejaVu Sans; Noto Sans was observed here.
- Mascot PNGs are byte-identical. Their pinned hashes and provenance are in
  assets/README.md and tests/test-ui-brand-assets.js.

## Implementation decisions

Use the existing Panel, Service, model, locales, editors and callbacks. No new
process, polling timer, package dependency, network operation or helper is added.
Brand.qml owns product tokens; Choice.qml shares radio-group rendering and native
Qt arrow/Return/Space/Tab behavior between home, Apps and Rules. The host's
ButtonGroup could not preserve the brand: this installed theme pins its selected
color to a literal purple even when foreground/accent are overridden. Direct
renders exposed that leak; branded Choice removes it without changing routing
payloads. Server latency uses the desktop pill palette, based on measured latency
(<100/<200/<500/≥500 ms); unknown stays neutral. Color means speed, not verification.

A capture iteration exposed two fixture problems: a late theme FileView could
replace the injected theme, and snapshots cleared the synthetic error. Captures
now assert the actual selected palette, reapply the explicit synthetic error after
snapshot completion and wait for the 120 ms color transition before the final
frame. Error without detail also gets the existing generic error, not the idle
traffic hint. These are recorded separately from live backend evidence.

## Acceptance and evidence

The full R7 report, exact commands/exit codes, token table, original asset hashes,
60 final3 renders, four desktop comparisons, motion frames and annotations are in
`r7-plugin.md` under the task's requested external scratchpad/codex directory.

- 11 Node suites, 38 Python packaging cases, host validator, shell syntax,
  qmllint and diff formatting passed (qmllint still has existing warnings).
- 12 actual Qt suites × EN/RU × 440×764 light / 400×560 dark passed: forms,
  callbacks, routing, actions, keyboard, list navigation, focus, theme and states.
- After the final error-hint and shield-glyph changes, the affected state/routing/geometry suites
  passed again. Unchanged form results are retained with their source identity.
- Connecting rotation advances in a single offscreen process and stops under
  reduced motion; three actual frames are saved separately.
- 40 scoped text/background contrast pairs pass 4.5:1 with alpha composition.
- Catalog fill is 267/267 in each language; changed units are 33 EN / 32 RU.
  This is not a human-language quality percentage or independent UX signoff.

Live loading, compositor focus, VPN connection/routing, screen reader, RTL and
large text scaling remain unverified. Owner acceptance of the visual match is
still a user judgment; this is a direct source/render comparison, not a user study.

## R7b follow-up — application summary and glyph semantics

Base: `73f04b08da217aa1e18c27d8f43ecbdc8006133c`. The lead review found that the
summary exposed process keys and used plural verbs for a single app. It now uses
known display names, preserves unknown names and exact routing keys, names at
most two apps and summarizes the rest. Single, pair and aggregate messages are
whole EN/RU catalog entries. The aggregate subject stays plural even when the
remaining count has CLDR category `one` (for example, 21 more apps). The integer
EN/RU CLDR rules are compared to ICU's Intl.PluralRules for 0–10000; fractional
and unknown counts are outside this array-count contract. Empty selection uses
a short desktop-style action hint.

All nine navigation glyphs were checked against Nerd Fonts glyph names. Apps
uses the same grid as the segment, subscriptions a link, rules a filter,
settings a cog, diagnostics a stethoscope, free servers a globe, profiles sliders
and custom configuration JSON. Related refresh/test/export/empty-state glyphs
were corrected as well. The comparison server is now `Frankfurt 1`; fixture
provenance stays in test source and image metadata.

The existing native fixture adds a summary suite for both languages, include
and exclude modes, 0/1/2/many counts, locale changes, exact routing-key retention
and stable panel geometry. It waits for the host adapter's initial palette load
before injecting the fixture palette, avoiding a demonstrated startup race.
README.md and README.ru.md remain accurate: setup, routing semantics and commands
did not change. R7b screenshots and exact verification/delivery evidence are
appended to the external `r7-plugin.md` report. No installation or live-shell
operation is part of this follow-up.
