import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui
import "../lib/Focus.js" as Focus

// Preserve the plugin action API while the host paints and sizes the control.
Item {
  id: root
  property string text: ""
  property string icon: ""
  property string tooltipText: ""
  property string variant: "normal"
  property bool busy: false

  property real fontSize: Commons.Style.font.body
  property string accessibleLabel: text
  signal clicked()
  implicitWidth: control.implicitWidth
  implicitHeight: Math.max(Commons.Style.spacing.controlHeight, control.implicitHeight)
  activeFocusOnTab: enabled && !busy
  onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(root) })
  Accessible.role: Accessible.Button
  Accessible.name: accessibleLabel
  Keys.onReturnPressed: if (enabled && !busy) clicked()
  Keys.onEnterPressed: if (enabled && !busy) clicked()
  Keys.onSpacePressed: if (enabled && !busy) clicked()
  Ui.Button {
    id: control
    anchors.fill: parent
    enabled: root.enabled && !root.busy
    text: root.text
    tooltipText: root.tooltipText
    iconText: root.busy ? "\u{f0772}" : root.icon
    iconSpinning: root.busy
    fontSize: root.fontSize
    foreground: Commons.Color.popups.text
    accent: root.variant === "danger" ? Commons.Color.urgent : Commons.Color.accent
    background: root.variant === "solid" || root.variant === "primary" ? Commons.Style.selectedAccentFill : "transparent"
    bordered: root.variant !== "subtle"
    hasCursor: root.activeFocus
    borderSpec: root.activeFocus ? Commons.Border.controlSpec("focus", foreground, accent) : _borderSpec
    opacity: root.enabled ? 1 : 0.5
    onClicked: { root.forceActiveFocus(); root.clicked() }
  }
  FocusCue { focused: root.activeFocus && !root.busy }
}
