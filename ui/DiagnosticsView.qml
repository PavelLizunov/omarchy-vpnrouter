import QtQuick
import qs.Commons 1.0
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0

  function tr(key, args) {
    var _ = i18nRevision
    return I18n.t(key, args)
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
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
      border.color: Color.accent
      border.width: 1

      Row {
        id: exportRow
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
          text: root.tr("diagnostics.exportedPath", [root.service ? root.service.diagnosticsExportPath : ""])
          color: Color.foreground
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
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰓅"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.tr("diagnostics.empty")
          color: Color.muted
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
            width: Style.space(52)
            height: Style.space(22)
            radius: Style.cornerRadius
            anchors.verticalCenter: parent.verticalCenter

            readonly property string st: String(modelData.status || "").toUpperCase()
            color: {
              if (st === "PASS" || st === "OK") return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
              if (st === "FAIL" || st === "ERROR") return Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.15)
              return Qt.rgba(0.9, 0.7, 0.2, 0.15) // Warning
            }
            border.color: {
              if (st === "PASS" || st === "OK") return Color.accent
              if (st === "FAIL" || st === "ERROR") return Color.urgent
              return "#d4a017"
            }
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: {
                if (statusPill.st === "PASS" || statusPill.st === "OK") return root.tr("diagnostics.statusPass")
                if (statusPill.st === "FAIL" || statusPill.st === "ERROR") return root.tr("diagnostics.statusFail")
                return root.tr("diagnostics.statusWarn")
              }
              color: statusPill.border.color
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - statusPill.width - Style.space(20)
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: modelData.name || "Check"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              visible: modelData.message !== "" && modelData.message !== undefined
              width: parent.width
              text: modelData.message || ""
              color: Color.muted
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
