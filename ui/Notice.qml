pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
import "../lib/Focus.js" as Focus

Ui.BorderSurface {
  id: root
  property string text: ""
  property bool error: false
  property string dismissLabel: ""
  signal dismissed()
  visible: text.length > 0
  function reveal() {
    Qt.callLater(function() {
      if (!root.text || !root.visible) return
      if (root.error) message.forceActiveFocus()
      Focus.reveal(root, true)
    })
  }
  onTextChanged: root.reveal()
  implicitHeight: Math.max(message.implicitHeight, dismiss.implicitHeight) + Commons.Style.space(12)
  color: Commons.Style.normalFill
  radius: Commons.Style.cornerRadius
  borderSpec: Commons.Border.controlSpec(message.activeFocus ? "focus" : "normal", error ? Commons.Color.urgent : Commons.Color.popups.text, Commons.Color.accent)
  TextEdit {
    id: message
    objectName: "vpnNoticeText"
    onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(message) })
    x: Commons.Style.space(8); y: Commons.Style.space(6)
    width: parent.width - dismiss.width - Commons.Style.space(24)
    height: implicitHeight
    text: root.text
    textFormat: TextEdit.PlainText
    readOnly: true
    selectByMouse: true
    activeFocusOnTab: true
    wrapMode: TextEdit.Wrap
    color: root.error ? Commons.Color.urgent : Commons.Color.popups.text
    selectionColor: Commons.Color.accent
    selectedTextColor: Commons.Color.popups.background
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.bodySmall
  }
  IconButton {
    id: dismiss
    anchors.right: parent.right
    anchors.rightMargin: Commons.Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    icon: "󰅖"
    tooltipText: root.dismissLabel
    onClicked: root.dismissed()
  }
}
