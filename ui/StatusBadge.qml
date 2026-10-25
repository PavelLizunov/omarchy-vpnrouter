import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  state: "unavailable"
  property bool showText: true

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  readonly property color statusColor: {
    switch (state) {
      case "connected":
        return Commons.Color.accent
      case "connecting":
      case "disconnecting":
        return Commons.Color.accent
      case "unavailable":
      case "error":
        return Commons.Color.urgent
      case "disconnected":
        return Commons.Color.muted
      default:
        return Commons.Color.muted
    }
  }

  readonly property string stateTitle: root.tr("state." + (state || "unavailable"))
  readonly property string stateGlyph: Model.stateGlyph(state)

  implicitWidth: badgeRow.implicitWidth + (showText ? Style.space(16) : Style.space(10))
  implicitHeight: Style.space(22)

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b, 0.12)
    border.color: Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b, 0.3)
    border.width: 1

    Behavior on border.color { ColorAnimation { duration: Style.duration(150) } }
    Behavior on color { ColorAnimation { duration: Style.duration(150) } }

    Row {
      id: badgeRow
      anchors.centerIn: parent
      spacing: Style.space(5)

      // Pulsing dot or glyph
      Text {
        textFormat: Text.PlainText
        text: root.stateGlyph
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter

        NumberAnimation on opacity {
          running: (root.state === "connecting" || root.state === "disconnecting") && root.visible && !Style.reduceMotion
          from: 0.3
          to: 1.0
          duration: 600
          loops: Animation.Infinite
          easing.type: Easing.InOutSine
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: root.showText
        text: root.stateTitle
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
