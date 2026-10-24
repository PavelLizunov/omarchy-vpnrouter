import QtQuick
import qs.Commons as Commons
// Offscreen adapter: only replaces layer-shell window, not the plugin content.
Item {
 id: root
 property var anchorItem: null
 property var owner: null
 property var bar: null
 property bool open: false
 property var focusTarget: null
 property int contentWidth: 540
 property int contentHeight: 640
 property int availableWidth: parent ? parent.width : 540
 property int availableHeight: parent ? parent.height : 640
 property int padding: Commons.Style.spacing.popupPadding
 property Component content: null
 property bool contentRequested: false
 readonly property Item loadedContent: loader.item
 readonly property real loadedContentHeight: loader.item ? loader.item.implicitHeight : 0
 function ensureContent() { contentRequested = true; return loader.item }
 default property alias contentItem: holder.children
 width: contentWidth
 height: contentHeight
 function fittedContentWidth(value) { return Math.min(value, availableWidth) }
 function fittedContentHeight(value, cap) { return Math.min(value + padding*2, cap || 10000, availableHeight) }
 onOpenChanged: if (open && focusTarget) Qt.callLater(function() { focusTarget.forceActiveFocus() })
 Item {
  id: holder; anchors.fill: parent; anchors.margins: root.padding
  Loader { id: loader; anchors.fill: parent; active: root.contentRequested; sourceComponent: root.content }
 }
}
