import QtQuick
import "../lib/Model.js" as Model
Rectangle {
  id: root
  property var latency: null
  property string label: ""
  readonly property string category: latency === null || latency === undefined || !isFinite(latency) || latency < 0 ? "Neutral" : latency < 100 ? "Fast" : latency < 200 ? "Medium" : latency < 500 ? "Slow" : "Danger"
  height: Brand.space(20)
  width: Math.max(Brand.space(58), caption.implicitWidth + Brand.space(16))
  radius: height / 2
  color: Brand["pill" + category + "Bg"]
  Text {
    id: caption
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: root.label
    color: Brand["pill" + root.category + "Fg"]
    font.family: Brand.fontFamily
    font.pixelSize: Brand.space(10)
    font.weight: Font.DemiBold
  }
}
