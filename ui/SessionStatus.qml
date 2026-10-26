pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Commons as Commons
import "../lib/Model.js" as Model

Text {
  id: root
  objectName: "vpnSessionTelemetry"
  property var service: null
  property bool active: false
  readonly property var telemetry: service && service.isConnected ? service.telemetry : null
  visible: !!telemetry
  textFormat: Text.PlainText
  text: telemetry && service ? service.tr("home.sessionTelemetry", [
    Model.connectionElapsed(telemetry, clock.date.getTime()),
    Model.trafficMiB(telemetry.downloadBytes), Model.trafficMiB(telemetry.uploadBytes)]) : ""
  color: Commons.Color.popups.text
  font.family: Commons.Style.font.family
  font.pixelSize: Commons.Style.font.bodySmall
  horizontalAlignment: Text.AlignHCenter
  wrapMode: Text.WordWrap
  SystemClock {
    id: clock
    precision: SystemClock.Seconds
    enabled: root.active && root.visible
  }
}
