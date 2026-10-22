import QtQuick
import "../lib/Focus.js" as Focus

Item {
  id: root

  property string icon: ""
  property string tooltipText: ""
  property string variant: "subtle" // "subtle" | "danger" | "accent"
  property bool busy: false

  signal clicked()

  implicitWidth: Brand.spacing.controlHeight
  implicitHeight: Brand.spacing.controlHeight

  activeFocusOnTab: true
  onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(root) })
  Accessible.role: Accessible.Button
  Accessible.name: root.tooltipText

  Keys.onReturnPressed: if (root.enabled && !root.busy) root.clicked()
  Keys.onEnterPressed: if (root.enabled && !root.busy) root.clicked()
  Keys.onSpacePressed: if (root.enabled && !root.busy) root.clicked()

  readonly property bool hot: mouseArea.containsMouse
  readonly property bool pressed: mouseArea.pressed

  readonly property color iconColor: variant === "danger" ? Brand.dangerFg : variant === "accent" ? Brand.accentFg : Brand.textSecondary

  readonly property color bgFill: {
    if (pressed) return Brand.pressedFill
    if (hot || activeFocus) return Brand.hoverFill
    return "transparent"
  }

  Rectangle {
    anchors.fill: parent
    radius: Brand.cornerRadius
    color: root.bgFill
    border.color: root.activeFocus ? Brand.focusBorderColor : "transparent"
    border.width: root.activeFocus ? Brand.focusBorderWidth : 0

    Behavior on color { ColorAnimation { duration: Brand.reduceMotion ? 0 : 120 } }

    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      visible: !root.busy
      text: root.icon
      color: root.iconColor
      font.family: Brand.iconFamily
      font.pixelSize: Brand.font.iconSmall
    }

    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      visible: root.busy
      text: "󰦞"
      color: root.iconColor
      font.family: Brand.iconFamily
      font.pixelSize: Brand.font.iconSmall
      NumberAnimation on rotation {
        running: root.busy && root.visible && !Brand.reduceMotion
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
