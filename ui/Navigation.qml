pragma ComponentBehavior: Bound
import QtQuick
import "../lib/I18n.js" as I18n
import "../lib/Focus.js" as Focus

Rectangle {
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
  implicitHeight: rows.implicitHeight + Brand.space(8)
  radius: Brand.cardRadius
  color: "transparent"
  border.color: Brand.borderDefault
  Column {
    id: rows
    width: parent.width - Brand.space(8)
    x: Brand.space(4); y: Brand.space(4)
    Repeater {
      id: entries
      model: root.tabs
      Item {
        id: entry
        required property var modelData
        required property int index
        objectName: "vpnTab-" + modelData.id
        width: rows.width
        height: Brand.space(56)
        activeFocusOnTab: true
        onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { entry.reveal() })
        function reveal() { Focus.reveal(entry) }
        Accessible.role: Accessible.Button
        Accessible.name: root.tr("nav." + modelData.id)
        Keys.onReturnPressed: root.tabSelected(modelData.id)
        Keys.onEnterPressed: root.tabSelected(modelData.id)
        Keys.onSpacePressed: root.tabSelected(modelData.id)
        Rectangle {
          anchors.fill: parent
          radius: Brand.space(10)
          color: mouse.pressed ? Brand.accentBgMuted : mouse.containsMouse || entry.activeFocus ? Brand.accentBgSubtle : "transparent"
          border.color: entry.activeFocus ? Brand.accentSolid : "transparent"
          border.width: entry.activeFocus ? 2 : 0
        }
        Text {
          x: Brand.space(12); anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: entry.modelData.icon
          color: Brand.textSecondary
          font.family: Brand.iconFamily
          font.pixelSize: Brand.space(18)
        }
        Column {
          x: Brand.space(42); anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Brand.space(72)
          spacing: Brand.space(2)
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.tr("nav." + entry.modelData.id)
            color: Brand.textPrimary
            font.family: Brand.fontFamily
            font.pixelSize: Brand.space(12)
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.tr("nav.hint." + entry.modelData.id)
            color: Brand.textMuted
            font.family: Brand.fontFamily
            font.pixelSize: Brand.space(10)
            elide: Text.ElideRight
          }
        }
        Text {
          anchors.right: parent.right; anchors.rightMargin: Brand.space(12)
          anchors.verticalCenter: parent.verticalCenter
          text: "›"; color: Brand.textMuted
          font.family: Brand.fontFamily; font.pixelSize: Brand.space(22)
        }
        Rectangle {
          visible: entry.index < root.tabs.length - 1
          x: Brand.space(42); y: parent.height-1
          width: parent.width-x-Brand.space(12); height: 1
          color: Brand.borderSubtle
        }
        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { entry.forceActiveFocus(); root.tabSelected(entry.modelData.id) }
        }
      }
    }
  }
}
