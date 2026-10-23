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
  property string mode: "simple"
  property string currentTab: "servers"

  onOpenedChanged: {
    if (opened) {
      if (service) {
        service.refreshSnapshot()
        service.listSubscriptions(0, 100)
        service.getApps()
        if (mode === "advanced") {
          refreshTab(currentTab)
        } else {
          service.listServers(0, 50)
        }
      }
    }
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

  function setDisplayMode(nextMode) {
    root.mode = nextMode
    flickableContent.contentY = 0
    Qt.callLater(function() {
      // Refresh the positioner extent before focus restoration clamps scrolling.
      mainColumn.forceLayout()
      if (nextMode === "advanced") backButton.forceActiveFocus()
      else homeNavigation.restoreFocus(root.currentTab)
    })
    if (nextMode === "advanced") {
      refreshTab(currentTab)
    } else if (root.service) {
      root.service.listServers(0, 50)
    }
  }

  function openSection(tabId) {
    root.currentTab = tabId
    root.setDisplayMode("advanced")
  }

  function navigate(page, form) {
    if (page === "home") root.setDisplayMode("simple")
    else root.openSection(page)
    if (page === "subscriptions" && form === "add") root.openSubscriptionForm()
    if (page === "servers" && form === "import") serversView.openImportForm()
  }

  function openSubscriptionForm() {
    root.currentTab = "subscriptions"
    root.setDisplayMode("advanced")
    flickableContent.contentY = 0
    subscriptionsView.openForm()
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
                      text: hero.needsSetup ? root.tr("home.addConfig") : root.selectedServer ? root.selectedServer.name : root.service && root.service.activeServer ? root.service.activeServer : root.tr("simple.noActiveServer")
                      color: Commons.Color.popups.text
                      font.family: Commons.Style.font.family; font.pixelSize: Commons.Style.font.body; font.weight: Font.DemiBold
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      textFormat: Text.PlainText
                      text: root.tr(root.service && root.service.configMode === "custom" ? "home.custom" : root.selectedServer && root.selectedServer.source === "subscription" ? "home.subscription" : "home.serverLink")
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
                    onClicked: { if (hero.needsSetup) root.openSubscriptionForm(); else root.openSection("servers") }
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
            VpnUi.ServersView {
              id: serversView
              onAddSubscriptionRequested: root.openSubscriptionForm()
              visible: root.currentTab === "servers"
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
            }
            VpnUi.SubscriptionsView {
              id: subscriptionsView
              visible: root.currentTab === "subscriptions"
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
            }
            VpnUi.FreePoolView {
              visible: root.currentTab === "free"
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
            }
            VpnUi.AppsView {
              appLibrary: root.hostWidget && root.hostWidget.effectiveShell ? root.hostWidget.effectiveShell.appLibrary : null
              visible: root.currentTab === "apps"
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
            }
            VpnUi.ProfilesView {
              visible: root.currentTab === "profiles"
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
            }
            VpnUi.RulesView {
              visible: root.currentTab === "rules"
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
            }
            VpnUi.CustomConfigView {
              visible: root.currentTab === "custom"
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
            }
            VpnUi.SettingsView {
              visible: root.currentTab === "settings"
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
            }
            VpnUi.DiagnosticsView {
              visible: root.currentTab === "diagnostics"
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
            }
          }
        }
      }
    }
  }
}
