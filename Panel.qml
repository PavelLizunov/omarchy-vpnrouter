pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons 1.0
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
    return I18n.t(key, args)
  }

  // User configuration and display mode
  property string mode: setting("mode", "simple")
  property string currentTab: "servers"

  onOpenedChanged: {
    if (opened) {
      if (service) {
        service.refreshSnapshot()
        if (mode === "advanced") {
          refreshTab(currentTab)
        } else {
          service.listServers(0, 50)
        }
      }
    }
  }

  function refreshTab(tabId) {
    if (!service) return
    switch (tabId) {
      case "servers":
        service.listServers(0, 100)
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
    if (hostWidget && typeof hostWidget.updateSetting === "function") {
      hostWidget.updateSetting("mode", nextMode)
    }
    if (nextMode === "advanced") {
      refreshTab(currentTab)
    }
  }

  function toggleLocale() {
    var cur = I18n.getEffectiveLocale()
    var next = cur === "ru" ? "en" : "ru"
    I18n.setLocale(next)
    localI18nRevision++
    if (service && typeof service.setLocale === "function") {
      service.setLocale(next)
    } else if (service) {
      service.i18nRevision++
    }
    if (hostWidget && typeof hostWidget.updateSetting === "function") {
      hostWidget.updateSetting("locale", next)
    }
  }

  Ui.KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(root.mode === "advanced" ? 540 : 440))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight, Style.space(640))

    Ui.PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: flickableContent
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + Style.space(24)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: mainColumn
          width: flickableContent.width
          spacing: Style.space(12)

          // 1. Header
          VpnUi.Header {
            width: parent.width
            service: root.service
            i18nRevision: root.i18nRevision
            mode: root.mode
            onModeChangeRequested: function(m) { root.setDisplayMode(m) }
            onLocaleToggled: root.toggleLocale()
            onCloseRequested: root.close()
          }

          // 2. Hero Connection Card
          VpnUi.HeroCard {
            width: parent.width
            service: root.service
            i18nRevision: root.i18nRevision
            onConnectRequested: if (root.service) root.service.connect()
            onDisconnectRequested: if (root.service) root.service.disconnect()
            onCancelRequested: if (root.service) root.service.cancel()
          }

          // 3. Simple Mode View: Server Quick Selector & Routing Mode Switch
          Column {
            visible: root.mode === "simple"
            width: parent.width
            spacing: Style.space(10)

            // Server Quick Selector Card
            Rectangle {
              width: parent.width
              height: simpleServerCol.implicitHeight + Style.space(16)
              radius: Style.cornerRadius
              color: Style.normalFill
              border.color: Style.normalBorderColor
              border.width: Style.normalBorderWidth

              Column {
                id: simpleServerCol
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Row {
                  width: parent.width

                  Text {
                    text: root.tr("simple.activeServer")
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                  }

                  Item { Layout.fillWidth: true; width: 1; height: 1 }

                  VpnUi.Button {
                    text: root.tr("action.refresh")
                    variant: "subtle"
                    onClicked: if (root.service) root.service.listServers(0, 50)
                  }
                }

                // Server Items (top 5 quick select)
                Repeater {
                  model: (root.service && root.service.servers) ? root.service.servers.slice(0, 6) : []

                  Rectangle {
                    width: simpleServerCol.width
                    height: Style.space(32)
                    radius: Style.cornerRadius
                    color: modelData.selected ? Style.selectedFill : (sMouse.containsMouse ? Style.hoverFill : "transparent")
                    border.color: modelData.selected ? Color.accent : "transparent"
                    border.width: modelData.selected ? 1 : 0

                    Row {
                      anchors.fill: parent
                      anchors.margins: Style.space(6)
                      spacing: Style.space(8)

                      Rectangle {
                        width: Style.space(14)
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.selected ? Color.accent : "transparent"
                        border.color: modelData.selected ? Color.accent : Color.muted
                        border.width: 1
                      }

                      Text {
                        width: parent.width - latLabel.width - Style.space(36)
                        text: modelData.name || "Server"
                        color: modelData.selected ? Color.accent : Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                      }

                      Text {
                        id: latLabel
                        text: Model.formatLatency(modelData.latencyMs)
                        color: Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }

                    MouseArea {
                      id: sMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: if (root.service) root.service.selectServer(modelData.id)
                    }
                  }
                }
              }
            }

            // Quick Routing Mode Card
            Rectangle {
              width: parent.width
              height: quickRouteCol.implicitHeight + Style.space(16)
              radius: Style.cornerRadius
              color: Style.normalFill
              border.color: Style.normalBorderColor
              border.width: Style.normalBorderWidth

              Column {
                id: quickRouteCol
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Text {
                  text: root.tr("apps.routingMode")
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                }

                Row {
                  spacing: Style.space(12)

                  VpnUi.Toggle {
                    label: root.tr("apps.routingMode.split")
                    checked: root.service && root.service.routingMode === "split"
                    onToggled: function(val) {
                      if (root.service) root.service.setRouting(val ? "split" : "full", root.service.routingAppsMode)
                    }
                  }

                  VpnUi.Toggle {
                    label: root.tr("apps.routingMode.full")
                    checked: root.service && root.service.routingMode === "full"
                    onToggled: function(val) {
                      if (root.service) root.service.setRouting(val ? "full" : "split", root.service.routingAppsMode)
                    }
                  }
                }
              }
            }

            // Switch to Advanced Mode Button
            VpnUi.Button {
              width: parent.width
              text: "󰒓 " + root.tr("simple.switchAdvanced")
              variant: "subtle"
              onClicked: root.setDisplayMode("advanced")
            }
          }

          // 4. Advanced Mode View: Tab Navigation + Dedicated Section View
          Column {
            visible: root.mode === "advanced"
            width: parent.width
            spacing: Style.space(12)

            VpnUi.Navigation {
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
              currentTab: root.currentTab
              onTabSelected: function(tId) {
                root.currentTab = tId
                root.refreshTab(tId)
              }
            }

            // Section Views
            VpnUi.ServersView {
              visible: root.currentTab === "servers"
              width: parent.width
              service: root.service
              i18nRevision: root.i18nRevision
            }

            VpnUi.SubscriptionsView {
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
