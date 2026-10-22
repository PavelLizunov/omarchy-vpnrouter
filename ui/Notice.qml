pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons 1.0
import "../lib/Focus.js" as Focus
import qs.Commons 1.0 as Commons

Rectangle {
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
  implicitHeight: Math.max(message.implicitHeight, dismiss.implicitHeight) + Style.space(12)
  color: Style.normalFill
  radius: Style.cornerRadius
  border.color: message.activeFocus ? Style.focusBorderColor : error ? Commons.Color.urgent : Style.normalBorderColor
  border.width: Math.max(1, Style.normalBorderWidth)
  TextEdit {
    id: message
    objectName: "vpnNoticeText"
    onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(message) })
    x: Style.space(8); y: Style.space(6)
    width: parent.width - dismiss.width - Style.space(24)
    height: implicitHeight
    text: root.text
    textFormat: TextEdit.PlainText
    readOnly: true
    selectByMouse: true
    activeFocusOnTab: true
    wrapMode: TextEdit.WrapAnywhere
    color: Commons.Color.foreground
    selectionColor: Commons.Color.accent
    selectedTextColor: Commons.Color.background
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }
  IconButton {
    id: dismiss
    anchors.right: parent.right
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    icon: "󰅖"
    tooltipText: root.dismissLabel
    onClicked: root.dismissed()
  }
}
