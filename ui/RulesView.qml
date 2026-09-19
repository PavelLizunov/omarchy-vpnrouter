import QtQuick
import qs.Commons 1.0
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string selectedPriority: (service && service.rules && service.rules.priority) ? service.rules.priority : "toggles_first"
  property string importExportFormat: "json"
  property string statusNotice: ""

  function tr(key, args) {
    var _ = i18nRevision
    return I18n.t(key, args)
  }

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Style.space(12)

    // Notice banner
    Rectangle {
      visible: root.statusNotice !== ""
      width: parent.width
      height: noticeRow.implicitHeight + Style.space(12)
      radius: Style.cornerRadius
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
      border.color: Color.accent
      border.width: 1

      Row {
        id: noticeRow
        anchors.fill: parent
        anchors.margins: Style.space(6)
        spacing: Style.space(8)

        Text {
          text: "󰄬"
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          width: parent.width - Style.space(40)
          text: root.statusNotice
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }

        IconButton {
          icon: "󰅖"
          anchors.verticalCenter: parent.verticalCenter
          onClicked: root.statusNotice = ""
        }
      }
    }

    // Priority Order Card
    Rectangle {
      width: parent.width
      height: prioCol.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Style.normalFill
      border.color: Style.normalBorderColor
      border.width: Style.normalBorderWidth

      Column {
        id: prioCol
        anchors.fill: parent
        anchors.margins: Style.space(10)
        spacing: Style.space(8)

        Text {
          text: root.tr("rules.priority")
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
        }

        Row {
          spacing: Style.space(12)

          Toggle {
            label: root.tr("rules.priority.toggles_first")
            checked: root.selectedPriority === "toggles_first"
            onToggled: function(val) {
              root.selectedPriority = val ? "toggles_first" : "custom_first"
            }
          }

          Toggle {
            label: root.tr("rules.priority.custom_first")
            checked: root.selectedPriority === "custom_first"
            onToggled: function(val) {
              root.selectedPriority = val ? "custom_first" : "toggles_first"
            }
          }
        }
      }
    }

    // Rules Text Area
    Rectangle {
      width: parent.width
      height: Style.space(160)
      radius: Style.cornerRadius
      color: Style.normalFill
      border.color: rulesTextEdit.activeFocus ? Style.focusBorderColor : Style.normalBorderColor
      border.width: rulesTextEdit.activeFocus ? Style.focusBorderWidth : 1

      Flickable {
        anchors.fill: parent
        anchors.margins: Style.space(8)
        contentWidth: rulesTextEdit.implicitWidth
        contentHeight: rulesTextEdit.implicitHeight
        clip: true

        TextEdit {
          id: rulesTextEdit
          width: parent.width
          wrapMode: TextEdit.Wrap
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          color: Color.foreground
          selectionColor: Color.accent
          selectedTextColor: Color.background
          text: (root.service && root.service.rules) ? (root.service.rules.text || "") : ""
        }
      }
    }

    // Action and Import/Export Row
    Row {
      width: parent.width
      spacing: Style.space(8)

      Button {
        text: root.tr("rules.saveBtn")
        variant: "primary"
        onClicked: {
          if (root.service) {
            root.service.setRules(rulesTextEdit.text, root.selectedPriority)
            root.statusNotice = root.tr("rules.importedSuccess")
          }
        }
      }

      Button {
        text: root.tr("rules.importBtn")
        variant: "normal"
        onClicked: {
          if (root.service) {
            root.service.importRules(rulesTextEdit.text, root.importExportFormat)
            root.statusNotice = root.tr("rules.importedSuccess")
          }
        }
      }

      Button {
        text: root.tr("rules.exportBtn")
        variant: "normal"
        onClicked: {
          if (root.service) {
            root.service.exportRules(root.importExportFormat, function(exported) {
              rulesTextEdit.text = exported
              root.statusNotice = "Rules exported (" + root.importExportFormat.toUpperCase() + ")"
            })
          }
        }
      }

      // Format Selector
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        Repeater {
          model: ["json", "csv", "singbox"]

          Rectangle {
            width: fmtText.implicitWidth + Style.space(12)
            height: Style.spacing.controlHeight
            radius: Style.cornerRadius
            color: root.importExportFormat === modelData ? Style.selectedFill : (fmtMouse.containsMouse ? Style.hoverFill : Style.normalFill)
            border.color: root.importExportFormat === modelData ? Color.accent : Style.normalBorderColor
            border.width: 1

            Text {
              id: fmtText
              anchors.centerIn: parent
              text: modelData.toUpperCase()
              color: root.importExportFormat === modelData ? Color.accent : Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              id: fmtMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.importExportFormat = modelData
            }
          }
        }
      }
    }
  }
}
