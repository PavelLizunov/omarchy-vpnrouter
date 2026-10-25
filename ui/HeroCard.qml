pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
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
  readonly property bool motionEnabled: !Commons.Style.reduceMotion
  readonly property bool connected: !!service && service.isConnected
  readonly property bool busy: !!service && (service.isConnecting || service.isDisconnecting || service.activeOperation === "connect" || service.activeOperation === "disconnect")
  readonly property bool operationBusy: !!service && service.busy
  readonly property bool initializing: Model.backendStarting(service)
  readonly property bool missing: !service || service.backendMissing || (service.state === "unavailable" && !initializing)
  readonly property bool failed: !!service && (service.state === "error" || service.state === "conflict")
  readonly property bool canConnect: !!service && service.capabilities && service.capabilities.connect === true && !missing && !initializing && (service.configMode === "custom" ? !!service.activeServer : service.serversLoaded && service.servers.length > 0)
  readonly property bool needsSetup: !!service && service.serversLoaded && service.subscriptionsLoaded && !service.servers.length && !service.subscriptions.length && !connected && !busy && !missing && !initializing && service.configMode !== "custom"
  readonly property color stateColor: connected ? Commons.Color.accent : busy ? Commons.Color.accent : failed || missing ? Commons.Color.urgent : Commons.Color.muted
  readonly property string availability: availabilityText()
  readonly property bool longError: !!service && !!service.lastError && (availability.length > 180 || availability.indexOf("\n") !== -1)
  function availabilityText() {
    var _ = root.i18nRevision
    if (root.connected) return ""
    if (root.service && root.service.backendMissing) return root.tr("backend.notInstalled") + "\n" + root.tr("backend.installHint")
    if (!root.service) return root.tr("backend.statusUnavailable")
    if (root.service.lastError) return root.service.lastErrorText || root.service.lastError
    if (root.initializing) return root.tr("backend.startingDetail")
    if (root.service.state === "unavailable")
      return root.service.helperPresent ? Model.unavailableText(root.service, ({t:root.tr})) : root.tr("backend.notRunning")
    if (!root.canConnect && !root.busy && !root.needsSetup) return Model.unavailableText(root.service, ({t:root.tr}))
    return ""
  }
  spacing: Commons.Style.space(6)
  Item {
    width: parent.width
    height: Commons.Style.space(152)
    Rectangle {
      id: emblem
      objectName: "vpnEmblem"
      anchors.horizontalCenter: parent.horizontalCenter
      width: Commons.Style.space(136); height: width; radius: width / 2
      color: root.connected ? Commons.Style.selectedAccentFill : root.busy ? Commons.Style.normalFill : root.failed || root.missing ? Commons.Util.alpha(Commons.Color.urgent, Commons.Style.selectedFillAlpha) : "transparent"
      // The ring leaves a gap at the bottom for the state badge; theme popup
      // surfaces can be translucent, so covering the line is not enough.
      Shape {
        id: ring
        objectName: "vpnStateRing"
        anchors.centerIn: parent
        width: Commons.Style.space(114); height: width
        readonly property real radius: width / 2 - Commons.Style.space(3) / 2
        readonly property real gapHalfAngle: Math.asin(Math.min(1, (badge.width / 2 + Commons.Style.space(4)) / radius)) * 180 / Math.PI
        ShapePath {
          strokeColor: root.stateColor
          strokeWidth: Commons.Style.space(3)
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathAngleArc { centerX: ring.width/2; centerY: ring.height/2; radiusX: ring.radius; radiusY: ring.radius; startAngle: 90 + ring.gapHalfAngle; sweepAngle: 360 - 2 * ring.gapHalfAngle }
        }
      }
      Shape {
        id: spinner
        objectName: "vpnConnectingArc"
        visible: root.busy
        anchors.centerIn: parent
        width: Commons.Style.space(114); height: width
        ShapePath {
          strokeColor: Commons.Color.accent
          strokeWidth: Commons.Style.space(3)
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathAngleArc { centerX: spinner.width/2; centerY: spinner.height/2; radiusX: spinner.width/2-1.5; radiusY: spinner.height/2-1.5; startAngle: -90; sweepAngle: 100 }
        }
        RotationAnimation on rotation { from: 0; to: 360; duration: 1100; loops: Animation.Infinite; running: root.busy && root.visible && root.motionEnabled }
      }
      Ui.BorderSurface {
        anchors.centerIn: parent
        width: Commons.Style.space(92); height: width; radius: width / 2
        color: Commons.Color.popups.background
        borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)
        Image {
          objectName: "vpnHeroMascot"
          anchors.centerIn: parent
          width: Commons.Style.space(70); height: width
          source: Brand.mascot
          fillMode: Image.PreserveAspectFit
          smooth: true
          asynchronous: true
        }
      }
      Rectangle {
        id: badge
        objectName: "vpnStateBadge"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: ring.bottom
        anchors.verticalCenterOffset: -Commons.Style.space(3) / 2
        width: Commons.Style.space(30); height: width; radius: width / 2
        color: root.connected || root.busy ? root.stateColor : Commons.Style.normalFill
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: root.connected ? "\u{f0cc8}" : root.failed || root.missing ? "\u{f0ecd}" : "\u{f0499}"
          color: root.connected || root.busy ? Commons.Color.popups.background : Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.heading
        }
      }
    }
  }
  Text {
    objectName: "vpnStateTitle"
    width: parent.width
    textFormat: Text.PlainText
    text: root.initializing ? root.tr("backend.starting") : root.failed ? root.tr("home.error") : root.needsSetup ? root.tr("home.addConfig") : root.service && root.service.state === "disconnected" ? root.tr("home.disconnected") : root.tr("state." + (root.service ? root.service.state : "unavailable"))
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    color: Commons.Color.popups.text
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.display
    font.weight: Font.DemiBold
  }
  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: root.busy ? root.tr(root.service.isDisconnecting || root.service.activeOperation === "disconnect" ? "home.disconnecting" : "home.connecting") : root.connected ? root.tr("home.active") : root.needsSetup ? root.tr("home.addHint") : (root.longError ? root.tr("error.generic") : root.availability) || root.tr(root.failed ? "error.generic" : "home.direct")
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    color: Commons.Color.popups.text
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.body
    lineHeight: 1.3
  }
  Item { width: 1; height: Commons.Style.space(6) }
  Button {
    objectName: "vpnConnect"
    width: parent.width
    implicitHeight: Commons.Style.space(48)

    fontSize: Commons.Style.font.title
    icon: "⏻"
    text: root.busy ? root.tr("home.wait") : root.connected ? root.tr("action.disconnect") : root.tr("action.connect")
    variant: root.busy ? "normal" : root.connected ? "danger" : "solid"
    enabled: !root.busy && !root.operationBusy && (root.connected || root.canConnect) && !root.needsSetup
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
  Notice {
    objectName: "vpnHomeErrorDetails"
    width: parent.width
    service: root.service
    text: root.longError ? root.availability : ""
    error: true
    detailsOnly: true
  }
}
