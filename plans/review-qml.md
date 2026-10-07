# Independent Code Review: Omarchy VPNRouter QML & Headless Adapter

**Target**: `PavelLizunov/omarchy-vpnrouter` and `VPNRouter.Headless` (`dsh/omarchy-plugin-2026-09-17`)  
**Review Mode**: Independent, Read-Only, Differential Security & Change Verification  
**Reviewed Base**: `517bf7e2` | **Head**: `b8bde92c` + task-owned untracked workspace files  
**Reference Contracts**: `plans/omarchy-protocol-v1.md`, `docs/agent-contract.md`, `/tmp/vpnrouter-omarchy-host-20260917/`

---

## Executive Summary

The implementation provides an architecture separating the headless C# protocol service (`VPNRouter.Headless`) from the Omarchy Quattro QML frontend (`omarchy-vpnrouter`). The C# backend implements protocol v1 with bounded memory allocation, CAS storage, and ownership checking.

However, the QML client layer and test fixtures contain **8 critical and high-priority defects**:
1. Singleton host injection in `BarWidget.qml` looks for `bar.shell` instead of declaring `property var shell: null`, causing `hostService` to always evaluate to `null` on real Omarchy hosts.
2. The client request queue pre-serializes JSON payloads at enqueue time, baking in stale revisions that cause cascading `conflict` errors on subsequent mutations.
3. Urgent requests (`disconnect`, `cancel`) prematurely clear `inFlight` queue state in `handleResponse()`, causing concurrency collisions and unexpected `busy` errors.
4. `Protocol.js` accumulator allows up to 512 KiB before discarding and measures UTF-16 characters instead of UTF-8 bytes, violating the 256 KiB specification limit.
5. A protocol shape mismatch on `dnsMode` causes settings saves to fail with `invalid_argument`.
6. Sibling stacking order in `ServersView.qml` places a full-row `MouseArea` on top of action buttons, redirecting all Test, Verify, and Delete clicks into server selection.
7. Keyboard navigation and focus trapping fail inside the panel, while test suites substituted a fake stub for `Ui.KeyboardPanel` to mask offscreen failures.
8. User-visible strings in `ServersView.qml` and `DiagnosticsView.qml` bypass locale catalogs, violating i18n project invariants.

---

## Prioritized Findings

### Finding 1 [CRITICAL] — Broken Singleton Host Injection on Real Omarchy Hosts Masked by Test Mocks

- **Source Anchor**: `/var/lib/dsh/Project/omarchy-vpnrouter/BarWidget.qml:13-22,70-76`
- **Counterevidence**: `/tmp/vpnrouter-omarchy-host-20260917/PluginShellApi.qml:1-35` and `shell-README.md:105-115`
- **Description**:
  In Omarchy Quattro, host shell dependencies are injected directly into declared properties on plugin entry points (`omarchyPath`, `shell`, `manifest`, `pluginRegistry`). The shell object (`PluginShellApi.qml`) exposes `serviceFor(id)` and `updateEntryInline(id, settings)`. The host's `bar` object does *not* possess a `.shell` property.
  In `BarWidget.qml`, the component fails to declare `property var shell: null` and instead queries:
  ```qml
  readonly property var hostService: {
    if (bar && bar.shell && typeof bar.shell.serviceFor === "function") {
      var s = bar.shell.serviceFor(moduleName)
      if (s) return s
      if (bar.pluginId) {
        s = bar.shell.serviceFor(bar.pluginId)
        if (s) return s
      }
    }
    return null
  }
  ```
  In production, `bar.shell` is `undefined`. Consequently, `hostService` always returns `null`, and `updateSetting()` fails silently. `effectiveService` remains `null`, leaving the widget dead and disconnected from `Service.qml`.
- **Test Cover-up / Fake Test Transformation**:
  In `tests/qml-mock-host.qml:91`, `tests/qml-harness.qml:57`, and `tests/qml-load-test.qml:89`, test authors explicitly invented `property var shell: mockShell` on `mockBar`. Furthermore, `test_6_bar_widget_lifecycle` explicitly passed `service: serviceItem` directly to `BarWidget`, never testing real host injection.
- **Impact**: The plugin cannot connect to its singleton service when installed on a live Omarchy Quattro shell.
- **Fix**:
  Declare `property var shell: null` in `BarWidget.qml`. Resolve service via `shell ? shell.serviceFor(moduleName) : null`, and persist settings via `shell.updateEntryInline(moduleName, entry)`.

