import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "lib/Model.js" as Model
import "lib/Contrast.js" as Contrast
import "lib/I18n.js" as I18n
import "ui" as VpnUi

Ui.BarWidget {
  id: root

  moduleName: "io.github.pavellizunov.vpnrouter"

  // Documented Omarchy host shell injection property
  property var shell: null
  readonly property var effectiveShell: shell ? shell : (bar && bar.shell ? bar.shell : null)

  // Shared singleton service lookup via Omarchy Quattro host shell API
  readonly property var hostService: {
    var sh = effectiveShell
    if (sh && typeof sh.serviceFor === "function") {
      var s = sh.serviceFor(moduleName)
      if (s) return s
    }
    return null
  }

  // External service injection override (for testing or shell injection)
  property var service: null
  readonly property var effectiveService: service ? service : hostService

  readonly property var panelItem: panelLoader.item
  readonly property bool opened: panelItem ? panelItem.opened : false
  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing : false

  readonly property int i18nRevision: effectiveService ? effectiveService.i18nRevision : 0

  function tr(key, args) {
    var _ = root.i18nRevision
    return root.effectiveService ? root.effectiveService.tr(key, args) : I18n.t(key, args)
  }

  readonly property string vpnState: effectiveService ? effectiveService.state : "unavailable"
  readonly property bool isStarting: Model.backendStarting(effectiveService)
  readonly property bool isConnected: vpnState === "connected"
  readonly property bool isError: effectiveService ? (effectiveService.isError || vpnState === "error") : false
  readonly property string activeServerName: effectiveService ? effectiveService.activeServer : ""
  readonly property var activeServerItem: {
    if (!effectiveService || effectiveService.configMode === "custom" || !effectiveService.servers) return null
    for (var i = 0; i < effectiveService.servers.length; i++) {
      if (effectiveService.servers[i].selected) return effectiveService.servers[i]
    }
    return null
  }
  readonly property var serverLatency: activeServerItem ? activeServerItem.latencyMs : null

  // Settings
  readonly property bool showLatencySetting: setting("showLatency", true) !== false

  readonly property string visualState: effectiveService && effectiveService.backendMissing ? "missing" : isStarting ? "starting" : !effectiveService || vpnState === "unavailable" ? "unavailable" : isError ? "error" : vpnState === "connecting" || vpnState === "disconnecting" ? "connecting" : isConnected ? "connected" : "disconnected"
  // The penguin mark stays monochrome like the neighbouring bar glyphs; the
  // tile fill shows the routing mode and a badge marks a problem.
  readonly property string markFill: isConnected ? (effectiveService && effectiveService.routingMode === "full" ? "full" : "split") : "off"
  readonly property bool markBadge: visualState === "error" || visualState === "unavailable" || visualState === "missing"
  readonly property color preferredInk: Commons.Color.bar.text

  readonly property color barSurface: root.bar && root.bar.background !== undefined ? root.bar.background : Commons.Color.bar.background
  readonly property color inkColor: Contrast.ratio(preferredInk, barSurface, Commons.Color.background) >= 3 ? preferredInk : Commons.Color.bar.text

  readonly property string barTooltip: {
    var _ = i18nRevision
    var label = visualState === "missing" ? root.tr("backend.notInstalled") : visualState === "starting" ? root.tr("backend.starting") : root.tr("state." + vpnState)
    var title = root.tr("bar.state", [label])
    var server = activeServerName || (activeServerItem ? activeServerItem.name : "")
    if (server) title += "\n" + root.tr("bar.server", [server])
    if (showLatencySetting && isConnected && typeof serverLatency === "number" && isFinite(serverLatency) && serverLatency >= 0) title += " · " + Model.formatLatency(serverLatency, ({ t: root.tr }))
    return title
  }

  function updateSetting(key, val) {
    var entry = { id: moduleName }
    for (var k in settings) entry[k] = settings[k]
    entry[key] = val
    settings = entry
    var sh = effectiveShell
    if (sh && typeof sh.updateEntryInline === "function") {
      sh.updateEntryInline(moduleName, entry)
    }
  }

  function syncPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.settings = root.settings
    panelLoader.item.hostWidget = root
    panelLoader.item.anchorItem = button
    panelLoader.item.service = root.effectiveService
  }

  function syncSettings() {
    syncPanel()
    var locale = setting("locale", "auto")
    if (effectiveService && effectiveService.locale !== locale) effectiveService.setLocale(locale)
  }

  function open() {
    panelLoader.active = true
    Qt.callLater(function() {
      root.syncPanel()
      if (root.panelItem) {
        var request = root.effectiveService ? root.effectiveService.pendingNavigation : null
        if (request) {
          root.effectiveService.pendingNavigation = null
          root.panelItem.navigate(request.page, request.form)
        }
        root.panelItem.open()
      }
    })
  }

  function close() {
    if (root.panelItem) root.panelItem.close()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function closeForPopoutSwitch() {
    if (root.panelItem) root.panelItem.closeForPopoutSwitch()
  }

  onBarChanged: syncPanel()
  onSettingsChanged: syncSettings()
  onEffectiveServiceChanged: syncSettings()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Loader {
    id: panelLoader
    active: false
    visible: false
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: root.syncPanel()
  }

  Ui.WidgetButton {
    id: button
    bar: root.bar
    hasVisualContent: true
    labelVisible: false
    dimmed: false
    fixedWidth: root.vertical ? -1 : contentRow.implicitWidth
    fixedHeight: root.vertical ? (contentRow.implicitHeight + Style.space(12)) : -1
    tooltipText: root.barTooltip

    Accessible.role: Accessible.Button
    Accessible.name: root.barTooltip
    Accessible.onPressAction: root.toggle()

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        // Right click: quick connect/disconnect toggle
        if (root.effectiveService) {
          if (root.isConnected) root.effectiveService.disconnect()
          else root.effectiveService.connect()
        }
      } else if (buttonCode === Qt.MiddleButton) {
        // Middle click: refresh snapshot
        if (root.effectiveService) root.effectiveService.refreshSnapshot()
      } else {
        root.toggle()
      }
    }

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(5)

      // Same slot width as the host's bar icon buttons.
      Item {
        width: Style.bar.iconSlot
        height: mark.height
        anchors.verticalCenter: parent.verticalCenter

        VpnUi.PenguinMark {
          id: mark
          objectName: "vpnBarMark"
          anchors.centerIn: parent
          iconSize: Style.bar.iconCanvas
          color: root.inkColor
          fill: root.markFill
          dimmed: !root.isConnected
          badge: root.markBadge
          pulsing: root.visualState === "connecting" && !Style.reduceMotion
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: !root.vertical && root.showLatencySetting && root.isConnected && typeof root.serverLatency === "number" && isFinite(root.serverLatency) && root.serverLatency >= 0
        text: Model.formatLatency(root.serverLatency, ({ t: root.tr }))
        color: root.inkColor
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
