import QtQuick
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

  function cancelForm() {
    if (root.pending) return
    customNameInput.clear(); customTextArea.text = ""
    root.noticeKey = ""; root.showImportForm = false
    importToggle.forceActiveFocus()
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
      importToggle.forceActiveFocus()
    }, function(err) {
      root.pending = false; root.noticeError = true
      root.noticeKey = err && err.code === "invalid_argument" ? "custom.invalidConfig" : "form.failed"
    })
  }

  implicitWidth: parent ? parent.width : Brand.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Brand.space(10)

    Row {
      width: parent.width
      spacing: Brand.space(8)

      Button {
        id: importToggle
        enabled: !root.pending
        text: root.showImportForm ? root.tr("action.cancel") : "+ " + root.tr("custom.addTitle")
        variant: root.showImportForm ? "subtle" : "primary"
        onClicked: {
          if (root.showImportForm) root.cancelForm()
          else { root.noticeKey = ""; root.showImportForm = true; Qt.callLater(function() { customNameInput.forceActiveFocus() }) }
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
    Rectangle {
      visible: root.showImportForm
      width: parent.width
      height: importCol.implicitHeight + Brand.space(20)
      radius: Brand.cornerRadius
      color: Brand.hoverFill
      border.color: Brand.normalBorderColor
      border.width: Brand.normalBorderWidth

      Column {
        id: importCol
        anchors.fill: parent
        anchors.margins: Brand.space(10)
        spacing: Brand.space(8)

        Text {
          textFormat: Text.PlainText
          text: root.tr("custom.addTitle")
          color: Brand.textPrimary
          font.family: Brand.font.family
          font.pixelSize: Brand.font.title
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.tr("custom.nameLabel")
          wrapMode: Text.WordWrap
          color: Brand.textPrimary
          font.family: Brand.font.family
          font.pixelSize: Brand.font.caption
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
          color: Brand.textPrimary
          font.family: Brand.font.family
          font.pixelSize: Brand.font.caption
        }
        Editor {
          id: customTextArea
          objectName: "vpnCustomJson"
          width: parent.width
          height: Brand.space(110)
          enabled: !root.pending
          label: root.tr("custom.jsonLabel")
          placeholderText: root.tr("custom.jsonLabel")
          onSubmitted: root.submit()
        }

        Row {
          spacing: Brand.space(8)

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
    Rectangle {
      visible: !root.service || !root.service.customConfigs || root.service.customConfigs.length === 0
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
          text: "󰘦"
          color: Brand.textPrimary
          font.family: Brand.iconFamily
          font.pixelSize: Brand.font.display
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.tr("custom.empty")
          color: Brand.textPrimary
          font.family: Brand.font.family
          font.pixelSize: Brand.font.bodySmall
        }
      }
    }

    // Custom configs list
    Repeater {
      model: root.service ? root.service.customConfigs : []

      Rectangle {
        width: column.width
        height: customRow.implicitHeight + Brand.space(16)
        radius: Brand.cornerRadius
        color: modelData.selected ? Brand.selectedFill : (cMouse.containsMouse ? Brand.hoverFill : Brand.normalFill)
        border.color: modelData.selected ? Brand.accentFg : Brand.normalBorderColor
        border.width: modelData.selected ? 1 : Brand.normalBorderWidth

        Row {
          id: customRow
          anchors.fill: parent
          anchors.margins: Brand.space(8)
          spacing: Brand.space(10)

          Rectangle {
            width: Brand.space(18)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.color: modelData.selected ? Brand.accentFg : Brand.textPrimary
            border.width: 2

            Rectangle {
              visible: modelData.selected
              width: Brand.space(8)
              height: width
              radius: width / 2
              anchors.centerIn: parent
              color: Brand.accentFg
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width - btnRow.width - Brand.space(50)
            text: modelData.name || modelData.id
            color: Brand.textPrimary
            font.family: Brand.font.family
            font.pixelSize: Brand.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
          }

          Row {
            id: btnRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Brand.space(6)

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
          anchors.rightMargin: btnRow.width + Brand.space(16)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.service) root.service.selectCustom(modelData.id)
        }
      }
    }
  }
}
