import QtQuick
import qs.Commons 1.0
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

Rectangle {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0

  function tr(key, args) {
    var _ = i18nRevision
    return I18n.t(key, args)
  }

  signal connectRequested()
  signal disconnectRequested()
  signal cancelRequested()
  signal openServerPickerRequested()

  radius: Style.cornerRadius
  color: Style.normalFill
  border.color: Style.normalBorderColor
  border.width: Style.normalBorderWidth

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: cardColumn.implicitHeight + Style.space(24)

  readonly property bool canConnect: service && service.capabilities && service.capabilities.connect === true
  readonly property bool connected: service ? service.isConnected : false
  readonly property bool connecting: service ? service.isConnecting : false
  readonly property bool disconnecting: service ? service.isDisconnecting : false
  readonly property bool busy: service ? (service.busy || connecting || disconnecting) : false
  readonly property string activeServerName: service && service.activeServer ? service.activeServer : root.tr("simple.noActiveServer")

  Column {
    id: cardColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(12)
    spacing: Style.space(12)

    // Main status row
    Row {
      width: parent.width
      spacing: Style.space(12)

      // Connection Action Button (Hero Dial)
      Rectangle {
        id: connectBtn
        width: Style.space(52)
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.connected ? Color.accent : (root.busy ? Color.urgent : Style.hoverFill)
        border.color: root.connected ? Color.accent : Style.hoverBorderColor
        border.width: connectBtnMouse.activeFocus ? Style.focusBorderWidth : 1

        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
          anchors.centerIn: parent
          text: root.busy ? "󰦞" : (root.connected ? "󰖂" : "󱚤")
          color: root.connected ? Color.background : Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.display

          NumberAnimation on rotation {
            running: root.busy
            from: 0
            to: 360
            loops: Animation.Infinite
            duration: 1000
          }
        }

        MouseArea {
          id: connectBtnMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: (root.connected || root.canConnect) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
          onClicked: {
            if (root.connected) root.disconnectRequested()
            else if (root.canConnect) root.connectRequested()
          }
        }
      }

      // Server Info & Quick Switch
      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - connectBtn.width - actionRow.width - Style.space(24)
        spacing: Style.space(3)

        Text {
          text: root.connected ? root.tr("state.connected") : (root.connecting ? root.tr("state.connecting") : root.tr("state.disconnected"))
          color: root.connected ? Color.accent : (root.busy ? Color.urgent : Color.muted)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          width: parent.width
          text: root.activeServerName
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          elide: Text.ElideRight
        }

        Row {
          spacing: Style.space(8)

          // Routing mode badge
          Rectangle {
            radius: Style.cornerRadius
            height: Style.space(18)
            width: modeText.implicitWidth + Style.space(10)
            color: Style.normalFill
            border.color: Style.normalBorderColor
            border.width: 1

            Text {
              id: modeText
              anchors.centerIn: parent
              text: root.service && root.service.routingMode === "full" ? "FULL VPN" : "SPLIT"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      // Right Action Row
      Row {
        id: actionRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Button {
          text: root.connected ? root.tr("action.disconnect") : root.tr("action.connect")
          variant: root.connected ? "danger" : "primary"
          busy: root.busy
          enabled: root.connected || root.canConnect
          onClicked: {
            if (root.connected) root.disconnectRequested()
            else if (root.canConnect) root.connectRequested()
          }
        }
      }
    }

    // In-Flight Operation & Cancel Row
    Rectangle {
      visible: root.service && root.service.activeOperation !== ""
      width: parent.width
      height: Style.space(28)
      radius: Style.cornerRadius
      color: Style.hoverFill

      Row {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        Text {
          text: "󰦞"
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          NumberAnimation on rotation {
            running: root.service && root.service.activeOperation !== ""
            from: 0; to: 360; loops: Animation.Infinite; duration: 1000
          }
        }

        Text {
          text: (root.service ? root.service.activeOperation : "") + "…"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          visible: root.service && root.service.activeProgress !== null
          text: root.service && root.service.activeProgress
            ? "(" + root.service.activeProgress.completed + "/" + root.service.activeProgress.total + ")"
            : ""
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      IconButton {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰅖"
        tooltipText: root.tr("action.cancel")
        onClicked: root.cancelRequested()
      }
    }

    // Error Alert Banner
    Rectangle {
      visible: root.service && root.service.lastError !== ""
      width: parent.width
      height: errRow.implicitHeight + Style.space(12)
      radius: Style.cornerRadius
      color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.15)
      border.color: Color.urgent
      border.width: 1

      Row {
        id: errRow
        anchors.fill: parent
        anchors.margins: Style.space(6)
        spacing: Style.space(8)

        Text {
          text: "󰅚"
          color: Color.urgent
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          width: parent.width - dismissErrBtn.width - Style.space(32)
          text: root.service ? root.service.lastError : ""
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          anchors.verticalCenter: parent.verticalCenter
        }

        IconButton {
          id: dismissErrBtn
          icon: "󰅖"
          tooltipText: root.tr("action.dismiss")
          anchors.verticalCenter: parent.verticalCenter
          onClicked: if (root.service) root.service.lastError = ""
        }
      }
    }
  }
}
