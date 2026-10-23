pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
import "../lib/I18n.js" as I18n
import "../lib/Focus.js" as Focus

Ui.BorderSurface {
  id: root
  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string currentTab: "servers"
  signal tabSelected(string tabId)
  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }
  function restoreFocus(tabId) {
    for (var i = 0; i < entries.count; i++) {
      var item = entries.itemAt(i)
      if (item && item.modelData.id === tabId) { item.forceActiveFocus(); return }
    }
  }
  readonly property var tabs: [
    {id:"servers",icon:"󰒋"}, {id:"subscriptions",icon:"󰌹"},
    {id:"apps",icon:"󰀻"}, {id:"rules",icon:"󰈶"},
    {id:"settings",icon:"󰒓"}, {id:"diagnostics",icon:"󰓙"},
    {id:"free",icon:"󰇧"}, {id:"profiles",icon:"󰘮"}, {id:"custom",icon:"󰘦"}
  ]
  implicitHeight: rows.implicitHeight + Commons.Style.space(8)
  radius: Commons.Style.cornerRadius
  color: "transparent"
  borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)
  Column {
    id: rows
    width: parent.width - Commons.Style.space(8)
    x: Commons.Style.space(4); y: Commons.Style.space(4)
    Repeater {
      id: entries
      model: root.tabs
      Item {
        id: entry
        required property var modelData
        required property int index
        objectName: "vpnTab-" + modelData.id
        width: rows.width
        height: Commons.Style.space(56)
        activeFocusOnTab: true
        onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { entry.reveal() })
        function reveal() { Focus.reveal(entry) }
        Accessible.role: Accessible.Button
        Accessible.name: root.tr("nav." + modelData.id)
        Keys.onReturnPressed: root.tabSelected(modelData.id)
        Keys.onEnterPressed: root.tabSelected(modelData.id)
        Keys.onSpacePressed: root.tabSelected(modelData.id)
        Ui.CursorSurface {
          anchors.fill: parent
          hasCursor: mouse.containsMouse || entry.activeFocus
          foreground: Commons.Color.popups.text
          borderSpec: entry.activeFocus ? Commons.Border.controlSpec("focus", foreground, accent)
            : hasCursor ? Commons.Border.controlSpec("hover-cursor", foreground, accent) : Commons.Border.none()
        }
        Text {
          x: Commons.Style.space(12); anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: entry.modelData.icon
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.heading
        }
        Column {
          x: Commons.Style.space(42); anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Commons.Style.space(72)
          spacing: Commons.Style.space(2)
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.tr("nav." + entry.modelData.id)
            color: Commons.Color.popups.text
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.body
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.tr("nav.hint." + entry.modelData.id)
            color: Commons.Color.popups.text
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            elide: Text.ElideRight
          }
        }
        Text {
          anchors.right: parent.right; anchors.rightMargin: Commons.Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          text: "›"; color: Commons.Color.popups.text
          font.family: Commons.Style.font.family; font.pixelSize: Commons.Style.font.display
        }
        Rectangle {
          visible: entry.index < root.tabs.length - 1
          x: Commons.Style.space(42); y: parent.height-1
          width: parent.width-x-Commons.Style.space(12); height: 1
          color: Commons.Style.normalBorderColor
        }
        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { entry.forceActiveFocus(); root.tabSelected(entry.modelData.id) }
        }
        FocusCue { focused: entry.activeFocus }
      }
    }
  }
}
