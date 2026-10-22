import QtQuick
import "../lib/Focus.js" as Focus
import qs.Commons 1.0
import qs.Commons 1.0 as Commons

FocusScope {
  id: root

  property alias text: textInput.text
  property string placeholderText: ""
  property bool isPassword: false
  property string passwordToggleLabel: ""
  property int echoMode: isPassword ? (showPassword ? TextInput.Normal : TextInput.Password) : TextInput.Normal
  property bool showPassword: false

  signal accepted()
  signal cleared()

  function clear() {
    textInput.text = ""
    root.showPassword = false
    cleared()
  }

  implicitWidth: Style.space(240)
  implicitHeight: Style.spacing.controlHeight

  activeFocusOnTab: true
  onActiveFocusChanged: if (activeFocus) { textInput.forceActiveFocus(); Qt.callLater(function() { Focus.reveal(root) }) }

  readonly property bool hot: mouseArea.containsMouse || textInput.activeFocus

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Style.controlFill(textInput.activeFocus, root.hot, Commons.Color.foreground, Commons.Color.accent)
    border.color: Style.controlBorder(textInput.activeFocus, root.hot, Commons.Color.foreground, Commons.Color.accent)
    border.width: Style.controlBorderWidth(textInput.activeFocus, root.hot)

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.spacing.controlPaddingX
      anchors.rightMargin: Style.spacing.controlPaddingX
      spacing: Style.space(6)

      Item {
        id: inputContainer
        width: parent.width - (eyeBtn.visible ? eyeBtn.width + Style.space(6) : 0)
        height: parent.height

        TextInput {
          id: textInput
          anchors.fill: parent
          verticalAlignment: TextInput.AlignVCenter
          echoMode: root.echoMode
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          color: Commons.Color.foreground
          selectionColor: Commons.Color.accent
          selectedTextColor: Commons.Color.background
          clip: true
          activeFocusOnTab: false
          focus: true
          Accessible.name: root.placeholderText

          onAccepted: root.accepted()

          Text {
            textFormat: Text.PlainText
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: textInput.text.length === 0 && !textInput.activeFocus
            text: root.placeholderText
            color: Commons.Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }
      }

      // Password visibility toggle icon
      Item {
        id: eyeBtn
        activeFocusOnTab: root.isPassword
        Keys.onSpacePressed: root.showPassword = !root.showPassword
        Keys.onReturnPressed: root.showPassword = !root.showPassword
        Accessible.role: Accessible.CheckBox
        Accessible.name: root.passwordToggleLabel
        Accessible.checked: root.showPassword
        visible: root.isPassword
        width: Style.space(18)
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: root.showPassword ? "󰈈" : "󰈉"
          color: eyeMouseArea.containsMouse ? Commons.Color.accent : Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.iconSmall
        }

        MouseArea {
          id: eyeMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.showPassword = !root.showPassword
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    z: -1
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.IBeamCursor
    onClicked: textInput.forceActiveFocus()
  }
}
