# R5 application suggestions — 2026-10-23

Base: `553e35005f805f41ff72172dffdd164044cd215a`.

The Apps tab defaults to running applications with a desktop entry or a matching
open Hyprland window. It uses the installed host's shared
`Hyprland.toplevels.values`, `lastIpcObject.class` / `initialClass` and
`wayland.appId`, with exact case-insensitive class comparison. Optional peer
`pid` / `pids` can match `lastIpcObject.pid`; the current backend contract supplies
no process IDs. Local window evidence overrides backend window hints. Routing
names retain their original case. No polling, process enumeration or dependency
was added.

Other validated suggestions live in a counted, initially collapsed section.
Search covers both sections and opens matching processes; clearing search
collapses them. The disclosure remains operable with pointer, Return and Space.
Manual process entry, selected apps and old-backend fallback remain available.
A shared row delegate avoids duplicating the two lists. Bound component context,
explicit delegate properties and qualified accesses remove 19 unqualified-access
warnings; one unused fixture import was removed. Host dynamic Style token
warnings remain visible and were not suppressed.

Verification uses actual Panel/Service/locales in the existing qml-render harness,
with inert backend responses, processDisabled=true and synthetic Hyprland window
records. The realistic fixture contains ChatGPT/chatgpt, Chromium/chromium,
Discord/com.discordapp.Discord, Dropbox/dropbox, Neovim/nvim and
Thunderbird/org.mozilla.Thunderbird, plus bash, cat, at-spi-bus-launcher, codex and
bwrap without desktop metadata. Actual Qt input covers disclosure pointer/keys,
hidden-process search/add/remove, manual exact-case entry, no matches, window
open/close, Wayland fallback and Escape; frame/navigation remain stable at
540x640 and 430x560 in EN/RU.

Nine Node suites, 38 isolated Python packaging tests, manifest validation, shell
syntax and diff checks pass. On the same 24 QML files qmllint exits 0:
488 -> 469 warnings (production 425 -> 406; AppsView 38 -> 19). The additional R5
fixture adds no warnings. Categories: missing-property 254 unchanged;
unqualified 234 -> 215. Unused-import information: 1 -> 0.
The old Model snapshot fails the new window-matching check; the current one passes.

Applied skills: omarchy-plugin; omarchy-plugin-patterns (plugin-authoring,
design-review, visual-review, localization-review); omarchy-visual-verification;
anti-slop; ponytail; change-verification; repository-readme. Translation uses the
bundled local fallback, whole-message EN/RU count labels and the existing formatter.
The native utilitarian composition and mascot are preserved (ENERGY 1, RHYTHM 1,
MOTION 1). Design review is direct self-review, not independent or human-language
signoff. Current installed source was compared with the official development guide
and Quickshell type documentation; installed contracts determine implementation.

Private evidence: r5-plugin.md, r5-checks.json, r5-lint-counts.json,
r5-red-green.json, r5-evidence.json, r5-render-manifest.json,
r5-design-review.html and r5-final3-*.png under the owner-specified scratchpad.

No installation, activation, live capture, shell IPC command, shell restart or
running-shell interaction occurred. Live loading and compositor behavior remain
unverified by explicit scope. Backend network/routing operations were not tested.
Git delivery targets the existing PR branch itself, as explicitly requested.
