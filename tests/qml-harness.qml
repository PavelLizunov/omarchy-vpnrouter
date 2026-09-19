import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Commons 1.0
import qs.Ui 1.0 as Ui
import "." as VpnPlugin
import "ui" as VpnUi
import "lib/Protocol.js" as Protocol
import "lib/Model.js" as Model
import "lib/I18n.js" as I18n

ShellRoot {
  id: harnessRoot

  property bool testsFinished: false
  property var sentRequests: []
  property var fakeBackend: function(rawText) {
    var line = String(rawText || "").trim()
    if (!line) return
    var req = null
    try { req = JSON.parse(line) } catch (e) { return }
    sentRequests.push(req)
    Qt.callLater(function() {
      if (!serviceItem) return
      if (req.method === "snapshot") {
        serviceItem.feedFrame({
          v: 1,
          type: "response",
          id: req.id,
          isError: false,
          result: {
            state: "disconnected",
            revision: "rev-load-test-01",
            backendVersion: "2.48.0",
            activeServer: "Frankfurt-01",
            routingMode: "split",
            routingAppsMode: "include",
            configMode: "generated",
            busy: false,
            capabilities: {
              connect: true,
              killSwitch: true,
              dnsLockdown: true
            }
          }
        })
      } else if (req.method === "connect") {
        serviceItem.feedFrame({
          v: 1,
          type: "response",
          id: req.id,
          isError: false,
          result: {
            state: "connected",
            revision: "rev-load-test-02",
            activeServer: "Frankfurt-01",
            capabilities: {
              connect: true,
              killSwitch: true,
              dnsLockdown: true
            }
          }
        })
      }
    })
  }

  QtObject {
    id: mockBar
    property string position: "top"
    property int barSize: 28
    property color foreground: Color.foreground
    property color barForeground: Color.foreground
    property color background: Color.background
    property color urgent: Color.urgent
    property string fontFamily: Style.font.family
    property bool vertical: false
    property bool foregroundAnimationEnabled: false
    function requestPopout(owner) {}
    function releasePopout(owner) {}
    function switchPanelFrom(owner, dir) { return false }
    function hideTooltip(target) {}
    function showTooltip(target, text) {}
  }

  QtObject {
    id: mockShell
    property var _service: serviceItem
    function serviceFor(id) { return _service }
    function updateEntryInline(id, settings) { return true }
  }

  Item {
    id: dummyAnchor
    width: 28
    height: 28
  }

  Service {
    id: serviceItem
    processDisabled: true
    fakeBackend: harnessRoot.fakeBackend
  }

  TestCase {
    id: testCase
    name: "OmarchyVpnRouterQuickShellLoadTest"
    when: true

    property bool started: false

    function test_1_service_defaults_and_handshake_safety() {
      compare(serviceItem.processDisabled, true, "Process spawning must be disabled in isolated harness")
      compare(serviceItem.capabilities.connect, false, "capabilities.connect must be false before handshake")
      compare(serviceItem.state, "unavailable", "Initial state must be unavailable")
      compare(serviceItem.isConnected, false, "isConnected must be false")

      var connectReturned = serviceItem.connect()
      compare(connectReturned, null, "connect() before handshake must fail closed and return null")
      compare(serviceItem.lastError, "Connect capability unavailable before handshake")
    }

    function test_2_fake_backend_handshake_and_capabilities() {
      harnessRoot.sentRequests = []
      serviceItem.refreshSnapshot()

      tryVerify(function() {
        return serviceItem.capabilities && serviceItem.capabilities.connect === true
      }, 2000, "Service failed to apply handshake snapshot with connect capability")

      compare(serviceItem.capabilities.connect, true, "connect capability must be enabled after handshake")
      compare(serviceItem.capabilities.killSwitch, true, "killSwitch capability must be enabled")
      compare(serviceItem.state, "disconnected", "State should transition to disconnected")

      var reqId = serviceItem.connect()
      verify(reqId !== null && reqId.length > 0, "connect() must return a valid request ID after handshake")

      tryVerify(function() {
        return serviceItem.isConnected === true
      }, 2000, "Service failed to transition to isConnected after mock connect response")
    }

    function test_3_i18n_reactivity() {
      var initialRev = serviceItem.i18nRevision
      var listenerTriggered = false
      var listenerRev = -1

      var testListener = function(rev) {
        listenerTriggered = true
        listenerRev = rev
      }
      I18n.addListener(testListener)

      serviceItem.setLocale("ru")
      verify(listenerTriggered, "I18n listener must be called on setLocale")
      verify(serviceItem.i18nRevision > initialRev, "Service i18nRevision must increment")
      compare(serviceItem.effectiveLocale, "ru", "effectiveLocale must update to ru")

      serviceItem.setLocale("en")
      compare(serviceItem.effectiveLocale, "en", "effectiveLocale must update to en")

      I18n.removeListener(testListener)
    }

    Component {
      id: headerComponent
      VpnUi.Header {
        service: serviceItem
        mode: "simple"
      }
    }

    function test_4_header_signals_and_properties() {
      var header = headerComponent.createObject(harnessRoot)
      verify(header !== null, "Header component must instantiate cleanly")

      var requestedMode = ""
      header.modeChangeRequested.connect(function(next) {
        requestedMode = next
      })

      header.modeChangeRequested("advanced")
      compare(requestedMode, "advanced", "Header must emit modeChangeRequested signal with next mode")

      header.destroy()
    }

    Component {
      id: panelComponent
      Panel {
        bar: mockBar
        anchorItem: dummyAnchor
        service: serviceItem
      }
    }

    function test_5_panel_keyboard_and_keycatcher() {
      var panel = panelComponent.createObject(harnessRoot)
      verify(panel !== null, "Panel component must instantiate cleanly")

      panel.open()
      verify(panel.opened, "Panel opened state must be true")

      panel.close()
      verify(!panel.opened, "Panel opened state must be false after close()")

      panel.destroy()
    }

    Component {
      id: barWidgetInjectedComp
      BarWidget {
        bar: mockBar
        service: serviceItem
      }
    }

    Component {
      id: barWidgetAbsentComp
      BarWidget {
        bar: mockBar
        service: null
      }
    }

    Component {
      id: barWidgetShellComp
      BarWidget {
        bar: mockBar
        shell: mockShell
      }
    }

    function test_6_bar_widget_lifecycle_and_absence() {
      // 1. Injected service: widget must use it
      var widget = barWidgetInjectedComp.createObject(harnessRoot)
      verify(widget !== null, "BarWidget component must instantiate cleanly")
      compare(widget.effectiveService, serviceItem, "BarWidget must use injected service")
      widget.destroy()

      // 2. Absence of host/injected service: must report unavailable, NOT load fallback service
      var widgetAbsent = barWidgetAbsentComp.createObject(harnessRoot)
      verify(widgetAbsent !== null, "BarWidget without service must instantiate cleanly")
      compare(widgetAbsent.effectiveService, null, "Absence of service must leave effectiveService null")
      compare(widgetAbsent.vpnState, "unavailable", "Absence of service must report state unavailable")
      widgetAbsent.destroy()

      // 3. Documented shell injection: BarWidget receives shell property and resolves hostService
      var widgetShell = barWidgetShellComp.createObject(harnessRoot)
      verify(widgetShell !== null, "BarWidget with shell must instantiate cleanly")
      compare(widgetShell.shell, mockShell, "BarWidget must have shell property set")
      compare(widgetShell.hostService, serviceItem, "BarWidget must resolve hostService from shell.serviceFor")
      compare(widgetShell.effectiveService, serviceItem, "BarWidget effectiveService must resolve from shell")
      widgetShell.destroy()
    }

    Component { id: serversComp; VpnUi.ServersView { service: serviceItem; width: 500 } }
    Component { id: subsComp; VpnUi.SubscriptionsView { service: serviceItem; width: 500 } }
    Component { id: freeComp; VpnUi.FreePoolView { service: serviceItem; width: 500 } }
    Component { id: appsComp; VpnUi.AppsView { service: serviceItem; width: 500 } }
    Component { id: profilesComp; VpnUi.ProfilesView { service: serviceItem; width: 500 } }
    Component { id: rulesComp; VpnUi.RulesView { service: serviceItem; width: 500 } }
    Component { id: customComp; VpnUi.CustomConfigView { service: serviceItem; width: 500 } }
    Component { id: settingsComp; VpnUi.SettingsView { service: serviceItem; width: 500 } }
    Component { id: diagComp; VpnUi.DiagnosticsView { service: serviceItem; width: 500 } }

    function test_7_all_subviews_instantiation() {
      var views = [
        serversComp.createObject(harnessRoot),
        subsComp.createObject(harnessRoot),
        freeComp.createObject(harnessRoot),
        appsComp.createObject(harnessRoot),
        profilesComp.createObject(harnessRoot),
        rulesComp.createObject(harnessRoot),
        customComp.createObject(harnessRoot),
        settingsComp.createObject(harnessRoot),
        diagComp.createObject(harnessRoot)
      ]

      for (var i = 0; i < views.length; i++) {
        verify(views[i] !== null, "Subview at index " + i + " must instantiate without errors")
        views[i].destroy()
      }
    }

    function test_8_settings_view_contract() {
      var view = settingsComp.createObject(harnessRoot)
      verify(view !== null, "SettingsView must instantiate cleanly")

      // In default harness, configMode is generated and dnsLockdown is true
      compare(view.isCustomMode, false, "Default configMode generated should not be customMode")
      compare(view.hasDnsLockdownCap, true, "Harness snapshot has dnsLockdown=true")

      var payloadNormal = view.buildSettingsPayload()
      verify(payloadNormal !== null, "buildSettingsPayload must return object")
      compare(payloadNormal.mtu, 1420, "Default MTU must be 1420")
      verify(payloadNormal.dnsMode !== undefined, "Normal payload must include dnsMode")
      compare(payloadNormal.dnsMode, "vpn_only", "Default dnsMode in normal mode should be vpn_only")

      // Switch to custom mode
      serviceItem.configMode = "custom"
      compare(view.isCustomMode, true, "SettingsView must reflect custom mode")

      var payloadCustom = view.buildSettingsPayload()
      verify(payloadCustom !== null, "Custom payload must return object")
      compare(payloadCustom.mtu, 1420, "MTU should be present in custom payload")
      verify(payloadCustom.dnsMode === undefined, "Custom payload MUST omit dnsMode")
      verify(!("dnsMode" in payloadCustom), "dnsMode key must not exist in custom payload")

      // Restore generated configMode
      serviceItem.configMode = "generated"
      compare(view.isCustomMode, false, "Restored generated mode")

      view.destroy()
    }

    function test_9_dns_draft_binding() {
      var savedData = serviceItem.settingsData
      var savedMode = serviceItem.configMode
      var savedRouting = serviceItem.routingMode
      var view = null
      try {
        serviceItem.configMode = "generated"
        serviceItem.routingMode = "split"
        serviceItem.settingsData = { mtu: 1420, ipv6Enabled: false, strictRoute: false,
          strictDns: true, dnsMode: "direct", dnsModeOverride: "direct",
          dnsModeSemantics: "StrictDns active: all DNS forced through VPN tunnel (vpn-dns) regardless of mode",
          bypassRussianTraffic: false, blockAds: false, dnsLeakLockdown: false, routeExcludeAddress: [] }
        view = settingsComp.createObject(harnessRoot)
        verify(view !== null)
        compare(view.dnsExplanationText, view.tr("settings.dnsMode.forcedStrictDns"))
        view.strictDnsVal = false
        tryCompare(view, "dnsExplanationText", view.tr("settings.dnsMode.directDesc"))
        view.dnsModeVal = null
        tryCompare(view, "dnsExplanationText", view.tr("settings.dnsMode.profileDefaultDesc"))
        serviceItem.configMode = "custom"
        view.strictDnsVal = true
        tryCompare(view, "dnsExplanationText", view.tr("settings.dnsMode.forcedCustomStrictDns"))
        view.strictDnsVal = false
        serviceItem.routingMode = "full"
        tryCompare(view, "dnsExplanationText", view.tr("settings.dnsMode.forcedCustomFull"))
      } finally {
        if (view) view.destroy()
        serviceItem.settingsData = savedData
        serviceItem.configMode = savedMode
        serviceItem.routingMode = savedRouting
      }
    }

    function test_z_verdict_negative_control() {
      // Test-only opt-in: the runner must reject a real failed assertion.
      if (Quickshell.env("VPNROUTER_QML_EXPECT_FAILURE") === "1")
        fail("Intentional verdict negative control")
    }

    onCompletedChanged: {
      if (!completed) return
      // QtTest finishes counters after setting completed; observe on next turn.
      Qt.callLater(function() {
        // qtest_results is a QtTest implementation detail verified on Qt 6.11.
        // Unknown API/version fails closed rather than fabricating a green run.
        var results = testCase.qtest_results
        var ok = results && typeof results.failCount === "number"
          && typeof results.passCount === "number" && typeof results.skipCount === "number"
          // Ten test functions plus initTestCase and cleanupTestCase on Qt 6.11.
          // A removed test must fail the gate, not silently lower coverage.
          && results.failCount === 0 && results.passCount === 12 && results.skipCount === 0
        console.log("VPNROUTER_QML_VERDICT", ok ? "PASS" : "FAIL",
          results ? results.passCount : -1, results ? results.failCount : -1)
        harnessRoot.testsFinished = true
        killer.command = ["sh", "-c", "echo " + (ok ? "0" : "1") + " > \"$RESULT_FILE\"; kill -TERM " + Quickshell.processId]
        killer.running = true
      })
    }
  }

  // Safety fallback timeout (25s)
  Timer {
    interval: 25000
    running: true
    onTriggered: {
      if (!harnessRoot.testsFinished) {
        console.log("TIMEOUT in test runner")
        killer.command = ["sh", "-c", "echo 1 > \"$RESULT_FILE\"; kill -TERM " + Quickshell.processId]
        killer.running = true
      }
    }
  }

  Process {
    id: killer
  }
}
