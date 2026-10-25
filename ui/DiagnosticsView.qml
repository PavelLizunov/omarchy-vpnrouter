import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
import "../lib/I18n.js" as I18n
import "../lib/Model.js" as Model

Item {
  id: root
  objectName: "vpnDiagnosticsView"

  property var service: null
  readonly property bool loading: !!service && ["diagnostics.check"].indexOf(service.activeOperation) !== -1
  readonly property bool loadFailed: !!service && !!service.lastError && ["diagnostics.check"].indexOf(service.lastErrorMethod) !== -1
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

  implicitWidth: parent ? parent.width : Commons.Style.space(480)
  implicitHeight: column.implicitHeight

  readonly property var items: (service && service.diagnosticsItems) ? service.diagnosticsItems : []

  Column {
    id: column
    width: parent.width
    spacing: Commons.Style.space(12)

    // Top action row
    Flow {
      width: parent.width
      spacing: Commons.Style.space(8)

      Button {
        icon: "󰓙"
        busy: root.loading
        text: root.tr("diagnostics.checkBtn")
        variant: "primary"
        onClicked: if (root.service) root.service.checkDiagnostics()
      }

      Button {
        icon: "󰈇"
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
    Ui.BorderSurface {
      visible: root.items.length === 0
      width: parent.width
      height: Math.max(Commons.Style.space(120), emptyContent.implicitHeight + Commons.Style.space(32))
      radius: Commons.Style.cornerRadius
      color: Commons.Style.normalFill
      borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)

      Column {
        id: emptyContent
        width: parent.width - Commons.Style.space(32)
        anchors.centerIn: parent
        spacing: Commons.Style.space(8)

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰓙"
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.display
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: root.loading ? root.tr("diagnostics.loading") : !root.service || root.loadFailed ? root.tr("state.unavailable") : root.tr("diagnostics.empty")
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.bodySmall
        }
      }
    }

    // Diagnostics Results List
    Repeater {
      model: root.items

      Ui.BorderSurface {
        id: diagnosticResult
        readonly property bool messageOnly: modelData.name === "HealthCheck" && typeof modelData.message === "string" && modelData.message.length > 0
        width: column.width
        height: diagRow.implicitHeight + Commons.Style.space(16)
        radius: Commons.Style.cornerRadius
        color: Commons.Style.normalFill
        borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)

        Row {
          id: diagRow
          anchors.fill: parent
          anchors.margins: Commons.Style.space(8)
          spacing: Commons.Style.space(10)

          // Status indicator badge
          Ui.BorderSurface {
            id: statusPill
            width: Math.max(Commons.Style.space(52), statusLabel.implicitWidth + Commons.Style.space(16))
            height: Commons.Style.space(22)
            radius: Commons.Style.cornerRadius
            anchors.verticalCenter: parent.verticalCenter

            readonly property string st: Model.diagnosticSeverity(modelData)
            color: Commons.Style.normalFill
            borderSpec: Commons.Border.controlSpec("normal", st === "fail" || st === "warn" ? Commons.Color.urgent : Commons.Color.popups.text, Commons.Color.accent)

            Text {
              textFormat: Text.PlainText
              id: statusLabel
              anchors.centerIn: parent
              text: root.tr("diagnostics.severity." + statusPill.st)
              color: Commons.Color.popups.text
              font.family: Commons.Style.font.family
              font.pixelSize: Commons.Style.font.caption
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - statusPill.width - Commons.Style.space(20)
            spacing: Commons.Style.space(2)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: modelData.name || root.tr("diagnostics.fallbackName")
              visible: !diagnosticResult.messageOnly
              wrapMode: Text.WordWrap
              color: Commons.Color.popups.text
              font.family: Commons.Style.font.family
              font.pixelSize: Commons.Style.font.bodySmall
            }

            Text {
              textFormat: Text.PlainText
              visible: modelData.message !== "" && modelData.message !== undefined
              width: parent.width
              text: Model.diagnosticIsUnconfigured(modelData) ? root.tr("diagnostics.notConfigured") : modelData.message || ""
              color: Commons.Color.popups.text
              font.family: Commons.Style.font.family
              font.pixelSize: diagnosticResult.messageOnly ? Commons.Style.font.bodySmall : Commons.Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }
}
