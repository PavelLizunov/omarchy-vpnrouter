import QtQuick
import "../lib/Focus.js" as Focus
import qs.Ui as Ui
import qs.Commons as Commons
import "../lib/I18n.js" as I18n

Item {
  id: root
  objectName: "vpnSubscriptionsView"

  property var service: null
  readonly property bool loading: !!service && ["subscriptions.list", "subscriptions.refresh"].indexOf(service.activeOperation) !== -1
  readonly property bool loadFailed: !!service && !!service.lastError && ["subscriptions.list", "subscriptions.refresh"].indexOf(service.lastErrorMethod) !== -1
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
    Qt.callLater(function() { subUrlInput.focusInput() })
  }

  function restoreEntryFocus() {
    Qt.callLater(function() { if (root.visible) addToggle.forceActiveFocus() })
  }

  function cancelForm() {
    if (root.pending) return
    subUrlInput.clear(); subNameInput.clear()
    root.errorKey = ""
    root.showAddForm = false
    root.restoreEntryFocus()
  }

  function submit() {
    if (!root.service || root.pending) return
    feedback.reveal()
    root.successNotice = ""
    var url = subUrlInput.text.trim()
    if (!url) { root.errorKey = "form.required"; return }
    // An empty name falls back to the URL's host.
    var rest = url.indexOf("://") >= 0 ? url.slice(url.indexOf("://") + 3) : url
    var host = rest.split(/[/?#]/)[0].replace(/^.*@/, "")
    host = host.charAt(0) === "[" ? host.slice(1, host.indexOf("]")) : host.split(":")[0]
    var name = subNameInput.text.trim() || host
    if (name.length > 256) { root.errorKey = "form.nameTooLong"; return }
    if (url.length > 2048 || !/^https?:\/\/[^\s/?#]+(?:[/?#][^\s]*)?$/i.test(url)) { root.errorKey = "subscriptions.invalidUrl"; return }
    root.errorKey = ""
    root.pending = true
    root.service.addSubscription(name, url, function() {
      root.pending = false
      subUrlInput.clear(); subNameInput.clear()
      root.showAddForm = false
      root.successNotice = "subscriptions.added"
      root.restoreEntryFocus()
    }, function() { root.pending = false; root.errorKey = "subscriptions.addFailed" })
  }

  implicitWidth: parent ? parent.width : Commons.Style.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Commons.Style.space(10)

    // Top action bar
    Flow {
      visible: !root.showAddForm
      width: parent.width
      spacing: Commons.Style.space(8)

      Button {
        id: addToggle
        enabled: !root.pending
        text: "+ " + root.tr("subscriptions.addTitle")
        variant: "primary"
        onClicked: root.openForm()
      }

      Button {
        icon: "󰓦"
        busy: root.loading
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
    Ui.BorderSurface {
      visible: root.showAddForm
      width: parent.width
      height: addFormCol.implicitHeight + Commons.Style.space(20)
      radius: Commons.Style.cornerRadius
      color: Commons.Style.hoverFill
      borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)

      Column {
        id: addFormCol
        anchors.fill: parent
        anchors.margins: Commons.Style.space(10)
        spacing: Commons.Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: root.tr("subscriptions.addTitle")
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.title
        }

        // Secret URL field (password masked)
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.tr("subscriptions.urlLabel")
          wrapMode: Text.WordWrap
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
        }

        TextField {
          id: subUrlInput
          enabled: !root.pending
          width: parent.width
          isPassword: true
          passwordToggleLabel: root.tr("subscriptions.showUrl")
          passwordHideLabel: root.tr("subscriptions.hideUrl")
          placeholderText: root.tr("subscriptions.urlPlaceholder")
          onAccepted: subNameInput.focusInput()
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.tr("subscriptions.nameLabel")
          wrapMode: Text.WordWrap
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
        }

        TextField {
          id: subNameInput
          enabled: !root.pending
          width: parent.width
          placeholderText: root.tr("subscriptions.namePlaceholder")
          onAccepted: root.submit()
        }

        Row {
          spacing: Commons.Style.space(8)

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
    Ui.BorderSurface {
      visible: !root.showAddForm && (!root.service || !root.service.subscriptions || root.service.subscriptions.length === 0)
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
          text: "󰌹"
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
          text: root.loading ? root.tr("subscriptions.loading") : !root.service || root.loadFailed ? root.tr("state.unavailable") : root.tr("subscriptions.empty")
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.bodySmall
        }
      }
    }

    // Subscriptions List
    Repeater {
      model: root.service ? root.service.subscriptions : []

      Ui.BorderSurface {
        width: column.width
        height: subRow.implicitHeight + Commons.Style.space(16)
        radius: Commons.Style.cornerRadius
        color: Commons.Style.normalFill
        borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)

        Row {
          id: subRow
          anchors.fill: parent
          anchors.margins: Commons.Style.space(8)
          spacing: Commons.Style.space(10)

          // Enable toggle
          Toggle {
            id: subscriptionToggle
            accessibleLabel: root.tr("subscriptions.accessibleToggle", [modelData.name || root.tr("subscriptions.fallbackName")])
            anchors.verticalCenter: parent.verticalCenter
            checked: modelData.enabled !== false
            onToggled: function(val) {
              if (root.service) root.service.enableSubscription(modelData.id, val)
            }
          }

          // Details
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - actionsCol.width - subscriptionToggle.width - parent.spacing * 2
            spacing: Commons.Style.space(2)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: modelData.name || root.tr("subscriptions.fallbackName")
              color: Commons.Color.popups.text
              font.family: Commons.Style.font.family
              font.pixelSize: Commons.Style.font.bodySmall
              id: fullName1
              elide: Text.ElideMiddle
              activeFocusOnTab: truncated
              Accessible.role: Accessible.StaticText
              Accessible.name: text
              onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(fullName1) })
              HoverHandler { id: nameHover1 }
              Ui.PanelToolTip {
                width: Math.min(implicitWidth, Commons.Style.space(360))
                visible: fullName1.truncated && (nameHover1.hovered || fullName1.activeFocus)
                text: fullName1.text
                timeout: 0
                contentItem: Text {
                  width: Math.min(implicitWidth, Commons.Style.space(340))
                  text: fullName1.text
                  textFormat: Text.PlainText
                  wrapMode: Text.Wrap
                  color: Commons.Color.tooltip.text
                  font.family: Commons.Style.font.family
                  font.pixelSize: Commons.Style.font.bodySmall
                  padding: Commons.Style.spacing.controlPaddingX
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              text: typeof modelData.serverCount === "number" ? root.tr("subscriptions.serversCount", [modelData.serverCount]) : root.tr("subscriptions.countUnknown")
              color: Commons.Color.popups.text
              font.family: Commons.Style.font.family
              font.pixelSize: Commons.Style.font.caption
            }
          }

          // Action buttons
          Row {
            id: actionsCol
            anchors.verticalCenter: parent.verticalCenter
            spacing: Commons.Style.space(4)

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
    Button {
      objectName: "vpnLoadMoreSubscriptions"
      text: root.tr("list.loadMore")
      visible: !!root.service && root.service.subscriptions.length < root.service.subscriptionsTotal
      enabled: !!root.service && !root.service.activeOperation
      onClicked: root.service.listSubscriptions(root.service.subscriptions.length, 100)
    }
  }
}
