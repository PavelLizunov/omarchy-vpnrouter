import QtQuick
import "../lib/Focus.js" as Focus

Item {
  id: root

  property bool checked: false
  property string label: ""
  property string description: ""

  signal toggled(bool nextState)

  implicitWidth: Brand.space(36) + Brand.space(10) + labels.implicitWidth
  implicitHeight: Math.max(Brand.spacing.controlHeight, row.implicitHeight)

  activeFocusOnTab: true
  onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(root) })
  Accessible.role: Accessible.CheckBox
  Accessible.name: root.label
  Accessible.checked: root.checked

  Keys.onSpacePressed: if (root.enabled) root.toggle()
  Keys.onReturnPressed: if (root.enabled) root.toggle()
  Keys.onEnterPressed: if (root.enabled) root.toggle()

  function toggle() {
    toggled(!root.checked)
  }

  readonly property bool hot: mouseArea.containsMouse

  Row {
    id: row
    width: parent.width
    anchors.verticalCenter: parent.verticalCenter
    spacing: Brand.space(10)

    // Switch track
    Rectangle {
      id: track
      width: Brand.space(36)
      height: Brand.space(20)
      radius: height / 2
      anchors.verticalCenter: parent.verticalCenter

      color: {
        if (!root.enabled) return Brand.surfaceSunken
        if (root.checked) return Brand.accentSolid
        return Brand.normalFill
      }

      border.color: {
        if (root.activeFocus) return Brand.focusBorderColor
        if (root.checked) return Brand.accentSolid
        if (root.hot) return Brand.hoverBorderColor
        return Brand.normalBorderColor
      }
      border.width: root.activeFocus ? Brand.focusBorderWidth : Brand.normalBorderWidth

      Behavior on color { ColorAnimation { duration: 150 } }
      Behavior on border.color { ColorAnimation { duration: 150 } }

      // Switch thumb
      Rectangle {
        id: thumb
        width: Brand.space(14)
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? (track.width - width - Brand.space(3)) : Brand.space(3)
        color: root.checked ? Brand.accentOnSolid : (root.hot ? Brand.textPrimary : Qt.darker(Brand.textPrimary, 1.2))

        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 150 } }
      }
    }

    // Label column
    Column {
      id: labels
      width: Math.max(0, row.width - track.width - row.spacing)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Brand.space(2)

      Text {
        textFormat: Text.PlainText
        visible: root.label !== ""
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.label
        color: Brand.textPrimary
        font.family: Brand.font.family
        font.pixelSize: Brand.font.bodySmall
      }

      Text {
        textFormat: Text.PlainText
        visible: root.description !== ""
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.description
        color: Brand.textPrimary
        font.family: Brand.font.family
        font.pixelSize: Brand.font.caption
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
