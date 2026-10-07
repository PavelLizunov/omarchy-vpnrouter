import QtQuick
import qs.Commons 1.0

Item {
  id: root

  property string icon: ""
  property string tooltipText: ""
  property string variant: "subtle" // "subtle" | "danger" | "accent"
  property bool busy: false
  property bool enabled: true

  signal clicked()

  implicitWidth: Style.spacing.controlHeight
  implicitHeight: Style.spacing.controlHeight

  activeFocusOnTab: true

  Keys.onReturnPressed: if (root.enabled && !root.busy) root.clicked()
  Keys.onEnterPressed: if (root.enabled && !root.busy) root.clicked()
  Keys.onSpacePressed: if (root.enabled && !root.busy) root.clicked()

  readonly property bool hot: mouseArea.containsMouse
  readonly property bool pressed: mouseArea.pressed

  readonly property color iconColor: {
    if (!root.enabled) return Color.muted
    if (variant === "danger") return hot ? Color.urgent : Qt.darker(Color.urgent, 1.2)
    if (variant === "accent") return hot ? Color.accent : Qt.darker(Color.accent, 1.2)
    if (hot || activeFocus) return Color.foreground
    return Qt.darker(Color.foreground, 1.3)
  }

  readonly property color bgFill: {
    if (pressed) return Style.pressedFill
    if (hot || activeFocus) return Style.hoverFill
    return "transparent"
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.bgFill
    border.color: activeFocus ? Style.focusBorderColor : "transparent"
    border.width: activeFocus ? Style.focusBorderWidth : 0

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
      anchors.centerIn: parent
      visible: !root.busy
      text: root.icon
      color: root.iconColor
      font.family: Style.font.family
      font.pixelSize: Style.font.iconSmall
    }

    Text {
      anchors.centerIn: parent
      visible: root.busy
      text: "󰦞"
      color: root.iconColor
      font.family: Style.font.family
      font.pixelSize: Style.font.iconSmall
      NumberAnimation on rotation {
        running: root.busy
        from: 0
        to: 360
        loops: Animation.Infinite
        duration: 1000
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      if (root.enabled && !root.busy) {
        root.forceActiveFocus()
        root.clicked()
      }
    }
  }
}