---

### Finding 2 [CRITICAL] — Pre-serialized Request Queue Causes Stale Revisions and Cascading Conflict Errors

- **Source Anchor**: `/var/lib/dsh/Project/omarchy-vpnrouter/Service.qml:370-388,405-442` & `/var/lib/dsh/Project/omarchy-vpnrouter/lib/Protocol.js:154-210`
- **Counterevidence**: `plans/omarchy-protocol-v1.md:28-36` & `VPNRouter.Headless/Storage/ConfigStorage.cs:72-83`
- **Description**:
  `Service.sendRequest` formats and serializes the JSON request text (`Protocol.formatRequest`) immediately when called, baking in `root.revision` at the moment of queuing:
  ```qml
  var reqResult = Protocol.formatRequest(method, params) // params contains root.revision
  ...
  var item = { id: reqResult.id, method: method, text: reqResult.text, ... }
  _requestQueue.enqueue(item)
  ```
  When multiple mutations are queued (e.g. quick server switch, toggling app route lists, updating rules), the first mutation succeeds on the backend, advancing the disk configuration revision and emitting a new revision. When `pumpQueue()` subsequently sends the next item, it transmits the pre-serialized `item.text` containing the *old* revision. The backend's atomic CAS validator (`_storage.ValidateRevision`) rejects it with `RouterException("conflict", ...)`. This causes `handleResponse` to trigger `root.refreshSnapshot()`, while subsequent queued mutations fail with conflict errors.
- **Impact**: Rapid UI actions or sequential configuration changes cascade into revision conflict errors.
- **Fix**:
  Do not pre-serialize `item.text` at enqueue time. Store a mutation factory or dynamically inject `root.revision` into parameters at dequeue time immediately before writing to stdin.

---

### Finding 3 [HIGH] — Urgent Requests (Disconnect/Cancel) Desynchronize Request Queue and Cause In-Flight Collisions

- **Source Anchor**: `/var/lib/dsh/Project/omarchy-vpnrouter/Service.qml:303-335,413-424`
- **Counterevidence**: `VPNRouter.Headless/Protocol/ProtocolDispatcher.cs:40-62`
- **Description**:
  Urgent control commands (`disconnect` and `cancel`) bypass `_requestQueue` and write directly to `backendProc`. However, in `handleResponse(reqId, ...)`:
  ```qml
  // Release in-flight flag if this matches
  if (root.activeRequestId === reqId) {
    root.activeRequestId = ""
    root.activeOperation = ""
    root.activeProgress = null
  }

  _requestQueue.clearActive()
  ...
  pumpQueue()
  ```
  `_requestQueue.clearActive()` is executed unconditionally for *any* response received. When a disconnect response returns while an ordinary queued request is still running on the backend, `_requestQueue.clearActive()` clears the queue's `inFlight` record and `pumpQueue()` immediately sends the *next* queued request. The backend, which is still executing the ordinary operation, rejects the new request with `error: { code: "busy" }`.
- **Impact**: Disconnecting or cancelling during an active operation corrupts client queue synchronization and triggers unhandled `busy` errors.
- **Fix**:
  Only clear `_requestQueue.clearActive()` and pump the queue if `reqId` matches `_requestQueue.getActive()?.id`.

---

### Finding 4 [HIGH] — Frame Accumulator Violates 256 KiB Spec Ceiling (Allows 512 KiB & UTF-16 Count)

- **Source Anchor**: `/var/lib/dsh/Project/omarchy-vpnrouter/lib/Protocol.js:116-150`
- **Counterevidence**: `plans/omarchy-protocol-v1.md:25-30` & `VPNRouter.Headless/Protocol/ProtocolConstants.cs:6-8`
- **Description**:
  `plans/omarchy-protocol-v1.md` specifies: *"Input maximum 256 KiB BEFORE accumulation; max JSON depth 32. Output maximum 256 KiB"*.
  In `Protocol.js`, `createChunkAccumulator` permits the buffer to grow to twice the limit:
  ```javascript
  if (buffer.length + chunk.length > MAX_FRAME_BYTES * 2) {
    buffer = "";
    if (onError) onError({ code: "buffer_overflow", message: "Input buffer exceeded 256 KiB before delimiter" });
    return;
  }
  ```
  `MAX_FRAME_BYTES * 2` allows 524,288 characters before discarding. Furthermore, `buffer.length` checks UTF-16 code units rather than UTF-8 bytes. Multi-byte UTF-8 payloads (such as Cyrillic rules, server names, or error messages) can consume >400 KiB UTF-8 while remaining under 256,000 UTF-16 code units.
