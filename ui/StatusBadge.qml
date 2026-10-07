import QtQuick
import qs.Commons 1.0
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string state: "unavailable"
  property bool showText: true

  function tr(key, args) {
    var _ = i18nRevision
    return I18n.t(key, args)
  }

  readonly property color statusColor: {
    switch (state) {
      case "connected":
        return Color.accent
      case "connecting":
      case "disconnecting":
        return Style.resolveStateColor("urgent", Color.foreground, Color.accent, Color.urgent)
      case "error":
        return Color.urgent
      case "disconnected":
        return Color.muted
      case "unavailable":
      default:
        return Qt.darker(Color.muted, 1.4)
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

    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on color { ColorAnimation { duration: 150 } }

    Row {
      id: badgeRow
      anchors.centerIn: parent
      spacing: Style.space(5)

      // Pulsing dot or glyph
      Text {
        text: root.stateGlyph
        color: root.statusColor
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter

        NumberAnimation on opacity {
          running: root.state === "connecting" || root.state === "disconnecting"
          from: 0.3
          to: 1.0
          duration: 600
          loops: Animation.Infinite
          easing.type: Easing.InOutSine
        }
      }

      Text {
        visible: root.showText
        text: root.stateTitle
        color: root.statusColor
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
