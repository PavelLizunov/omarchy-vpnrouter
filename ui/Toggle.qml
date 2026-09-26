import QtQuick
import qs.Commons 1.0

Item {
  id: root

  property bool checked: false
  property string label: ""
  property string description: ""
  property bool enabled: true

  signal toggled(bool nextState)

  implicitWidth: row.implicitWidth
  implicitHeight: Math.max(Style.spacing.controlHeight, row.implicitHeight)

  activeFocusOnTab: true

  Keys.onSpacePressed: if (root.enabled) root.toggle()
  Keys.onReturnPressed: if (root.enabled) root.toggle()
  Keys.onEnterPressed: if (root.enabled) root.toggle()

  function toggle() {
    var next = !checked
    checked = next
    toggled(next)
  }

  readonly property bool hot: mouseArea.containsMouse

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(10)

    // Switch track
    Rectangle {
      id: track
      width: Style.space(36)
      height: Style.space(20)
      radius: height / 2
      anchors.verticalCenter: parent.verticalCenter

      color: {
        if (!root.enabled) return Qt.rgba(0.2, 0.2, 0.2, 0.3)
        if (root.checked) return Color.accent
        return Style.normalFill
      }

      border.color: {
        if (root.activeFocus) return Style.focusBorderColor
        if (root.checked) return Color.accent
        if (root.hot) return Style.hoverBorderColor
        return Style.normalBorderColor
      }
      border.width: root.activeFocus ? Style.focusBorderWidth : Style.normalBorderWidth

      Behavior on color { ColorAnimation { duration: 150 } }
      Behavior on border.color { ColorAnimation { duration: 150 } }

      // Switch thumb
      Rectangle {
        id: thumb
        width: Style.space(14)
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? (track.width - width - Style.space(3)) : Style.space(3)
        color: root.checked ? Color.background : (root.hot ? Color.foreground : Qt.darker(Color.foreground, 1.2))

        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 150 } }
      }
    }

    // Label column
    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        visible: root.label !== ""
        text: root.label
        color: root.enabled ? Color.foreground : Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        visible: root.description !== ""
        text: root.description
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      if (root.enabled) {
        root.forceActiveFocus()
        root.toggle()
      }
    }
  }
}
