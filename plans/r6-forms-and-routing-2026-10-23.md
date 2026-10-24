# R6: routing choices and offline form acceptance

Base: `c7d03b26bff5f33d08f5fb47a4000870a9063937` on
`dsh/omarchy-plugin-mvp-2026-10-22`. Delivery targets that same PR branch.

## Behavior

- Reuse installed `Ui.ButtonGroup` for explicit routing and app-policy choices
  in both panel modes. The app-policy group is visible only in split mode.
- Put routing before the application lists. Preserve exact process names;
  Thunderbird's fixture process is `thunderbird`, with its desktop ID/icon kept
  as `org.mozilla.Thunderbird`.
- Separate fixed navigation from scrolling pages with `Ui.PanelSeparator`.
  Reserve the hero height so pending/error messages do not move navigation.
- Forms validate required input, keep drafts after rejected writes, prevent
  duplicate submissions, and clear only after success or Cancel. A repeated
  validation error must be revealed inside the actual page viewport.
- Reuse one scrolling editor for rules, server/configuration import and CIDRs.
  Enter inserts a line, Ctrl+Enter submits, Tab/Shift+Tab traverse controls.
- Keep Toggle.checked bound to the owning model. Settings Revert restores the
  last service readback, including after saving; MTU typing is not clamped on
  each keystroke. Preserve every nonempty CIDR for authoritative service
  validation, including IPv6.
- Rules export follows the existing `{text}` protocol: show selectable output
  separately, preserve the draft, and state that no file was written.
  Diagnostics export displays the complete selectable path and clears stale
  output before retrying.
- Keep enabled text in the theme foreground. Selection/status icons and fills
  retain their roles; the light fixture's accent was insufficient for small
  selected-server text.

## Verification

`tests/test-ui-forms.js` executes the production QML handlers with inert callbacks.
Existing Node suites and Python packaging tests remain required. Run packaging
checks in an isolated network namespace with the installed backend directory
masked, as in the preceding rounds.

`tests/qml-r6-consumer.qml` loads actual Panel/Service/locales. It has
`processDisabled=true`, mock JSON-line responses, and synthetic window metadata.
The renderer uses the existing layer-shell-to-Item adapter, installed host
components, software/offscreen rendering and DPR 2. It never launches Quickshell.

The ten native suites cover subscriptions, server import, custom import, rules,
settings, routing/language/mode, list actions/diagnostics, keyboard/inner scrolling,
real tab activation/geometry, and pointer form/choice actions. Exercise EN/RU at
540x640 and 430x560. The R5 native fixture additionally covers app search,
disclosure, add/remove, manual exact-case names and window updates at both sizes.

All service operations, including network-related action buttons, are mocked.
No real VPN, subscription retrieval, ping, server verification, profile fetch or
filesystem export is exercised. The owner's installed plugin and running shell
are outside this round's test surface. These are offscreen consumer results,
not live-shell or network acceptance. Human translation/independent design
signoff, screen readers, RTL and other themes/scales remain unverified.
