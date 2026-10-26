import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui

// The host keeps its focus chrome; the accent edge makes the target readable
// even in themes whose focus border is deliberately faint. It owns no input.
Ui.BorderSurface {
  property bool focused: false
  objectName: "vpnFocusCue"
  anchors.left: parent.left
  anchors.top: parent.top
  anchors.bottom: parent.bottom
  width: Commons.Style.space(2)
  color: Commons.Color.accent
  radius: Commons.Style.cornerRadius
  visible: focused && parent.enabled
  z: 10
  Accessible.ignored: true
}
