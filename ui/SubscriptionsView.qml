import QtQuick
import qs.Commons 1.0
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property bool showAddForm: false
  property string successNotice: ""

  function tr(key, args) {
    var _ = i18nRevision
    return I18n.t(key, args)
  }

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Style.space(10)

    // Top action bar
    Row {
      width: parent.width
      spacing: Style.space(8)

      Button {
        text: "+ " + root.tr("subscriptions.addTitle")
        variant: root.showAddForm ? "subtle" : "primary"
        onClicked: root.showAddForm = !root.showAddForm
      }

      Button {
        text: "󰑤 " + root.tr("subscriptions.refreshAll")
        variant: "normal"
        onClicked: if (root.service) root.service.refreshSubscription()
      }
    }

    // Success notice banner
    Rectangle {
      visible: root.successNotice !== ""
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
          text: root.successNotice
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }

        IconButton {
          icon: "󰅖"
          anchors.verticalCenter: parent.verticalCenter
          onClicked: root.successNotice = ""
        }
      }
    }

    // Add Subscription Form
    Rectangle {
      visible: root.showAddForm
      width: parent.width
      height: addFormCol.implicitHeight + Style.space(20)
      radius: Style.cornerRadius
      color: Style.hoverFill
      border.color: Style.normalBorderColor
      border.width: Style.normalBorderWidth

      Column {
        id: addFormCol
        anchors.fill: parent
        anchors.margins: Style.space(10)
        spacing: Style.space(8)

        Text {
          text: root.tr("subscriptions.addTitle")
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
        }

        TextField {
          id: subNameInput
          width: parent.width
          placeholderText: root.tr("subscriptions.namePlaceholder")
        }

        // Secret URL field (password masked)
        TextField {
          id: subUrlInput
          width: parent.width
          isPassword: true
          placeholderText: root.tr("subscriptions.urlPlaceholder")
        }

        Row {
          spacing: Style.space(8)

          Button {
            text: root.tr("action.add")
            variant: "primary"
            enabled: subNameInput.text.trim().length > 0 && subUrlInput.text.trim().length > 0
            onClicked: {
              if (root.service) {
                var name = subNameInput.text.trim()
                var url = subUrlInput.text.trim()
                // IMMEDIATELY clear sensitive URL from text field property
                subUrlInput.clear()
                subNameInput.clear()
                root.showAddForm = false
                root.successNotice = root.tr("subscriptions.urlClearedNotice")
                root.service.addSubscription(name, url)
              }
            }
          }

          Button {
            text: root.tr("action.cancel")
            variant: "subtle"
            onClicked: {
              subUrlInput.clear()
              subNameInput.clear()
              root.showAddForm = false
            }
          }
        }
      }
    }

    // Empty state
    Rectangle {
      visible: !root.service || !root.service.subscriptions || root.service.subscriptions.length === 0
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
          text: "󰑤"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.tr("subscriptions.empty")
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }
    }

    // Subscriptions List
    Repeater {
      model: root.service ? root.service.subscriptions : []

      Rectangle {
        width: column.width
        height: subRow.implicitHeight + Style.space(16)
        radius: Style.cornerRadius
        color: Style.normalFill
        border.color: Style.normalBorderColor
        border.width: Style.normalBorderWidth

        Row {
          id: subRow
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(10)

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
            width: parent.width - actionsCol.width - Style.space(60)
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: modelData.name || "Subscription"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Text {
              text: root.tr("subscriptions.serversCount", [modelData.serverCount || 0])
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          // Action buttons
          Row {
            id: actionsCol
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            IconButton {
              icon: "󰑤"
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
