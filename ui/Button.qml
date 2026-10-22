import QtQuick
import "../lib/Focus.js" as Focus

Item {
  id: root

  property string text: ""
  property string icon: ""
  property string variant: "normal" // "normal" | "primary" | "danger" | "subtle"
  property bool busy: false
  property bool pill: false
  property real fontSize: Brand.font.bodySmall
  property string accessibleLabel: text

  signal clicked()

  implicitWidth: Math.max(Brand.space(72), contentRow.implicitWidth + Brand.space(24))
  implicitHeight: Brand.spacing.controlHeight

  opacity: 1
  activeFocusOnTab: enabled && !busy
  onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(root) })
  Accessible.role: Accessible.Button
  Accessible.name: root.accessibleLabel

  Keys.onReturnPressed: if (root.enabled && !root.busy) root.clicked()
  Keys.onEnterPressed: if (root.enabled && !root.busy) root.clicked()
  Keys.onSpacePressed: if (root.enabled && !root.busy) root.clicked()

  readonly property bool hot: mouseArea.containsMouse
  readonly property bool pressed: mouseArea.pressed

  readonly property color bgFill: {
    if (!enabled) return Brand.surfaceSunken
    if (variant === "solid") return hot || pressed ? Brand.accentSolidHover : Brand.accentSolid
    if (variant === "danger") return Brand.dangerBg
    if (variant === "subtle") return hot || activeFocus ? Brand.accentBgSubtle : "transparent"
    return pressed ? Brand.accentBorder : hot || activeFocus ? Brand.accentBgMuted : Brand.accentBgSubtle
  }
  readonly property color textColor: !enabled ? Brand.textMuted : variant === "solid" ? Brand.accentOnSolid : variant === "danger" ? Brand.dangerFg : Brand.accentFg
  readonly property color borderColor: activeFocus ? Brand.accentSolid : variant === "danger" ? Brand.dangerBorder : "transparent"
  readonly property int borderWidth: activeFocus ? 2 : variant === "danger" ? 1 : 0

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: root.pill ? height / 2 : Brand.space(6)
    color: root.bgFill
    border.color: root.borderColor
    border.width: root.borderWidth

    Behavior on color { ColorAnimation { duration: Brand.reduceMotion ? 0 : 120 } }
    Behavior on border.color { ColorAnimation { duration: Brand.reduceMotion ? 0 : 120 } }

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Brand.space(6)

      Text {
        textFormat: Text.PlainText
        visible: root.icon !== "" && !root.busy
        text: root.icon
        color: root.textColor
        font.family: Brand.iconFamily
        font.pixelSize: Brand.font.iconSmall
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        visible: root.busy
        text: "\u{f0772}"
        color: root.textColor
        font.family: Brand.iconFamily
        font.pixelSize: Brand.font.iconSmall
        anchors.verticalCenter: parent.verticalCenter
        NumberAnimation on rotation {
          running: root.busy && root.visible && !Brand.reduceMotion
          from: 0
          to: 360
          loops: Animation.Infinite
          duration: 1000
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: root.text !== ""
        text: root.text
        color: root.textColor
        font.family: Brand.font.family
        font.pixelSize: root.fontSize
        font.weight: Font.DemiBold
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      if (root.enabled && !root.busy) {
        root.forceActiveFocus()
        root.clicked()
      }
    }
  }
}
