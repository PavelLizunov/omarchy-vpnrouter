pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../lib/Focus.js" as Focus

FocusScope {
  id: root
  property alias text: edit.text
  property alias readOnly: edit.readOnly
  property string label: ""
  property string placeholderText: ""
  signal submitted()
  implicitHeight: Brand.space(100)
  activeFocusOnTab: true
  onActiveFocusChanged: if (activeFocus) {
    edit.forceActiveFocus()
    Qt.callLater(function() { Focus.reveal(root) })
  }
  Rectangle {
    anchors.fill: parent
    color: Brand.normalFill
    radius: Brand.space(6)
    border.color: root.activeFocus ? Brand.focusBorderColor : Brand.normalBorderColor
    border.width: root.activeFocus ? Math.max(1, Brand.focusBorderWidth) : Math.max(1, Brand.normalBorderWidth)
  }
  Flickable {
    id: viewport
    objectName: "vpnEditorViewport"
    anchors.fill: parent
    anchors.margins: Brand.space(8)
    clip: true
    contentWidth: width
    contentHeight: Math.max(height, edit.implicitHeight)
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    TextEdit {
      id: edit
      objectName: "vpnEditorInput"
      width: viewport.width
      height: Math.max(viewport.height, implicitHeight)
      focus: true
      textFormat: TextEdit.PlainText
      wrapMode: TextEdit.Wrap
      selectByMouse: true
      Accessible.name: root.label
      font.family: Brand.font.family
      font.pixelSize: Brand.font.bodySmall
      color: Brand.textPrimary
      selectionColor: Brand.accentFg
      selectedTextColor: Brand.surfaceApp
      Keys.onTabPressed: function(event) {
        root.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
        event.accepted = true
      }
      Keys.onBacktabPressed: function(event) {
        root.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
        event.accepted = true
      }
      Keys.onPressed: function(event) {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
          if (!edit.readOnly) root.submitted()
          event.accepted = true
        }
      }
      onCursorRectangleChanged: {
        if (cursorRectangle.y < viewport.contentY) viewport.contentY = cursorRectangle.y
        else if (cursorRectangle.y + cursorRectangle.height > viewport.contentY + viewport.height)
          viewport.contentY = cursorRectangle.y + cursorRectangle.height - viewport.height
      }
      Text {
        width: parent.width
        visible: !edit.text.length
        text: root.placeholderText
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Brand.textPrimary
        font: edit.font
      }
    }
  }
}
