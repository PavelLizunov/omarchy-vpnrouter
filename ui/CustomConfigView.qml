import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
import "../lib/I18n.js" as I18n

Item {
  id: root
  objectName: "vpnCustomConfigView"

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property bool showImportForm: false
  property bool pending: false
  property string noticeKey: ""
  property bool noticeError: false

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  function restoreEntryFocus() {
    Qt.callLater(function() { if (root.visible) importToggle.forceActiveFocus() })
  }

  function cancelForm() {
    if (root.pending) return
    customNameInput.clear(); customTextArea.text = ""
    root.noticeKey = ""; root.showImportForm = false
    root.restoreEntryFocus()
  }

  function submit() {
    if (!root.service || root.pending) return
    feedback.reveal()
    root.noticeError = true
    var text = customTextArea.text.trim()
    if (!text || !customNameInput.text.trim()) { root.noticeKey = "form.required"; return }
    try {
      var config = JSON.parse(text)
      if (!config || typeof config !== "object" || Array.isArray(config)) throw new Error("object required")
    } catch (e) { root.noticeKey = "custom.invalidJson"; return }
    root.pending = true; root.noticeError = false; root.noticeKey = "operation.pending"
    root.service.importCustom(customNameInput.text.trim(), text, function() {
      root.pending = false; root.noticeKey = "custom.imported"
      customNameInput.clear(); customTextArea.text = ""; root.showImportForm = false
      root.restoreEntryFocus()
    }, function(err) {
      root.pending = false; root.noticeError = true
      root.noticeKey = err && err.code === "invalid_argument" ? "custom.invalidConfig" : "form.failed"
    })
  }

  implicitWidth: parent ? parent.width : Commons.Style.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Commons.Style.space(10)

    Row {
      visible: !root.showImportForm
      width: parent.width
      spacing: Commons.Style.space(8)

      Button {
        id: importToggle
        enabled: !root.pending
        text: "+ " + root.tr("custom.addTitle")
        variant: "primary"
        onClicked: {
          root.noticeKey = ""; root.showImportForm = true
          Qt.callLater(function() { customNameInput.focusInput() })
        }
      }
    }

    Notice {
      id: feedback
      width: parent.width
      text: root.noticeKey ? root.tr(root.noticeKey) : ""
      error: root.noticeError
      dismissLabel: root.tr("action.dismiss")
      onDismissed: root.noticeKey = ""
    }

    // Collapsible Import Form
    Ui.BorderSurface {
      visible: root.showImportForm
      width: parent.width
      height: importCol.implicitHeight + Commons.Style.space(20)
      radius: Commons.Style.cornerRadius
      color: Commons.Style.hoverFill
      borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)

      Column {
        id: importCol
        anchors.fill: parent
        anchors.margins: Commons.Style.space(10)
        spacing: Commons.Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: root.tr("custom.addTitle")
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.title
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.tr("custom.nameLabel")
          wrapMode: Text.WordWrap
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
        }
        TextField {
          id: customNameInput
          enabled: !root.pending
          width: parent.width
          placeholderText: root.tr("custom.nameLabel")
          onAccepted: customTextArea.forceActiveFocus()
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.tr("custom.jsonLabel")
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
        }
        Editor {
          id: customTextArea
          objectName: "vpnCustomJson"
          width: parent.width
          height: Commons.Style.space(110)
          enabled: !root.pending
          label: root.tr("custom.jsonLabel")
          placeholderText: root.tr("custom.jsonLabel")
          onSubmitted: root.submit()
        }

        Row {
          spacing: Commons.Style.space(8)

          Button {
            text: root.tr("action.import")
            variant: "primary"
            enabled: !root.pending
            onClicked: root.submit()
          }

          Button {
            text: root.tr("action.cancel")
            variant: "subtle"
            enabled: !root.pending
            onClicked: root.cancelForm()
          }
        }
      }
    }

    // Empty state
    Ui.BorderSurface {
      visible: !root.showImportForm && (!root.service || !root.service.customConfigs || root.service.customConfigs.length === 0)
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
          text: "󰘦"
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
          text: root.tr("custom.empty")
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.bodySmall
        }
      }
    }

    // Custom configs list
    Repeater {
      model: root.service ? root.service.customConfigs : []

      Ui.CursorSurface {
        width: column.width
        height: customRow.implicitHeight + Commons.Style.space(16)
        radius: Commons.Style.cornerRadius
        current: modelData.selected === true
        hasCursor: cMouse.containsMouse || activeFocus
        foreground: Commons.Color.popups.text

        Row {
          id: customRow
          anchors.fill: parent
          anchors.margins: Commons.Style.space(8)
          spacing: Commons.Style.space(10)

          Rectangle {
            width: Commons.Style.space(18)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.color: modelData.selected ? Commons.Color.accent : Commons.Color.popups.text
            border.width: 2

            Rectangle {
              visible: modelData.selected
              width: Commons.Style.space(8)
              height: width
              radius: width / 2
              anchors.centerIn: parent
              color: Commons.Color.accent
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width - btnRow.width - Commons.Style.space(50)
            text: modelData.name || modelData.id
            color: Commons.Color.popups.text
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
          }

          Row {
            id: btnRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Commons.Style.space(6)

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
          anchors.rightMargin: btnRow.width + Commons.Style.space(16)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.service) root.service.selectCustom(modelData.id)
        }
      }
    }
  }
}
