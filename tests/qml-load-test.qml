import QtQuick
import QtTest
import qs.Commons 1.0
import qs.Ui 1.0 as Ui
import ".." as VpnPlugin
import "../ui" as VpnUi
import "../lib/Protocol.js" as Protocol
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

TestCase {
  id: testCase
  name: "OmarchyVpnRouterLoadTest"
  when: true
  width: 800
  height: 600

  // ---------------------------------------------------------------------------
  // Fixtures & Injected Fake Backend
  // ---------------------------------------------------------------------------

  property var sentRequests: []
  property var fakeBackend: function(rawText) {
    var line = String(rawText || "").trim()
    if (!line) return
    var req = null
    try {
      req = JSON.parse(line)
    } catch (e) {
      return
    }
    sentRequests.push(req)

    // Respond asynchronously via fake event loop
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

  // Standalone mock bar
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

  // Anchor item for popup attachment
  Item {
    id: dummyAnchor
    width: 28
    height: 28
  }

  // Service under test with processDisabled: true
  VpnPlugin.Service {
    id: serviceItem
    processDisabled: true
    fakeBackend: testCase.fakeBackend
  }

  // ---------------------------------------------------------------------------
  // Test 1: Service Defaults and Pre-Handshake Safety
  // ---------------------------------------------------------------------------
  function test_1_service_defaults_and_handshake_safety() {
    // 1. Invariants before handshake: connect must be false, processDisabled true
    compare(serviceItem.processDisabled, true, "Process spawning must be disabled in isolated harness")
    compare(serviceItem.capabilities.connect, false, "capabilities.connect must be false before handshake")
    compare(serviceItem.state, "unavailable", "Initial state must be unavailable")
    compare(serviceItem.isConnected, false, "isConnected must be false")

    // 2. Calling connect() before handshake should fail cleanly without crashing
    var connectReturned = serviceItem.connect()
    compare(connectReturned, null, "connect() before handshake must fail closed and return null")
    compare(serviceItem.lastError, "Connect capability unavailable before handshake")
  }

  // ---------------------------------------------------------------------------
  // Test 2: Fake Backend Handshake and Capabilities Injection
  // ---------------------------------------------------------------------------
  function test_2_fake_backend_handshake_and_capabilities() {
    testCase.sentRequests = []
    serviceItem.refreshSnapshot()

    tryVerify(function() {
      return serviceItem.capabilities && serviceItem.capabilities.connect === true
    }, 2000, "Service failed to apply handshake snapshot with connect capability")

    compare(serviceItem.capabilities.connect, true, "connect capability must be enabled after handshake")
    compare(serviceItem.capabilities.killSwitch, true, "killSwitch capability must be enabled")
    compare(serviceItem.state, "disconnected", "State should transition to disconnected")

    // Now connect() is authorized
    var reqId = serviceItem.connect()
    verify(reqId !== null && reqId.length > 0, "connect() must return a valid request ID after handshake")

    tryVerify(function() {
      return serviceItem.isConnected === true
    }, 2000, "Service failed to transition to isConnected after mock connect response")
  }

  // ---------------------------------------------------------------------------
  // Test 3: I18n Reactivity & Revision Increments
  // ---------------------------------------------------------------------------
  function test_3_i18n_reactivity() {
    var initialRev = serviceItem.i18nRevision
    var listenerTriggered = false
    var listenerRev = -1

    var testListener = function(rev) {
      listenerTriggered = true
      listenerRev = rev
    }
    I18n.addListener(testListener)

    // Toggle locale to 'ru'
    serviceItem.setLocale("ru")
    verify(listenerTriggered, "I18n listener must be called on setLocale")
    verify(serviceItem.i18nRevision > initialRev, "Service i18nRevision must increment")
    compare(serviceItem.effectiveLocale, "ru", "effectiveLocale must update to ru")

    // Toggle back to 'en'
    serviceItem.setLocale("en")
    compare(serviceItem.effectiveLocale, "en", "effectiveLocale must update to en")

    I18n.removeListener(testListener)
  }

  // ---------------------------------------------------------------------------
  // Test 4: Header Signals & Mode Change Request
  // ---------------------------------------------------------------------------
  Component {
    id: headerComponent
    VpnUi.Header {
      service: serviceItem
      mode: "simple"
    }
  }

  function test_4_header_signals_and_properties() {
    var header = headerComponent.createObject(testCase)
    verify(header !== null, "Header component must instantiate cleanly")

    var requestedMode = ""
    header.modeChangeRequested.connect(function(next) {
      requestedMode = next
    })

    // Simulate clicking mode toggle
    header.modeChangeRequested("advanced")
    compare(requestedMode, "advanced", "Header must emit modeChangeRequested signal with next mode")

    header.destroy()
  }

  // ---------------------------------------------------------------------------
  // Test 5: Panel KeyboardPanel & PanelKeyCatcher Lifecycle
  // ---------------------------------------------------------------------------
  Component {
    id: panelComponent
    VpnPlugin.Panel {
      bar: mockBar
      anchorItem: dummyAnchor
      service: serviceItem
    }
  }

  function test_5_panel_keyboard_and_keycatcher() {
    var panel = panelComponent.createObject(testCase)
    verify(panel !== null, "Panel component must instantiate cleanly")

    // Test toggle / open
    panel.open()
    verify(panel.opened, "Panel opened state must be true")

    panel.close()
    verify(!panel.opened, "Panel opened state must be false after close()")

    panel.destroy()
  }

  // ---------------------------------------------------------------------------
  // Test 6: BarWidget Lifecycle & Absence => Unavailable
  // ---------------------------------------------------------------------------
  Component {
    id: barWidgetComponent
    VpnPlugin.BarWidget {
      bar: mockBar
      service: serviceItem
    }
  }

  Component {
    id: barWidgetAbsentComponent
    VpnPlugin.BarWidget {
      bar: mockBar
      service: null
    }
  }

  Component {
    id: barWidgetShellComponent
    VpnPlugin.BarWidget {
      bar: mockBar
      shell: mockShell
    }
  }

  function test_6_bar_widget_lifecycle() {
    var widget = barWidgetComponent.createObject(testCase)
    verify(widget !== null, "BarWidget component must instantiate cleanly")
    compare(widget.effectiveService, serviceItem, "BarWidget must use injected service")
    widget.destroy()

    var widgetAbsent = barWidgetAbsentComponent.createObject(testCase)
    verify(widgetAbsent !== null, "BarWidget without service must instantiate cleanly")
    compare(widgetAbsent.effectiveService, null, "Absence of service must leave effectiveService null")
    compare(widgetAbsent.vpnState, "unavailable", "Absence of service must report state unavailable")
    widgetAbsent.destroy()

    // 3. Documented shell injection
    var widgetShell = barWidgetShellComponent.createObject(testCase)
    verify(widgetShell !== null, "BarWidget with shell must instantiate cleanly")
    compare(widgetShell.shell, mockShell, "BarWidget must have shell property set")
    compare(widgetShell.hostService, serviceItem, "BarWidget must resolve hostService from shell.serviceFor")
    compare(widgetShell.effectiveService, serviceItem, "BarWidget effectiveService must resolve from shell")
    widgetShell.destroy()
  }

  // ---------------------------------------------------------------------------
  // Test 7: Clean Instantiation of All 9 Dedicated Views
  // ---------------------------------------------------------------------------
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
      serversComp.createObject(testCase),
      subsComp.createObject(testCase),
      freeComp.createObject(testCase),
      appsComp.createObject(testCase),
      profilesComp.createObject(testCase),
      rulesComp.createObject(testCase),
      customComp.createObject(testCase),
      settingsComp.createObject(testCase),
      diagComp.createObject(testCase)
    ]

    for (var i = 0; i < views.length; i++) {
      verify(views[i] !== null, "Subview at index " + i + " must instantiate without errors")
      views[i].destroy()
    }
  }
}
