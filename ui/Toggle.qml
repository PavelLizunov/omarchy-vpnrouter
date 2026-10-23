import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui
import "../lib/Focus.js" as Focus

Item {
  id: root
  property bool checked: false
  property string label: ""
  property string description: ""
  readonly property bool compact: !label && !description
  signal toggled(bool nextState)
  implicitWidth: compact ? track.implicitWidth : Commons.Style.space(240)
  implicitHeight: compact ? track.implicitHeight : row.implicitHeight
  activeFocusOnTab: true
  onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(root) })
  Accessible.role: Accessible.CheckBox
  Accessible.name: label
  Accessible.checked: checked
  Keys.onReturnPressed: if (enabled) toggled(!checked)
  Keys.onEnterPressed: if (enabled) toggled(!checked)
  Keys.onSpacePressed: if (enabled) toggled(!checked)
  Ui.ToggleSwitch {
    id: track
    visible: root.compact
    anchors.centerIn: parent
    checked: root.checked
    hasCursor: root.activeFocus
    foreground: Commons.Color.popups.text
    onToggled: { root.forceActiveFocus(); root.toggled(!root.checked) }
  }
  Ui.Toggle {
    id: row
    visible: !root.compact
    anchors.fill: parent
    activeFocusOnTab: false
    label: root.label
    description: root.description
    checked: root.checked
    hasCursor: root.activeFocus
    foreground: Commons.Color.popups.text
    onClicked: { root.forceActiveFocus(); root.toggled(!root.checked) }
  }
}
