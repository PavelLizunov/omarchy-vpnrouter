import QtQuick
import qs.Commons as Commons

Rectangle {
  id: root
  property var latency: null
  property string label: ""
  readonly property bool known: latency !== null && latency !== undefined && isFinite(latency) && latency >= 0
  readonly property color statusColor: !known ? Commons.Color.muted : latency >= 500 ? Commons.Color.urgent : Commons.Color.accent
  height: caption.implicitHeight + Commons.Style.spacing.sm * 2
  width: caption.implicitWidth + Commons.Style.spacing.lg * 2
  radius: Commons.Style.cornerRadius
  color: Commons.Util.alpha(statusColor, Commons.Style.normalFillAlpha)
  Text {
    id: caption
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: root.label
    color: Commons.Color.popups.text
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.caption
  }
}
