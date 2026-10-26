import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui
import "../lib/Focus.js" as Focus

FocusScope {
  id: root
  property alias text: input.text
  property string placeholderText: ""
  property bool isPassword: false
  property string passwordToggleLabel: ""
  property string passwordHideLabel: passwordToggleLabel
  property bool showPassword: false
  property int echoMode: isPassword && !showPassword ? TextInput.Password : TextInput.Normal
  signal accepted()
  signal cleared()
  function clear() { input.clear(); showPassword = false; cleared() }
  function focusInput() { input.forceActiveFocus() }
  implicitWidth: Commons.Style.spacing.dropdownWidth
  implicitHeight: Math.max(Commons.Style.spacing.controlHeight, input.implicitHeight)
  onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(root) })
  Ui.TextField {
    id: input
    anchors.fill: parent
    focus: true
    activeFocusOnTab: true
    placeholderText: root.placeholderText
    echoMode: root.echoMode
    foreground: Commons.Color.popups.text
    rightPadding: (eye.visible ? eye.width : 0) + horizontalPadding + Commons.Border.right(_borderSpec)
    Accessible.name: root.placeholderText
    onAccepted: root.accepted()
  }
  IconButton {
    id: eye
    visible: root.isPassword
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    icon: root.showPassword ? "󰈈" : "󰈉"
    tooltipText: root.showPassword ? root.passwordHideLabel : root.passwordToggleLabel
    Accessible.role: Accessible.CheckBox
    Accessible.checked: root.showPassword
    onClicked: root.showPassword = !root.showPassword
  }
  FocusCue { focused: root.activeFocus && !eye.activeFocus }
}