- **Test Cover-up / Fake Test Transformation**:
  In `tests/test-ui-protocol.js:132`, the unit test asserts that overflow is triggered by feeding `Protocol.MAX_FRAME_BYTES * 2 + 10`, codifying the 512 KiB divergence rather than enforcing the 256 KiB specification.
- **Impact**: Client buffers up to 512 KiB of unparsed input without dropping, violating protocol bounds and risking client memory bloat on ill-behaved or high-chatter streams.
- **Fix**:
  Enforce `buffer.length + chunk.length > MAX_FRAME_BYTES` (256 KiB) strictly. Discard excess bytes immediately upon exceeding 262,144 bytes.

---

### Finding 5 [HIGH] — Protocol Mismatch on `dnsMode` Rejects Settings Save

- **Source Anchor**: `/var/lib/dsh/Project/omarchy-vpnrouter/ui/SettingsView.qml:170-195,245-265` & `/var/lib/dsh/Project/omarchy-vpnrouter/Service.qml:67`
- **Counterevidence**: `VPNRouter.Headless/Features/SettingsFeature.cs:40-60,150-160`
- **Description**:
  In `SettingsView.qml`, the DNS mode repeater offers `["system", "doh", "direct"]`, defaulting `root.dnsModeVal` to `"system"`. When saving settings, `setSettings` sends `dnsMode: root.dnsModeVal`.
  However, `SettingsFeature.cs:155` enforces:
  ```csharp
  if (mode != "vpn_only" && mode != "smart" && mode != "direct")
      throw new RouterException("invalid_argument", "dnsMode must be 'vpn_only', 'smart', or 'direct'");
  ```
  Because `"system"` and `"doh"` are rejected by the backend, clicking "Save Settings" with default settings fails immediately with `invalid_argument`. Moreover, `SettingsFeature.cs` validates `dnsMode` but never assigns it to `settings.App`, and `SettingsFeature.Get` hardcodes `dnsMode = "vpn_only"`.
- **Impact**: The settings form cannot be saved in its default configuration; DNS mode selection is non-functional.
- **Fix**:
  Align the allowed enum between backend and frontend (`vpn_only`, `smart`, `direct`), update the UI buttons and translations accordingly, and store the property in `AppSettings`.

---

### Finding 6 [HIGH] — Z-Order Click Interception in `ServersView.qml` Blocks Test, Verify, and Delete Buttons

- **Source Anchor**: `/var/lib/dsh/Project/omarchy-vpnrouter/ui/ServersView.qml:245-318`
- **Counterevidence**: Qt Quick Scene Graph Visual and Event Stacking Specification
- **Description**:
  In `ServersView.qml`, each server entry is rendered in a `Rectangle`. The row content (containing server labels and `IconButton` controls for Ping Test, Deep Verify, and Delete) is declared as child 1 (`Row { id: rowContent }`). Child 2 is `MouseArea { id: rowMouse; anchors.fill: parent }`.
  In Qt Quick, sibling items with identical z-values receive pointer events in declaration order: later siblings sit on top of earlier siblings. Because `rowMouse` is declared after `rowContent` and covers the entire parent (`anchors.fill: parent`), it intercepts all mouse clicks across the entire row.
  Clicking directly on the Delete (`󰆴`), Test (`󰓠`), or Verify (`󰄬`) icon buttons triggers `rowMouse.onClicked: selectServer(modelData.id)`. The button actions are completely unreachable.
- **Impact**: Users cannot test latency, perform deep verification, or remove servers via mouse interaction.
- **Fix**:
  Move `rowMouse` above `rowContent` in document order, or bound `rowMouse.width: parent.width - rowActions.width - Style.space(12)` so that `rowActions` remains uncovered.

---

### Finding 7 [HIGH] — Keyboard Navigation Failure Inside Panel Masked by Test Stub

