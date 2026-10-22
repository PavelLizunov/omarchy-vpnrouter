pragma ComponentBehavior: Bound
import QtQuick
import "../lib/Focus.js" as Focus

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
  implicitHeight: Math.max(message.implicitHeight, dismiss.implicitHeight) + Brand.space(12)
  color: Brand.normalFill
  radius: Brand.cornerRadius
  border.color: message.activeFocus ? Brand.focusBorderColor : error ? Brand.dangerFg : Brand.normalBorderColor
  border.width: Math.max(1, Brand.normalBorderWidth)
  TextEdit {
    id: message
    objectName: "vpnNoticeText"
    onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(message) })
    x: Brand.space(8); y: Brand.space(6)
    width: parent.width - dismiss.width - Brand.space(24)
    height: implicitHeight
    text: root.text
    textFormat: TextEdit.PlainText
    readOnly: true
    selectByMouse: true
    activeFocusOnTab: true
    wrapMode: TextEdit.WrapAnywhere
    color: Brand.textPrimary
    selectionColor: Brand.accentFg
    selectedTextColor: Brand.surfaceApp
    font.family: Brand.font.family
    font.pixelSize: Brand.font.bodySmall
  }
  IconButton {
    id: dismiss
    anchors.right: parent.right
    anchors.rightMargin: Brand.space(6)
    anchors.verticalCenter: parent.verticalCenter
    icon: "󰅖"
    tooltipText: root.dismissLabel
    onClicked: root.dismissed()
  }
}
