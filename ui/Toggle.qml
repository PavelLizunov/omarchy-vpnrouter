import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui
import "../lib/Focus.js" as Focus

Item {
  id: root
  property bool checked: false
  property string label: ""
  property string accessibleLabel: label
  property string description: ""
  readonly property bool compact: !label && !description
  signal toggled(bool nextState)
  implicitWidth: compact ? track.implicitWidth : Commons.Style.space(240)
  implicitHeight: compact ? track.implicitHeight : content.implicitHeight
  activeFocusOnTab: true
  onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(root) })
  Accessible.role: Accessible.CheckBox
  Accessible.name: accessibleLabel
  Accessible.description: description
  Accessible.checked: checked
  Keys.onReturnPressed: if (enabled) toggled(!checked)
  Keys.onEnterPressed: if (enabled) toggled(!checked)
  Keys.onSpacePressed: if (enabled) toggled(!checked)
  Ui.ToggleSwitch {
    id: track
    opacity: root.enabled ? 1 : 0.5
    visible: root.compact
    anchors.centerIn: parent
    checked: root.checked
    hasCursor: root.activeFocus
    foreground: Commons.Color.popups.text
    onToggled: { root.forceActiveFocus(); root.toggled(!root.checked) }
  }
  Column {
    id: content
    visible: !root.compact
    width: parent.width
    spacing: Commons.Style.spacing.xs
    Ui.Toggle {
      id: row
      opacity: root.enabled ? 1 : 0.5
      width: parent.width
      activeFocusOnTab: false
      label: root.label
      checked: root.checked
      hasCursor: root.activeFocus || descriptionMouse.containsMouse
      foreground: Commons.Color.popups.text
      onClicked: { root.forceActiveFocus(); root.toggled(!root.checked) }
    }
    Text {
      objectName: "vpnToggleDescription"
      visible: root.description !== ""
      x: Commons.Border.left(row.borderSpec) + Commons.Style.spacing.rowPaddingX
      width: parent.width - x * 2
      text: root.description
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: Commons.Color.popups.text
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.caption
      MouseArea {
        id: descriptionMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.forceActiveFocus(); root.toggled(!root.checked) }
      }
    }
  }
  FocusCue { focused: root.activeFocus }
}
