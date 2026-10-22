import QtQuick
import QtQuick.Controls as Controls
import qs.Commons 1.0
import qs.Commons 1.0 as Commons
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

Rectangle {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  function availabilityText() {
    var _ = root.i18nRevision
    if (!root.service || root.connected) return ""
    if (root.service.backendMissing)
      return root.tr("backend.notInstalled") + "\n" + root.tr("backend.installHint")
    if (!root.canConnect && !root.busy)
      return Model.unavailableText(root.service, ({ t: root.tr }))
    return ""
  }

  signal addSubscriptionRequested()
  signal connectRequested()
  signal disconnectRequested()
  signal cancelRequested()
  signal openServerPickerRequested()

  radius: Style.cornerRadius
  color: Style.normalFill
  border.color: Style.normalBorderColor
  border.width: Style.normalBorderWidth

  implicitWidth: parent ? parent.width : Style.space(480)
  // The panel owns a stable frame; shorter status text gives space to the tab.
  implicitHeight: Math.min(Style.space(176), cardColumn.implicitHeight + Style.space(24))

  readonly property bool needsSetup: !!(service && service.serversLoaded && service.subscriptionsLoaded && service.servers.length === 0 && service.subscriptions.length === 0 && !connected && !busy && service.configMode !== "custom")
  readonly property bool canConnect: service && service.capabilities && service.capabilities.connect === true
  readonly property bool connected: service ? service.isConnected : false
  readonly property bool connecting: service ? service.isConnecting : false
  readonly property bool disconnecting: service ? service.isDisconnecting : false
  readonly property bool busy: service ? (service.busy || connecting || disconnecting) : false
  readonly property string activeServerName: service && service.activeServer ? service.activeServer : root.tr("simple.noActiveServer")

  Flickable {
    id: heroViewport
    objectName: "vpnHeroViewport"
    anchors.fill: parent
    anchors.margins: Style.space(12)
    contentWidth: width
    contentHeight: cardColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

    Column {
      id: cardColumn
      width: heroViewport.width
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
          opacity: connectBtnMouse.enabled ? 1 : 0.4
          color: root.connected ? Commons.Color.accent : (root.busy ? Commons.Color.urgent : Style.hoverFill)
          border.color: root.connected ? Commons.Color.accent : Style.hoverBorderColor
          border.width: connectBtnMouse.activeFocus ? Style.focusBorderWidth : 1

          Behavior on color { ColorAnimation { duration: 150 } }

          Text {
            textFormat: Text.PlainText
            id: connectionGlyph
            anchors.centerIn: parent
            text: root.busy ? "\u{f0772}" : (root.connected ? "󰖂" : "󱚤")
            color: root.connected ? Commons.Color.background : Commons.Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.display

            NumberAnimation on rotation {
              running: root.busy
              onRunningChanged: if (!running) connectionGlyph.rotation = 0
              from: 0
              to: 360
              loops: Animation.Infinite
              duration: 1000
            }
          }

          MouseArea {
            id: connectBtnMouse
            anchors.fill: parent
            enabled: !root.needsSetup && (root.connected || (root.canConnect && !root.busy))
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
          width: parent.width - connectBtn.width - (actionRow.visible ? actionRow.width : 0) - Style.space(24)
          spacing: Style.space(3)

          Text {
            textFormat: Text.PlainText
            text: root.tr("state." + (root.service ? root.service.state : "unavailable"))
            color: root.connected ? Commons.Color.accent : (root.busy ? Commons.Color.urgent : Commons.Color.foreground)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.needsSetup ? root.tr("firstRun.title") : root.activeServerName
            color: Commons.Color.foreground
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
                textFormat: Text.PlainText
                id: modeText
                anchors.centerIn: parent
                text: root.service && root.service.routingMode === "full" ? root.tr("routing.fullBadge") : root.tr("routing.splitBadge")
                color: Commons.Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        // Right Action Row
        Row {
          id: actionRow
          visible: !root.needsSetup
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

      Button {
        visible: root.needsSetup
        text: root.tr("firstRun.addSubscription")
        variant: "primary"
        onClicked: root.addSubscriptionRequested()
      }

      Text {
        width: parent.width
        visible: text.length > 0
        text: root.availabilityText()
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
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
            textFormat: Text.PlainText
            text: "\u{f0772}"
            color: Commons.Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            NumberAnimation on rotation {
              running: root.service && root.service.activeOperation !== ""
              from: 0; to: 360; loops: Animation.Infinite; duration: 1000
            }
          }

          Text {
            textFormat: Text.PlainText
            text: root.tr("operation.pending")
            color: Commons.Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            textFormat: Text.PlainText
            visible: root.service && root.service.activeProgress !== null
            text: root.service && root.service.activeProgress
              ? "(" + root.service.activeProgress.completed + "/" + root.service.activeProgress.total + ")"
              : ""
            color: Commons.Color.foreground
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
        color: Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.15)
        border.color: Commons.Color.urgent
        border.width: 1

        Row {
          id: errRow
          anchors.fill: parent
          anchors.margins: Style.space(6)
          spacing: Style.space(8)

          Text {
            textFormat: Text.PlainText
            text: "󰅚"
            color: Commons.Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            width: parent.width - dismissErrBtn.width - Style.space(32)
            text: root.service ? root.service.lastError : ""
            textFormat: Text.PlainText
            color: Commons.Color.foreground
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
}
