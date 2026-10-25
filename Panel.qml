pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "ui" as VpnUi
import "lib/Model.js" as Model
import "lib/I18n.js" as I18n

Ui.Panel {
  id: root

  moduleName: "io.github.pavellizunov.vpnrouter"
  ipcTarget: "io.github.pavellizunov.vpnrouter"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null

  property int i18nRevision: service ? service.i18nRevision : localI18nRevision
  property int localI18nRevision: 0

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  // User configuration and display mode
  readonly property string configuredMode: setting("mode", "simple") === "advanced" ? "advanced" : "simple"
  property string mode: root.configuredMode
  onConfiguredModeChanged: root.mode = root.configuredMode
  readonly property bool showLatency: setting("showLatency", true) !== false
  property string currentTab: "servers"

  onOpenedChanged: {
    if (opened) {
      // A fresh open shows the connection status, not the last scroll position.
      if (mode === "simple") flickableContent.contentY = 0
      if (service) {
        service.refreshSnapshot()
        root.refreshPanelData()
      }
    }
  }

  function refreshPanelData() {
    if (!root.service) return
    root.service.listSubscriptions(0, 100)
    root.service.getApps()
    if (root.mode === "advanced") root.refreshTab(root.currentTab)
    else root.service.listServers(0, 100)
  }

  Connections {
    target: root.service
    function onBackendReady() { if (root.opened) root.refreshPanelData() }
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function refreshTab(tabId) {
    if (!service) return
    switch (tabId) {
      case "servers":
        service.listServers(0, 100)
        service.listSubscriptions(0, 100)
        break
      case "subscriptions":
        service.listSubscriptions(0, 100)
        break
      case "free":
        service.listFree(0, 100)
        break
      case "apps":
        service.getApps()
        break
      case "profiles":
        service.listProfiles()
        break
      case "rules":
        service.getRules()
        break
      case "custom":
        service.listCustom()
        break
      case "settings":
        service.getSettings()
        break
      case "diagnostics":
        service.checkDiagnostics()
        break
    }
  }

  function setDisplayMode(nextMode, keepTop) {
    root.mode = nextMode
    flickableContent.contentY = 0
    Qt.callLater(function() {
      // Refresh the positioner extent before focus restoration clamps scrolling.
      mainColumn.forceLayout()
      if (nextMode === "advanced") backButton.forceActiveFocus()
      else if (!keepTop) homeNavigation.restoreFocus(root.currentTab)
    })
    if (nextMode === "advanced") {
      refreshTab(currentTab)
    } else if (root.service) {
      root.service.listServers(0, 100)
    }
  }

  function openSection(tabId) {
    root.currentTab = tabId
    root.setDisplayMode("advanced")
  }

  function navigate(page, form) {
    if (page === "home") root.setDisplayMode("simple", true)
    else root.openSection(page)
    if (page === "subscriptions" && form === "add") root.openSubscriptionForm()
    if (page === "servers" && form === "import") serversLoader.item.openImportForm()
  }

  function openSubscriptionForm() {
    root.currentTab = "subscriptions"
    root.setDisplayMode("advanced")
    flickableContent.contentY = 0
    subscriptionsLoader.item.openForm()
  }

  function toggleLocale() {
    if (!service) return
    // Cycle back to the shell language after the two explicit overrides.
    var next = service.locale === "auto" ? "en" : service.locale === "en" ? "ru" : "auto"
    service.setLocale(next)
    if (hostWidget && typeof hostWidget.updateSetting === "function")
      hostWidget.updateSetting("locale", next)
  }

  readonly property var selectedServer: {
    if (!service) return null
    for (var server of service.servers) if (server.selected) return server
    return null
  }

  Ui.KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(Style.space(740), Style.space(764))

    FocusScope {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.close()
      Rectangle { anchors.fill: parent; color: Commons.Color.popups.background; radius: Commons.Style.cornerRadius }
      VpnUi.Header {
        id: header
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        service: root.service
        i18nRevision: root.i18nRevision
        onLocaleToggled: root.toggleLocale()
        onCloseRequested: root.close()
      }
      Item {
        id: sectionHeader
        objectName: "vpnSectionHeader"
        visible: root.mode === "advanced"
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: header.bottom
        height: visible ? Commons.Style.space(56) : 0
        VpnUi.Button {
          id: backButton
          objectName: "vpnBack"
          x: Commons.Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          icon: "󰁍"
          accessibleLabel: root.tr("home.back")
          tooltipText: accessibleLabel
          implicitWidth: Commons.Style.space(36)
          variant: "subtle"
          onClicked: root.setDisplayMode("simple")
        }
        Text {
          anchors.left: backButton.right; anchors.leftMargin: Commons.Style.space(8)
          anchors.right: parent.right; anchors.rightMargin: Commons.Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.tr("nav." + root.currentTab)
          elide: Text.ElideRight
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.heading
          font.weight: Font.DemiBold
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Commons.Style.normalBorderColor }
      }
      Flickable {
        id: flickableContent
        objectName: "vpnContentViewport"
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: sectionHeader.bottom; anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + Commons.Style.space(32)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
          id: mainColumn
          x: Commons.Style.space(16); y: Commons.Style.space(16)
          width: flickableContent.width - Commons.Style.space(32)
          spacing: Commons.Style.space(14)
          Column {
            visible: root.mode === "simple"
            width: parent.width
            spacing: Commons.Style.space(14)
            VpnUi.HeroCard {
              id: hero
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
              onConnectRequested: if (root.service) root.service.connect()
              onDisconnectRequested: if (root.service) root.service.disconnect()
              onCancelRequested: if (root.service) root.service.cancel()
            }
            VpnUi.Notice {
              objectName: "vpnTransportNotice"
              width: parent.width
              // The connected hero keeps the last reported VPN state; transport
              // failure is separate feedback and must remain visible on Home.
              text: root.service && root.service.transportStalled && root.service.isConnected ? root.service.lastErrorText : ""
              error: true
              dismissLabel: root.tr("action.dismiss")
              onDismissed: if (root.service) root.service.clearLastError()
            }
            Ui.BorderSurface {
              width: parent.width
              implicitHeight: connectionColumn.implicitHeight
              color: Commons.Color.popups.background
              radius: Commons.Style.cornerRadius
              borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)
              Column {
                id: connectionColumn
                width: parent.width
                Item {
                  width: parent.width; height: Commons.Style.space(70)
                  Rectangle {
                    x: Commons.Style.space(16); anchors.verticalCenter: parent.verticalCenter
                    width: Commons.Style.space(40); height: width; radius: Commons.Style.cornerRadius
                    color: Commons.Style.normalFill
                    Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: "󰒋"; color: Commons.Color.accent; font.family: Commons.Style.font.family; font.pixelSize: Commons.Style.font.display }
                  }
                  Column {
                    x: Commons.Style.space(68); anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, changeServer.x-x-Commons.Style.space(8))
                    spacing: Commons.Style.space(3)
                    Text {
                      objectName: "vpnHomeServerName"
                      width: parent.width
                      textFormat: Text.PlainText
                      text: hero.needsSetup ? root.tr("simple.noActiveServer") : root.service && root.service.configMode === "custom" ? root.service.activeServer || root.tr("simple.noActiveServer") : root.selectedServer ? root.selectedServer.name : root.service && root.service.activeServer ? root.service.activeServer : root.tr("simple.noActiveServer")
                      color: Commons.Color.popups.text
                      font.family: Commons.Style.font.family; font.pixelSize: Commons.Style.font.body; font.weight: Font.DemiBold
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      textFormat: Text.PlainText
                      text: root.tr(root.service && root.service.configMode === "custom" ? "home.custom" : root.selectedServer && root.selectedServer.source === "subscription" ? "home.subscription" : "home.serverLink")
                      visible: !hero.needsSetup
                      color: Commons.Color.popups.text
                      font.family: Commons.Style.font.family; font.pixelSize: Commons.Style.font.bodySmall
                      elide: Text.ElideRight
                    }
                  }
                  VpnUi.Button {
                    id: changeServer
                    objectName: "vpnChangeServer"
                    anchors.right: parent.right; anchors.rightMargin: Commons.Style.space(14)
                    anchors.verticalCenter: parent.verticalCenter
                    text: hero.needsSetup ? root.tr("firstRun.addSubscription") : root.tr("home.change")

                    fontSize: Commons.Style.font.bodySmall
                    implicitWidth: Math.max(Commons.Style.space(80), contentWidthHint.implicitWidth+Commons.Style.space(24))
                    onClicked: { if (hero.needsSetup) root.openSubscriptionForm(); else root.openSection(root.service && root.service.configMode === "custom" ? "custom" : "servers") }
                    Text { id: contentWidthHint; visible: false; text: changeServer.text; font.family: Commons.Style.font.family; font.pixelSize: changeServer.fontSize }
                  }
                }
                Rectangle { width: parent.width; height: 1; color: Commons.Style.normalBorderColor }
                Item {
                  width: parent.width
                  height: summary.implicitHeight + Commons.Style.space(30)
                  VpnUi.RoutingSummary {
                    id: summary
                    x: Commons.Style.space(16); y: Commons.Style.space(14)
                    width: parent.width - Commons.Style.space(32)
                    service: root.service
                    i18nRevision: root.i18nRevision
                  }
                }
              }
            }
            VpnUi.Navigation {
              id: homeNavigation
              objectName: "vpnHomeNavigation"
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
              onTabSelected: function(tabId) { root.openSection(tabId) }
            }
          }
          Column {
            visible: root.mode === "advanced"
            width: parent.width
            spacing: Commons.Style.space(12)
            VpnUi.Notice {
              width: parent.width
              text: root.service ? root.service.lastErrorText : ""
              error: true
              dismissLabel: root.tr("action.dismiss")
              onDismissed: if (root.service) root.service.clearLastError()
            }
            Loader {
              id: serversLoader
              objectName: "vpnSectionLoader-servers"
              property bool visited: false
              visible: root.mode === "advanced" && root.currentTab === "servers"
              active: visible || visited
              width: parent.width
              onLoaded: visited = true
              sourceComponent: VpnUi.ServersView {
                showLatency: root.showLatency
                onAddSubscriptionRequested: root.openSubscriptionForm()
                service: root.service
                i18nRevision: root.i18nRevision
              }
            }
            Loader {
              id: subscriptionsLoader
              objectName: "vpnSectionLoader-subscriptions"
              property bool visited: false
              visible: root.mode === "advanced" && root.currentTab === "subscriptions"
              active: visible || visited
              width: parent.width
              onLoaded: visited = true
              sourceComponent: VpnUi.SubscriptionsView {
                service: root.service
                i18nRevision: root.i18nRevision
              }
            }
            Loader {
              id: freeLoader
              objectName: "vpnSectionLoader-free"
              property bool visited: false
              visible: root.mode === "advanced" && root.currentTab === "free"
              active: visible || visited
              width: parent.width
              onLoaded: visited = true
              sourceComponent: VpnUi.FreePoolView {
                showLatency: root.showLatency
                service: root.service
                i18nRevision: root.i18nRevision
              }
            }
            Loader {
              id: appsLoader
              objectName: "vpnSectionLoader-apps"
              property bool visited: false
              visible: root.mode === "advanced" && root.currentTab === "apps"
              active: visible || visited
              width: parent.width
              onLoaded: visited = true
              sourceComponent: VpnUi.AppsView {
                appLibrary: root.hostWidget && root.hostWidget.effectiveShell ? root.hostWidget.effectiveShell.appLibrary : null
                service: root.service
                i18nRevision: root.i18nRevision
              }
            }
            Loader {
              id: profilesLoader
              objectName: "vpnSectionLoader-profiles"
              property bool visited: false
              visible: root.mode === "advanced" && root.currentTab === "profiles"
              active: visible || visited
              width: parent.width
              onLoaded: visited = true
              sourceComponent: VpnUi.ProfilesView {
                service: root.service
                i18nRevision: root.i18nRevision
              }
            }
            Loader {
              id: rulesLoader
              objectName: "vpnSectionLoader-rules"
              property bool visited: false
              visible: root.mode === "advanced" && root.currentTab === "rules"
              active: visible || visited
              width: parent.width
              onLoaded: visited = true
              sourceComponent: VpnUi.RulesView {
                service: root.service
                i18nRevision: root.i18nRevision
              }
            }
            Loader {
              id: customLoader
              objectName: "vpnSectionLoader-custom"
              property bool visited: false
              visible: root.mode === "advanced" && root.currentTab === "custom"
              active: visible || visited
              width: parent.width
              onLoaded: visited = true
              sourceComponent: VpnUi.CustomConfigView {
                service: root.service
                i18nRevision: root.i18nRevision
              }
            }
            Loader {
              id: settingsLoader
              objectName: "vpnSectionLoader-settings"
              property bool visited: false
              visible: root.mode === "advanced" && root.currentTab === "settings"
              active: visible || visited
              width: parent.width
              onLoaded: visited = true
              sourceComponent: VpnUi.SettingsView {
                service: root.service
                i18nRevision: root.i18nRevision
              }
            }
            Loader {
              id: diagnosticsLoader
              objectName: "vpnSectionLoader-diagnostics"
              property bool visited: false
              visible: root.mode === "advanced" && root.currentTab === "diagnostics"
              active: visible || visited
              width: parent.width
              onLoaded: visited = true
              sourceComponent: VpnUi.DiagnosticsView {
                service: root.service
                i18nRevision: root.i18nRevision
              }
            }
          }
        }
      }
    }
  }
}
