import QtQuick
import "../lib/I18n.js" as I18n
import "../lib/Model.js" as Model

Item {
  id: root
  objectName: "vpnDiagnosticsView"

  property var service: null
  property string noticeKey: ""
  property bool noticeError: false
  property int i18nRevision: service ? service.i18nRevision : 0

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  function exportBundle() {
    if (!root.service || root.service.activeOperation === "diagnostics.export") return
    root.noticeError = false; root.noticeKey = "operation.pending"
    root.service.exportDiagnostics(function(path) {
      root.noticeKey = path ? "" : "diagnostics.exportFailed"
      root.noticeError = !path
    }, function() { root.noticeError = true; root.noticeKey = "diagnostics.exportFailed" })
  }

  implicitWidth: parent ? parent.width : Brand.space(480)
  implicitHeight: column.implicitHeight

  readonly property var items: (service && service.diagnosticsItems) ? service.diagnosticsItems : []

  Column {
    id: column
    width: parent.width
    spacing: Brand.space(12)

    // Top action row
    Flow {
      width: parent.width
      spacing: Brand.space(8)

      Button {
        icon: "󰓅"
        text: root.tr("diagnostics.checkBtn")
        variant: "primary"
        onClicked: if (root.service) root.service.checkDiagnostics()
      }

      Button {
        icon: "󰑤"
        text: root.tr("diagnostics.exportBtn")
        variant: "normal"
        onClicked: root.exportBundle()
        enabled: !root.service || root.service.activeOperation !== "diagnostics.export"
      }
    }

    Notice {
      width: parent.width
      text: root.noticeKey ? root.tr(root.noticeKey) : root.service && root.service.diagnosticsExportPath ? root.tr("diagnostics.exportedPath", [root.service.diagnosticsExportPath]) : ""
      error: root.noticeError
      dismissLabel: root.tr("action.dismiss")
      onDismissed: { root.noticeKey = ""; if (root.service) root.service.diagnosticsExportPath = "" }
    }

    // Empty state
    Rectangle {
      visible: root.items.length === 0
      width: parent.width
      height: Brand.space(120)
      radius: Brand.cornerRadius
      color: Brand.normalFill
      border.color: Brand.normalBorderColor
      border.width: 1

      Column {
        anchors.centerIn: parent
        spacing: Brand.space(8)

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰓅"
          color: Brand.textPrimary
          font.family: Brand.iconFamily
          font.pixelSize: Brand.font.display
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.tr("diagnostics.empty")
          color: Brand.textPrimary
          font.family: Brand.font.family
          font.pixelSize: Brand.font.bodySmall
        }
      }
    }

    // Diagnostics Results List
    Repeater {
      model: root.items

      Rectangle {
        width: column.width
        height: diagRow.implicitHeight + Brand.space(16)
        radius: Brand.cornerRadius
        color: Brand.normalFill
        border.color: Brand.normalBorderColor
        border.width: Brand.normalBorderWidth

        Row {
          id: diagRow
          anchors.fill: parent
          anchors.margins: Brand.space(8)
          spacing: Brand.space(10)

          // Status indicator badge
          Rectangle {
            id: statusPill
            width: Math.max(Brand.space(52), statusLabel.implicitWidth + Brand.space(16))
            height: Brand.space(22)
            radius: Brand.cornerRadius
            anchors.verticalCenter: parent.verticalCenter

            readonly property string st: Model.diagnosticSeverity(modelData)
            color: Brand.normalFill
            border.color: st === "fail" || st === "warn" ? Brand.dangerFg : Brand.normalBorderColor
            border.width: 1

            Text {
              textFormat: Text.PlainText
              id: statusLabel
              anchors.centerIn: parent
              text: root.tr("diagnostics.severity." + statusPill.st)
              color: Brand.textPrimary
              font.family: Brand.font.family
              font.pixelSize: Brand.font.caption
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - statusPill.width - Brand.space(20)
            spacing: Brand.space(2)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: modelData.name || root.tr("diagnostics.fallbackName")
              wrapMode: Text.WordWrap
              color: Brand.textPrimary
              font.family: Brand.font.family
              font.pixelSize: Brand.font.bodySmall
            }

            Text {
              textFormat: Text.PlainText
              visible: modelData.message !== "" && modelData.message !== undefined
              width: parent.width
              text: Model.diagnosticIsUnconfigured(modelData) ? root.tr("diagnostics.notConfigured") : modelData.message || ""
              color: Brand.textPrimary
              font.family: Brand.font.family
              font.pixelSize: Brand.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }
}
