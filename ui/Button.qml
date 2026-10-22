import QtQuick
import "../lib/Focus.js" as Focus
import qs.Commons 1.0
import qs.Commons 1.0 as Commons

Item {
  id: root

  property string text: ""
  property string icon: ""
  property string variant: "normal" // "normal" | "primary" | "danger" | "subtle"
  property bool busy: false

  signal clicked()

  implicitWidth: Math.max(Style.space(72), contentRow.implicitWidth + Style.space(24))
  implicitHeight: Style.spacing.controlHeight

  opacity: enabled ? 1 : 0.4
  activeFocusOnTab: enabled && !busy
  onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(root) })
  Accessible.role: Accessible.Button
  Accessible.name: root.text

  Keys.onReturnPressed: if (root.enabled && !root.busy) root.clicked()
  Keys.onEnterPressed: if (root.enabled && !root.busy) root.clicked()
  Keys.onSpacePressed: if (root.enabled && !root.busy) root.clicked()

  readonly property bool hot: mouseArea.containsMouse
  readonly property bool pressed: mouseArea.pressed

  readonly property color baseColor: {
    if (variant === "primary") return Commons.Color.accent
    if (variant === "danger") return Commons.Color.urgent
    return Commons.Color.foreground
  }

  readonly property color bgFill: {
    if (!root.enabled) return Style.normalFill
    if (variant === "primary" || variant === "danger") {
      if (pressed) return Style.pressedFill
      if (hot || activeFocus) return Style.hoverFill
      return Style.selectedFill
    }
    if (variant === "subtle") {
      if (pressed) return Style.pressedFill
      if (hot || activeFocus) return Style.hoverFill
      return "transparent"
    }
    // Normal
    if (pressed) return Style.pressedFill
    if (hot || activeFocus) return Style.hoverFill
    return Style.normalFill
  }

  readonly property color textColor: {
    if (!root.enabled) return Commons.Color.foreground
    if (variant === "primary" || variant === "danger") return Commons.Color.foreground
    return Commons.Color.foreground
  }

  readonly property color borderColor: {
    if (!root.enabled) return Style.normalBorderColor
    if (activeFocus) return Style.focusBorderColor
    if (variant === "primary") return Commons.Color.accent
    if (variant === "danger") return Commons.Color.urgent
    if (hot) return Style.hoverBorderColor
    return Style.normalBorderColor
  }

  readonly property int borderWidth: activeFocus ? Math.max(1, Style.focusBorderWidth) : (variant === "subtle" ? 0 : Style.normalBorderWidth)

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.bgFill
    border.color: root.borderColor
    border.width: root.borderWidth

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        visible: root.icon !== "" && !root.busy
        text: root.icon
        color: root.textColor
        font.family: Style.font.family
        font.pixelSize: Style.font.iconSmall
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        visible: root.busy
        text: "\u{f0772}"
        color: root.textColor
        font.family: Style.font.family
        font.pixelSize: Style.font.iconSmall
        anchors.verticalCenter: parent.verticalCenter
        NumberAnimation on rotation {
          running: root.busy
          from: 0
          to: 360
          loops: Animation.Infinite
          duration: 1000
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: root.text !== ""
        text: root.text
        color: root.textColor
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        anchors.verticalCenter: parent.verticalCenter
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
