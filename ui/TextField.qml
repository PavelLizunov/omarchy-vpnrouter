import QtQuick
import "../lib/Focus.js" as Focus

FocusScope {
  id: root

  property alias text: textInput.text
  property string placeholderText: ""
  property bool isPassword: false
  property string passwordToggleLabel: ""
  property string passwordHideLabel: passwordToggleLabel
  property int echoMode: isPassword ? (showPassword ? TextInput.Normal : TextInput.Password) : TextInput.Normal
  property bool showPassword: false

  signal accepted()
  signal cleared()

  function clear() {
    textInput.text = ""
    root.showPassword = false
    cleared()
  }

  implicitWidth: Brand.space(240)
  implicitHeight: Brand.spacing.controlHeight

  activeFocusOnTab: true
  onActiveFocusChanged: if (activeFocus) { textInput.forceActiveFocus(); Qt.callLater(function() { Focus.reveal(root) }) }

  readonly property bool hot: mouseArea.containsMouse || textInput.activeFocus

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: Brand.space(6)
    color: Brand.controlFill(textInput.activeFocus, root.hot, Brand.textPrimary, Brand.accentFg)
    border.color: Brand.controlBorder(textInput.activeFocus, root.hot, Brand.textPrimary, Brand.accentFg)
    border.width: Brand.controlBorderWidth(textInput.activeFocus, root.hot)

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    Row {
      anchors.fill: parent
      anchors.leftMargin: Brand.spacing.controlPaddingX
      anchors.rightMargin: Brand.spacing.controlPaddingX
      spacing: Brand.space(6)

      Item {
        id: inputContainer
        width: parent.width - (eyeBtn.visible ? eyeBtn.width + Brand.space(6) : 0)
        height: parent.height

        TextInput {
          id: textInput
          anchors.fill: parent
          verticalAlignment: TextInput.AlignVCenter
          echoMode: root.echoMode
          font.family: Brand.font.family
          font.pixelSize: Brand.font.bodySmall
          color: Brand.textPrimary
          selectionColor: Brand.accentFg
          selectedTextColor: Brand.surfaceApp
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
            color: Brand.textPrimary
            font.family: Brand.font.family
            font.pixelSize: Brand.font.bodySmall
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
        Keys.onEnterPressed: root.showPassword = !root.showPassword
        Accessible.role: Accessible.CheckBox
        Accessible.name: root.showPassword ? root.passwordHideLabel : root.passwordToggleLabel
        Accessible.checked: root.showPassword
        visible: root.isPassword
        width: Brand.space(18)
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          anchors.fill: parent
          color: "transparent"
          border.color: eyeBtn.activeFocus ? Brand.focusBorderColor : "transparent"
          border.width: eyeBtn.activeFocus ? Math.max(1, Brand.focusBorderWidth) : 0
        }
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: root.showPassword ? "󰈈" : "󰈉"
          color: eyeMouseArea.containsMouse ? Brand.accentFg : Brand.textPrimary
          font.family: Brand.iconFamily
          font.pixelSize: Brand.font.iconSmall
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
