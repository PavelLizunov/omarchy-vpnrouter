import QtQuick
import qs.Commons 1.0
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property bool showImportForm: false

  function tr(key, args) {
    var _ = i18nRevision
    return I18n.t(key, args)
  }

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Style.space(10)

    Row {
      width: parent.width
      spacing: Style.space(8)

      Button {
        text: "+ " + root.tr("custom.addTitle")
        variant: root.showImportForm ? "subtle" : "primary"
        onClicked: root.showImportForm = !root.showImportForm
      }
    }

    // Collapsible Import Form
    Rectangle {
      visible: root.showImportForm
      width: parent.width
      height: importCol.implicitHeight + Style.space(20)
      radius: Style.cornerRadius
      color: Style.hoverFill
      border.color: Style.normalBorderColor
      border.width: Style.normalBorderWidth

      Column {
        id: importCol
        anchors.fill: parent
        anchors.margins: Style.space(10)
        spacing: Style.space(8)

        Text {
          text: root.tr("custom.addTitle")
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
        }

        TextField {
          id: customNameInput
          width: parent.width
          placeholderText: root.tr("custom.nameLabel")
        }

        Rectangle {
          width: parent.width
          height: Style.space(90)
          radius: Style.cornerRadius
          color: Style.normalFill
          border.color: customTextArea.activeFocus ? Style.focusBorderColor : Style.normalBorderColor
          border.width: customTextArea.activeFocus ? Style.focusBorderWidth : 1

          TextEdit {
            id: customTextArea
            anchors.fill: parent
            anchors.margins: Style.space(6)
            wrapMode: TextEdit.Wrap
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: Color.foreground
            selectionColor: Color.accent
            selectedTextColor: Color.background

            Text {
              visible: customTextArea.text.length === 0
              text: root.tr("custom.jsonLabel") + "…"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }

        Row {
          spacing: Style.space(8)

          Button {
            text: root.tr("action.import")
            variant: "primary"
            enabled: customNameInput.text.trim().length > 0 && customTextArea.text.trim().length > 0
            onClicked: {
              if (root.service) {
                var name = customNameInput.text.trim()
                var txt = customTextArea.text.trim()
                customNameInput.clear()
                customTextArea.text = ""
                root.showImportForm = false
                root.service.importCustom(name, txt)
              }
            }
          }

          Button {
            text: root.tr("action.cancel")
            variant: "subtle"
            onClicked: {
              customNameInput.clear()
              customTextArea.text = ""
              root.showImportForm = false
            }
          }
        }
      }
    }

    // Empty state
    Rectangle {
      visible: !root.service || !root.service.customConfigs || root.service.customConfigs.length === 0
      width: parent.width
      height: Style.space(120)
      radius: Style.cornerRadius
      color: Style.normalFill
      border.color: Style.normalBorderColor
      border.width: 1

      Column {
        anchors.centerIn: parent
        spacing: Style.space(8)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰘦"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.tr("custom.empty")
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }
    }

    // Custom configs list
    Repeater {
      model: root.service ? root.service.customConfigs : []

      Rectangle {
        width: column.width
        height: customRow.implicitHeight + Style.space(16)
        radius: Style.cornerRadius
        color: modelData.selected ? Style.selectedFill : (cMouse.containsMouse ? Style.hoverFill : Style.normalFill)
        border.color: modelData.selected ? Color.accent : Style.normalBorderColor
        border.width: modelData.selected ? 1 : Style.normalBorderWidth

        Row {
          id: customRow
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(10)

          Rectangle {
            width: Style.space(18)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.color: modelData.selected ? Color.accent : Color.muted
            border.width: 2

            Rectangle {
              visible: modelData.selected
              width: Style.space(8)
              height: width
              radius: width / 2
              anchors.centerIn: parent
              color: Color.accent
            }
          }

          Text {
            width: parent.width - btnRow.width - Style.space(50)
            text: modelData.name || modelData.id
            color: modelData.selected ? Color.accent : Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
          }

          Row {
            id: btnRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Button {
              text: root.tr("custom.activate")
              variant: modelData.selected ? "subtle" : "normal"
              enabled: !modelData.selected
              onClicked: if (root.service) root.service.selectCustom(modelData.id)
            }

            IconButton {
              icon: "󰆴"
              variant: "danger"
              tooltipText: root.tr("action.remove")
              onClicked: if (root.service) root.service.removeCustom(modelData.id)
            }
          }
        }

        MouseArea {
          id: cMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.service) root.service.selectCustom(modelData.id)
        }
      }
    }
  }
}
