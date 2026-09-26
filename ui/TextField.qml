import QtQuick
import qs.Commons 1.0

Item {
  id: root

  property alias text: textInput.text
  property string placeholderText: ""
  property bool isPassword: false
  property bool enabled: true
  property int echoMode: isPassword ? (showPassword ? TextInput.Normal : TextInput.Password) : TextInput.Normal
  property bool showPassword: false

  signal accepted()
  signal cleared()

  function clear() {
    textInput.text = ""
    cleared()
  }

  implicitWidth: Style.space(240)
  implicitHeight: Style.spacing.controlHeight

  activeFocusOnTab: true
  onActiveFocusChanged: if (activeFocus) textInput.forceActiveFocus()

  readonly property bool hot: mouseArea.containsMouse || textInput.activeFocus

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Style.controlFill(textInput.activeFocus, root.hot, Color.foreground, Color.accent)
    border.color: Style.controlBorder(textInput.activeFocus, root.hot, Color.foreground, Color.accent)
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
          color: root.enabled ? Color.foreground : Color.muted
          selectionColor: Color.accent
          selectedTextColor: Color.background
          clip: true
          activeFocusOnTab: false

          onAccepted: root.accepted()

          Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: textInput.text.length === 0 && !textInput.activeFocus
            text: root.placeholderText
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }
      }

      // Password visibility toggle icon
      Item {
        id: eyeBtn
        visible: root.isPassword
        width: Style.space(18)
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter

        Text {
          anchors.centerIn: parent
          text: root.showPassword ? "󰈈" : "󰈉"
          color: eyeMouseArea.containsMouse ? Color.accent : Color.muted
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
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.IBeamCursor
    onClicked: textInput.forceActiveFocus()
  }
}
