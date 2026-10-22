# R4 UI checkpoint — 2026-10-22

Production commit: `5bb5e207ca25cc528611214ece1a620ec55aedc2`; base: `207236441ce1de8ad0b215eb6193b4c88c9bc630`.

The plugin consumes optional runningApps, server source/removal metadata and
unavailable reason codes, with graceful old-peer behavior. First-run actions open
the real subscription form. The advanced panel and hero reserve stable bounds;
content scrolls inside. Diagnostics distinguish Info and preserve unrelated
warnings/errors. English/Russian catalogs and Linux availability labels match.

Eight Node suites, 38 isolated Python packaging tests, manifest validation and all
24 QML files passed their commands (qmllint retains 484 warnings). The actual
Panel/Service/locales were rendered offscreen in 34 EN/RU tab/state captures;
actual Qt input covered the first-run route, Apps add/remove/search, field Tab,
empty Enter and Escape. A deliberately blocked Tab fails the test. A control with
the previous PanelKeyCatcher also passes, so no original Tab defect is claimed.

A single live pass lasted about 4 seconds, then closed the panel. Installed source
hashes match, but the running shell retained older hero/Button components. Full
loading of R4 is therefore unverified; no shell restart or second pass occurred.
No VPN, server test/verify, refresh or production mutations were exercised.

Evidence is in the owner-requested private scratchpad: `r4-plugin.md`,
`r4-evidence.json`, `r4-checks.json`, `r4-design-review.html` and `r4-*.png`.
The annotated review uses original images with selectable overlay regions.
Do not treat the inert fixture or installed file hashes as full live acceptance.
