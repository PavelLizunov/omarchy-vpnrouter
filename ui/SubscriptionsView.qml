import QtQuick
import "../lib/I18n.js" as I18n

Item {
  id: root
  objectName: "vpnSubscriptionsView"

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property bool showAddForm: false
  property string successNotice: ""
  property string errorKey: ""
  property bool pending: false

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  function openForm() {
    if (root.pending) return
    root.errorKey = ""; root.successNotice = ""
    root.showAddForm = true
    Qt.callLater(function() { subNameInput.forceActiveFocus() })
  }

  function cancelForm() {
    if (root.pending) return
    subUrlInput.clear(); subNameInput.clear()
    root.errorKey = ""
    root.showAddForm = false
    addToggle.forceActiveFocus()
  }

  function submit() {
    if (!root.service || root.pending) return
    feedback.reveal()
    root.successNotice = ""
    if (!subNameInput.text.trim() || !subUrlInput.text.trim()) { root.errorKey = "form.required"; return }
    var name = subNameInput.text.trim()
    var url = subUrlInput.text.trim()
    if (name.length > 256) { root.errorKey = "form.nameTooLong"; return }
    if (url.length > 2048 || !/^https?:\/\/[^\s/?#]+(?:[/?#][^\s]*)?$/i.test(url)) { root.errorKey = "subscriptions.invalidUrl"; return }
    root.errorKey = ""
    root.pending = true
    root.service.addSubscription(name, url, function() {
      root.pending = false
      subUrlInput.clear(); subNameInput.clear()
      root.showAddForm = false
      root.successNotice = "subscriptions.added"
      addToggle.forceActiveFocus()
    }, function() { root.pending = false; root.errorKey = "subscriptions.addFailed" })
  }

  implicitWidth: parent ? parent.width : Brand.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Brand.space(10)

    // Top action bar
    Flow {
      width: parent.width
      spacing: Brand.space(8)

      Button {
        id: addToggle
        enabled: !root.pending
        text: root.showAddForm ? root.tr("action.cancel") : "+ " + root.tr("subscriptions.addTitle")
        variant: root.showAddForm ? "subtle" : "primary"
        onClicked: { if (root.showAddForm) root.cancelForm(); else root.openForm() }
      }

      Button {
        icon: "󰓦"
        text: root.tr("subscriptions.refreshAll")
        variant: "normal"
        onClicked: if (root.service) root.service.refreshSubscription()
      }
    }

    Notice {
      id: feedback
      width: parent.width
      text: root.errorKey ? root.tr(root.errorKey) : root.pending ? root.tr("operation.pending") : root.successNotice ? root.tr(root.successNotice) : ""
      error: root.errorKey !== ""
      dismissLabel: root.tr("action.dismiss")
      onDismissed: { root.errorKey = ""; root.successNotice = "" }
    }

    // Add Subscription Form
    Rectangle {
      visible: root.showAddForm
      width: parent.width
      height: addFormCol.implicitHeight + Brand.space(20)
      radius: Brand.cornerRadius
      color: Brand.hoverFill
      border.color: Brand.normalBorderColor
      border.width: Brand.normalBorderWidth

      Column {
        id: addFormCol
        anchors.fill: parent
        anchors.margins: Brand.space(10)
        spacing: Brand.space(8)

        Text {
          textFormat: Text.PlainText
          text: root.tr("subscriptions.addTitle")
          color: Brand.textPrimary
          font.family: Brand.font.family
          font.pixelSize: Brand.font.title
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.tr("subscriptions.nameLabel")
          wrapMode: Text.WordWrap
          color: Brand.textPrimary
          font.family: Brand.font.family
          font.pixelSize: Brand.font.caption
        }

        TextField {
          id: subNameInput
          enabled: !root.pending
          width: parent.width
          placeholderText: root.tr("subscriptions.namePlaceholder")
          onAccepted: subUrlInput.forceActiveFocus()
        }

        // Secret URL field (password masked)
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.tr("subscriptions.urlLabel")
          wrapMode: Text.WordWrap
          color: Brand.textPrimary
          font.family: Brand.font.family
          font.pixelSize: Brand.font.caption
        }

        TextField {
          id: subUrlInput
          enabled: !root.pending
          width: parent.width
          isPassword: true
          passwordToggleLabel: root.tr("subscriptions.showUrl")
          passwordHideLabel: root.tr("subscriptions.hideUrl")
          placeholderText: root.tr("subscriptions.urlPlaceholder")
          onAccepted: root.submit()
        }

        Row {
          spacing: Brand.space(8)

          Button {
            text: root.tr("action.add")
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
      visible: !root.service || !root.service.subscriptions || root.service.subscriptions.length === 0
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
          text: "󰌹"
          color: Brand.textPrimary
          font.family: Brand.iconFamily
          font.pixelSize: Brand.font.display
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.tr("subscriptions.empty")
          color: Brand.textPrimary
          font.family: Brand.font.family
          font.pixelSize: Brand.font.bodySmall
        }
      }
    }

    // Subscriptions List
    Repeater {
      model: root.service ? root.service.subscriptions : []

      Rectangle {
        width: column.width
        height: subRow.implicitHeight + Brand.space(16)
        radius: Brand.cornerRadius
        color: Brand.normalFill
        border.color: Brand.normalBorderColor
        border.width: Brand.normalBorderWidth

        Row {
          id: subRow
          anchors.fill: parent
          anchors.margins: Brand.space(8)
          spacing: Brand.space(10)

          // Enable toggle
          Toggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: modelData.enabled !== false
            onToggled: function(val) {
              if (root.service) root.service.enableSubscription(modelData.id, val)
            }
          }

          // Details
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - actionsCol.width - Brand.space(60)
            spacing: Brand.space(2)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: modelData.name || root.tr("subscriptions.fallbackName")
              color: Brand.textPrimary
              font.family: Brand.font.family
              font.pixelSize: Brand.font.bodySmall
              elide: Text.ElideRight
            }

            Text {
              textFormat: Text.PlainText
              text: typeof modelData.serverCount === "number" ? root.tr("subscriptions.serversCount", [modelData.serverCount]) : root.tr("subscriptions.countUnknown")
              color: Brand.textPrimary
              font.family: Brand.font.family
              font.pixelSize: Brand.font.caption
            }
          }

          // Action buttons
          Row {
            id: actionsCol
            anchors.verticalCenter: parent.verticalCenter
            spacing: Brand.space(4)

            IconButton {
              icon: "󰓦"
              tooltipText: root.tr("action.refresh")
              onClicked: if (root.service) root.service.refreshSubscription(modelData.id)
            }

            IconButton {
              icon: "󰆴"
              variant: "danger"
              tooltipText: root.tr("action.remove")
              onClicked: if (root.service) root.service.removeSubscription(modelData.id)
            }
          }
        }
      }
    }
  }
}
