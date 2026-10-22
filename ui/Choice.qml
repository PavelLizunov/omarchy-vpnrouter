pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../lib/Focus.js" as Focus

Rectangle {
  id: root
  property var options: []
  property string value: ""
  property bool pill: false
  property string label: ""
  property int focusedIndex: 0
  signal changed(string value)
  implicitHeight: row.implicitHeight + (pill ? Brand.space(8) : 0)
  color: pill ? Brand.surfaceSunken : "transparent"
  radius: pill ? height/2 : 0
  activeFocusOnTab: enabled
  opacity: enabled ? 1 : 0.6
  Accessible.role: Accessible.Grouping
  Accessible.name: label
  onActiveFocusChanged: if (activeFocus) {
    for (var i=0;i<options.length;i++) if (options[i].value === value) focusedIndex=i
    Qt.callLater(function() { Focus.reveal(root) })
  }
  function choose(index) {
    if (enabled && index >= 0 && index < options.length && value !== options[index].value) changed(options[index].value)
  }
  Keys.onLeftPressed: focusedIndex = Math.max(0, focusedIndex-1)
  Keys.onRightPressed: focusedIndex = Math.min(options.length-1, focusedIndex+1)
  Keys.onReturnPressed: choose(focusedIndex)
  Keys.onEnterPressed: choose(focusedIndex)
  Keys.onSpacePressed: choose(focusedIndex)
  RowLayout {
    id: row
    x: root.pill ? Brand.space(4) : 0
    y: x
    width: root.width - x*2
    spacing: Brand.space(4)
    Repeater {
      model: root.options
      Rectangle {
        id: option
        required property var modelData
        required property int index
        readonly property bool selected: modelData.value === root.value
        signal clicked()
        onClicked: { root.forceActiveFocus(); root.focusedIndex=index; root.choose(index) }
        objectName: "vpnChoice-" + modelData.value
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        implicitHeight: Math.max(Brand.space(36), caption.implicitHeight + Brand.space(12))
        radius: root.pill ? height/2 : Brand.space(6)
        color: selected ? (root.pill ? Brand.surfaceOverlay : Brand.accentBgMuted) : mouse.containsMouse ? Brand.accentBgSubtle : root.pill ? "transparent" : Brand.surfaceBase
        border.color: root.activeFocus && root.focusedIndex === index ? Brand.accentSolid : root.pill ? "transparent" : selected ? Brand.accentBorder : Brand.borderDefault
        border.width: root.activeFocus && root.focusedIndex === index ? 2 : root.pill ? 0 : 1
        Accessible.role: Accessible.RadioButton
        Accessible.name: modelData.label
        Accessible.checked: selected
        Text {
          id: glyph
          visible: !!option.modelData.icon
          x: caption.x - width - Brand.space(6); anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: option.modelData.icon || ""
          color: option.selected ? Brand.accentFg : Brand.textSecondary
          font.family: Brand.iconFamily; font.pixelSize: Brand.space(16)
        }
        Text {
          id: caption
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, parent.width - Brand.space(16) - (glyph.visible ? glyph.width + Brand.space(6) : 0))
          x: (parent.width - width + (glyph.visible ? glyph.width + Brand.space(6) : 0))/2
          textFormat: Text.PlainText
          text: option.modelData.label
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          color: option.selected && !root.pill ? Brand.accentFg : option.selected ? Brand.textPrimary : Brand.textSecondary
          font.family: Brand.fontFamily; font.pixelSize: Brand.space(12)
          font.weight: option.selected ? Font.DemiBold : Font.Normal
        }
        MouseArea {
          id: mouse
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: option.clicked()
        }
      }
    }
  }
}
