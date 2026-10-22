import QtQuick
import qs.Commons 1.0
import qs.Commons 1.0 as Commons
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string currentTab: "servers"

  signal tabSelected(string tabId)

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: tabRow.implicitHeight

  readonly property var tabs: {
    var _ = i18nRevision
    return [
      { id: "servers", label: root.tr("nav.servers"), icon: "󰒋" },
      { id: "subscriptions", label: root.tr("nav.subscriptions"), icon: "󰑤" },
      { id: "free", label: root.tr("nav.free"), icon: "󰓠" },
      { id: "apps", label: root.tr("nav.apps"), icon: "󰵮" },
      { id: "profiles", label: root.tr("nav.profiles"), icon: "󰒓" },
      { id: "rules", label: root.tr("nav.rules"), icon: "󰁝" },
      { id: "custom", label: root.tr("nav.custom"), icon: "󰘦" },
      { id: "settings", label: root.tr("nav.settings"), icon: "󰒓" },
      { id: "diagnostics", label: root.tr("nav.diagnostics"), icon: "󰓅" }
    ]
  }

  Grid {
    id: tabRow
    width: parent.width
    columns: 3
    spacing: Style.space(4)

    Repeater {
      model: root.tabs

      Item {
        id: tabItem
        width: (root.width - Style.space(8)) / 3
        height: Style.spacing.controlHeight
        activeFocusOnTab: true

        Keys.onReturnPressed: { root.currentTab = modelData.id; root.tabSelected(modelData.id) }
        Keys.onEnterPressed: { root.currentTab = modelData.id; root.tabSelected(modelData.id) }
        Keys.onSpacePressed: { root.currentTab = modelData.id; root.tabSelected(modelData.id) }

        readonly property bool active: root.currentTab === modelData.id
        readonly property bool hot: tabMouse.containsMouse

        Rectangle {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: active ? Style.selectedFill : (hot ? Style.hoverFill : "transparent")
          border.color: (tabItem.activeFocus || tabMouse.activeFocus) ? Style.focusBorderColor : (active ? Commons.Color.accent : "transparent")
          border.width: (tabItem.activeFocus || tabMouse.activeFocus) ? Style.focusBorderWidth : (active ? 1 : 0)

          Behavior on color { ColorAnimation { duration: 150 } }

          Row {
            id: tabBtnRow
            anchors.centerIn: parent
            spacing: Style.space(6)

            Text {
              text: modelData.icon
              color: active ? Commons.Color.accent : Commons.Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.iconSmall
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: modelData.label
              color: Commons.Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }

        MouseArea {
          id: tabMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            tabItem.forceActiveFocus()
            root.currentTab = modelData.id
            root.tabSelected(modelData.id)
          }
        }
      }
    }
  }
}
