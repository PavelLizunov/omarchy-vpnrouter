import QtQuick
import qs.Commons 1.0
import qs.Commons 1.0 as Commons
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
    return I18n.t(key, args)
  }

  readonly property color statusColor: {
    switch (state) {
      case "connected":
        return Commons.Color.accent
      case "connecting":
      case "disconnecting":
        return Style.resolveStateColor("urgent", Commons.Color.foreground, Commons.Color.accent, Commons.Color.urgent)
      case "error":
        return Commons.Color.urgent
      case "disconnected":
        return Commons.Color.muted
      case "unavailable":
      default:
        return Qt.darker(Commons.Color.muted, 1.4)
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
