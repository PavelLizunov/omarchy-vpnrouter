pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons 1.0
import qs.Commons 1.0 as Commons
import qs.Ui 1.0 as Ui
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
    Qt.callLater(function() { if (nextMode === "advanced") backButton.forceActiveFocus(); else homeNavigation.restoreFocus(root.currentTab) })
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
      Rectangle { anchors.fill: parent; color: VpnUi.Brand.surfaceApp; radius: VpnUi.Brand.cardRadius }
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
        height: visible ? VpnUi.Brand.space(56) : 0
        VpnUi.Button {
          id: backButton
          objectName: "vpnBack"
          x: VpnUi.Brand.space(12)
          anchors.verticalCenter: parent.verticalCenter
          icon: "󰁍"
          accessibleLabel: root.tr("home.back")
          implicitWidth: VpnUi.Brand.space(36)
          variant: "subtle"
          onClicked: root.setDisplayMode("simple")
        }
        Text {
          anchors.left: backButton.right; anchors.leftMargin: VpnUi.Brand.space(8)
          anchors.right: parent.right; anchors.rightMargin: VpnUi.Brand.space(16)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.tr("nav." + root.currentTab)
          elide: Text.ElideRight
          color: VpnUi.Brand.textPrimary
          font.family: VpnUi.Brand.fontFamily
          font.pixelSize: VpnUi.Brand.space(18)
          font.weight: Font.DemiBold
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: VpnUi.Brand.borderSubtle }
      }
      Flickable {
        id: flickableContent
        objectName: "vpnContentViewport"
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: sectionHeader.bottom; anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + VpnUi.Brand.space(32)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
          id: mainColumn
          x: VpnUi.Brand.space(16); y: VpnUi.Brand.space(16)
          width: flickableContent.width - VpnUi.Brand.space(32)
          spacing: VpnUi.Brand.space(14)
          Column {
            visible: root.mode === "simple"
            width: parent.width
            spacing: VpnUi.Brand.space(14)
            VpnUi.HeroCard {
              id: hero
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
              onConnectRequested: if (root.service) root.service.connect()
              onDisconnectRequested: if (root.service) root.service.disconnect()
              onCancelRequested: if (root.service) root.service.cancel()
            }
            Rectangle {
              width: parent.width
              implicitHeight: connectionColumn.implicitHeight
              color: VpnUi.Brand.surfaceBase
              radius: VpnUi.Brand.cardRadius
              border.color: VpnUi.Brand.borderDefault
              Column {
                id: connectionColumn
                width: parent.width
                Item {
                  width: parent.width; height: VpnUi.Brand.space(70)
                  Rectangle {
                    x: VpnUi.Brand.space(16); anchors.verticalCenter: parent.verticalCenter
                    width: VpnUi.Brand.space(40); height: width; radius: VpnUi.Brand.space(10)
                    color: VpnUi.Brand.accentBgSubtle
                    Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: "󰒋"; color: VpnUi.Brand.accentFg; font.family: VpnUi.Brand.iconFamily; font.pixelSize: VpnUi.Brand.space(20) }
                  }
                  Column {
                    x: VpnUi.Brand.space(68); anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, changeServer.x-x-VpnUi.Brand.space(8))
                    spacing: VpnUi.Brand.space(3)
                    Text {
                      objectName: "vpnHomeServerName"
                      width: parent.width
                      textFormat: Text.PlainText
                      text: hero.needsSetup ? root.tr("home.addConfig") : root.selectedServer ? root.selectedServer.name : root.service && root.service.activeServer ? root.service.activeServer : root.tr("simple.noActiveServer")
                      color: VpnUi.Brand.textPrimary
                      font.family: VpnUi.Brand.fontFamily; font.pixelSize: VpnUi.Brand.space(12); font.weight: Font.DemiBold
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      textFormat: Text.PlainText
                      text: root.tr(root.service && root.service.configMode === "custom" ? "home.custom" : root.selectedServer && root.selectedServer.source === "subscription" ? "home.subscription" : "home.serverLink")
                      color: VpnUi.Brand.textMuted
                      font.family: VpnUi.Brand.fontFamily; font.pixelSize: VpnUi.Brand.space(11)
                      elide: Text.ElideRight
                    }
                  }
                  VpnUi.Button {
                    id: changeServer
                    objectName: "vpnChangeServer"
                    anchors.right: parent.right; anchors.rightMargin: VpnUi.Brand.space(14)
                    anchors.verticalCenter: parent.verticalCenter
                    text: hero.needsSetup ? root.tr("firstRun.addSubscription") : root.tr("home.change")
                    pill: true
                    fontSize: VpnUi.Brand.space(11)
                    implicitWidth: Math.max(VpnUi.Brand.space(80), contentWidthHint.implicitWidth+VpnUi.Brand.space(24))
                    onClicked: { if (hero.needsSetup) root.openSubscriptionForm(); else root.openSection("servers") }
                    Text { id: contentWidthHint; visible: false; text: changeServer.text; font.family: VpnUi.Brand.fontFamily; font.pixelSize: changeServer.fontSize }
                  }
                }
                Rectangle { width: parent.width; height: 1; color: VpnUi.Brand.borderSubtle }
                Item {
                  width: parent.width
                  height: summary.implicitHeight + VpnUi.Brand.space(30)
                  VpnUi.RoutingSummary {
                    id: summary
                    x: VpnUi.Brand.space(16); y: VpnUi.Brand.space(14)
                    width: parent.width - VpnUi.Brand.space(32)
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
            spacing: VpnUi.Brand.space(12)
            VpnUi.ServersView {
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
