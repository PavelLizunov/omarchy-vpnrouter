import QtQuick
import qs.Commons 1.0
import qs.Commons 1.0 as Commons
import "../lib/I18n.js" as I18n
import "../lib/Model.js" as Model

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: column.implicitHeight

  readonly property var items: (service && service.diagnosticsItems) ? service.diagnosticsItems : []

  Column {
    id: column
    width: parent.width
    spacing: Style.space(12)

    // Top action row
    Row {
      width: parent.width
      spacing: Style.space(8)

      Button {
        text: "󰓅 " + root.tr("diagnostics.checkBtn")
        variant: "primary"
        onClicked: if (root.service) root.service.checkDiagnostics()
      }

      Button {
        text: "󰑤 " + root.tr("diagnostics.exportBtn")
        variant: "normal"
        onClicked: if (root.service) root.service.exportDiagnostics()
      }
    }

    // Exported Path Notification
    Rectangle {
      visible: root.service && root.service.diagnosticsExportPath !== ""
      width: parent.width
      height: exportRow.implicitHeight + Style.space(12)
      radius: Style.cornerRadius
      color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.12)
      border.color: Commons.Color.accent
      border.width: 1

      Row {
        id: exportRow
        anchors.fill: parent
        anchors.margins: Style.space(6)
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: "󰄬"
          color: Commons.Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width - Style.space(40)
          text: root.tr("diagnostics.exportedPath", [root.service ? root.service.diagnosticsExportPath : ""])
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
          elide: Text.ElideMiddle
        }

        IconButton {
          icon: "󰅖"
          anchors.verticalCenter: parent.verticalCenter
          onClicked: if (root.service) root.service.diagnosticsExportPath = ""
        }
      }
    }

    // Empty state
    Rectangle {
      visible: root.items.length === 0
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
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰓅"
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.tr("diagnostics.empty")
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }
    }

    // Diagnostics Results List
    Repeater {
      model: root.items

      Rectangle {
        width: column.width
        height: diagRow.implicitHeight + Style.space(16)
        radius: Style.cornerRadius
        color: Style.normalFill
        border.color: Style.normalBorderColor
        border.width: Style.normalBorderWidth

        Row {
          id: diagRow
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(10)

          // Status indicator badge
          Rectangle {
            id: statusPill
            width: Math.max(Style.space(52), statusLabel.implicitWidth + Style.space(16))
            height: Style.space(22)
            radius: Style.cornerRadius
            anchors.verticalCenter: parent.verticalCenter

            readonly property string st: Model.diagnosticSeverity(modelData)
            color: Style.normalFill
            border.color: st === "fail" || st === "warn" ? Commons.Color.urgent : Style.normalBorderColor
            border.width: 1

            Text {
              textFormat: Text.PlainText
              id: statusLabel
              anchors.centerIn: parent
              text: root.tr("diagnostics.severity." + statusPill.st)
              color: Commons.Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - statusPill.width - Style.space(20)
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: modelData.name || root.tr("diagnostics.fallbackName")
              wrapMode: Text.WordWrap
              color: Commons.Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              textFormat: Text.PlainText
              visible: modelData.message !== "" && modelData.message !== undefined
              width: parent.width
              text: Model.diagnosticIsUnconfigured(modelData) ? root.tr("diagnostics.notConfigured") : modelData.message || ""
              color: Commons.Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }
}
