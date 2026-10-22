import QtQuick
import "../lib/Focus.js" as Focus
import qs.Commons 1.0
import qs.Commons 1.0 as Commons

Item {
  id: root

  property bool checked: false
  property string label: ""
  property string description: ""

  signal toggled(bool nextState)

  implicitWidth: Style.space(36) + Style.space(10) + labels.implicitWidth
  implicitHeight: Math.max(Style.spacing.controlHeight, row.implicitHeight)

  activeFocusOnTab: true
  onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(root) })
  Accessible.role: Accessible.CheckBox
  Accessible.name: root.label
  Accessible.checked: root.checked

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
    width: parent.width
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
        if (root.checked) return Commons.Color.accent
        return Style.normalFill
      }

      border.color: {
        if (root.activeFocus) return Style.focusBorderColor
        if (root.checked) return Commons.Color.accent
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
        color: root.checked ? Commons.Color.background : (root.hot ? Commons.Color.foreground : Qt.darker(Commons.Color.foreground, 1.2))

        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 150 } }
      }
    }

    // Label column
    Column {
      id: labels
      width: Math.max(0, row.width - track.width - row.spacing)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        textFormat: Text.PlainText
        visible: root.label !== ""
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.label
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        textFormat: Text.PlainText
        visible: root.description !== ""
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.description
        color: Commons.Color.foreground
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
