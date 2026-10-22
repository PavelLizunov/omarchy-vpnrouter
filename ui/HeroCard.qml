pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

Column {
  id: root
  objectName: "vpnHero"
  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  signal connectRequested()
  signal disconnectRequested()
  signal cancelRequested()
  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }
  readonly property bool connected: !!service && service.isConnected
  readonly property bool busy: !!service && (service.busy || service.isConnecting || service.isDisconnecting)
  readonly property bool missing: !service || service.backendMissing || service.state === "unavailable"
  readonly property bool failed: !!service && (service.state === "error" || service.state === "conflict")
  readonly property bool canConnect: !!service && service.capabilities && service.capabilities.connect === true && !missing
  readonly property bool needsSetup: !!service && service.serversLoaded && service.subscriptionsLoaded && !service.servers.length && !service.subscriptions.length && !connected && !busy && !missing && service.configMode !== "custom"
  readonly property color stateColor: connected ? Brand.successSolid : busy ? Brand.accentSolid : failed || missing ? Brand.dangerSolid : Brand.borderStrong
  readonly property string availability: availabilityText()
  function availabilityText() {
    var _ = root.i18nRevision
    if (root.connected) return ""
    if (root.service && root.service.backendMissing) return root.tr("backend.notInstalled") + "\n" + root.tr("backend.installHint")
    if (!root.service || root.service.state === "unavailable") return root.tr("backend.notRunning")
    if (root.service.lastError) return root.service.lastError
    if (!root.canConnect && !root.busy && !root.needsSetup) return Model.unavailableText(root.service, ({t:root.tr}))
    return ""
  }
  spacing: Brand.space(6)
  Item {
    width: parent.width
    height: Brand.space(152)
    Rectangle {
      id: emblem
      objectName: "vpnEmblem"
      anchors.horizontalCenter: parent.horizontalCenter
      width: Brand.space(136); height: width; radius: width / 2
      color: root.connected ? Brand.successBg : root.busy ? Brand.accentBgSubtle : root.failed || root.missing ? Brand.dangerBg : "transparent"
      Rectangle {
        anchors.centerIn: parent
        width: Brand.space(114); height: width; radius: width / 2
        color: "transparent"
        border.width: Brand.space(3)
        border.color: root.stateColor
      }
      Shape {
        id: spinner
        objectName: "vpnConnectingArc"
        visible: root.busy
        anchors.centerIn: parent
        width: Brand.space(114); height: width
        ShapePath {
          strokeColor: Brand.accentFg
          strokeWidth: Brand.space(3)
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathAngleArc { centerX: spinner.width/2; centerY: spinner.height/2; radiusX: spinner.width/2-1.5; radiusY: spinner.height/2-1.5; startAngle: -90; sweepAngle: 100 }
        }
        RotationAnimation on rotation { from: 0; to: 360; duration: 1100; loops: Animation.Infinite; running: root.busy && root.visible && !Brand.reduceMotion }
      }
      Rectangle {
        anchors.centerIn: parent
        width: Brand.space(92); height: width; radius: width / 2
        color: Brand.surfaceBase
        border.color: Brand.borderDefault
        Image {
          objectName: "vpnHeroMascot"
          anchors.centerIn: parent
          width: Brand.space(70); height: width
          source: Brand.mascot
          fillMode: Image.PreserveAspectFit
          smooth: true
        }
      }
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height + Brand.space(6)
        width: Brand.space(34); height: width; radius: width / 2
        color: root.connected || root.busy || root.failed || root.missing ? root.stateColor : Brand.surfaceRaised
        border.width: Brand.space(3)
        border.color: Brand.surfaceApp
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: root.connected ? "\u{f0cc8}" : root.failed || root.missing ? "\u{f0ecd}" : "\u{f0499}"
          color: root.connected || root.busy || root.failed || root.missing ? Brand.surfaceBase : Brand.textMuted
          font.family: Brand.iconFamily
          font.pixelSize: Brand.space(16)
        }
      }
    }
  }
  Text {
    objectName: "vpnStateTitle"
    width: parent.width
    textFormat: Text.PlainText
    text: root.failed ? root.tr("home.error") : root.needsSetup ? root.tr("home.addConfig") : root.service && root.service.state === "disconnected" ? root.tr("home.disconnected") : root.tr("state." + (root.service ? root.service.state : "unavailable"))
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    color: root.connected ? Brand.successFg : root.failed || root.missing ? Brand.dangerFg : Brand.textPrimary
    font.family: Brand.fontFamily
    font.pixelSize: Brand.space(22)
    font.weight: Font.DemiBold
  }
  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: root.connected ? root.tr("home.active") : root.needsSetup ? root.tr("home.addHint") : root.busy ? root.tr("home.connecting") : root.availability || root.tr(root.failed ? "error.generic" : "home.direct")
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    color: Brand.textSecondary
    font.family: Brand.fontFamily
    font.pixelSize: Brand.space(12)
    lineHeight: 1.3
  }
  Item { width: 1; height: Brand.space(6) }
  Button {
    objectName: "vpnConnect"
    width: parent.width
    implicitHeight: Brand.space(48)
    pill: true
    fontSize: Brand.space(15)
    icon: "⏻"
    text: root.busy ? root.tr("home.wait") : root.connected ? root.tr("action.disconnect") : root.tr("action.connect")
    variant: root.busy ? "normal" : root.connected ? "danger" : "solid"
    enabled: !root.busy && (root.connected || root.canConnect) && !root.needsSetup
    onClicked: { if (root.connected) root.disconnectRequested(); else root.connectRequested() }
  }
  Button {
    objectName: "vpnCancelOperation"
    visible: root.busy && !!root.service && !!root.service.activeOperation
    anchors.horizontalCenter: parent.horizontalCenter
    text: root.tr("action.cancel")
    variant: "subtle"
    onClicked: root.cancelRequested()
  }
}
