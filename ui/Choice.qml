pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import qs.Ui as Ui
import "../lib/Focus.js" as Focus

// Keep short choices side by side; let native labels keep their size when long.
Item {
  id: root
  property var options: []
  property string value: ""

  property string label: ""
  property int focusedIndex: 0
  property int optionRevision: 0
  readonly property bool stacked: width > 0 && naturalRowWidth() > width
  signal changed(string value)
  implicitHeight: row.implicitHeight
  activeFocusOnTab: enabled
  opacity: enabled ? 1 : 0.5
  Accessible.role: Accessible.Grouping
  Accessible.name: label
  onActiveFocusChanged: if (activeFocus) {
    for (var i=0;i<options.length;i++) if (options[i].value === value) focusedIndex=i
    Qt.callLater(function() { Focus.reveal(root) })
  }
  function choose(index) {
    if (enabled && index >= 0 && index < options.length && value !== options[index].value) changed(options[index].value)
  }
  function naturalRowWidth() {
    var _ = root.optionRevision
    var widest = 0
    for (var i = 0; i < optionButtons.count; i++) {
      var button = optionButtons.itemAt(i)
      if (button) widest = Math.max(widest, button.implicitWidth)
    }
    return widest * optionButtons.count + Math.max(0, optionButtons.count - 1) * Commons.Style.spacing.md
  }
  Keys.onLeftPressed: focusedIndex = Math.max(0, focusedIndex-1)
  Keys.onRightPressed: focusedIndex = Math.min(options.length-1, focusedIndex+1)
  Keys.onUpPressed: if (stacked) focusedIndex = Math.max(0, focusedIndex-1)
  Keys.onDownPressed: if (stacked) focusedIndex = Math.min(options.length-1, focusedIndex+1)
  Keys.onReturnPressed: choose(focusedIndex)
  Keys.onEnterPressed: choose(focusedIndex)
  Keys.onSpacePressed: choose(focusedIndex)
  GridLayout {
    id: row
    width: parent.width
    columns: root.stacked ? 1 : Math.max(1, root.options.length)
    columnSpacing: Commons.Style.spacing.md
    rowSpacing: Commons.Style.spacing.md
    Repeater {
      id: optionButtons
      model: root.options
      onItemAdded: root.optionRevision++
      onItemRemoved: root.optionRevision++
      Ui.Button {
        id: option
        required property var modelData
        required property int index
        objectName: "vpnChoice-" + modelData.value
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        text: modelData.label
        iconText: modelData.icon || ""
        selected: modelData.value === root.value
        bordered: true
        foreground: Commons.Color.popups.text
        hasCursor: root.activeFocus && root.focusedIndex === index
        Accessible.role: Accessible.RadioButton
        Accessible.name: modelData.label
        Accessible.checked: selected
        onClicked: { root.forceActiveFocus(); root.focusedIndex=index; root.choose(index) }
        FocusCue { focused: root.activeFocus && root.focusedIndex === option.index }
      }
    }
  }
}