- **Source Anchor**: `/var/lib/dsh/Project/omarchy-vpnrouter/ui/TextField.qml:20-55`, `/var/lib/dsh/Project/omarchy-vpnrouter/ui/Navigation.qml:45-95`, `/var/lib/dsh/Project/omarchy-vpnrouter/Panel.qml:90-105`
- **Counterevidence**: `shell-README.md:12-25` & `/tmp/vpnrouter-omarchy-host-20260917/Style.qml:30-45`
- **Description**:
  The Omarchy shell contract requires full keyboard accessibility. Several defects prevent keyboard operation:
  1. In `Panel.qml`, `Ui.KeyboardPanel` sets `focusTarget: keyCatcher`. `PanelKeyCatcher` captures Tab (`onTabRequested: switchPanel(direction)`), consuming Tab to switch panels rather than moving between controls inside the panel.
  2. In `TextField.qml`, the outer `Item` has `activeFocusOnTab: true`, while the inner `TextInput` has `activeFocusOnTab: false`. When focused via Tab, the outer Item receives focus, but `TextInput` does not. Keystrokes are discarded until the user clicks with the mouse.
  3. In `Navigation.qml`, tab items lack `activeFocusOnTab` and arrow-key handlers. Tabs cannot be switched using keyboard controls.
- **Test Cover-up / Fake Test Transformation**:
  In `tests/qml-test-runner.sh:47-75`, the test harness script dynamically writes a dummy `Item` stub for `qs/Ui/KeyboardPanel.qml`, replacing the real Omarchy `KeyboardPanel` and bypassing window management, key events, and focus traversal.
- **Impact**: The plugin cannot be operated via keyboard in desktop environments, violating Omarchy's UI contract.
- **Fix**:
  Implement focus proxying in `TextField.qml` (`onActiveFocusChanged: if (activeFocus) textInput.forceActiveFocus()`), support arrow-key navigation in `Navigation.qml`, and handle internal Tab traversal within `Panel.qml`.

---

### Finding 8 [MEDIUM] — Hardcoded User-Visible String and Unlocalized Diagnostics Status

- **Source Anchor**: `/var/lib/dsh/Project/omarchy-vpnrouter/ui/ServersView.qml:37` & `/var/lib/dsh/Project/omarchy-vpnrouter/ui/DiagnosticsView.qml:140-160`
- **Counterevidence**: Project Invariant: *"All user-visible strings go through Strings.cs (Ru/En). No hardcoded Russian/English in ViewModels / XAML / toasts. Approved adaptation: QML uses en/ru locale catalogs"*
- **Description**:
  1. In `ServersView.qml:37`, the search input field hardcodes `placeholderText: "Search servers…"`. The Russian catalog (`locales/ru.json`) is not used.
  2. In `DiagnosticsView.qml:144-158`, the check result badge displays `text: statusPill.st` where `st` is the raw backend string (`"OK"`, `"WARN"`, `"ERROR"`), bypassing the locale keys `diagnostics.statusPass`, `diagnostics.statusFail`, and `diagnostics.statusWarn`.
- **Impact**: Violates i18n invariants; English strings are displayed even when Russian locale is selected.
- **Fix**:
  Add `"servers.searchPlaceholder"` to `locales/en.json` and `locales/ru.json`, bind `placeholderText: root.tr("servers.searchPlaceholder")`, and map diagnostic status text through `root.tr("diagnostics.status" + ...)`.

---

## Coverage and Untested Boundaries

In compliance with `security-review` and `change-verification` standards:
- **Examined Scope**:
  - `VPNRouter.Headless/` (Protocol line reader, parser, server, dispatcher, output queue, router backend, storage, features, and lifecycle engine).
  - `VPNRouter.Core/VPNRouter.Core.csproj` (`InternalsVisibleTo` friend change).
  - `/var/lib/dsh/Project/omarchy-vpnrouter/` (`BarWidget.qml`, `Panel.qml`, `Service.qml`, all 17 components in `ui/`, `lib/Protocol.js`, `lib/Model.js`, `lib/I18n.js`, `locales/en.json`, `locales/ru.json`, `setup`, `bin/vpnrouter-headless`, and `tests/`).
  - `/tmp/vpnrouter-omarchy-host-20260917/` (`PluginShellApi.qml`, `Panel.qml`, `Color.qml`, `Style.qml`, `shell-README.md`).
- **Untested Boundaries**:
  - **No Live GUI/Process Launch**: Per task instructions, no Quickshell instances, X11/Wayland display sessions, or live background daemons were started.
  - **Live Privileges & Kernel Datapath**: The real Linux `nft` firewall execution and TUN device provisioning require root/Polkit elevation and were not executed against live host interfaces.
  - **Wayland / Hyprland Rendering**: Actual multi-monitor bar layout, popout positioning, and window scaling were not verified on a live compositor.
