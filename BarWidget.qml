import QtQuick
import qs.Commons 1.0
import qs.Ui 1.0 as Ui
import "lib/Model.js" as Model
import "lib/I18n.js" as I18n

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
      if (root.pluginId) {
        s = sh.serviceFor(root.pluginId)
        if (s) return s
      }
      if (bar && bar.pluginId) {
        s = sh.serviceFor(bar.pluginId)
        if (s) return s
      }
    }
    return null
  }

  // External service injection override (for testing or shell injection)
  property var service: null
  readonly property var effectiveService: service ? service : hostService

  readonly property var panelItem: panelLoader.item
  readonly property bool opened: panelItem ? panelItem.opened : false
  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing : false

  // Reactive state from singleton service and locale engine
  property int localI18nRevision: 0
  readonly property int i18nRevision: (effectiveService ? effectiveService.i18nRevision : 0) + localI18nRevision

  property var _i18nListener: function(r) {
    root.localI18nRevision = r
  }

  Component.onCompleted: {
    I18n.addListener(_i18nListener)
  }

  Component.onDestruction: {
    I18n.removeListener(_i18nListener)
  }

  readonly property string vpnState: effectiveService ? effectiveService.state : "unavailable"
  readonly property bool isConnected: vpnState === "connected"
  readonly property bool isBusy: effectiveService ? (effectiveService.busy || vpnState === "connecting" || vpnState === "disconnecting") : false
  readonly property bool isError: effectiveService ? (effectiveService.isError || vpnState === "error") : false
  readonly property string activeServerName: effectiveService ? effectiveService.activeServer : ""
  readonly property var activeServerItem: {
    if (!effectiveService || !effectiveService.servers) return null
    for (var i = 0; i < effectiveService.servers.length; i++) {
      if (effectiveService.servers[i].selected) return effectiveService.servers[i]
    }
    return null
  }
  readonly property var serverLatency: activeServerItem ? activeServerItem.latencyMs : null

  // Settings
  readonly property bool showLatencySetting: setting("showLatency", true) !== false

  // Ink color according to state
  readonly property color inkColor: {
    if (isError) return bar ? bar.urgent : Color.urgent
    if (isBusy) return bar ? bar.urgent : Color.urgent
    if (isConnected) return Color.accent
    return bar ? bar.foreground : Color.muted
  }

  readonly property string barTooltip: {
    var _ = i18nRevision
    var title = "VPNRouter: " + I18n.t("state." + vpnState)
    if (activeServerName) title += " (" + activeServerName + ")"
    if (serverLatency !== null && serverLatency !== undefined) title += " · " + Math.round(serverLatency) + " ms"
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
    panelLoader.item.hostWidget = root
    panelLoader.item.anchorItem = button
    panelLoader.item.service = root.effectiveService
  }

  function open() {
    panelLoader.active = true
    Qt.callLater(function() {
      root.syncPanel()
      if (root.panelItem) root.panelItem.open()
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
  onEffectiveServiceChanged: syncPanel()
  onServiceChanged: syncPanel()

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
    dimmed: !root.isConnected && !root.isBusy && !root.isError
    fixedWidth: root.vertical ? -1 : (contentRow.implicitWidth + Style.space(16))
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

      Text {
        text: root.isBusy ? "󰦞" : "󰖂"
        color: root.inkColor
        font.family: Style.font.family
        font.pixelSize: Style.font.iconSmall
        anchors.verticalCenter: parent.verticalCenter

        NumberAnimation on rotation {
          running: root.isBusy
          from: 0
          to: 360
          loops: Animation.Infinite
          duration: 1000
        }
      }

      // Latency badge or server label on bar if enabled and connected
      Text {
        visible: !root.vertical && root.showLatencySetting && root.isConnected && root.serverLatency !== null
        text: Math.round(root.serverLatency || 0) + "ms"
        color: root.inkColor
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
