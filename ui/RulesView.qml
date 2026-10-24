import QtQuick
import qs.Commons as Commons
import "../lib/Focus.js" as Focus
import "../lib/I18n.js" as I18n

Item {
  id: root
  objectName: "vpnRulesView"
  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string selectedPriority: service && service.rules ? service.rules.priority : "toggles_first"
  property string importExportFormat: "json"
  property string statusNotice: ""
  property var noticeArgs: []
  property bool noticeError: false
  property bool pending: false
  property string exportedText: ""

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  Connections {
    target: root.service
    function onRulesChanged() {
      rulesTextEdit.text = root.service.rules.text
      root.selectedPriority = root.service.rules.priority
    }
  }

  function failure(err) {
    root.pending = false
    root.noticeError = true
    root.statusNotice = err && err.code === "invalid_argument" ? "rules.invalid" : "form.failed"
  }

  function save() {
    if (!root.service || root.pending) return
    feedback.reveal()
    root.pending = true; root.noticeError = false; root.statusNotice = "operation.pending"
    root.service.setRules(rulesTextEdit.text, root.selectedPriority, function() {
      root.pending = false; root.statusNotice = "rules.saved"
    }, root.failure)
  }

  function importText() {
    if (!root.service || root.pending) return
    feedback.reveal()
    if (!rulesTextEdit.text.trim()) { root.noticeError = true; root.statusNotice = "form.required"; return }
    root.pending = true; root.noticeError = false; root.statusNotice = "operation.pending"
    root.service.importRules(rulesTextEdit.text, root.importExportFormat, function() {
      root.pending = false; root.statusNotice = "rules.importedSuccess"
    }, root.failure)
  }

  function exportText() {
    if (!root.service || root.pending) return
    feedback.reveal()
    root.exportedText = ""
    root.pending = true; root.noticeError = false; root.statusNotice = "operation.pending"
    var format = root.importExportFormat
    root.service.exportRules(format, function(text) {
      root.pending = false; root.exportedText = text
      root.noticeArgs = [format.toUpperCase()]; root.statusNotice = "rules.exportReady"
    }, root.failure)
  }

  implicitWidth: parent ? parent.width : Commons.Style.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Commons.Style.space(10)
    Notice {
      id: feedback
      width: parent.width
      text: root.statusNotice ? root.tr(root.statusNotice, root.noticeArgs) : ""
      error: root.noticeError
      dismissLabel: root.tr("action.dismiss")
      onDismissed: root.statusNotice = ""
    }
    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.tr("rules.priority")
      color: Commons.Color.popups.text
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.title
    }
    Choice {
      width: parent.width
      id: priorityChoice
      objectName: "vpnRulesPriority"
      label: root.tr("rules.priority")
      enabled: !root.pending
      value: root.selectedPriority
      options: [{value:"toggles_first",label:root.tr("rules.priority.toggles_first")},
                {value:"custom_first",label:root.tr("rules.priority.custom_first")}]
      onChanged: function(value) { root.selectedPriority = value }
      onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(priorityChoice) })
    }
    Text {
      textFormat: Text.PlainText
      text: root.tr("rules.textLabel")
      color: Commons.Color.popups.text
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.bodySmall
    }
    Editor {
      id: rulesTextEdit
      objectName: "vpnRulesEditor"
      width: parent.width
      height: Commons.Style.space(140)
      enabled: !root.pending
      label: root.tr("rules.textLabel")
      text: root.service && root.service.rules ? root.service.rules.text : ""
      onSubmitted: root.save()
    }
    Flow {
      width: parent.width
      spacing: Commons.Style.space(8)
      Button {
        text: root.tr("rules.saveBtn")
        variant: "primary"
        enabled: !root.pending
        onClicked: root.save()
      }
      Button {
        text: root.tr("rules.importBtn")
        enabled: !root.pending
        onClicked: root.importText()
      }
      Button {
        text: root.tr("rules.exportBtn")
        enabled: !root.pending
        onClicked: root.exportText()
      }
      Choice {
      width: parent.width
        id: formatChoice
        objectName: "vpnRulesFormat"
        label: root.tr("rules.format")
        enabled: !root.pending
        value: root.importExportFormat
        options: [{value:"json",label:"JSON"},{value:"csv",label:"CSV"},{value:"singbox",label:"SINGBOX"}]
        onChanged: function(value) { root.importExportFormat = value }
        onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(formatChoice) })
      }
    }
    Editor {
      objectName: "vpnRulesExport"
      visible: root.exportedText !== ""
      width: parent.width
      height: Commons.Style.space(110)
      text: root.exportedText
      readOnly: true
      label: root.tr("rules.exportBtn")
    }
  }
}
